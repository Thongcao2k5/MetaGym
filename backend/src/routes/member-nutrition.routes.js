import { randomUUID } from 'node:crypto';
import { Router } from 'express';
import { z } from 'zod';
import { createAuthentication } from './users.routes.js';

const dateSchema = z.iso.date();
const entrySchema = z.strictObject({
  eatenAt: z.iso.datetime({ offset: true }),
  mealType: z.enum(['BREAKFAST', 'LUNCH', 'DINNER', 'SNACK']),
  mealName: z.string().trim().min(1).max(150),
  foodId: z.uuid().nullable().optional(),
  quantity: z.number().min(0.01).max(10000),
  unit: z.string().trim().min(1).max(30),
  imageMediaId: z.uuid().nullable().optional(),
  notes: z.string().trim().max(5000).nullable().optional(),
  estimatedCalories: z.number().min(0).max(20000).nullable().optional(),
});
export function vietnamDate(value = new Date()) {
  return new Intl.DateTimeFormat('en-CA', { timeZone: 'Asia/Ho_Chi_Minh',
    year: 'numeric', month: '2-digit', day: '2-digit' }).format(new Date(value));
}
function fail(res, status, code, message) {
  return res.status(status).json({ error: { code, message, details: {} } });
}
async function canWrite(db, memberId) {
  const { rows } = await db.query(`SELECT 1 FROM member_memberships WHERE member_id=$1
    AND status='ACTIVE' AND start_date <= (now() AT TIME ZONE 'Asia/Ho_Chi_Minh')::date
    AND end_date >= (now() AT TIME ZONE 'Asia/Ho_Chi_Minh')::date LIMIT 1`, [memberId]);
  return rows.length > 0;
}
// A day's first observation freezes its recommendation, including a missing menu.
async function snapshot(db, memberId, day) {
  await db.query(`INSERT INTO member_nutrition_days(member_id,log_date,plan_snapshot)
    SELECT $1,$2::date,(SELECT jsonb_build_object('revisionId',v.id,'title',v.title,'items',v.items)
      FROM nutrition_guide_revisions v JOIN coach_relationships r ON r.id=v.relationship_id
      WHERE v.member_id=$1 AND v.effective_at <= LEAST(now(),
        (($2::date + 1)::timestamp AT TIME ZONE 'Asia/Ho_Chi_Minh') - interval '1 microsecond')
      AND (r.ended_at IS NULL OR r.ended_at > ($2::date::timestamp AT TIME ZONE 'Asia/Ho_Chi_Minh'))
      AND r.started_at <= (($2::date + 1)::timestamp AT TIME ZONE 'Asia/Ho_Chi_Minh')
      ORDER BY v.effective_at DESC,v.id DESC LIMIT 1)
    ON CONFLICT DO NOTHING`, [memberId, day]);
  const { rows: [row] } = await db.query(
    'SELECT plan_snapshot FROM member_nutrition_days WHERE member_id=$1 AND log_date=$2::date', [memberId, day]);
  return row.plan_snapshot;
}
export function compareMeal(plan, entries, weekday, meal) {
  if (meal === 'SNACK') return { status:'UNREGULATED', message:'Bữa phụ được ghi riêng, không tự coi là khác thực đơn.' };
  if (!plan) return { status:'INSUFFICIENT', message:'Chưa đủ dữ liệu để đối chiếu: chưa có thực đơn có hiệu lực.' };
  const expected = plan.items.filter(item => item.day === weekday && item.meal === meal);
  const actual = entries.filter(item => item.mealType === meal);
  if (!expected.length || !actual.length || actual.some(item => !item.foodId || item.unit !== 'g' || !(item.quantity > 0))) {
    return { status:'INSUFFICIENT', message:'Chưa đủ dữ liệu để đối chiếu: cần món danh mục, gram thực tế và thực đơn cho cùng bữa.' };
  }
  const totals = items => {
    const map = new Map();
    for (const item of items) map.set(item.foodId,(map.get(item.foodId) ?? 0) + Number(item.grams ?? item.quantity));
    return map;
  };
  const wanted=totals(expected), eaten=totals(actual);
  return { status:'DIFFERENCES', message:'Chênh lệch khẩu phần; không kết luận mức độ tuân thủ.',
    differences:[...new Set([...wanted.keys(),...eaten.keys()])].map(foodId => ({ foodId,
      foodName:expected.find(item=>item.foodId===foodId)?.foodName ?? actual.find(item=>item.foodId===foodId)?.mealName,
      suggestedGrams:wanted.get(foodId) ?? 0, actualGrams:eaten.get(foodId) ?? 0,
      deltaGrams:(eaten.get(foodId) ?? 0)-(wanted.get(foodId) ?? 0) })) };
}
export function createMemberNutritionRouter({ database, jwtSecret }) {
  const router = Router();
  router.use('/member/nutrition', createAuthentication({ database, jwtSecret }), (req,res,next) => {
    if (req.authUser.role !== 'MEMBER') return fail(res,403,'FORBIDDEN','Nhật ký ăn chỉ dành cho chính Member.');
    next();
  });
  router.get('/member/nutrition/foods', async (_req,res) => {
    try {
      const { rows } = await database.query(`SELECT id,name,kcal_per_100g::float8 AS "kcalPer100g"
        FROM nutrition_foods WHERE active ORDER BY name,id`);
      return res.json({ data: rows });
    } catch {
      return fail(res,500,'INTERNAL_SERVER_ERROR','Không tải được danh mục thực phẩm. Vui lòng thử lại.');
    }
  });
  router.get('/member/nutrition/day', async (req,res) => {
    const parsed = z.strictObject({ date: dateSchema.optional() }).safeParse(req.query);
    if (!parsed.success) return fail(res,422,'VALIDATION_ERROR','Ngày không hợp lệ.');
    const day = parsed.data.date ?? vietnamDate();
    if (day > vietnamDate()) return fail(res,422,'VALIDATION_ERROR','Chưa thể xem ngày tương lai.');
    const member = req.authUser.id;
    try {
      const plan = await snapshot(database,member,day);
      const { rows } = await database.query(`SELECT id,meal_name AS "mealName",meal_type AS "mealType",
        image_media_id AS "imageMediaId",eaten_at AS "eatenAt",food_id AS "foodId",quantity::float8,unit,notes,
        COALESCE(CASE WHEN unit='g' AND food_id IS NOT NULL THEN quantity*kcal_per_100g/100 END, estimated_calories)::float8 AS kcal
        FROM meal_logs WHERE member_id=$1
        AND (eaten_at AT TIME ZONE 'Asia/Ho_Chi_Minh')::date=$2::date ORDER BY eaten_at,id`,[member,day]);
      const { rows: relationships } = await database.query(`SELECT status FROM coach_relationships
        WHERE member_id=$1 AND status IN ('ACTIVE','PAUSED') LIMIT 1`,[member]);
      const hasActiveMembership = await canWrite(database,member);
      res.json({ data: { date:day,hasActiveMembership,canWrite:hasActiveMembership && day === vietnamDate(),
        relationshipStatus:relationships[0]?.status ?? 'NONE',plan,entries:rows,
        comparisons:Object.fromEntries(['BREAKFAST','LUNCH','DINNER','SNACK'].map(meal=>[meal,
          compareMeal(plan,rows,new Date(day+'T12:00:00+07:00').getUTCDay() || 7,meal)])) } });
    } catch { return fail(res,500,'INTERNAL_SERVER_ERROR','Không tải được nhật ký ăn. Vui lòng thử lại.'); }
  });
  const saveEntry = async (req,res) => {
    const editing = req.method === 'PATCH';
    if (editing && !z.uuid().safeParse(req.params.id).success) return fail(res,422,'VALIDATION_ERROR','Mã món không hợp lệ.');
    const parsed = entrySchema.safeParse(req.body);
    if (!parsed.success) return fail(res,422,'VALIDATION_ERROR','Thông tin món ăn không hợp lệ.');
    const item=parsed.data; const day=vietnamDate(item.eatenAt);
    if (day !== vietnamDate()) return fail(res,409,'DAY_LOCKED','Chỉ được ghi và sửa món trong hôm nay theo giờ Việt Nam.');
    const client=await database.connect();
    try {
      await client.query('BEGIN');
      if (!await canWrite(client,req.authUser.id)) {
        await client.query('ROLLBACK');
        return fail(res,403,'MEMBERSHIP_REQUIRED','Cần gói Gym ACTIVE để ghi; lịch sử vẫn xem được.');
      }
      let existing = null;
      if (editing) {
        const { rows:[row] } = await client.query(`SELECT *,
          (eaten_at AT TIME ZONE 'Asia/Ho_Chi_Minh')::date =
          (clock_timestamp() AT TIME ZONE 'Asia/Ho_Chi_Minh')::date AS editable
          FROM meal_logs WHERE id=$1 AND member_id=$2 FOR UPDATE`,[req.params.id,req.authUser.id]);
        existing = row ?? null;
        if (!existing || !existing.editable) {
          await client.query('ROLLBACK');
          return fail(res,existing ? 409 : 404,existing ? 'DAY_LOCKED' : 'NOT_FOUND',
            existing ? 'Ngày đã qua chỉ được xem, không sửa hoặc xóa.' : 'Không tìm thấy món ăn.');
        }
      }
      if (item.imageMediaId) {
        const {rows} = await client.query("SELECT 1 FROM media_assets WHERE id=$1 AND owner_id=$2 AND purpose='MEAL_PHOTO' AND status='READY'",[item.imageMediaId,req.authUser.id]);
        if (!rows.length) { await client.query('ROLLBACK'); return fail(res,422,'VALIDATION_ERROR','Ảnh không hợp lệ.'); }
      }
      let name=item.mealName; let kcal=null;
      if (item.foodId) {
        const keepExistingFood = editing && existing.food_id === item.foodId;
        const { rows:[food] }=await client.query(`SELECT name,kcal_per_100g,active FROM nutrition_foods
          WHERE id=$1 FOR SHARE`,[item.foodId]);
        if (!food || (!food.active && !keepExistingFood) || item.unit !== 'g') {
          await client.query('ROLLBACK');
          return fail(res,422,'VALIDATION_ERROR',
            item.unit !== 'g'
              ? 'Món danh mục cần khẩu phần theo gram.'
              : 'Món danh mục không tồn tại hoặc đã ngừng sử dụng.');
        }
        name=food.name; kcal=food.kcal_per_100g;
      }
      await snapshot(client,req.authUser.id,day);
      const id=editing ? req.params.id : randomUUID();
      const estimatedCalories = item.foodId ? null : (item.estimatedCalories != null ? Math.round(item.estimatedCalories) : null);
      const values=[id,req.authUser.id,item.eatenAt,item.mealType,name,item.foodId ?? null,item.quantity,item.unit,kcal,item.notes ?? null,item.imageMediaId ?? null,estimatedCalories];
      const result = editing ? await client.query(`UPDATE meal_logs SET eaten_at=$3,meal_type=$4,meal_name=$5,
        food_id=$6,quantity=$7,unit=$8,kcal_per_100g=$9,notes=$10,image_media_id=$11,estimated_calories=$12
        WHERE id=$1 AND member_id=$2
        AND (eaten_at AT TIME ZONE 'Asia/Ho_Chi_Minh')::date=(clock_timestamp() AT TIME ZONE 'Asia/Ho_Chi_Minh')::date
        AND ($3::timestamptz AT TIME ZONE 'Asia/Ho_Chi_Minh')::date=(clock_timestamp() AT TIME ZONE 'Asia/Ho_Chi_Minh')::date
        RETURNING id`,values) : await client.query(`INSERT INTO meal_logs(id,member_id,eaten_at,meal_type,meal_name,food_id,quantity,unit,kcal_per_100g,notes,image_media_id,estimated_calories)
        SELECT $1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12
        WHERE ($3::timestamptz AT TIME ZONE 'Asia/Ho_Chi_Minh')::date=(clock_timestamp() AT TIME ZONE 'Asia/Ho_Chi_Minh')::date RETURNING id`,
      values);
      if (!result.rows.length) {
        await client.query('ROLLBACK');
        return fail(res,409,'DAY_LOCKED','Ngày đã qua chỉ được xem, không sửa hoặc xóa.');
      }
      await client.query('COMMIT');
      return res.status(editing ? 200 : 201).json({ data:{id} });
    } catch {
      await client.query('ROLLBACK').catch(()=>{});
      return fail(res,500,'SAVE_FAILED','Không lưu được món ăn. Vui lòng thử lại.');
    } finally { client.release(); }
  };
  router.post('/member/nutrition/entries',saveEntry);
  router.patch('/member/nutrition/entries/:id',saveEntry);
  router.delete('/member/nutrition/entries/:id',async (req,res) => {
    if (!z.uuid().safeParse(req.params.id).success) return fail(res,422,'VALIDATION_ERROR','Mã món không hợp lệ.');
    const client=await database.connect();
    try {
      await client.query('BEGIN');
      if (!await canWrite(client,req.authUser.id)) {
        await client.query('ROLLBACK');
        return fail(res,403,'MEMBERSHIP_REQUIRED','Cần gói Gym ACTIVE để xóa món.');
      }
      const { rows:[existing] }=await client.query(`SELECT *,
        (eaten_at AT TIME ZONE 'Asia/Ho_Chi_Minh')::date=(clock_timestamp() AT TIME ZONE 'Asia/Ho_Chi_Minh')::date AS editable
        FROM meal_logs WHERE id=$1 AND member_id=$2 FOR UPDATE`,[req.params.id,req.authUser.id]);
      if (!existing || !existing.editable) {
        await client.query('ROLLBACK');
        return fail(res,existing ? 409 : 404,existing ? 'DAY_LOCKED' : 'NOT_FOUND',
          existing ? 'Ngày đã qua chỉ được xem, không sửa hoặc xóa.' : 'Không tìm thấy món ăn.');
      }
      await client.query('DELETE FROM progress_comments WHERE meal_log_id=$1 AND member_id=$2',[req.params.id,req.authUser.id]);
      const result=await client.query(`DELETE FROM meal_logs WHERE id=$1 AND member_id=$2
        AND (eaten_at AT TIME ZONE 'Asia/Ho_Chi_Minh')::date=(clock_timestamp() AT TIME ZONE 'Asia/Ho_Chi_Minh')::date RETURNING id`,[req.params.id,req.authUser.id]);
      if (!result.rows.length) { await client.query('ROLLBACK'); return fail(res,409,'DAY_LOCKED','Ngày đã qua chỉ được xem.'); }
      await client.query('COMMIT');
      return res.json({data:{id:req.params.id}});
    } catch {
      await client.query('ROLLBACK').catch(()=>{});
      return fail(res,500,'DELETE_FAILED','Không xóa được món ăn. Vui lòng thử lại.');
    } finally { client.release(); }
  });
  return router;
}

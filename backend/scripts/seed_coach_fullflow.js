import dotenv from 'dotenv';
import bcrypt from 'bcryptjs';
import { createHash, randomBytes } from 'node:crypto';
import { mkdir, readFile, writeFile } from 'node:fs/promises';
import { homedir } from 'node:os';
import path from 'node:path';
import { createDatabasePool } from '../src/config/database.js';
import { hasCoachCapacity } from '../src/services/coach-capacity.js';

// Additive fixtures only. Stable IDs make reruns preserve changes made while testing.
dotenv.config({ quiet: true });
const APPLY = process.argv.includes('--apply');
const targetUrl = new URL(process.env.DATABASE_URL);
if (!['localhost', '127.0.0.1', '[::1]'].includes(targetUrl.hostname)) {
  throw new Error('This fixture script only supports a local test database.');
}
const outputDir = path.join(homedir(), 'Documents', 'MetaGym-Coach-Test');
const credentialFile = path.join(outputDir, 'accounts.json');
let saved;
try { saved = JSON.parse(await readFile(credentialFile, 'utf8')); }
catch (error) { if (error.code !== 'ENOENT') throw error; }
const password = process.env.COACH_TEST_PASSWORD || saved?.password || `CoachTest!${randomBytes(8).toString('hex')}`;
if (saved && process.env.COACH_TEST_PASSWORD && saved.password !== process.env.COACH_TEST_PASSWORD) {
  throw new Error('Existing test credentials are preserved; COACH_TEST_PASSWORD must match the saved password.');
}
const pool = createDatabasePool();
const client = await pool.connect();
const inserted = {};
const id = (label) => {
  const h = createHash('sha256').update(`metagym-coach-fullflow-v1:${label}`).digest('hex');
  return `c0ac2026-${h.slice(8, 12)}-4${h.slice(13, 16)}-8${h.slice(17, 20)}-${h.slice(20, 32)}`;
};
const members = [
  ['gain', 'TEST Coach · Nguyễn Thanh Bình', 'Tăng cơ, giáo trình và thực đơn đầy đủ', 'ACTIVE'],
  ['lose', 'TEST Coach · Trần Thị Ngọc Mai Anh - Học viên giảm mỡ và cải thiện sức bền', 'Kiểm tra tên dài, nhiều lịch hẹn, chấm dứt quan hệ', 'ACTIVE'],
  ['expiry', 'TEST Coach · Lê Minh Dũng', 'Gói PT còn 1 buổi và sắp hết hạn', 'ACTIVE'],
  ['new', 'TEST Coach · Phạm Khánh Linh', 'Học viên mới, chưa có giáo trình/thực đơn', 'ACTIVE'],
  ['paused', 'TEST Coach · Võ Thu Hạnh', 'Tạm dừng do gói Gym hết hạn', 'PAUSED'],
  ['ended', 'TEST Coach · Đặng Hữu Phúc', 'Quan hệ và gói PT đã kết thúc', 'ENDED'],
  ['pending1', 'TEST Coach · Bùi Hải Nam', 'Yêu cầu chờ duyệt thứ nhất', 'PENDING'],
  ['pending2', 'TEST Coach · Đỗ Thảo Vy', 'Yêu cầu chờ duyệt thứ hai', 'PENDING'],
  ['pending3', 'TEST Coach · Hoàng Gia Bảo', 'Yêu cầu chờ duyệt thứ ba', 'PENDING'],
  ['rejected', 'TEST Coach · Nguyễn Yến Nhi', 'Yêu cầu đã từ chối', 'REJECTED'],
  ['cancelled', 'TEST Coach · Trương Đức Huy', 'Yêu cầu đã hủy', 'CANCELLED'],
  ['purchase', 'TEST Coach · Lý An Khang', 'Có gói Gym, chưa có Coach: thử mua PT', 'UNASSIGNED'],
  ['health', 'TEST Coach · Đinh Bảo Ngọc', 'Chưa khai báo sức khỏe: kiểm tra điều kiện đầu vào', 'UNASSIGNED'],
].map(([key, name, scenario, state]) => ({ key, name, scenario, state,
  id: id(`member:${key}`), email: `${key}@coachtest.metagym.local` }));

async function insert(table, record, conflict = 'ON CONFLICT DO NOTHING') {
  const keys = Object.keys(record);
  const values = Object.values(record);
  const result = await client.query(
    `INSERT INTO ${table} (${keys.join(',')}) VALUES (${keys.map((_, i) => `$${i + 1}`).join(',')}) ${conflict} RETURNING 1`, values,
  );
  inserted[table] = (inserted[table] || 0) + result.rowCount;
  return result.rowCount > 0;
}

try {
  await client.query('BEGIN');
  await client.query("SELECT pg_advisory_xact_lock(hashtext('metagym-coach-fullflow-v1'))");
  const coach = (await client.query(
    "SELECT u.*, c.member_limit FROM users u JOIN coach_profiles c ON c.user_id=u.id WHERE u.email='coach@metagym.local' AND u.role='COACH' AND u.status='ACTIVE' FOR UPDATE OF u",
  )).rows[0];
  if (!coach) throw new Error('Active Coach Demo not found; refusing to seed an unrelated account.');
  const admin = (await client.query("SELECT id FROM users WHERE role='ADMIN' AND status='ACTIVE' LIMIT 1")).rows[0];
  const gymPlan = (await client.query("SELECT * FROM membership_plans WHERE status='ACTIVE' AND duration_days>=90 ORDER BY duration_days,price LIMIT 1")).rows[0];
  const packages = new Map((await client.query('SELECT * FROM coach_package_plans')).rows.map((p) => [p.code, p]));
  if (!admin || !gymPlan || !packages.has('BASIC') || !packages.has('STANDARD')) throw new Error('Required baseline catalog is missing.');
  const today = (await client.query("SELECT (now() AT TIME ZONE 'Asia/Ho_Chi_Minh')::date::text AS day")).rows[0].day;
  const day = (offset) => {
    const value = new Date(`${today}T00:00:00Z`);
    value.setUTCDate(value.getUTCDate() + offset);
    return value.toISOString().slice(0, 10);
  };
  const at = (offset, time = '08:00') => new Date(`${day(offset)}T${time}:00+07:00`).toISOString();
  const before = (iso, minutes) => new Date(Date.parse(iso) - minutes * 60000).toISOString();
  const existingFixture = (await client.query('SELECT password_hash FROM users WHERE id=$1', [members[0].id])).rows[0];
  if (existingFixture && !saved && (!process.env.COACH_TEST_PASSWORD || !await bcrypt.compare(password, existingFixture.password_hash))) {
    throw new Error('Fixture accounts exist but the credential file is missing. Restore accounts.json or supply the original COACH_TEST_PASSWORD.');
  }
  const hash = await bcrypt.hash(password, 12);

  for (const member of members) {
    const collision = (await client.query('SELECT id FROM users WHERE email=$1', [member.email])).rows[0];
    if (collision && collision.id !== member.id) throw new Error(`Test email already belongs to another account: ${member.email}`);
    await insert('users', { id: member.id, email: member.email, password_hash: hash,
      role: 'MEMBER', full_name: member.name, status: 'ACTIVE' });
    await insert('member_profiles', { user_id: member.id, date_of_birth: '1998-06-15',
      gender: ['lose', 'new', 'paused', 'health'].includes(member.key) ? 'FEMALE' : 'MALE',
      height_cm: 170, weight_kg: member.key === 'lose' ? 76 : 65,
      body_fat_percent: 22, fitness_goal: `[COACH_TEST] ${member.scenario}`,
      experience_level: 'BEGINNER', activity_level: 'MODERATE',
      health_notes: '[COACH_TEST] Hồ sơ sức khỏe giả lập, không phải thông tin y tế thực.',
      injury_notes: member.key === 'lose' ? '[COACH_TEST] Lưu ý đầu gối trái khi tập.' : 'Không khai báo chấn thương.',
      dietary_preferences: 'Thực đơn mẫu cân bằng, dùng cho kiểm thử.',
      health_declaration_completed_at: member.key === 'health' ? null : at(-15),
    });
    const paused = member.key === 'paused';
    const starts = paused ? -gymPlan.duration_days : member.key === 'ended' ? -75 : -14;
    const ends = starts + gymPlan.duration_days - 1;
    await insert('payments', { id: id(`gym-payment:${member.key}`), member_id: member.id,
      plan_id: gymPlan.id, plan_name_snapshot: gymPlan.name, duration_days_snapshot: gymPlan.duration_days,
      amount: gymPlan.price, method: 'FRONT_DESK', status: 'SUCCESS',
      transaction_code: `TESTCOACH-${member.key}`, idempotency_key: `coach-fullflow:${member.key}`,
      request_hash: createHash('sha256').update(`coach-test:${member.key}`).digest('hex'),
      created_by: admin.id, decided_by: admin.id, created_at: at(starts), confirmed_at: at(starts), decided_at: at(starts),
    });
    await insert('member_memberships', { id: id(`gym-membership:${member.key}`), member_id: member.id,
      plan_id: gymPlan.id, source_payment_id: id(`gym-payment:${member.key}`),
      start_date: day(starts), end_date: day(ends), status: paused ? 'EXPIRED' : 'ACTIVE',
      activated_at: at(starts), expired_at: paused ? at(-1, '23:59') : null,
    });
  }

  // A separate empty Coach lets the user test profile/schedule setup without editing commitments.
  const setupCoach = { id: id('coach:setup'), email: 'schedule@coachtest.metagym.local', name: 'TEST Coach · Thiết lập lịch' };
  const setupCollision = (await client.query('SELECT id FROM users WHERE email=$1', [setupCoach.email])).rows[0];
  if (setupCollision && setupCollision.id !== setupCoach.id) throw new Error('Setup Coach email belongs to another account.');
  await insert('users', { id: setupCoach.id, email: setupCoach.email, password_hash: hash,
    role: 'COACH', full_name: setupCoach.name, status: 'ACTIVE' });
  await insert('coach_profiles', { user_id: setupCoach.id, biography: '[COACH_TEST] Tài khoản trống để thử sửa hồ sơ và thiết lập lịch.',
    specialties: ['Sức mạnh', 'Thể lực'], qualifications: 'Chứng chỉ mẫu phục vụ kiểm thử',
    experience_years: 3, availability_note: 'Chưa cấu hình lịch, hãy thiết lập trên ứng dụng.', member_limit: 8 });

  for (let weekday = 1; weekday <= 7; weekday++) {
    for (const minute of [510, 600, 690, 780, 870]) {
      const overlap = (await client.query(
        'SELECT 1 FROM coach_weekly_slots WHERE coach_id=$1 AND weekday=$2 AND start_minute<$3+90 AND end_minute>$3',
        [coach.id, weekday, minute],
      )).rowCount;
      if (!overlap) await insert('coach_weekly_slots', { id: id(`slot:${weekday}:${minute}`), coach_id: coach.id, weekday, start_minute: minute });
    }
  }

  for (const member of members) {
    if (member.state === 'UNASSIGNED') continue;
    const relational = ['ACTIVE', 'PAUSED', 'ENDED'].includes(member.state);
    const requestStatus = relational ? 'ACCEPTED' : member.state;
    await insert('coach_requests', { id: id(`request:${member.key}`), member_id: member.id, coach_id: coach.id,
      message: `[COACH_TEST] ${member.scenario}. Mong được Coach hướng dẫn và xếp lịch phù hợp.`,
      status: requestStatus, requested_at: at(member.key === 'ended' ? -63 : relational ? -25 : -1, '09:00'),
      decided_at: requestStatus === 'PENDING' ? null : at(member.key === 'ended' ? -62 : relational ? -24 : -1, '10:00'),
      rejection_reason: requestStatus === 'REJECTED' ? '[COACH_TEST] Khung giờ mong muốn chưa phù hợp.' : null,
    });
    if (!relational) continue;
    member.relationshipId = id(`relationship:${member.key}`);
    await insert('coach_relationships', { id: member.relationshipId, member_id: member.id, coach_id: coach.id,
      source_request_id: id(`request:${member.key}`), status: member.state,
      started_at: at(member.key === 'ended' ? -61 : -23),
      paused_at: member.state === 'PAUSED' ? at(-1) : null,
      pause_reason: member.state === 'PAUSED' ? 'MEMBERSHIP_EXPIRED' : null,
      ended_at: member.state === 'ENDED' ? at(-31, '18:00') : null,
      ended_by: member.state === 'ENDED' ? member.id : null,
      end_reason: member.state === 'ENDED' ? '[COACH_TEST] Đã hoàn thành gói PT.' : null,
    });
    const key = member.key;
    const plan = packages.get(key === 'lose' ? 'STANDARD' : 'BASIC');
    const startOffset = ({ gain: -20, lose: -10, expiry: -27, new: 0, paused: -10, ended: -60 })[key];
    const remaining = ({ gain: 8, lose: 18, expiry: 1, new: 10, paused: 10, ended: 0 })[key];
    member.startOffset = startOffset;
    member.entitlementId = id(`entitlement:${key}`);
    async function entitlement(suffix, selected, status, start, remainder) {
      const holdId = id(`hold:${suffix}`);
      await insert('coach_payment_holds', { id: holdId, member_id: member.id, coach_id: coach.id,
        plan_code: selected.code, plan_name: selected.name, session_count: selected.session_count,
        duration_days: selected.duration_days, amount: selected.price, request_key: id(`hold-key:${suffix}`),
        status: 'CONSUMED', created_at: at(start ?? 0, '07:00'), expires_at: at(start ?? 0, '07:15') });
      await insert('coach_entitlements', { id: id(`entitlement:${suffix}`), hold_id: holdId,
        relationship_id: member.relationshipId, member_id: member.id, coach_id: coach.id,
        status, total_sessions: selected.session_count, remaining_sessions: remainder, duration_days: selected.duration_days,
        starts_on: start === null ? null : day(start),
        original_ends_on: start === null ? null : day(start + selected.duration_days - 1),
        ends_on: start === null ? null : day(start + selected.duration_days - 1),
        ended_at: status === 'ENDED' ? at(start + selected.duration_days - 1, '18:00') : null });
    }
    await entitlement(key, plan, key === 'ended' ? 'ENDED' : 'ACTIVE', startOffset, remaining);
    if (key === 'gain') await entitlement('gain-renewal', packages.get('BASIC'), 'QUEUED', null, 10);
  }

  const exercises = [
    ['squat', 'TEST · Goblet Squat', ['Đùi', 'Mông']],
    ['press', 'TEST · Dumbbell Chest Press', ['Ngực', 'Tay sau']],
    ['row', 'TEST · Seated Cable Row', ['Lưng', 'Tay trước']],
    ['plank', 'TEST · Plank', ['Bụng']],
    ['walk', 'TEST · Đi bộ trên máy', ['Toàn thân']],
    ['hinge', 'TEST · Romanian Deadlift', ['Đùi sau', 'Mông']],
  ];
  for (const [key, name, muscles] of exercises) await insert('exercises', {
    id: id(`exercise:${key}`), name, target_muscles: muscles, description: '[COACH_TEST] Bài tập mẫu cho kiểm thử giao diện.',
    instructions: 'Khởi động, thực hiện chậm và theo hướng dẫn của Coach.', safety_notes: 'Dừng khi đau hoặc chóng mặt.',
    difficulty: 'BEGINNER', status: 'ACTIVE', created_by: admin.id });
  const foods = [ ['rice', 'TEST · Cơm gạo lứt', 111], ['chicken', 'TEST · Ức gà', 165],
    ['oat', 'TEST · Yến mạch', 389], ['milk', 'TEST · Sữa không đường', 60],
    ['fish', 'TEST · Cá hồi', 208], ['vegetable', 'TEST · Rau xanh', 35] ];
  for (const [key, name, kcal] of foods) await insert('nutrition_foods', { id: id(`food:${key}`), name, kcal_per_100g: kcal, active: true });

  for (const member of members.filter((m) => m.relationshipId && m.key !== 'new')) {
    const states = member.state === 'ACTIVE' ? ['ARCHIVED', 'ACTIVE', 'DRAFT'] : ['ARCHIVED'];
    for (const [index, status] of states.entries()) {
      const label = ({ ARCHIVED: 'Lịch sử', ACTIVE: 'Đang áp dụng', DRAFT: 'Bản nháp' })[status];
      const planId = id(`training:${member.key}:${status}`);
      await insert('training_plans', { id: planId, relationship_id: member.relationshipId, member_id: member.id, coach_id: coach.id,
        title: `TEST · ${label} · ${member.key === 'lose' ? 'Giảm mỡ và tăng sức bền toàn thân trong 8 tuần' : 'Nền tảng sức mạnh 4 tuần'}`,
        goal: `[COACH_TEST] ${member.scenario}`, version: index + 1, status,
        start_date: day(status === 'ARCHIVED' ? -21 : 0), end_date: day(status === 'ARCHIVED' ? -1 : 27),
        published_at: status === 'DRAFT' ? null : at(status === 'ARCHIVED' ? -21 : -1),
        archived_at: status === 'ARCHIVED' ? at(-1) : null });
      for (let d = 1; d <= 3; d++) {
        const dayId = id(`training-day:${member.key}:${status}:${d}`);
        await insert('training_plan_days', { id: dayId, plan_id: planId, day_number: d,
          title: ['Thân dưới và core', 'Thân trên và sức mạnh', 'Toàn thân và cardio'][d - 1],
          notes: '[COACH_TEST] Kiểm tra chi tiết bài tập, hướng dẫn và thực đơn theo ngày.',
          scheduled_date: day((status === 'ARCHIVED' ? -7 : 0) + (d - 1) * 2) });
        for (let e = 0; e < 3; e++) {
          const [exerciseKey, name] = exercises[(d + e - 1) % exercises.length];
          await insert('training_plan_exercises', { id: id(`plan-exercise:${dayId}:${e}`), plan_day_id: dayId,
            exercise_id: id(`exercise:${exerciseKey}`), exercise_name_snapshot: name,
            instructions_snapshot: 'Thực hiện có kiểm soát, theo dõi nhịp thở.', safety_notes_snapshot: 'Không cố tập khi đau.',
            display_order: e + 1, sets: 3, reps: '10–12', rest_seconds: 60,
            weight_guidance: 'Mức nhẹ theo hướng dẫn Coach', notes: '[COACH_TEST] Có dữ liệu dài để kiểm tra xuống dòng.' });
        }
        for (const [e, type] of ['BREAKFAST', 'LUNCH', 'DINNER'].entries()) await insert('training_plan_day_meals', {
          id: id(`day-meal:${dayId}:${e}`), plan_day_id: dayId, display_order: e + 1, meal_type: type,
          scheduled_time: ['07:00', '12:00', '18:30'][e], title: ['Bữa sáng mẫu', 'Bữa trưa mẫu', 'Bữa tối mẫu'][e], notes: '[COACH_TEST] Thực đơn demo phục vụ kiểm thử.' });
      }
      const items = Array.from({ length: 7 }, (_, d) => ['BREAKFAST', 'LUNCH', 'DINNER'].flatMap((meal, mealIndex) =>
        [foods[mealIndex * 2], foods[mealIndex * 2 + 1]].map(([key, name, kcal], j) => ({
          day: d + 1, meal, foodId: id(`food:${key}`), grams: j ? 150 : 100,
          foodName: name, kcalPer100g: kcal })))).flat();
      await insert('nutrition_guides', { id: id(`nutrition:${member.key}:${status}`), relationship_id: member.relationshipId,
        member_id: member.id, coach_id: coach.id, title: `TEST · ${label} · Thực đơn cân bằng 7 ngày`,
        content: '[COACH_TEST] Thực đơn giả lập có 7 ngày, 3 bữa/ngày, 2 món/bữa. Không dùng làm chỉ định dinh dưỡng.',
        meal_items: JSON.stringify(items), version: index + 1, status,
        published_at: status === 'DRAFT' ? null : at(-14), archived_at: status === 'ARCHIVED' ? at(-1) : null });
    }
  }

  async function booking(member, label, status, fromOffset, toOffset, { charged = false, future = false } = {}) {
    const bookingId = id(`booking:${member.key}:${label}`);
    if ((await client.query('SELECT 1 FROM coach_bookings WHERE id=$1', [bookingId])).rowCount) return;
    const chosen = (await client.query(
      `WITH candidates AS (
        SELECT (d::date + make_interval(mins=>s.start_minute)) AT TIME ZONE 'Asia/Ho_Chi_Minh' AS ts
        FROM generate_series($2::date,$3::date,interval '1 day') d
        JOIN coach_weekly_slots s ON s.coach_id=$1 AND s.weekday=extract(isodow from d)
      ) SELECT ts FROM candidates c WHERE (NOT $5::boolean OR c.ts>statement_timestamp())
      AND NOT EXISTS (SELECT 1 FROM coach_slot_blocks x WHERE x.coach_id=$1 AND x.starts_at=c.ts)
      AND NOT EXISTS (SELECT 1 FROM coach_bookings b WHERE
        (b.coach_id=$1 AND b.status IN ('BOOKED','COMPLETED') AND b.starts_at<c.ts+interval '90 minutes' AND b.ends_at>c.ts)
        OR (b.member_id=$4 AND b.booking_date=(c.ts AT TIME ZONE 'Asia/Ho_Chi_Minh')::date
            AND (b.status IN ('BOOKED','COMPLETED') OR b.charged_at IS NOT NULL)))
      AND NOT EXISTS (SELECT 1 FROM training_sessions t JOIN coach_relationships r ON r.id=t.relationship_id
        WHERE r.coach_id=$1 AND t.status='SCHEDULED' AND t.scheduled_start_at<c.ts+interval '90 minutes'
          AND COALESCE(t.scheduled_end_at,t.scheduled_start_at+interval '90 minutes')>c.ts)
      ORDER BY c.ts LIMIT 1`, [coach.id, day(fromOffset), day(toOffset), member.id, future],
    )).rows[0];
    if (!chosen) throw new Error(`No conflict-free slot for ${member.key}/${label}; no data committed.`);
    const startsAt = chosen.ts.toISOString();
    const endsAt = new Date(chosen.ts.getTime() + 90 * 60000).toISOString();
    const isCharged = status === 'COMPLETED' || charged;
    const resolved = status === 'BOOKED' ? null : status === 'CANCELLED' ? before(startsAt, charged ? 60 : 1440) : endsAt;
    await insert('coach_bookings', { id: bookingId, entitlement_id: member.entitlementId,
      member_id: member.id, coach_id: coach.id, starts_at: startsAt, ends_at: endsAt, status,
      charged_at: isCharged ? resolved : null, resolved_at: resolved,
      resolved_by: status === 'BOOKED' ? null : status === 'CANCELLED' ? member.id : coach.id,
      reason: status === 'CANCELLED' ? `[COACH_TEST] ${charged ? 'Hủy sát giờ, có trừ lượt' : 'Hủy sớm, không trừ lượt'}` : null });
    await client.query('UPDATE coach_notifications SET event_at=$2,read_at=$3 WHERE subject_id=$1 AND kind=\'BOOKED\'',
      [bookingId, before(startsAt, 2880), status === 'BOOKED' ? null : resolved]);
    if (status !== 'BOOKED') await client.query(
      'INSERT INTO coach_notifications (user_id,kind,subject_id,event_at) VALUES ($1,$2,$3,$4)',
      [coach.id, status, bookingId, resolved]);
  }
  const byKey = Object.fromEntries(members.map((m) => [m.key, m]));
  for (const [key, count] of [['gain', 2], ['lose', 1], ['expiry', 9], ['ended', 10]]) {
    for (let n = 0; n < count; n++) await booking(byKey[key], `completed:${n}`, 'COMPLETED',
      byKey[key].startOffset + 1, key === 'ended' ? -32 : -1);
  }
  await booking(byKey.lose, 'cancelled-late', 'CANCELLED', -7, -1, { charged: true });
  await booking(byKey.lose, 'cancelled-early', 'CANCELLED', 3, 6);
  await booking(byKey.gain, 'today-action', 'BOOKED', 0, 0);
  await booking(byKey.expiry, 'last-session', 'BOOKED', 0, 1, { future: true });
  await booking(byKey.gain, 'future-cancel', 'BOOKED', 2, 5, { future: true });
  await booking(byKey.lose, 'future-reschedule', 'BOOKED', 1, 4, { future: true });

  // A blocked slot on the next day with no conflict with either scheduling system.
  const block = (await client.query(
    `SELECT (d::date+make_interval(mins=>s.start_minute)) AT TIME ZONE 'Asia/Ho_Chi_Minh' AS ts
     FROM generate_series($2::date,$3::date,interval '1 day') d JOIN coach_weekly_slots s
       ON s.coach_id=$1 AND s.weekday=extract(isodow from d)
     WHERE NOT EXISTS (SELECT 1 FROM coach_bookings b WHERE b.coach_id=$1 AND b.status IN ('BOOKED','COMPLETED')
       AND b.starts_at<((d::date+make_interval(mins=>s.start_minute)) AT TIME ZONE 'Asia/Ho_Chi_Minh')+interval '90 minutes'
       AND b.ends_at>((d::date+make_interval(mins=>s.start_minute)) AT TIME ZONE 'Asia/Ho_Chi_Minh'))
     AND NOT EXISTS (SELECT 1 FROM training_sessions t JOIN coach_relationships r ON r.id=t.relationship_id
       WHERE r.coach_id=$1 AND t.status='SCHEDULED' AND t.scheduled_start_at<((d::date+make_interval(mins=>s.start_minute)) AT TIME ZONE 'Asia/Ho_Chi_Minh')+interval '90 minutes'
       AND coalesce(t.scheduled_end_at,t.scheduled_start_at+interval '90 minutes')>((d::date+make_interval(mins=>s.start_minute)) AT TIME ZONE 'Asia/Ho_Chi_Minh'))
     ORDER BY d,s.start_minute DESC LIMIT 1`, [coach.id, day(1), day(7)],
  )).rows[0];
  if (!(await client.query("SELECT 1 FROM coach_slot_blocks WHERE coach_id=$1 AND reason LIKE '[COACH_TEST]%'", [coach.id])).rowCount && block) {
    await insert('coach_slot_blocks', { coach_id: coach.id, starts_at: block.ts, reason: '[COACH_TEST] Bận họp nội bộ, thử bỏ chặn.' });
  }

  for (const member of members.filter((m) => m.relationshipId && ['gain', 'lose', 'expiry'].includes(m.key))) {
    const conversationId = id(`conversation:${member.key}`);
    await insert('conversations', { id: conversationId, relationship_id: member.relationshipId,
      member_id: member.id, coach_id: coach.id, last_message_at: at(-1, '19:15') });
    await insert('conversation_participants', { conversation_id: conversationId, user_id: member.id });
    await insert('conversation_participants', { conversation_id: conversationId, user_id: coach.id });
    const texts = [ 'Chào Coach, em đã xem giáo trình rồi ạ.', 'Mình đã chuẩn bị lịch tập và thực đơn mẫu cho bạn.',
      'Em muốn kiểm tra lịch và đổi giờ buổi sắp tới.', 'Bạn có thể mở Lịch Coach để xem các khung giờ còn trống nhé.',
      'Dạ, em sẽ cập nhật sau buổi tập. Đây là tin nhắn mẫu chưa đọc.' ];
    for (let n = 0; n < texts.length; n++) await insert('messages', { id: id(`message:${member.key}:${n}`),
      conversation_id: conversationId, sender_id: n % 2 ? coach.id : member.id,
      client_message_id: id(`message:${member.key}:${n}`), message_type: 'TEXT',
      content: `[COACH_TEST] ${texts[n]}`, sent_at: at(-1, `19:${String(n * 3).padStart(2, '0')}`) });
    for (let n = 0; n < 4; n++) {
      const weight = member.key === 'lose' ? 79 - n : 63 + n * 0.5;
      await insert('body_measurements', { id: id(`measurement:${member.key}:${n}`), member_id: member.id,
        measured_at: at(-21 + n * 7), weight_kg: weight, body_fat_percent: 25 - n,
        chest_cm: 90, waist_cm: 85 - n, hips_cm: 95, arm_cm: 30, thigh_cm: 50,
        notes: '[COACH_TEST] Số liệu tổng hợp giả lập.' });
      await insert('member_journal_entries', { id: id(`journal:${member.key}:${n}`), member_id: member.id,
        journal_date: day(-21 + n * 7), notes: '[COACH_TEST] Hoàn thành kế hoạch và theo dõi chỉ số.',
        chest_cm: 90, waist_cm: 85 - n, hips_cm: 95, achievements: JSON.stringify(['Đủ buổi tập', 'Theo dõi tiến độ']) });
    }
    for (let n = 0; n < 2; n++) {
      const logId = id(`workout:${member.key}:${n}`);
      await insert('workout_logs', { id: logId, member_id: member.id, training_plan_id: id(`training:${member.key}:ACTIVE`),
        performed_at: at(-3 + n, '17:00'), duration_minutes: 60, completion_level: n ? 100 : 80,
        notes: '[COACH_TEST] Nhật ký cá nhân, Coach không được đọc qua API riêng tư.' });
      await insert('workout_log_exercises', { id: id(`workout-exercise:${member.key}:${n}`), workout_log_id: logId,
        exercise_id: id('exercise:squat'), exercise_name_snapshot: 'TEST · Goblet Squat', display_order: 1,
        sets_completed: 3, reps_summary: '12/12/10', weight_kg: 10 });
      await insert('meal_logs', { id: id(`meal-log:${member.key}:${n}`), member_id: member.id,
        eaten_at: at(-2 + n, '12:00'), meal_type: 'LUNCH', meal_name: 'TEST · Cơm và ức gà', estimated_calories: 550,
        notes: '[COACH_TEST] Nhật ký dinh dưỡng mẫu.' });
    }
    for (const [n, status] of ['COMPLETED', 'MEMBER_ABSENT', 'CANCELLED', 'SCHEDULED'].entries()) {
      const memberOffset = ['gain', 'lose', 'expiry'].indexOf(member.key);
      const offset = n === 3 ? 3 + memberOffset : -8 + n - memberOffset * 4;
      const starts = at(offset, '17:00');
      await insert('training_sessions', { id: id(`session:${member.key}:${status}`), relationship_id: member.relationshipId,
        member_id: member.id, title: `TEST · ${status} · Buổi tập ${member.key}`,
        scheduled_start_at: starts, scheduled_end_at: at(offset, '18:30'), status,
        notes: '[COACH_TEST] Buổi tập theo giáo trình (khác lịch PT 90 phút).',
        completed_at: status === 'COMPLETED' ? at(offset, '18:30') : null,
        absent_at: status === 'MEMBER_ABSENT' ? at(offset, '17:15') : null,
        cancelled_at: status === 'CANCELLED' ? before(starts, 1440) : null,
        cancellation_reason: status === 'CANCELLED' ? '[COACH_TEST] Xin nghỉ trước buổi tập.' : null });
    }
    for (const [n, status] of ['ENDED', 'MISSED'].entries()) await insert('call_logs', {
      id: id(`call:${member.key}:${status}`), relationship_id: member.relationshipId,
      caller_id: n ? member.id : coach.id, receiver_id: n ? coach.id : member.id,
      call_type: n ? 'VOICE' : 'VIDEO', status, initiated_at: at(-2, n ? '19:00' : '18:00'),
      answered_at: n ? null : at(-2, '18:01'), ended_at: at(-2, n ? '19:01' : '18:06'), duration_seconds: n ? 0 : 300 });
  }
  for (const [n, status] of ['PENDING_MEMBER', 'APPROVED', 'DECLINED', 'WITHDRAWN'].entries()) {
    const member = byKey[n % 2 ? 'lose' : 'gain'];
    await insert('coach_outcome_cases', { id: id(`outcome:${status}`), coach_id: coach.id,
      member_id: member.id, relationship_id: member.relationshipId,
      goal: `[COACH_TEST] Kết quả minh họa · ${status}`, duration_weeks: 8,
      before_weight_kg: 78, after_weight_kg: 73, before_body_fat_percent: 25, after_body_fat_percent: 21,
      status, allow_real_name: false, submitted_at: at(-2), responded_at: status === 'PENDING_MEMBER' ? null : at(-1) });
  }
  await insert('coach_termination_requests', { id: id('termination:lose'), relationship_id: byKey.lose.relationshipId,
    coach_id: coach.id, reason: '[COACH_TEST] Tình huống lịch sử yêu cầu kết thúc để kiểm tra trạng thái.', status: 'PENDING' });
  for (const status of ['FAILED', 'CANCELLED', 'EXPIRED']) {
    const p = packages.get('BASIC');
    await insert('coach_payment_holds', { id: id(`hold-history:${status}`), member_id: byKey.purchase.id,
      coach_id: coach.id, plan_code: p.code, plan_name: p.name, session_count: p.session_count,
      duration_days: p.duration_days, amount: p.price, request_key: id(`hold-history-key:${status}`), status,
      created_at: at(-3, '09:00'), expires_at: at(-3, '09:15') });
  }

  const newSeats = (await client.query('SELECT coach_occupied_seats($1) AS count', [coach.id])).rows[0].count;
  if (newSeats > Math.min(8, coach.member_limit)) throw new Error('Coach capacity exceeded.');
  if (!await hasCoachCapacity(client, coach.id)) throw new Error('Fixture packages cannot fit the work schedule.');
  const badBalance = (await client.query(
    `SELECT e.id FROM coach_entitlements e LEFT JOIN coach_bookings b ON b.entitlement_id=e.id
     WHERE e.id::text LIKE 'c0ac2026-%' GROUP BY e.id
     HAVING e.remaining_sessions<>e.total_sessions-count(b.id) FILTER (WHERE b.charged_at IS NOT NULL)
       OR count(b.id) FILTER (WHERE b.status='BOOKED')>e.remaining_sessions`,
  )).rows;
  if (badBalance.length) throw new Error('Entitlement balance mismatch.');

  const summary = { date: today, database: (await client.query('SELECT current_database() AS name')).rows[0].name,
    primaryCoach: coach.email, setupCoach: setupCoach.email, inserted, occupiedSeats: newSeats,
    members: members.map(({ email, name, scenario, state, id: memberId }) => ({ email, name, scenario, state, id: memberId })) };
  if (!APPLY) {
    await client.query('ROLLBACK');
    console.log(JSON.stringify({ mode: 'DRY_RUN_ROLLED_BACK', ...summary }, null, 2));
  } else {
    // Persist credentials before commit so a filesystem failure cannot orphan newly created accounts.
    await mkdir(outputDir, { recursive: true });
    await writeFile(credentialFile, JSON.stringify({ password, setupCoach, members: summary.members }, null, 2), { mode: 0o600 });
    await client.query('COMMIT');
    const report = `# MetaGym — bộ dữ liệu Coach\n\nNgày tạo: ${today} (UTC+7).\n\n` +
      `Coach có dữ liệu: **${coach.email}** — giữ nguyên mật khẩu hiện tại.\n\n` +
      `Coach trống để thử sửa hồ sơ/lịch: **${setupCoach.email}**\n\n` +
      `Mật khẩu các tài khoản mới: **${password}**\n\n` +
      `Nếu đã tự đổi mật khẩu của một tài khoản sau khi tạo, dùng mật khẩu đã đổi; seed không reset mật khẩu.\n\n` +
      `Tất cả dữ liệu mới có tiền tố TEST / COACH_TEST hoặc UUID c0ac2026. Không gọi thanh toán, LiveKit, email hoặc dịch vụ AI.\n\n` +
      `## Tài khoản học viên\n\n| Email | Tình huống |\n|---|---|\n` +
      members.map((m) => `| ${m.email} | ${m.scenario} |`).join('\n') +
      `\n\n## Checklist\n\n` +
      `- [ ] Đăng nhập Coach Demo; kiểm tra tổng quan, danh sách học viên và tên dài.\n` +
      `- [ ] Xem hồ sơ sức khỏe học viên đang hoạt động; học viên PAUSED bị ẩn thông tin theo phân quyền.\n` +
      `- [ ] Xem ba yêu cầu chờ, yêu cầu đã chấp nhận/từ chối/hủy.\n` +
      `- [ ] Xem lịch hôm nay, tương lai, hoàn thành, hủy sớm và hủy sát giờ.\n` +
      `- [ ] Với gain: hoàn tất buổi hôm nay, hủy buổi tương lai; đối chiếu remainingSessions.\n` +
      `- [ ] Với lose: đổi lịch tương lai; không chọn trùng giờ hoặc ngày đã đặt.\n` +
      `- [ ] Với expiry: hoàn tất buổi cuối; gói/quan hệ kết thúc nếu không có gói chờ.\n` +
      `- [ ] Với gain: xem gói đang dùng và gói gia hạn QUEUED.\n` +
      `- [ ] Xem lịch cố định 7 ngày và khung giờ bị chặn; thử bỏ chặn.\n` +
      `- [ ] Dùng Coach schedule để thử lịch trống → thiết lập ≥6 ngày, ≥4 ca 90 phút liên tiếp/ngày.\n` +
      `- [ ] Xem giáo trình ACTIVE/DRAFT/ARCHIVED, ngày tập, bài tập, bữa ăn.\n` +
      `- [ ] Với new: tạo giáo trình đầu tiên bằng luồng V2 hiện có.\n` +
      `- [ ] Xem/sửa thực đơn 7 ngày, 3 bữa và 2 món mỗi bữa; đối chiếu kcal.\n` +
      `- [ ] Với new: tạo thực đơn đầu tiên.\n` +
      `- [ ] Xem buổi tập SCHEDULED/COMPLETED/MEMBER_ABSENT/CANCELLED.\n` +
      `- [ ] Xem thông báo lịch PT; đánh dấu đã đọc.\n` +
      `- [ ] Xem tin nhắn hai chiều/chưa đọc và lịch sử cuộc gọi minh họa.\n` +
      `- [ ] Xem thành tích PENDING_MEMBER/APPROVED/DECLINED/WITHDRAWN; Member phản hồi trường hợp chờ.\n` +
      `- [ ] Với purchase: thử mua gói PT bằng cơ chế thanh toán hiện có. Không có giao dịch Sandbox mới được thực hiện bởi seed.\n` +
      `- [ ] Với health: kiểm tra luồng yêu cầu khai báo sức khỏe.\n` +
      `- [ ] Kiểm tra Coach không được đọc nhật ký cá nhân qua API progress của Member (403).\n\n` +
      `## Giới hạn của backend hiện tại\n\n` +
      `Các thao tác gửi/duyệt yêu cầu Coach, tạo/sửa/công bố giáo trình, nutrition-guides và training-sessions được mở khi ENABLE_COACH_WORKFLOWS=true trong backend .env và đã khởi động lại backend. Khi cờ tắt, các API này trả 410. Luồng V2 current, meal-plans, coach-bookings tiếp tục hoạt động. Các API ghi nhật ký cá nhân cũ vẫn bị ngừng; phân quyền riêng tư không thay đổi.\n\n` +
      `Không tạo ảnh người giả, không đánh dấu tệp media không tồn tại là READY. Ảnh/avatar/tải ảnh, AI, cuộc gọi thực và cổng thanh toán cần kiểm tra với tệp/dịch vụ thực được cấu hình riêng.\n\n` +
      `Chạy lại seed chỉ thêm bản ghi còn thiếu, không khôi phục trạng thái đã thay đổi khi test. Không chạy cleanup_demo_data.js để xóa bộ này.\n`;
    await writeFile(path.join(outputDir, 'README.md'), report, 'utf8');
    await writeFile(path.join(outputDir, 'seed-summary.json'), JSON.stringify(summary, null, 2), 'utf8');
    console.log(JSON.stringify({ mode: 'COMMITTED', report: path.join(outputDir, 'README.md'), ...summary }, null, 2));
  }
} catch (error) {
  await client.query('ROLLBACK').catch(() => {});
  console.error(JSON.stringify({ error: error.message, code: error.code, constraint: error.constraint }));
  process.exitCode = 1;
} finally {
  client.release();
  await pool.end();
}

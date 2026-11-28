import { randomUUID } from 'node:crypto';
import { createDatabasePool } from '../src/config/database.js';

const VIETNAM_TZ = 'Asia/Ho_Chi_Minh';

// Chuẩn phòng gym: 05:00 – 22:00 (90 phút/ca), T2 – T7 (weekday 1..6)
// Mỗi Coach đảm nhận 1 ca liên tiếp 4 slot 90 phút/ngày (6 ngày T2–T7)
const STANDARD_COACH_SHIFTS = new Map([
  ['a1000001-0000-4000-8000-000000000001', [300, 390, 480, 570]],    // 05:00 – 11:00
  ['a1000001-0000-4000-8000-000000000002', [390, 480, 570, 660]],    // 06:30 – 12:30
  ['a1000001-0000-4000-8000-000000000005', [780, 870, 960, 1050]],   // 13:00 – 19:00
  ['a1000001-0000-4000-8000-000000000004', [870, 960, 1050, 1140]],  // 14:30 – 20:30
  ['a1000001-0000-4000-8000-000000000003', [960, 1050, 1140, 1230]], // 16:00 – 22:00
]);
const WORKDAYS = [1, 2, 3, 4, 5, 6];

function todayVietnamDate() {
  return new Intl.DateTimeFormat('en-CA', { timeZone: VIETNAM_TZ }).format(new Date());
}

function addDaysToIsoDate(isoDate, offsetDays) {
  const [y, m, d] = isoDate.split('-').map(Number);
  const dt = new Date(Date.UTC(y, m - 1, d + offsetDays));
  const yy = dt.getUTCFullYear();
  const mm = String(dt.getUTCMonth() + 1).padStart(2, '0');
  const dd = String(dt.getUTCDate()).padStart(2, '0');
  return `${yy}-${mm}-${dd}`;
}

function isoWeekday(isoDate) {
  const [y, m, d] = isoDate.split('-').map(Number);
  const day = new Date(Date.UTC(y, m - 1, d)).getUTCDay();
  return day === 0 ? 7 : day;
}

function buildStartsAtIso(isoDate, startMinute) {
  const hh = String(Math.floor(startMinute / 60)).padStart(2, '0');
  const mm = String(startMinute % 60).padStart(2, '0');
  return `${isoDate}T${hh}:${mm}:00+07:00`;
}

async function seedCoachSchedule() {
  const database = createDatabasePool();
  const client = await database.connect();
  const baseDate = todayVietnamDate();
  const dayOffsets = [0, 1, 2, 3, 4, 5, 6, 7];

  let syncedCoaches = 0;
  let clearedLegacyFutureBookings = 0;
  let insertedBookings = 0;
  let insertedBlocks = 0;

  try {
    await client.query('BEGIN');

    // 1. Chuẩn hóa lịch ca tuần T2–T7 từ 05:00 – 22:00 (90p/ca) cho các Coach hoạt động
    const { rows: activeCoaches } = await client.query(
      `SELECT id FROM users WHERE role = 'COACH' AND status = 'ACTIVE'`,
    );
    const activeIds = new Set(activeCoaches.map((c) => c.id));

    for (const [coachId, starts] of STANDARD_COACH_SHIFTS.entries()) {
      if (!activeIds.has(coachId)) continue;
      await client.query('DELETE FROM coach_weekly_slots WHERE coach_id = $1', [coachId]);
      for (const wd of WORKDAYS) {
        for (const startMin of starts) {
          await client.query(
            `INSERT INTO coach_weekly_slots (id, coach_id, weekday, start_minute)
             VALUES ($1, $2, $3, $4)`,
            [randomUUID(), coachId, wd, startMin],
          );
        }
      }
      syncedCoaches += 1;
    }

    // 2. Xóa các booking BOOKED mẫu tương lai (>= today) bị lệch khung giờ chuẩn mới
    const { rowCount: clearedCount } = await client.query(
      `DELETE FROM coach_bookings b
        WHERE b.status = 'BOOKED'
          AND b.charged_at IS NULL
          AND b.booking_date >= $1::date
          AND NOT EXISTS (
            SELECT 1 FROM coach_weekly_slots s
             WHERE s.coach_id = b.coach_id
               AND s.weekday = EXTRACT(ISODOW FROM b.starts_at AT TIME ZONE 'Asia/Ho_Chi_Minh')::int
               AND s.start_minute = (
                 EXTRACT(HOUR FROM b.starts_at AT TIME ZONE 'Asia/Ho_Chi_Minh')::int * 60
                 + EXTRACT(MINUTE FROM b.starts_at AT TIME ZONE 'Asia/Ho_Chi_Minh')::int
               )
          )`,
      [baseDate],
    );
    clearedLegacyFutureBookings = clearedCount;

    // 3. Lấy entitlements ACTIVE và danh sách slot mới
    const { rows: entitlements } = await client.query(
      `SELECT e.id, e.member_id, e.coach_id,
              e.starts_on::text AS starts_on, e.ends_on::text AS ends_on,
              e.remaining_sessions
         FROM coach_entitlements e
         JOIN coach_relationships r ON r.id = e.relationship_id
        WHERE e.status = 'ACTIVE'
          AND r.status = 'ACTIVE'
          AND e.remaining_sessions > 1
        ORDER BY e.id`,
    );

    const { rows: weeklySlots } = await client.query(
      `SELECT coach_id, weekday, start_minute, end_minute
         FROM coach_weekly_slots
        ORDER BY coach_id, weekday, start_minute`,
    );

    const slotsByCoachWeekday = new Map();
    for (const slot of weeklySlots) {
      const key = `${slot.coach_id}:${slot.weekday}`;
      const list = slotsByCoachWeekday.get(key) ?? [];
      list.push(slot);
      slotsByCoachWeekday.set(key, list);
    }

    // 4. Tạo booking mẫu từ T2–T7 (bỏ qua Chủ nhật weekday = 7) phủ từ 05:00 đến 22:00
    for (const offset of dayOffsets) {
      const targetDate = addDaysToIsoDate(baseDate, offset);
      const weekday = isoWeekday(targetDate);
      if (weekday === 7) continue;

      let dayCreated = 0;
      for (let idx = 0; idx < entitlements.length && dayCreated < 3; idx += 1) {
        const ent = entitlements[(idx + offset) % entitlements.length];
        if (targetDate < ent.starts_on || targetDate > ent.ends_on) continue;

        const { rows: [{ count: bookedCount }] } = await client.query(
          `SELECT count(*)::int AS count FROM coach_bookings
            WHERE entitlement_id = $1 AND status = 'BOOKED'`,
          [ent.id],
        );
        if (bookedCount >= ent.remaining_sessions - 1) continue;

        const { rows: [memberDayConflict] } = await client.query(
          `SELECT 1 FROM coach_bookings
            WHERE member_id = $1 AND booking_date = $2::date
              AND (status IN ('BOOKED', 'COMPLETED') OR charged_at IS NOT NULL)
            LIMIT 1`,
          [ent.member_id, targetDate],
        );
        if (memberDayConflict) continue;

        const candidates = slotsByCoachWeekday.get(`${ent.coach_id}:${weekday}`) ?? [];
        if (!candidates.length) continue;

        const orderedCandidates = candidates.slice((offset + idx) % candidates.length)
          .concat(candidates.slice(0, (offset + idx) % candidates.length));

        for (const slot of orderedCandidates) {
          const startsAt = buildStartsAtIso(targetDate, slot.start_minute);
          const { rows: [busyConflict] } = await client.query(
            `SELECT 1 FROM coach_bookings b
              WHERE b.coach_id = $1
                AND b.status IN ('BOOKED', 'COMPLETED')
                AND b.starts_at < $2::timestamptz + interval '90 minutes'
                AND b.ends_at > $2::timestamptz
             UNION ALL
             SELECT 1 FROM coach_slot_blocks sb
              WHERE sb.coach_id = $1 AND sb.starts_at = $2::timestamptz
             UNION ALL
             SELECT 1 FROM training_sessions ts
              JOIN coach_relationships cr ON cr.id = ts.relationship_id
              WHERE cr.coach_id = $1 AND ts.status = 'SCHEDULED'
                AND ts.scheduled_start_at < $2::timestamptz + interval '90 minutes'
                AND COALESCE(ts.scheduled_end_at, ts.scheduled_start_at + interval '90 minutes') > $2::timestamptz
             LIMIT 1`,
            [ent.coach_id, startsAt],
          );
          if (busyConflict) continue;

          await client.query(
            `INSERT INTO coach_bookings (id, entitlement_id, member_id, coach_id, starts_at, ends_at)
             VALUES ($1, $2, $3, $4, $5::timestamptz, $5::timestamptz + interval '90 minutes')`,
            [randomUUID(), ent.id, ent.member_id, ent.coach_id, startsAt],
          );
          insertedBookings += 1;
          dayCreated += 1;
          break;
        }
      }
    }

    // 5. Tạo 2 block mẫu trên ngày làm việc (T2–T7)
    const blockReasons = ['Họp chuyên môn nội bộ', 'Nghỉ phép cá nhân'];
    let blockIdx = 0;
    for (const offset of dayOffsets) {
      if (blockIdx >= blockReasons.length) break;
      const targetDate = addDaysToIsoDate(baseDate, offset);
      const weekday = isoWeekday(targetDate);
      if (weekday === 7) continue;

      const { rows: [freeSlot] } = await client.query(
        `SELECT s.coach_id, s.start_minute
           FROM coach_weekly_slots s
          WHERE s.weekday = $1
            AND NOT EXISTS (
              SELECT 1 FROM coach_bookings b
               WHERE b.coach_id = s.coach_id
                 AND b.status IN ('BOOKED', 'COMPLETED')
                 AND b.starts_at < (($2 || 'T00:00:00+07:00')::timestamptz + make_interval(mins => s.start_minute + 90))
                 AND b.ends_at > (($2 || 'T00:00:00+07:00')::timestamptz + make_interval(mins => s.start_minute))
            )
            AND NOT EXISTS (
              SELECT 1 FROM coach_slot_blocks sb
               WHERE sb.coach_id = s.coach_id
                 AND sb.starts_at = (($2 || 'T00:00:00+07:00')::timestamptz + make_interval(mins => s.start_minute))
            )
          ORDER BY s.start_minute DESC, s.coach_id
          LIMIT 1`,
        [weekday, targetDate],
      );
      if (freeSlot) {
        const startsAt = buildStartsAtIso(targetDate, freeSlot.start_minute);
        const { rowCount } = await client.query(
          `INSERT INTO coach_slot_blocks (coach_id, starts_at, reason)
           VALUES ($1, $2::timestamptz, $3)
           ON CONFLICT (coach_id, starts_at) DO NOTHING`,
          [freeSlot.coach_id, startsAt, blockReasons[blockIdx]],
        );
        insertedBlocks += rowCount;
        blockIdx += 1;
      }
    }

    await client.query('COMMIT');
    console.log(JSON.stringify({
      baseDate,
      syncedCoaches,
      clearedLegacyFutureBookings,
      insertedBookings,
      insertedBlocks,
      status: 'OK',
    }));
  } catch (err) {
    await client.query('ROLLBACK');
    throw err;
  } finally {
    client.release();
    await database.end();
  }
}

seedCoachSchedule().catch((err) => {
  console.error('Seed coach schedule failed:', err);
  process.exitCode = 1;
});

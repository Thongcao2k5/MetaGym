// Each package may take at most one slot per day. An augmenting path can
// move an earlier assignment to make room for a package with fewer options.
export function canFitCoachSessions(days, commitments) {
  const assignments = days.map(() => new Set());
  function assign(packageIndex, visitedDays) {
    const commitment = commitments[packageIndex];
    for (const [index, day] of days.entries()) {
      if (day.available <= 0 || day.date < commitment.from || day.date > commitment.through
          || commitment.bookedDates.has(day.date) || visitedDays.has(index)
          || assignments[index].has(packageIndex)) continue;
      visitedDays.add(index);
      const assigned = assignments[index];
      if (assigned.size < day.available) {
        assigned.add(packageIndex);
        return true;
      }
      for (const other of assigned) {
        if (assign(other, visitedDays)) {
          assigned.delete(other);
          assigned.add(packageIndex);
          return true;
        }
      }
    }
    return false;
  }
  return commitments.every(({ remaining }, index) => {
    for (let count = 0; count < remaining; count++) {
      if (!assign(index, new Set())) return false;
    }
    return true;
  });
}

export async function hasCoachCapacity(client, coachId, proposal) {
  const { rows: days } = await client.query(
    `WITH bounds AS (
       SELECT (statement_timestamp() AT TIME ZONE 'Asia/Ho_Chi_Minh')::date AS today
     ), dates AS (
       SELECT today + offset_days AS day FROM bounds CROSS JOIN generate_series(0, 190) offset_days
     )
     SELECT d.day::text AS date, count(*) FILTER (WHERE s.id IS NOT NULL
       AND slot.start_at > statement_timestamp() AND NOT EXISTS (
         SELECT 1 FROM coach_slot_blocks block WHERE block.coach_id = $1
           AND block.starts_at = slot.start_at
       ) AND NOT EXISTS (
         SELECT 1 FROM coach_bookings b WHERE b.coach_id = $1
           AND b.status IN ('BOOKED', 'COMPLETED')
           AND b.starts_at < slot.start_at + interval '90 minutes' AND b.ends_at > slot.start_at
       ) AND NOT EXISTS (
         SELECT 1 FROM training_sessions t JOIN coach_relationships r ON r.id = t.relationship_id
           WHERE r.coach_id = $1 AND t.status = 'SCHEDULED'
             AND t.scheduled_start_at < slot.start_at + interval '90 minutes'
             AND COALESCE(t.scheduled_end_at, t.scheduled_start_at + interval '90 minutes') > slot.start_at
       ))::int AS available
     FROM dates d LEFT JOIN coach_weekly_slots s ON s.coach_id = $1
       AND s.weekday = EXTRACT(ISODOW FROM d.day)
     CROSS JOIN LATERAL (
       SELECT ((d.day + make_interval(mins => s.start_minute)) AT TIME ZONE 'Asia/Ho_Chi_Minh') AS start_at
     ) slot GROUP BY d.day ORDER BY d.day`, [coachId],
  );
  const { rows } = await client.query(
    `SELECT e.status, COALESCE(e.starts_on, a.original_ends_on + 8)::text AS "from",
       COALESCE(e.ends_on, (statement_timestamp() AT TIME ZONE 'Asia/Ho_Chi_Minh')::date
         + e.duration_days - 1)::text AS through,
       e.remaining_sessions - count(b.id) FILTER (WHERE b.status = 'BOOKED')::int AS remaining,
       ARRAY(SELECT day_booking.booking_date::text FROM coach_bookings day_booking
             WHERE day_booking.member_id = e.member_id
               AND (day_booking.status IN ('BOOKED', 'COMPLETED') OR day_booking.charged_at IS NOT NULL))
         AS "bookedDates"
     FROM coach_entitlements e JOIN coach_relationships r ON r.id = e.relationship_id
     LEFT JOIN coach_entitlements a ON a.relationship_id = e.relationship_id AND a.status = 'ACTIVE'
     LEFT JOIN coach_bookings b ON b.entitlement_id = e.id AND b.status = 'BOOKED'
     WHERE e.coach_id = $1 AND e.status IN ('ACTIVE', 'QUEUED') AND r.status <> 'ENDED'
     GROUP BY e.id, a.original_ends_on`, [coachId],
  );
  const commitments = rows.map((row) => ({ ...row, bookedDates: new Set(row.bookedDates) }));
  if (proposal) {
    const { rows: occupied } = await client.query(
      `SELECT booking_date::text AS date FROM coach_bookings WHERE member_id = $1
       AND (status IN ('BOOKED', 'COMPLETED') OR charged_at IS NOT NULL)`,
      [proposal.memberId],
    );
    commitments.push({ ...proposal, bookedDates: new Set(occupied.map(({ date }) => date)) });
  }
  return canFitCoachSessions(days, commitments);
}

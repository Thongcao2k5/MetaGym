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

export async function hasCoachCapacity(client, coachId, proposalOrProposals) {
  const proposals = Array.isArray(proposalOrProposals)
    ? proposalOrProposals.filter(Boolean)
    : proposalOrProposals
      ? [proposalOrProposals]
      : [];

  // Load existing commitments with valid non-empty date windows (T2 §2 D2):
  // - ACTIVE: [GREATEST(today, starts_on), ends_on]
  // - QUEUED: [active.original_ends_on + active.frozen_days_total + 8, from + duration_days - 1]
  const { rows } = await client.query(
    `WITH bounds AS (
       SELECT (statement_timestamp() AT TIME ZONE 'Asia/Ho_Chi_Minh')::date AS today
     )
     SELECT e.status,
       CASE
         WHEN e.status = 'ACTIVE'
           THEN LEAST(GREATEST(bounds.today, e.starts_on), e.ends_on)::text
         ELSE (COALESCE(a.original_ends_on + a.frozen_days_total + 8, bounds.today))::text
       END AS "from",
       CASE
         WHEN e.status = 'ACTIVE'
           THEN e.ends_on::text
         ELSE (COALESCE(a.original_ends_on + a.frozen_days_total + 8, bounds.today)
           + e.duration_days - 1)::text
       END AS through,
       GREATEST(0, e.remaining_sessions - count(b.id) FILTER (WHERE b.status = 'BOOKED')::int) AS remaining,
       ARRAY(SELECT day_booking.booking_date::text FROM coach_bookings day_booking
             WHERE day_booking.member_id = e.member_id
               AND (day_booking.status IN ('BOOKED', 'COMPLETED') OR day_booking.charged_at IS NOT NULL))
         AS "bookedDates"
     FROM bounds
     CROSS JOIN coach_entitlements e
     JOIN coach_relationships r ON r.id = e.relationship_id
     LEFT JOIN coach_entitlements a ON a.relationship_id = e.relationship_id AND a.status = 'ACTIVE'
     LEFT JOIN coach_bookings b ON b.entitlement_id = e.id AND b.status = 'BOOKED'
     WHERE e.coach_id = $1 AND e.status IN ('ACTIVE', 'QUEUED') AND r.status <> 'ENDED'
     GROUP BY bounds.today, e.id, a.original_ends_on, a.frozen_days_total`,
    [coachId],
  );

  const commitments = rows.map((row) => ({ ...row, bookedDates: new Set(row.bookedDates) }));

  if (proposals.length) {
    const memberIds = [...new Set(proposals.map((p) => p.memberId).filter(Boolean))];
    const occupiedByMember = new Map();
    if (memberIds.length) {
      const { rows: occupiedRows } = await client.query(
        `SELECT member_id, booking_date::text AS date FROM coach_bookings
         WHERE member_id = ANY($1::uuid[])
           AND (status IN ('BOOKED', 'COMPLETED') OR charged_at IS NOT NULL)`,
        [memberIds],
      );
      for (const row of occupiedRows) {
        let set = occupiedByMember.get(row.member_id);
        if (!set) {
          set = new Set();
          occupiedByMember.set(row.member_id, set);
        }
        set.add(row.date);
      }
    }
    for (const proposal of proposals) {
      const bookedDates = proposal.bookedDates instanceof Set
        ? proposal.bookedDates
        : new Set(occupiedByMember.get(proposal.memberId) ?? []);
      commitments.push({
        from: proposal.from,
        through: proposal.through,
        remaining: proposal.remaining,
        bookedDates,
      });
    }
  }

  // Dynamic horizon: always >= 190 days and expands to cover max commitment through date!
  let maxThrough = null;
  for (const commitment of commitments) {
    if (commitment.through && (!maxThrough || commitment.through > maxThrough)) {
      maxThrough = commitment.through;
    }
  }

  const { rows: days } = await client.query(
    `WITH bounds AS (
       SELECT (statement_timestamp() AT TIME ZONE 'Asia/Ho_Chi_Minh')::date AS today
     ), horizon AS (
       SELECT today,
              GREATEST(190, COALESCE(($2::date - today)::int, 190)) AS max_offset
       FROM bounds
     ), dates AS (
       SELECT h.today + offset_days AS day
       FROM horizon h
       CROSS JOIN LATERAL generate_series(0, h.max_offset) offset_days
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
     ) slot GROUP BY d.day ORDER BY d.day`,
    [coachId, maxThrough],
  );

  return canFitCoachSessions(days, commitments);
}

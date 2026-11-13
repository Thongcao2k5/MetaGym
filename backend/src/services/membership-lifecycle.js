const reconciliationIntervalMs = 60_000;
const inFlightByDatabase = new WeakMap();
const lastRunByDatabase = new WeakMap();
const gymDateFormatter = new Intl.DateTimeFormat('en-US', {
  timeZone: 'Asia/Ho_Chi_Minh', year: 'numeric', month: '2-digit', day: '2-digit',
});

function gymBusinessDate(timestamp) {
  const parts = Object.fromEntries(gymDateFormatter.formatToParts(new Date(timestamp))
    .filter(({ type }) => type !== 'literal')
    .map(({ type, value }) => [type, value]));
  return `${parts.year}-${parts.month}-${parts.day}`;
}

export function reconcileMembershipLifecycles(database) {
  if (typeof database.connect !== 'function') return undefined;
  const startedAt = Date.now();
  const businessDate = gymBusinessDate(startedAt);
  const lastRun = lastRunByDatabase.get(database);
  if (lastRun && lastRun.businessDate === businessDate &&
      startedAt - lastRun.completedAt < reconciliationIntervalMs) return undefined;
  const current = inFlightByDatabase.get(database);
  if (current) {
    if (current.businessDate === businessDate) return current.promise;
    return current.promise.then(() => reconcileMembershipLifecycles(database));
  }
  const reconciliation = runReconciliation(database, businessDate)
    .then(() => { lastRunByDatabase.set(database, {
      businessDate, completedAt: Date.now(),
    }); })
    .finally(() => { inFlightByDatabase.delete(database); });
  inFlightByDatabase.set(database, { businessDate, promise: reconciliation });
  return reconciliation;
}

async function runReconciliation(database, businessDate) {
  const client = await database.connect();
  try {
    await client.query('BEGIN');
    await client.query(`SELECT pg_advisory_xact_lock(hashtext('meta-gym-membership-lifecycle'))`);
    await client.query(
      `UPDATE member_memberships SET status = 'EXPIRED', expired_at = now()
       WHERE status = 'ACTIVE' AND end_date < $1::date`, [businessDate],
    );
    await client.query(
      `UPDATE member_memberships SET status = 'EXPIRED',
       activated_at = start_date::timestamp AT TIME ZONE 'Asia/Ho_Chi_Minh',
       expired_at = now()
       WHERE status = 'SCHEDULED' AND end_date < $1::date`, [businessDate],
    );
    await client.query(
      `UPDATE member_memberships SET status = 'ACTIVE', activated_at = now()
       WHERE status = 'SCHEDULED' AND start_date <= $1::date
       AND end_date >= $1::date`, [businessDate],
    );
    const paused = await client.query(
      `UPDATE coach_relationships r SET status = 'PAUSED', paused_at = now(),
       pause_reason = 'MEMBERSHIP_EXPIRED'
       WHERE r.status = 'ACTIVE'
       AND EXISTS (
         SELECT 1 FROM member_memberships owned WHERE owned.member_id = r.member_id
       ) AND NOT EXISTS (
         SELECT 1 FROM member_memberships m WHERE m.member_id = r.member_id
         AND m.status = 'ACTIVE' AND m.start_date <= $1::date
         AND m.end_date >= $1::date
       ) RETURNING r.id`, [businessDate],
    );
    if (paused.rows.length) {
      await client.query(
        `UPDATE training_sessions SET status = 'CANCELLED', cancelled_at = now(),
         cancellation_reason = 'Gói tập của Member đã hết hạn'
         WHERE relationship_id = ANY($1::uuid[]) AND status = 'SCHEDULED'
         AND scheduled_start_at > now()`,
        [paused.rows.map((row) => row.id)],
      );
    }
    await client.query(
      `UPDATE coach_relationships r SET status = 'ACTIVE', paused_at = NULL,
       pause_reason = NULL
       WHERE r.status = 'PAUSED' AND r.pause_reason = 'MEMBERSHIP_EXPIRED'
       AND EXISTS (
         SELECT 1 FROM member_memberships m WHERE m.member_id = r.member_id
         AND m.status = 'ACTIVE' AND m.start_date <= $1::date
         AND m.end_date >= $1::date
       )`, [businessDate],
    );
    await client.query(
      `SELECT r.id FROM coach_relationships r JOIN coach_entitlements e ON e.relationship_id = r.id
       WHERE e.status = 'ACTIVE' AND e.ends_on < $1::date ORDER BY r.id FOR UPDATE OF r`, [businessDate],
    );
    await client.query(
      `UPDATE coach_entitlements SET ends_on = original_ends_on + 7
       WHERE status = 'ACTIVE' AND ends_on = original_ends_on
         AND original_ends_on < $1::date`, [businessDate],
    );
    await client.query(
      `WITH expired AS (
         UPDATE coach_entitlements SET status = 'ENDED', ended_at = statement_timestamp()
         WHERE status = 'ACTIVE' AND ends_on < $1::date
         RETURNING relationship_id, ends_on
       ), activated AS (
         UPDATE coach_entitlements e SET status = CASE
             WHEN expired.ends_on + e.duration_days + 7 < $1::date THEN 'ENDED' ELSE 'ACTIVE' END,
           starts_on = expired.ends_on + 1,
           original_ends_on = expired.ends_on + e.duration_days,
           ends_on = expired.ends_on + e.duration_days
             + CASE WHEN expired.ends_on + e.duration_days < $1::date THEN 7 ELSE 0 END,
           ended_at = CASE WHEN expired.ends_on + e.duration_days + 7 < $1::date
                           THEN statement_timestamp() END
         FROM expired WHERE e.relationship_id = expired.relationship_id AND e.status = 'QUEUED'
         RETURNING e.relationship_id, e.status
       )
       UPDATE coach_relationships r SET status = 'ENDED', ended_at = statement_timestamp(),
         ended_by = r.coach_id, end_reason = 'Gói Coach đã hết hạn'
       FROM expired WHERE r.id = expired.relationship_id AND r.status IN ('ACTIVE', 'PAUSED')
         AND NOT EXISTS (SELECT 1 FROM activated a WHERE a.relationship_id = r.id AND a.status = 'ACTIVE')`,
      [businessDate],
    );
    await client.query('COMMIT');
  } catch (error) {
    await client.query('ROLLBACK').catch(() => {});
    throw error;
  } finally {
    client.release();
  }
}

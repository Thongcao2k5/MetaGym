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
    await client.query('COMMIT');
  } catch (error) {
    await client.query('ROLLBACK').catch(() => {});
    throw error;
  } finally {
    client.release();
  }
}

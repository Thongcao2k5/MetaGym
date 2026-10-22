const today = `(now() AT TIME ZONE 'Asia/Ho_Chi_Minh')::date`;

export async function reconcileMembershipLifecycles(database) {
  if (typeof database.connect !== 'function') return;

  const client = await database.connect();
  try {
    await client.query('BEGIN');
    await client.query(`SELECT pg_advisory_xact_lock(hashtext('meta-gym-membership-lifecycle'))`);
    await client.query(
      `UPDATE member_memberships SET status = 'EXPIRED', expired_at = now()
       WHERE status = 'ACTIVE' AND end_date < ${today}`,
    );
    await client.query(
      `UPDATE member_memberships SET status = 'EXPIRED',
       activated_at = start_date::timestamp AT TIME ZONE 'Asia/Ho_Chi_Minh',
       expired_at = now()
       WHERE status = 'SCHEDULED' AND end_date < ${today}`,
    );
    await client.query(
      `UPDATE member_memberships SET status = 'ACTIVE', activated_at = now()
       WHERE status = 'SCHEDULED' AND start_date <= ${today}
       AND end_date >= ${today}`,
    );
    const paused = await client.query(
      `UPDATE coach_relationships r SET status = 'PAUSED', paused_at = now(),
       pause_reason = 'MEMBERSHIP_EXPIRED'
       WHERE r.status = 'ACTIVE'
       AND EXISTS (
         SELECT 1 FROM member_memberships owned WHERE owned.member_id = r.member_id
       ) AND NOT EXISTS (
         SELECT 1 FROM member_memberships m WHERE m.member_id = r.member_id
         AND m.status = 'ACTIVE' AND m.start_date <= ${today}
         AND m.end_date >= ${today}
       ) RETURNING r.id`,
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
         AND m.status = 'ACTIVE' AND m.start_date <= ${today}
         AND m.end_date >= ${today}
       )`,
    );
    await client.query('COMMIT');
  } catch (error) {
    await client.query('ROLLBACK').catch(() => {});
    throw error;
  } finally {
    client.release();
  }
}

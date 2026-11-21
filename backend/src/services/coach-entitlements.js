import { randomUUID } from 'node:crypto';

import { hasCoachCapacity } from './coach-capacity.js';

// Call only after the payment integration has verified the result on the server.
export async function settleCoachHold(database, holdId, { paid, amount }) {
  const client = await database.connect();
  try {
    await client.query('BEGIN');
    const identity = (await client.query(
      'SELECT coach_id, member_id FROM coach_payment_holds WHERE id = $1', [holdId],
    )).rows[0];
    let result = { status: 'NOT_FOUND' };
    if (identity) {
      await client.query('SELECT id FROM users WHERE id = $1 FOR UPDATE', [identity.coach_id]);
      await client.query('SELECT id FROM users WHERE id = $1 FOR UPDATE', [identity.member_id]);
      result = await settleLockedHold(client, holdId, paid, amount);
    }
    await client.query('COMMIT');
    return result;
  } catch (error) {
    await client.query('ROLLBACK').catch(() => {});
    throw error;
  } finally {
    client.release();
  }
}

async function settleLockedHold(client, holdId, paid, amount) {
  const hold = (await client.query(
    `SELECT h.*, h.expires_at <= statement_timestamp() AS expired,
       c.member_limit, u.status AS coach_status, m.status AS member_status,
       (statement_timestamp() AT TIME ZONE 'Asia/Ho_Chi_Minh')::date::text AS today,
       ((statement_timestamp() AT TIME ZONE 'Asia/Ho_Chi_Minh')::date
         + h.duration_days - 1)::text AS through
     FROM coach_payment_holds h JOIN users u ON u.id = h.coach_id
     JOIN users m ON m.id = h.member_id JOIN coach_profiles c ON c.user_id = h.coach_id
     WHERE h.id = $1 FOR UPDATE OF h`, [holdId],
  )).rows[0];
  if (!hold) return { status: 'NOT_FOUND' };
  if (hold.status === 'CONSUMED') {
    const { rows } = await client.query(
      'SELECT id FROM coach_entitlements WHERE hold_id = $1', [holdId],
    );
    return { status: 'CONSUMED', entitlementId: rows[0].id };
  }
  if (hold.status !== 'HELD') return { status: hold.status };
  const release = async (status, reason) => {
    await client.query('UPDATE coach_payment_holds SET status = $2 WHERE id = $1', [holdId, status]);
    return { status, reason };
  };
  if (hold.expired) return release('EXPIRED', 'HOLD_EXPIRED');
  if (paid !== true) return release('FAILED', 'PAYMENT_FAILED');
  if (!Number.isSafeInteger(amount) || amount !== Number(hold.amount)) {
    return release('FAILED', 'AMOUNT_MISMATCH');
  }
  const membership = await client.query(
    `SELECT 1 FROM member_memberships WHERE member_id = $1 AND status = 'ACTIVE'
     AND $2::date BETWEEN start_date AND end_date FOR SHARE`, [hold.member_id, hold.today],
  );
  if (!membership.rows.length || hold.member_status !== 'ACTIVE' || hold.coach_status !== 'ACTIVE') {
    return release('FAILED', 'PARTICIPANT_INELIGIBLE');
  }
  const current = (await client.query(
    `SELECT id, coach_id FROM coach_relationships WHERE member_id = $1
     AND status IN ('ACTIVE', 'PAUSED') FOR UPDATE`, [hold.member_id],
  )).rows[0];
  if (current && current.coach_id !== hold.coach_id) return release('FAILED', 'RELATIONSHIP_EXISTS');

  const seats = (await client.query('SELECT coach_occupied_seats($1) AS count', [hold.coach_id]))
    .rows[0].count;
  if (!current && seats > Math.min(8, hold.member_limit)) return release('FAILED', 'COACH_FULL');

  let eligible = false;
  if (current) {
    const { rows: [existing] } = await client.query(
      `SELECT (original_ends_on + frozen_days_total + 8)::text AS late_from,
         (original_ends_on + frozen_days_total + 8 + $2::int - 1)::text AS late_through,
         ($3::date + remaining_sessions)::text AS early_from,
         ($3::date + remaining_sessions + $2::int - 1)::text AS early_through,
         EXISTS (SELECT 1 FROM coach_entitlements WHERE relationship_id = $1
           AND status = 'QUEUED') AS queued
       FROM coach_entitlements WHERE relationship_id = $1 AND status = 'ACTIVE'`,
      [current.id, hold.duration_days, hold.today],
    );
    if (!existing || existing.queued) return release('FAILED', 'QUEUED_UNAVAILABLE');
    // T2 §2 D2: check both late (expiry+grace) and early (fast completion) QUEUED windows
    eligible = await hasCoachCapacity(client, hold.coach_id, {
      from: existing.late_from,
      through: existing.late_through,
      remaining: hold.session_count,
      memberId: hold.member_id,
    }) && await hasCoachCapacity(client, hold.coach_id, {
      from: existing.early_from,
      through: existing.early_through,
      remaining: hold.session_count,
      memberId: hold.member_id,
    });
  } else {
    eligible = await hasCoachCapacity(client, hold.coach_id, {
      from: hold.today,
      through: hold.through,
      remaining: hold.session_count,
      memberId: hold.member_id,
    });
  }

  if (!eligible) return release('FAILED', 'CAPACITY_UNAVAILABLE');
  const relationshipId = current?.id ?? randomUUID();
  const entitlementId = randomUUID();
  const consumed = await client.query(
    `UPDATE coach_payment_holds
     SET status = 'CONSUMED', settled_at = statement_timestamp()
     WHERE id = $1 AND expires_at > statement_timestamp()
     RETURNING id`,
    [holdId],
  );
  if (!consumed.rows.length) return release('EXPIRED', 'HOLD_EXPIRED');
  if (!current) {
    await client.query(
      'INSERT INTO coach_relationships (id, member_id, coach_id) VALUES ($1, $2, $3)',
      [relationshipId, hold.member_id, hold.coach_id],
    );
  }
  await client.query(
    `INSERT INTO coach_entitlements (
       id, hold_id, original_hold_id, relationship_id, member_id, coach_id,
       plan_code, plan_name, snapshot_price,
       status, total_sessions, remaining_sessions, duration_days,
       starts_on, original_ends_on, ends_on
     ) VALUES ($1, $2, $2, $3, $4, $5, $6, $7, $8, $13, $9, $9, $10, $11, $12, $12)`,
    [
      entitlementId,
      holdId,
      relationshipId,
      hold.member_id,
      hold.coach_id,
      hold.plan_code,
      hold.plan_name,
      hold.amount,
      hold.session_count,
      hold.duration_days,
      current ? null : hold.today,
      current ? null : hold.through,
      current ? 'QUEUED' : 'ACTIVE',
    ],
  );
  return { status: 'CONSUMED', entitlementId };
}

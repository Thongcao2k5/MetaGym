import { createHash } from 'node:crypto';

const FAILURE_LIMIT = 5;
const WINDOW_MINUTES = 15;

function hashBucket(scope, value) {
  return createHash('sha256').update(`${scope}:${value}`).digest('hex');
}

function advisoryLockKey(keyHash) {
  return BigInt.asIntN(64, BigInt(`0x${keyHash.slice(0, 16)}`)).toString();
}

function getBuckets({ email, ip }) {
  return [
    { key: hashBucket('ACCOUNT', email), scope: 'ACCOUNT' },
    { key: hashBucket('IP', ip), scope: 'IP' },
  ].sort((left, right) => left.key.localeCompare(right.key));
}

export function createDatabaseLoginRateLimiter({ database }) {
  return {
    async run(context, handler) {
      const client = await database.connect();
      const buckets = getBuckets(context);
      const acquiredLocks = [];

      try {
        for (const bucket of buckets) {
          const lockKey = advisoryLockKey(bucket.key);
          await client.query('SELECT pg_advisory_lock($1::bigint)', [lockKey]);
          acquiredLocks.push(lockKey);
        }

        const blockedResult = await client.query(
          `SELECT coalesce(bool_or(blocked_until > now()), false) AS blocked
           FROM auth_login_rate_limits
           WHERE key_hash = ANY($1::text[])`,
          [buckets.map((bucket) => bucket.key)],
        );

        return await handler({
          blocked: blockedResult.rows[0]?.blocked === true,
          database: client,
          registerFailure: async () => {
            const result = await client.query(
              `INSERT INTO auth_login_rate_limits (
                 key_hash, scope, failure_count, window_started_at, blocked_until
               )
               SELECT bucket.key_hash, bucket.scope, 1, now(), NULL
               FROM unnest($1::text[], $2::text[]) AS bucket(key_hash, scope)
               ON CONFLICT (key_hash) DO UPDATE
               SET failure_count = CASE
                     WHEN auth_login_rate_limits.window_started_at <= now() - make_interval(mins => $3)
                       THEN 1
                     ELSE auth_login_rate_limits.failure_count + 1
                   END,
                   window_started_at = CASE
                     WHEN auth_login_rate_limits.window_started_at <= now() - make_interval(mins => $3)
                       THEN now()
                     ELSE auth_login_rate_limits.window_started_at
                   END,
                   blocked_until = CASE
                     WHEN auth_login_rate_limits.blocked_until > now()
                       THEN auth_login_rate_limits.blocked_until
                     WHEN CASE
                            WHEN auth_login_rate_limits.window_started_at <= now() - make_interval(mins => $3)
                              THEN 1
                            ELSE auth_login_rate_limits.failure_count + 1
                          END >= $4
                       THEN now() + make_interval(mins => $3)
                     ELSE NULL
                   END,
                   updated_at = now()
               RETURNING blocked_until > now() AS blocked`,
              [
                buckets.map((bucket) => bucket.key),
                buckets.map((bucket) => bucket.scope),
                WINDOW_MINUTES,
                FAILURE_LIMIT,
              ],
            );
            return result.rows.some((row) => row.blocked === true);
          },
          resetAccount: async () => {
            const account = buckets.find((bucket) => bucket.scope === 'ACCOUNT');
            await client.query(
              'DELETE FROM auth_login_rate_limits WHERE key_hash = $1',
              [account.key],
            );
          },
        });
      } finally {
        try {
          for (const lockKey of acquiredLocks.reverse()) {
            await client.query('SELECT pg_advisory_unlock($1::bigint)', [lockKey]);
          }
        } finally {
          client.release();
        }
      }
    },
  };
}

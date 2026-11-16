import jwt from 'jsonwebtoken';
import { Router } from 'express';
import { createAuthentication } from '../routes/users.routes.js';

export function createRealtimeFromEnv(env = process.env, send = fetch) {
  const { SUPABASE_URL, SUPABASE_SECRET_KEY, SUPABASE_PUBLISHABLE_KEY,
    SUPABASE_REALTIME_JWT_SECRET } = env;
  if (!SUPABASE_PUBLISHABLE_KEY && !SUPABASE_REALTIME_JWT_SECRET) return;
  const url = URL.parse(SUPABASE_URL ?? '');
  if (!url || !/^https:\/\/[a-z0-9]+\.supabase\.co\/$/.test(url.href) ||
      !SUPABASE_SECRET_KEY || !SUPABASE_PUBLISHABLE_KEY?.startsWith('sb_publishable_') ||
      !SUPABASE_REALTIME_JWT_SECRET || SUPABASE_REALTIME_JWT_SECRET === env.JWT_SECRET) {
    throw new Error('Invalid Supabase Realtime configuration');
  }
  const topic = (id) => `metagym-user:${id}`;
  return {
    subscription(userId) {
      return { url: url.origin, key: SUPABASE_PUBLISHABLE_KEY, topic: topic(userId),
        token: jwt.sign({ role: 'authenticated', metagym_realtime: true },
          SUPABASE_REALTIME_JWT_SECRET, { subject: userId, expiresIn: '5m' }) };
    },
    async publish(userId, event, payload) {
      try {
        const result = await send(new URL('/realtime/v1/api/broadcast', url), {
          method: 'POST', redirect: 'error', signal: AbortSignal.timeout(3000),
          headers: { apikey: SUPABASE_SECRET_KEY, 'content-type': 'application/json' },
          body: JSON.stringify({ messages: [{ topic: topic(userId), private: true, event, payload }] }),
        });
        await result.body?.cancel();
        if (!result.ok) console.warn('Supabase Realtime broadcast failed', result.status);
      } catch {
        console.warn('Supabase Realtime broadcast unavailable');
      }
    },
  };
}

export function createRealtimeRouter({ database, jwtSecret, realtime }) {
  const router = Router();
  router.get('/realtime/subscription', createAuthentication({ database, jwtSecret }), (req, res) => {
    res.set('Cache-Control', 'no-store');
    const { id, role } = req.authUser;
    res.json({ data: realtime && ['MEMBER', 'COACH'].includes(role)
      ? realtime.subscription(id) : null });
  });
  return router;
}

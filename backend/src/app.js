import cors from 'cors';
import express from 'express';
import helmet from 'helmet';
import morgan from 'morgan';

import { createAuthRouter } from './routes/auth.routes.js';
import { createAdminUsersRouter } from './routes/admin-users.routes.js';
import { createHealthRouter } from './routes/health.routes.js';
import { createUsersRouter } from './routes/users.routes.js';
import { createMembershipPlansRouter } from './routes/membership-plans.routes.js';
import { createCoachPackagesRouter } from './routes/coach-packages.routes.js';
import { createCoachScheduleRouter } from './routes/coach-schedule.routes.js';
import { createCoachPaymentHoldsRouter } from './routes/coach-payment-holds.routes.js';
import { createCoachBookingsRouter } from './routes/coach-bookings.routes.js';
import { createPaymentsRouter } from './routes/payments.routes.js';
import { createCoachingRouter } from './routes/coaching.routes.js';
import { createCatalogRouter } from './routes/catalog.routes.js';
import { createTrainingRouter } from './routes/training.routes.js';
import { retireLegacyWrites } from './routes/legacy-v1.routes.js';
import { createStructuredNutritionRouter } from './routes/structured-nutrition.routes.js';
import { createSessionsRouter } from './routes/sessions.routes.js';
import { createMessagingRouter } from './routes/messaging.routes.js';
import { createProgressRouter } from './routes/progress.routes.js';
import { createJournalRouter } from './routes/journal.routes.js';
import { createMemberSelfTrainingRouter } from './routes/member-self-training.routes.js';
import { createGymVisitsRouter } from './routes/gym-visits.routes.js';
import { createDashboardRouter } from './routes/dashboard.routes.js';
import { createAiConversationsRouter } from './routes/ai-conversations.routes.js';
import { createCallsRouter } from './routes/calls.routes.js';
import { createPasswordResetsRouter } from './routes/password-resets.routes.js';
import { createMediaRouter } from './routes/media.routes.js';
import { createDatabaseLoginRateLimiter } from './security/login-rate-limiter.js';

const JWT_SECRET_PLACEHOLDER =
  'replace-with-a-random-secret-of-at-least-32-characters';

function validateJwtSecret(jwtSecret) {
  if (typeof jwtSecret !== 'string' || jwtSecret.length === 0) {
    throw new Error('JWT_SECRET is required');
  }

  if (
    Buffer.byteLength(jwtSecret, 'utf8') < 32 ||
    jwtSecret === JWT_SECRET_PLACEHOLDER ||
    new Set(jwtSecret).size < 12
  ) {
    throw new Error('JWT_SECRET must be a strong non-placeholder secret');
  }
}

function allowedCorsOrigins(value, nodeEnv) {
  const origins = value?.split(',').map((origin) => origin.trim()).filter(Boolean) ?? [];
  if (nodeEnv === 'production' && !origins.length) {
    throw new Error('CORS_ALLOWED_ORIGINS is required in production');
  }
  for (const origin of origins) {
    let parsed;
    try { parsed = new URL(origin); }
    catch { throw new Error('CORS_ALLOWED_ORIGINS contains an invalid origin'); }
    if (parsed.origin !== origin ||
        (nodeEnv === 'production' && parsed.protocol !== 'https:')) {
      throw new Error('CORS_ALLOWED_ORIGINS contains an invalid origin');
    }
  }
  return origins.length ? origins : '*';
}

export function createApp({
  database,
  jwtSecret = process.env.JWT_SECRET,
  loginRateLimiter = createDatabaseLoginRateLimiter({ database }),
  sendPasswordResetCode,
  aiResponder,
  callTokenProvider,
  imageStorage,
  corsAllowedOrigins = process.env.CORS_ALLOWED_ORIGINS,
  nodeEnv = process.env.NODE_ENV,
  enableLegacyWrites = false,
}) {
  validateJwtSecret(jwtSecret);
  const corsOrigin = allowedCorsOrigins(corsAllowedOrigins, nodeEnv);

  const app = express();

  app.use(helmet());
  app.use(cors({ origin: corsOrigin }));
  app.use(express.json());
  app.use(morgan((tokens, request, response) =>
    `${tokens.method(request, response)} ${request.originalUrl.split('?')[0]} ${tokens.status(request, response)} ${tokens['response-time'](request, response)} ms`));

  app.use(
    '/api/v1/auth',
    createAuthRouter({ database, jwtSecret, loginRateLimiter }),
  );
  if (!enableLegacyWrites) app.use('/api/v1', retireLegacyWrites());
  app.use('/api/v1/health', createHealthRouter({ database }));
  app.use('/api/v1', createPasswordResetsRouter({ database, sendPasswordResetCode }));
  app.use('/api/v1', createMediaRouter({ database, jwtSecret, imageStorage }));
  app.use('/api/v1/users', createUsersRouter({ database, jwtSecret, imageStorage }));
  app.use('/api/v1/admin', createAdminUsersRouter({ database, jwtSecret }));
  app.use('/api/v1', createMembershipPlansRouter({ database, jwtSecret }));
  app.use('/api/v1', createCoachPackagesRouter({ database, jwtSecret }));
  app.use('/api/v1', createCoachScheduleRouter({ database, jwtSecret }));
  app.use('/api/v1', createCoachPaymentHoldsRouter({ database, jwtSecret }));
  app.use('/api/v1', createCoachBookingsRouter({ database, jwtSecret }));
  app.use('/api/v1', createCatalogRouter({ database, jwtSecret }));
  app.use('/api/v1', createStructuredNutritionRouter({ database, jwtSecret }));
  app.use('/api/v1', createTrainingRouter({ database, jwtSecret }));
  app.use('/api/v1', createSessionsRouter({ database, jwtSecret }));
  app.use('/api/v1', createMessagingRouter({ database, jwtSecret }));
  app.use('/api/v1', createProgressRouter({ database, jwtSecret }));
  app.use('/api/v1', createJournalRouter({ database, jwtSecret }));
  app.use('/api/v1', createMemberSelfTrainingRouter({ database, jwtSecret }));
  app.use('/api/v1', createGymVisitsRouter({ database, jwtSecret }));
  app.use('/api/v1', createDashboardRouter({ database, jwtSecret }));
  app.use('/api/v1', createAiConversationsRouter({ database, jwtSecret, aiResponder }));
  app.use('/api/v1', createCallsRouter({ database, jwtSecret, callTokenProvider }));
  app.use('/api/v1', createPaymentsRouter({ database, jwtSecret }));
  app.use('/api/v1', createCoachingRouter({ database, jwtSecret }));

  return app;
}

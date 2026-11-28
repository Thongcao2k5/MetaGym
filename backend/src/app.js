import cors from 'cors';
import express from 'express';
import helmet from 'helmet';
import morgan from 'morgan';

import { createAuthRouter, createPasswordResetsRouter } from './modules/auth/index.js';
import {
  createUsersRouter,
  createAdminUsersRouter,
  createAdminAuditRouter,
  createStaffRouter,
} from './modules/users/index.js';
import {
  createCoachingRouter,
  createCoachPackagesRouter,
  createCoachScheduleRouter,
  createCoachCalendarRouter,
  createCoachPaymentHoldsRouter,
  createCoachBookingsRouter,
  createCoachIncidentsRouter,
  createCoachOutcomesRouter,
} from './modules/coaching/index.js';
import { createMembershipPlansRouter, createGymVisitsRouter } from './modules/memberships/index.js';
import {
  createPaymentsRouter,
  createVnpayCallbacksRouter,
  createMomoCallbacksRouter,
  createZalopayCallbacksRouter,
  createVouchersRouter,
} from './modules/payments/index.js';
import {
  createMediaRouter,
  createImagesRouter,
  createImageCollectionsRouter,
  createImageAdminRouter,
} from './modules/media/index.js';
import {
  createTrainingRouter,
  createMemberSelfTrainingRouter,
  createCatalogRouter,
} from './modules/training/index.js';
import {
  createStructuredNutritionRouter,
  createMemberNutritionRouter,
} from './modules/nutrition/index.js';
import { createProgressRouter, createJournalRouter } from './modules/tracking/index.js';
import {
  createMessagingRouter,
  createCallsRouter,
  createSessionsRouter,
  createAiConversationsRouter,
} from './modules/communication/index.js';
import {
  createHealthRouter,
  createDashboardRouter,
  createDatabaseUiRouter,
  createDocsRouter,
  createSystemInfoRouter,
  retireLegacyWrites,
} from './modules/system/index.js';
import { createRealtimeRouter } from './config/realtime.js';
import { createNotificationsRouter } from './routes/notifications.routes.js';
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
  liveKit,
  realtime,
  fcm,
  imageStorage,
  vnpay,
  momo,
  zalopay,
  preferredPaymentGateway,
  corsAllowedOrigins = process.env.CORS_ALLOWED_ORIGINS,
  nodeEnv = process.env.NODE_ENV,
  enableLegacyWrites = false,
  enableCoachWorkflows = false,
  enableDatabaseUi = nodeEnv !== 'production',
  databaseUiUsername = process.env.DB_UI_USERNAME || 'admin',
  databaseUiPassword = process.env.DB_UI_PASSWORD || 'admin',
}) {
  validateJwtSecret(jwtSecret);
  const corsOrigin = allowedCorsOrigins(corsAllowedOrigins, nodeEnv);

  const app = express();

  app.use(helmet());
  app.use(cors({ origin: corsOrigin }));
  app.use(express.json());
  app.use(morgan((tokens, request, response) =>
    `${tokens.method(request, response)} ${request.originalUrl.split('?')[0]} ${tokens.status(request, response)} ${tokens['response-time'](request, response)} ms`));

  app.get('/ping', (_request, response) => {
    response.status(200).json({
      data: {
        status: 'ok',
        uptimeSeconds: Math.floor(process.uptime()),
      },
    });
  });

  app.use('/api-docs', createDocsRouter());
  if (enableDatabaseUi) {
    app.use(
      '/database',
      createDatabaseUiRouter({
        database,
        jwtSecret,
        username: databaseUiUsername,
        password: databaseUiPassword,
      }),
    );
  }
  app.use(
    '/api/v1/auth',
    createAuthRouter({ database, jwtSecret, loginRateLimiter }),
  );
  if (!enableLegacyWrites) app.use('/api/v1', retireLegacyWrites({ enableCoachWorkflows }));
  app.use('/api/v1/health', createHealthRouter({ database }));
  app.use('/api/v1/payments/vnpay', createVnpayCallbacksRouter({ database, vnpay }));
  app.use('/api/v1/payments/momo', createMomoCallbacksRouter({ database, momo }));
  app.use('/api/v1/payments/zalopay', createZalopayCallbacksRouter({ database, zalopay }));
  app.use('/api/v1', createPasswordResetsRouter({ database, sendPasswordResetCode }));
  app.use('/api/v1', createMediaRouter({ database, jwtSecret, imageStorage }));
  app.use('/api/v1', createSystemInfoRouter({ database, jwtSecret, imageStorage }));
  app.use('/api/v1', createVouchersRouter({ database, jwtSecret, imageStorage }));
  app.use('/api/v1', createImagesRouter({ database, jwtSecret, imageStorage }));
  app.use('/api/v1', createImageCollectionsRouter({ database, jwtSecret, imageStorage }));
  app.use('/api/v1', createImageAdminRouter({ database, jwtSecret, imageStorage }));
  app.use('/api/v1/users', createUsersRouter({ database, jwtSecret, imageStorage }));
  app.use('/api/v1/admin', createStaffRouter({ database, jwtSecret }));
  app.use('/api/v1/admin', createCoachCalendarRouter({ database, jwtSecret }));
  app.use('/api/v1/admin', createAdminUsersRouter({ database, jwtSecret, imageStorage }));
  app.use('/api/v1', createAdminAuditRouter({ database, jwtSecret }));
  app.use('/api/v1', createMembershipPlansRouter({ database, jwtSecret, imageStorage }));
  app.use('/api/v1', createCoachPackagesRouter({ database, jwtSecret }));
  app.use('/api/v1', createCoachScheduleRouter({ database, jwtSecret }));
  app.use('/api/v1', createCoachPaymentHoldsRouter({ database, jwtSecret }));
  app.use('/api/v1', createCoachBookingsRouter({ database, jwtSecret, realtime, fcm }));
  app.use('/api/v1', createCatalogRouter({ database, jwtSecret }));
  app.use('/api/v1', createStructuredNutritionRouter({ database, jwtSecret, realtime, fcm }));
  app.use('/api/v1', createTrainingRouter({ database, jwtSecret, realtime, fcm }));
  app.use('/api/v1', createSessionsRouter({ database, jwtSecret }));
  app.use('/api/v1', createRealtimeRouter({ database, jwtSecret, realtime }));
  app.use('/api/v1', createNotificationsRouter({ database, jwtSecret, realtime, fcm }));
  app.use('/api/v1', createMessagingRouter({ database, jwtSecret, realtime, fcm }));
  app.use('/api/v1', createMemberNutritionRouter({ database, jwtSecret }));
  app.use('/api/v1', createProgressRouter({ database, jwtSecret }));
  app.use('/api/v1', createJournalRouter({ database, jwtSecret }));
  app.use('/api/v1', createMemberSelfTrainingRouter({ database, jwtSecret }));
  app.use('/api/v1', createGymVisitsRouter({ database, jwtSecret }));
  app.use('/api/v1', createDashboardRouter({ database, jwtSecret }));
  app.use('/api/v1', createAiConversationsRouter({ database, jwtSecret, aiResponder }));
  app.use('/api/v1', createCallsRouter({ database, jwtSecret, callTokenProvider, liveKit, realtime, fcm }));
  app.use('/api/v1', createPaymentsRouter({ database, jwtSecret, vnpay, momo, zalopay, preferredPaymentGateway,
    allowMockPayments: nodeEnv !== 'production' && !vnpay && !momo && !zalopay }));
  app.use('/api/v1', createCoachingRouter({ database, jwtSecret }));
  app.use('/api/v1', createCoachIncidentsRouter({ database, jwtSecret }));
  app.use('/api/v1', createCoachOutcomesRouter({ database, jwtSecret, imageStorage }));

  return app;
}

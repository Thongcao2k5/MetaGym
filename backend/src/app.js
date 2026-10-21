import cors from 'cors';
import express from 'express';
import helmet from 'helmet';
import morgan from 'morgan';

import { createAuthRouter } from './routes/auth.routes.js';
import { createHealthRouter } from './routes/health.routes.js';
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

export function createApp({
  database,
  jwtSecret = process.env.JWT_SECRET,
  loginRateLimiter = createDatabaseLoginRateLimiter({ database }),
}) {
  validateJwtSecret(jwtSecret);

  const app = express();

  app.use(helmet());
  app.use(cors());
  app.use(express.json());
  app.use(morgan('dev'));

  app.use(
    '/api/v1/auth',
    createAuthRouter({ database, jwtSecret, loginRateLimiter }),
  );
  app.use('/api/v1/health', createHealthRouter({ database }));

  return app;
}

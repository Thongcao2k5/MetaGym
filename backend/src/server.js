import 'dotenv/config';
import path from 'node:path';

import { createApp } from './app.js';
import { createDatabasePool } from './config/database.js';
import { createRealtimeFromEnv } from './config/realtime.js';
import { createFcmFromEnv } from './config/fcm.js';
import { createLiveKitFromEnv } from './config/livekit.js';
import { createVnpayFromEnv } from './config/vnpay.js';
import { createMomoFromEnv } from './config/momo.js';
import { createZalopayFromEnv } from './config/zalopay.js';
import {
  createAiResponderFromEnv,
  createCallTokenProviderFromEnv,
  createPasswordResetSenderFromEnv,
} from './config/providers.js';
import { createImageStorageFromEnv } from './storage/image-storage.js';
import { createLocalImageStorage } from './storage/local-image-storage.js';

const port = Number(process.env.PORT ?? 3000);
const database = createDatabasePool();
const imageStorage =
  createImageStorageFromEnv(process.env) ??
  (process.env.NODE_ENV !== 'production'
    ? createLocalImageStorage(path.resolve('uploads/media'))
    : undefined);
let vnpay;
try {
  vnpay = createVnpayFromEnv();
} catch {
  console.error('Kiểm tra cấu hình merchant và URL HTTPS của VNPay Sandbox.');
}
let momo;
try {
  momo = createMomoFromEnv();
} catch {
  console.error('Kiểm tra cấu hình merchant và URL HTTPS của MoMo Sandbox.');
}
let zalopay;
try {
  zalopay = createZalopayFromEnv();
} catch {
  console.error('Kiểm tra cấu hình merchant của ZaloPay Sandbox.');
}
let fcm;
try {
  fcm = createFcmFromEnv();
} catch {
  console.error('Kiểm tra cấu hình Firebase Cloud Messaging (FCM_PROJECT_ID, FCM_CLIENT_EMAIL, FCM_PRIVATE_KEY).');
}
const app = createApp({
  database,
  enableCoachWorkflows: process.env.ENABLE_COACH_WORKFLOWS === 'true',
  enableDatabaseUi: process.env.ENABLE_DB_UI
    ? process.env.ENABLE_DB_UI === 'true'
    : process.env.NODE_ENV !== 'production',
  vnpay,
  momo,
  zalopay,
  preferredPaymentGateway: process.env.PAYMENT_GATEWAY,
  realtime: createRealtimeFromEnv(),
  fcm,
  imageStorage,
  sendPasswordResetCode: createPasswordResetSenderFromEnv(),
  aiResponder: createAiResponderFromEnv(),
  callTokenProvider: createCallTokenProviderFromEnv(),
  liveKit: createLiveKitFromEnv(),
});

const server = app.listen(port, '0.0.0.0', () => {
  console.log(`Meta Gym API is running at http://0.0.0.0:${port}`);
});

async function shutdown() {
  server.close(async () => {
    await database.end();
  });
}

process.on('SIGINT', shutdown);
process.on('SIGTERM', shutdown);

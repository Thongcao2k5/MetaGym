import 'dotenv/config';

import { createApp } from './app.js';
import { createDatabasePool } from './config/database.js';
import {
  createAiResponderFromEnv,
  createCallTokenProviderFromEnv,
  createPasswordResetSenderFromEnv,
} from './config/providers.js';
import { createImageStorageFromEnv } from './storage/image-storage.js';

const port = Number(process.env.PORT ?? 3000);
const database = createDatabasePool();
const imageStorage = createImageStorageFromEnv(process.env);
const app = createApp({
  database,
  imageStorage,
  sendPasswordResetCode: createPasswordResetSenderFromEnv(),
  aiResponder: createAiResponderFromEnv(),
  callTokenProvider: createCallTokenProviderFromEnv(),
});

const server = app.listen(port, () => {
  console.log(`Meta Gym API is running at http://localhost:${port}`);
});

async function shutdown() {
  server.close(async () => {
    await database.end();
  });
}

process.on('SIGINT', shutdown);
process.on('SIGTERM', shutdown);

import 'dotenv/config';

import { createApp } from './app.js';
import { createDatabasePool } from './config/database.js';

const port = Number(process.env.PORT ?? 3000);
const database = createDatabasePool();
const app = createApp({ database });

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

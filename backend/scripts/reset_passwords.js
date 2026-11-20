import 'dotenv/config';
import bcrypt from 'bcryptjs';
import pg from 'pg';

const { Client } = pg;
const client = new Client({
  connectionString: process.env.DATABASE_URL || 'postgresql://postgres:postgres@localhost:5432/meta_gym'
});

async function run() {
  await client.connect();
  const hash = bcrypt.hashSync('123456aA@', 10);
  const result = await client.query('UPDATE users SET password_hash = $1', [hash]);
  console.log('Successfully updated', result.rowCount, 'users to password: 123456aA@');
  await client.end();
}

run().catch(console.error);

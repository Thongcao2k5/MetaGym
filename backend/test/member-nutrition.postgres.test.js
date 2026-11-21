import assert from 'node:assert/strict';
import { randomUUID } from 'node:crypto';
import test from 'node:test';

import jwt from 'jsonwebtoken';
import pg from 'pg';

import { createApp } from '../src/app.js';

const databaseUrl = process.env.TEST_DATABASE_URL;
const secret = 'member-nutrition-postgres-test-secret';

test('PostgreSQL nutrition menu history freezes the daily snapshot and remains owned by its fixture',
  { skip: !databaseUrl }, async () => {
    const database = new pg.Pool({ connectionString: databaseUrl });
    const memberId = randomUUID();
    const coachId = randomUUID();
    const relationshipId = randomUUID();
    const guideId = randomUUID();
    const app = createApp({ database, jwtSecret: secret });
    const server = app.listen(0, '127.0.0.1');
    const bearer = jwt.sign({ role: 'MEMBER', sessionVersion: 0 }, secret, {
      algorithm: 'HS256', audience: 'meta-gym-clients', issuer: 'meta-gym-api',
      subject: memberId, expiresIn: 3600,
    });

    async function readDay(day) {
      const response = await fetch(
        `http://127.0.0.1:${server.address().port}/api/v1/member/nutrition/day?date=${day}`,
        { headers: { authorization: `Bearer ${bearer}` } },
      );
      const body = await response.json();
      assert.equal(response.status, 200, JSON.stringify(body));
      return body.data;
    }

    try {
      await database.query(
        `INSERT INTO users (id, email, password_hash, role, full_name)
         VALUES ($1, $2, 'hash', 'MEMBER', 'Nutrition Member'),
                ($3, $4, 'hash', 'COACH', 'Nutrition Coach')`,
        [memberId, `${memberId}@example.com`, coachId, `${coachId}@example.com`],
      );
      await database.query(
        `INSERT INTO coach_relationships (id, member_id, coach_id)
         VALUES ($1, $2, $3)`, [relationshipId, memberId, coachId],
      );
      const day = await database.query(
        "SELECT (now() AT TIME ZONE 'Asia/Ho_Chi_Minh')::date::text AS date",
      );
      const today = day.rows[0].date;
      const menuItem = {
        day: new Date(`${today}T12:00:00+07:00`).getUTCDay() || 7,
        meal: 'BREAKFAST', foodId: randomUUID(), foodName: 'Rice', grams: 120,
      };
      await database.query(
        `INSERT INTO nutrition_guides
           (id, relationship_id, member_id, coach_id, title, content, version,
            status, published_at, meal_items)
         VALUES ($1, $2, $3, $4, 'First menu', 'Breakfast', 1, 'ACTIVE', now(), $5::jsonb)`,
        [guideId, relationshipId, memberId, coachId, JSON.stringify([menuItem])],
      );

      const firstDay = await readDay(today);
      assert.equal(firstDay.plan.title, 'First menu');
      assert.equal(firstDay.plan.items[0].grams, 120);
      const firstRevisionId = firstDay.plan.revisionId;

      await database.query(
        'UPDATE nutrition_guides SET title = $2, meal_items = $3::jsonb WHERE id = $1',
        [guideId, 'Revised menu', JSON.stringify([{ ...menuItem, grams: 180 }])],
      );
      const sameDay = await readDay(today);
      assert.equal(sameDay.plan.title, 'First menu');
      assert.equal(sameDay.plan.items[0].grams, 120);
      const revisionCount = await database.query(
        `SELECT id::text AS id, title, items FROM nutrition_guide_revisions
         WHERE guide_id = $1 ORDER BY id`,
        [guideId],
      );
      assert.equal(revisionCount.rows.length, 2);
      assert.equal(revisionCount.rows[0].id, String(firstRevisionId));
      assert.equal(revisionCount.rows[0].items[0].grams, 120);
      assert.equal(revisionCount.rows[1].title, 'Revised menu');
      assert.equal(revisionCount.rows[1].items[0].grams, 180);
      assert.notEqual(sameDay.plan.revisionId, revisionCount.rows[1].id);
      await assert.rejects(
        database.query('DELETE FROM nutrition_guides WHERE id = $1', [guideId]),
        (error) => error.code === '23503',
      );
      assert.equal((await database.query(
        'SELECT 1 FROM nutrition_guides WHERE id = $1', [guideId],
      )).rowCount, 1);
    } finally {
      try {
        await database.query('BEGIN');
        await database.query('DELETE FROM member_nutrition_days WHERE member_id = $1', [memberId]);
        await database.query('DELETE FROM nutrition_guide_revisions WHERE guide_id = $1', [guideId]);
        await database.query('DELETE FROM nutrition_guides WHERE id = $1', [guideId]);
        await database.query('DELETE FROM coach_relationships WHERE id = $1', [relationshipId]);
        await database.query('DELETE FROM users WHERE id = ANY($1::uuid[])', [[memberId, coachId]]);
        await database.query('COMMIT');
      } catch (error) {
        await database.query('ROLLBACK').catch(() => {});
        throw error;
      } finally {
        await new Promise((resolve) => server.close(resolve));
        await database.end();
      }
    }
  });

import assert from 'node:assert/strict';
import { randomUUID } from 'node:crypto';
import fs from 'node:fs/promises';
import os from 'node:os';
import path from 'node:path';
import test from 'node:test';

import jwt from 'jsonwebtoken';
import pg from 'pg';
import sharp from 'sharp';

import { createApp } from '../src/app.js';
import { createLocalImageStorage } from '../src/storage/local-image-storage.js';

const databaseUrl = process.env.TEST_DATABASE_URL;
const secret = 'coach-outcomes-integration-secret-32-chars';

test(
  'Coach outcome cases stay private until Member approves and support anonymity and withdrawal',
  { skip: !databaseUrl },
  async () => {
    const database = new pg.Pool({ connectionString: databaseUrl });
    const storageDir = await fs.mkdtemp(path.join(os.tmpdir(), 'metagym-outcomes-'));
    const imageStorage = createLocalImageStorage(storageDir);
    const server = createApp({ database, jwtSecret: secret, imageStorage }).listen(0);
    const [coach, member, outsider] = [randomUUID(), randomUUID(), randomUUID()];
    const relationshipId = randomUUID();

    function tokenFor(userId, role) {
      return jwt.sign({ role, sessionVersion: 0 }, secret, {
        algorithm: 'HS256',
        audience: 'meta-gym-clients',
        issuer: 'meta-gym-api',
        subject: userId,
        expiresIn: 3600,
      });
    }

    async function callJson(userId, role, apiPath, method = 'GET', body) {
      const response = await fetch(
        `http://127.0.0.1:${server.address().port}/api/v1${apiPath}`,
        {
          method,
          headers: {
            authorization: `Bearer ${tokenFor(userId, role)}`,
            ...(body ? { 'content-type': 'application/json' } : {}),
          },
          body: body ? JSON.stringify(body) : undefined,
        },
      );
      return { status: response.status, body: await response.json() };
    }

    async function uploadOutcomeImage(userId, role, bytes, fileName) {
      const response = await fetch(
        `http://127.0.0.1:${server.address().port}/api/v1/media/images`,
        {
          method: 'POST',
          headers: {
            authorization: `Bearer ${tokenFor(userId, role)}`,
            'content-type': 'image/png',
            'x-image-purpose': 'COACH_OUTCOME',
            'x-file-name': fileName,
          },
          body: bytes,
        },
      );
      return { status: response.status, body: await response.json() };
    }

    try {
      await database.query(
        `INSERT INTO users (id, email, password_hash, role, full_name) VALUES
         ($1, $2, 'hash', 'COACH', 'Lê Hoàng Nam'),
         ($3, $4, 'hash', 'MEMBER', 'Trần Gia Huy'),
         ($5, $6, 'hash', 'MEMBER', 'Khách Ngoài')`,
        [
          coach, `${coach}@example.com`,
          member, `${member}@example.com`,
          outsider, `${outsider}@example.com`,
        ],
      );
      await database.query(`INSERT INTO coach_profiles (user_id, member_limit) VALUES ($1, 8)`, [coach]);
      await database.query(
        `INSERT INTO member_profiles (user_id) VALUES ($1), ($2)`,
        [member, outsider],
      );
      await database.query(
        `INSERT INTO coach_relationships (id, member_id, coach_id, status)
         VALUES ($1, $2, $3, 'ACTIVE')`,
        [relationshipId, member, coach],
      );

      const samplePng = await sharp({
        create: { width: 8, height: 8, channels: 3, background: { r: 255, g: 94, b: 54 } },
      }).png().toBuffer();

      // Members cannot upload COACH_OUTCOME assets.
      const forbiddenUpload = await uploadOutcomeImage(member, 'MEMBER', samplePng, 'hack.png');
      assert.equal(forbiddenUpload.status, 422);

      // Coach cannot submit outcomes for unassigned Members.
      const noRel = await callJson(
        coach, 'COACH', `/coach/members/${outsider}/outcomes`, 'POST',
        { goal: 'Tăng cơ', durationWeeks: 8, beforeWeightKg: 70, afterWeightKg: 73 },
      );
      assert.equal(noRel.status, 409);

      const beforeMedia = await uploadOutcomeImage(coach, 'COACH', samplePng, 'before.png');
      const afterMedia = await uploadOutcomeImage(coach, 'COACH', samplePng, 'after.png');
      assert.equal(beforeMedia.status, 201);
      assert.equal(afterMedia.status, 201);

      const created = await callJson(
        coach, 'COACH', `/coach/members/${member}/outcomes`, 'POST',
        {
          goal: 'Tăng cơ',
          durationWeeks: 12,
          beforeWeightKg: 68,
          afterWeightKg: 73,
          beforeBodyFatPercent: 22,
          afterBodyFatPercent: 17,
          beforeMediaId: beforeMedia.body.data.id,
          afterMediaId: afterMedia.body.data.id,
        },
      );
      assert.equal(created.status, 201, JSON.stringify(created.body));
      const outcomeId = created.body.data.id;
      assert.equal(created.body.data.status, 'PENDING_MEMBER');

      // Pending outcome & photos are hidden from other Members.
      const publicPending = await callJson(outsider, 'MEMBER', `/coaches/${coach}/outcomes`);
      assert.equal(publicPending.status, 200);
      assert.deepEqual(publicPending.body.data, []);

      const blockedPhoto = await fetch(
        `http://127.0.0.1:${server.address().port}/api/v1/coach-outcomes/${outcomeId}/photos/before`,
        { headers: { authorization: `Bearer ${tokenFor(outsider, 'MEMBER')}` } },
      );
      assert.equal(blockedPhoto.status, 404);

      // Outsider cannot approve someone else's outcome.
      const outsiderApprove = await callJson(
        outsider, 'MEMBER', `/member/coach-outcomes/${outcomeId}`, 'PATCH',
        { decision: 'APPROVED', allowRealName: true },
      );
      assert.equal(outsiderApprove.status, 404);

      // Member sees pending outcome and approves anonymously.
      const memberList = await callJson(member, 'MEMBER', '/member/coach-outcomes');
      assert.equal(memberList.status, 200);
      assert.equal(memberList.body.data.length, 1);

      const approvedAnon = await callJson(
        member, 'MEMBER', `/member/coach-outcomes/${outcomeId}`, 'PATCH',
        { decision: 'APPROVED', allowRealName: false },
      );
      assert.equal(approvedAnon.status, 200);
      assert.equal(approvedAnon.body.data.status, 'APPROVED');

      const publicAnon = await callJson(outsider, 'MEMBER', `/coaches/${coach}/outcomes`);
      assert.equal(publicAnon.body.data.length, 1);
      assert.equal(publicAnon.body.data[0].studentName, 'Học viên ẩn danh');
      assert.equal(publicAnon.body.data[0].studentInitials, 'HV');
      assert.equal(publicAnon.body.data[0].beforeWeightKg, 68);
      assert.equal(publicAnon.body.data[0].afterWeightKg, 73);

      const allowedPhoto = await fetch(
        `http://127.0.0.1:${server.address().port}/api/v1/coach-outcomes/${outcomeId}/photos/before`,
        { headers: { authorization: `Bearer ${tokenFor(outsider, 'MEMBER')}` } },
      );
      assert.equal(allowedPhoto.status, 200);

      // Member opts in to real name.
      const approvedNamed = await callJson(
        member, 'MEMBER', `/member/coach-outcomes/${outcomeId}`, 'PATCH',
        { allowRealName: true },
      );
      assert.equal(approvedNamed.status, 200);
      const publicNamed = await callJson(outsider, 'MEMBER', `/coaches/${coach}/outcomes`);
      assert.equal(publicNamed.body.data[0].studentName, 'Trần Gia Huy');
      assert.equal(publicNamed.body.data[0].studentInitials, 'TH');

      // Member withdraws consent & deletes photos; immediately hidden.
      const withdrawn = await callJson(
        member, 'MEMBER', `/member/coach-outcomes/${outcomeId}`, 'PATCH',
        { decision: 'WITHDRAWN', removePhotos: true },
      );
      assert.equal(withdrawn.status, 200);
      assert.equal(withdrawn.body.data.status, 'WITHDRAWN');
      const publicAfterWithdraw = await callJson(outsider, 'MEMBER', `/coaches/${coach}/outcomes`);
      assert.deepEqual(publicAfterWithdraw.body.data, []);

      const revokedPhoto = await fetch(
        `http://127.0.0.1:${server.address().port}/api/v1/coach-outcomes/${outcomeId}/photos/before`,
        { headers: { authorization: `Bearer ${tokenFor(outsider, 'MEMBER')}` } },
      );
      assert.equal(revokedPhoto.status, 404);
    } finally {
      server.close();
      await database.query(`DELETE FROM coach_outcome_cases WHERE coach_id = $1`, [coach]);
      await database.query(`DELETE FROM media_assets WHERE owner_id = ANY($1::uuid[])`, [[coach, member, outsider]]);
      await database.query(`DELETE FROM coach_relationships WHERE coach_id = $1`, [coach]);
      await database.query(`DELETE FROM coach_profiles WHERE user_id = $1`, [coach]);
      await database.query(`DELETE FROM member_profiles WHERE user_id = ANY($1::uuid[])`, [[member, outsider]]);
      await database.query(`DELETE FROM users WHERE id = ANY($1::uuid[])`, [[coach, member, outsider]]);
      await database.end();
      await fs.rm(storageDir, { recursive: true, force: true });
    }
  },
);

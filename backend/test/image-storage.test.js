import assert from 'node:assert/strict';
import test from 'node:test';

import { createImageStorageFromEnv } from '../src/storage/image-storage.js';
import { createSupabaseImageStorage } from '../src/storage/supabase-image-storage.js';

test('Supabase image storage uploads and downloads private object bytes', async () => {
  const calls = [];
  const client = {
    storage: {
      from(bucket) {
        assert.equal(bucket, 'meta-gym-media');
        return {
          async upload(key, bytes, options) {
            calls.push({ key, bytes, options });
            return { error: null };
          },
          async download(key) {
            assert.equal(key, 'f47ac10b-58cc-4372-a567-0e02b2c3d479');
            return { data: new Blob([Buffer.from('stored-image')]), error: null };
          },
        };
      },
    },
  };
  const storage = createSupabaseImageStorage({
    url: 'https://project.supabase.co',
    secretKey: 'sb_secret_test',
    bucket: 'meta-gym-media',
    createClient: () => client,
  });
  const key = 'f47ac10b-58cc-4372-a567-0e02b2c3d479';
  const bytes = Buffer.from('image');

  await storage.put(key, bytes, 'image/jpeg');
  const downloaded = await storage.get(key);

  assert.equal(calls.length, 1);
  assert.equal(calls[0].key, key);
  assert.equal(calls[0].bytes, bytes);
  assert.deepEqual(calls[0].options, {
    contentType: 'image/jpeg',
    upsert: false,
  });
  assert.deepEqual(downloaded, Buffer.from('stored-image'));
});

test('Supabase image storage converts provider failures to storage errors', async () => {
  const client = {
    storage: {
      from: () => ({
        upload: async () => ({ error: new Error('provider unavailable') }),
        download: async () => ({ data: null, error: new Error('missing') }),
      }),
    },
  };
  const storage = createSupabaseImageStorage({
    url: 'https://project.supabase.co',
    secretKey: 'sb_secret_test',
    bucket: 'meta-gym-media',
    createClient: () => client,
  });

  await assert.rejects(
    storage.put('f47ac10b-58cc-4372-a567-0e02b2c3d479', Buffer.from('image'), 'image/png'),
    /Supabase Storage upload failed/,
  );
  await assert.rejects(
    storage.get('f47ac10b-58cc-4372-a567-0e02b2c3d479'),
    /Supabase Storage download failed/,
  );
});

test('image storage configuration prefers complete Supabase settings', () => {
  const selected = createImageStorageFromEnv({
    SUPABASE_URL: 'https://project.supabase.co',
    SUPABASE_SECRET_KEY: 'sb_secret_test',
    SUPABASE_STORAGE_BUCKET: 'meta-gym-media',
    MEDIA_STORAGE_DIR: 'C:\\local-media',
  }, {
    createSupabase: (settings) => ({ provider: 'supabase', settings }),
    createLocal: () => ({ provider: 'local' }),
  });

  assert.equal(selected.provider, 'supabase');
  assert.equal(selected.settings.bucket, 'meta-gym-media');
});

test('image storage configuration rejects incomplete Supabase settings', () => {
  assert.throws(
    () => createImageStorageFromEnv({ SUPABASE_URL: 'https://project.supabase.co' }),
    /SUPABASE_URL, SUPABASE_SECRET_KEY and SUPABASE_STORAGE_BUCKET/,
  );
});

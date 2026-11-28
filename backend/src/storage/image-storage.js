import { createLocalImageStorage } from './local-image-storage.js';
import { createS3CompatibleImageStorage } from './s3-image-storage.js';
import { createSupabaseImageStorage } from './supabase-image-storage.js';

export function createImageStorageFromEnv(env, factories = {}) {
  const createLocal = factories.createLocal ?? createLocalImageStorage;
  const createSupabase = factories.createSupabase ?? createSupabaseImageStorage;
  const createS3 = factories.createS3 ?? createS3CompatibleImageStorage;

  const supabase = {
    url: env.SUPABASE_URL?.trim(),
    secretKey: env.SUPABASE_SECRET_KEY?.trim(),
    bucket: env.SUPABASE_STORAGE_BUCKET?.trim(),
  };
  const configuredValues = Object.values(supabase).filter(Boolean).length;
  if (configuredValues > 0 && configuredValues < 3) {
    throw new Error(
      'SUPABASE_URL, SUPABASE_SECRET_KEY and SUPABASE_STORAGE_BUCKET must be configured together',
    );
  }
  if (configuredValues === 3) {
    const cloud = createSupabase(supabase);
    if (!env.MEDIA_STORAGE_DIR) return cloud;

    const local = createLocal(env.MEDIA_STORAGE_DIR);
    return {
      ...cloud,
      async get(key) {
        try {
          return await local.get(key);
        } catch (error) {
          if (error.code !== 'ENOENT') throw error;
          return cloud.get(key);
        }
      },
    };
  }

  const s3 = {
    bucket: env.S3_BUCKET?.trim(),
    accessKeyId: env.S3_ACCESS_KEY_ID?.trim(),
    secretAccessKey: env.S3_SECRET_ACCESS_KEY?.trim(),
    endpoint: env.S3_ENDPOINT?.trim(),
    region: env.S3_REGION?.trim() || 'auto',
  };
  if (s3.bucket && s3.accessKeyId && s3.secretAccessKey) {
    return createS3(s3);
  }

  if (env.MEDIA_STORAGE_DIR) return createLocal(env.MEDIA_STORAGE_DIR);
  return undefined;
}

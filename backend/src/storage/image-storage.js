import { createLocalImageStorage } from './local-image-storage.js';
import { createSupabaseImageStorage } from './supabase-image-storage.js';

export function createImageStorageFromEnv(env, factories = {}) {
  const createLocal = factories.createLocal ?? createLocalImageStorage;
  const createSupabase = factories.createSupabase ?? createSupabaseImageStorage;
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
  if (env.MEDIA_STORAGE_DIR) return createLocal(env.MEDIA_STORAGE_DIR);
  return undefined;
}

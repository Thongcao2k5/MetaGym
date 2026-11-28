import { createClient as createSupabaseClient } from '@supabase/supabase-js';

import { assertValidStorageKey } from './storage-key.js';

const KNOWN_PREFIXES = ['', 'original', 'thumbnails', 'variants', 'avatars', 'equipment', 'exercises', 'gym', 'misc'];

/**
 * Creates a Supabase Storage adapter for private bucket object operations.
 */
export function createSupabaseImageStorage({
  url,
  secretKey,
  bucket,
  createClient = createSupabaseClient,
}) {
  if (!url || !secretKey || !bucket) {
    throw new Error('Supabase Storage configuration is incomplete');
  }
  const client = createClient(url, secretKey, {
    auth: {
      autoRefreshToken: false,
      persistSession: false,
      detectSessionInUrl: false,
    },
  });
  const objects = client.storage.from(bucket);

  return {
    providerType: 'supabase',
    async put(key, bytes, mimeType) {
      assertValidStorageKey(key);
      const { error } = await objects.upload(key, bytes, {
        contentType: mimeType,
        upsert: false,
      });
      if (error) throw new Error('Supabase Storage upload failed', { cause: error });
    },
    async get(key) {
      assertValidStorageKey(key);
      const { data, error } = await objects.download(key);
      if (error || !data) {
        throw new Error('Supabase Storage download failed', { cause: error });
      }
      return Buffer.from(await data.arrayBuffer());
    },
    async remove(key) {
      assertValidStorageKey(key);
      const { error } = await objects.remove([key]);
      if (error) throw new Error('Supabase Storage cleanup failed', { cause: error });
    },
    async list(prefix = '') {
      const prefixes = prefix ? [prefix.replace(/\/$/, '')] : KNOWN_PREFIXES;
      const keys = new Set();
      for (const dir of prefixes) {
        const { data, error } = await objects.list(dir, { limit: 1000 });
        if (error || !Array.isArray(data)) continue;
        for (const item of data) {
          if (!item?.name || item.id === null) continue;
          const key = dir ? `${dir}/${item.name}` : item.name;
          if (!prefix || key.startsWith(prefix)) keys.add(key);
        }
      }
      return [...keys];
    },
    async healthCheck() {
      const { error } = await objects.list('', { limit: 1 });
      if (error) throw new Error('Supabase Storage health check failed', { cause: error });
      return { status: 'healthy', provider: 'supabase', bucket };
    },
  };
}

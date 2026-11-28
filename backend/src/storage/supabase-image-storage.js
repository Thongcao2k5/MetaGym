import { createClient as createSupabaseClient } from '@supabase/supabase-js';

import { assertValidStorageKey } from './storage-key.js';

async function traverseStorage(objects, prefix = '') {
  const rootDir = prefix ? prefix.replace(/\/$/, '') : '';
  const queue = [rootDir];
  const visited = new Set();
  const entries = [];

  while (queue.length > 0) {
    const dir = queue.shift();
    if (visited.has(dir)) continue;
    visited.add(dir);

    let offset = 0;
    const pageSize = 1000;
    while (true) {
      const { data, error } = await objects.list(dir, { limit: pageSize, offset });
      if (error || !Array.isArray(data) || data.length === 0) break;

      for (const item of data) {
        if (!item?.name) continue;
        const fullKey = dir ? `${dir}/${item.name}` : item.name;
        if (item.id === null) {
          queue.push(fullKey);
        } else if (!prefix || fullKey.startsWith(prefix)) {
          entries.push({
            key: fullKey,
            name: item.name,
            sizeBytes: Number(item.metadata?.size ?? item.metadata?.contentLength ?? 0),
            mimeType: item.metadata?.mimetype || null,
            createdAt: item.created_at || null,
            updatedAt: item.updated_at || null,
          });
        }
      }

      if (data.length < pageSize) break;
      offset += data.length;
    }
  }
  return entries;
}

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
    bucket,
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
    async listDetailed(prefix = '') {
      return traverseStorage(objects, prefix);
    },
    async list(prefix = '') {
      const entries = await traverseStorage(objects, prefix);
      return entries.map((e) => e.key);
    },
    async healthCheck() {
      const { error } = await objects.list('', { limit: 1 });
      if (error) throw new Error('Supabase Storage health check failed', { cause: error });
      return { status: 'healthy', provider: 'supabase', bucket };
    },
  };
}

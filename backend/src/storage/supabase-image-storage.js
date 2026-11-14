import { createClient as createSupabaseClient } from '@supabase/supabase-js';

const keyPattern = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/;

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
  const validateKey = (key) => {
    if (!keyPattern.test(key)) throw new Error('Invalid image storage key');
  };

  return {
    async put(key, bytes, mimeType) {
      validateKey(key);
      const { error } = await objects.upload(key, bytes, {
        contentType: mimeType,
        upsert: false,
      });
      if (error) throw new Error('Supabase Storage upload failed', { cause: error });
    },
    async get(key) {
      validateKey(key);
      const { data, error } = await objects.download(key);
      if (error || !data) {
        throw new Error('Supabase Storage download failed', { cause: error });
      }
      return Buffer.from(await data.arrayBuffer());
    },
    async remove(key) {
      validateKey(key);
      const { error } = await objects.remove([key]);
      if (error) throw new Error('Supabase Storage cleanup failed', { cause: error });
    },
  };
}

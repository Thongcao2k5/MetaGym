import { resolveThumbKeys } from '../../storage/storage-key.js';
import { resetSupabaseSyncCache } from './supabase-sync.js';

/**
 * Prepares transactional DB row cleanup (via SAVEPOINT) and post-commit Storage removal
 * for a `media_assets` record plus any derived thumbnail variants.
 */
export async function prepareMediaAssetCleanup(client, mediaId, { purpose, refCheck } = {}) {
  const noop = {
    async deleteDbRow() {},
    async removeStorageObjects() {},
  };
  if (!mediaId || !client) return noop;

  const assetRes = await client.query(
    `SELECT id, storage_key, purpose
     FROM media_assets
     WHERE id = $1 ${purpose ? 'AND purpose = $2' : ''}`,
    purpose ? [mediaId, purpose] : [mediaId],
  );
  const asset = assetRes.rows[0];
  if (!asset) return noop;

  if (typeof refCheck === 'function') {
    const stillReferenced = await refCheck(client, asset.id);
    if (stillReferenced) return noop;
  }

  let deletedFromDb = false;

  return {
    async deleteDbRow() {
      await client.query('SAVEPOINT sp_delete_old_media');
      try {
        if (asset.storage_key) {
          await client.query('DELETE FROM images WHERE storage_key = $1', [asset.storage_key]);
        }
        await client.query('DELETE FROM media_assets WHERE id = $1', [asset.id]);
        await client.query('RELEASE SAVEPOINT sp_delete_old_media');
        deletedFromDb = true;
      } catch {
        await client.query('ROLLBACK TO SAVEPOINT sp_delete_old_media').catch(() => {});
      }
      if (deletedFromDb) resetSupabaseSyncCache();
    },
    async removeStorageObjects(imageStorage) {
      if (!deletedFromDb || !asset.storage_key || !imageStorage || typeof imageStorage.remove !== 'function') {
        return;
      }
      const keys = [asset.storage_key, ...resolveThumbKeys(asset.storage_key)];
      await Promise.all(keys.map((key) => imageStorage.remove(key).catch(() => {})));
    },
  };
}

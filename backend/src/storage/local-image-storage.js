import { access, mkdir, readdir, readFile, unlink, writeFile } from 'node:fs/promises';
import path from 'node:path';

import { assertValidStorageKey } from './storage-key.js';

async function collectKeys(rootDir, currentDir, prefixFilter) {
  let entries;
  try {
    entries = await readdir(currentDir, { withFileTypes: true });
  } catch (error) {
    if (error.code === 'ENOENT') return [];
    throw error;
  }
  const keys = [];
  for (const entry of entries) {
    const full = path.join(currentDir, entry.name);
    if (entry.isDirectory()) {
      keys.push(...await collectKeys(rootDir, full, prefixFilter));
    } else if (entry.isFile()) {
      const rel = path.relative(rootDir, full).split(path.sep).join('/');
      if (!prefixFilter || rel.startsWith(prefixFilter)) {
        keys.push(rel);
      }
    }
  }
  return keys;
}

/**
 * Creates a filesystem-backed image storage adapter inside `directory`.
 */
export function createLocalImageStorage(directory) {
  if (typeof directory !== 'string' || !path.isAbsolute(directory)) {
    throw new Error('MEDIA_STORAGE_DIR must be an absolute path');
  }
  const location = (key) => {
    assertValidStorageKey(key);
    const resolved = path.resolve(directory, key);
    const rootResolved = path.resolve(directory);
    if (!resolved.startsWith(`${rootResolved}${path.sep}`)) {
      throw new Error('Invalid image storage key');
    }
    return resolved;
  };
  return {
    providerType: 'local',
    async put(key, bytes) {
      const target = location(key);
      await mkdir(path.dirname(target), { recursive: true, mode: 0o700 });
      await writeFile(target, bytes, { flag: 'wx', mode: 0o600 });
    },
    async get(key) {
      return readFile(location(key));
    },
    async remove(key) {
      try {
        await unlink(location(key));
      } catch (error) {
        if (error.code !== 'ENOENT') throw error;
      }
    },
    async list(prefix = '') {
      await mkdir(directory, { recursive: true, mode: 0o700 });
      return collectKeys(directory, directory, prefix);
    },
    async healthCheck() {
      await mkdir(directory, { recursive: true, mode: 0o700 });
      await access(directory);
      return { status: 'healthy', provider: 'local', directory };
    },
  };
}

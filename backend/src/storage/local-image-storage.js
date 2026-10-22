import { mkdir, readFile, writeFile } from 'node:fs/promises';
import path from 'node:path';

const keyPattern = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/;

export function createLocalImageStorage(directory) {
  if (typeof directory !== 'string' || !path.isAbsolute(directory)) {
    throw new Error('MEDIA_STORAGE_DIR must be an absolute path');
  }
  const location = (key) => {
    if (!keyPattern.test(key)) throw new Error('Invalid image storage key');
    return path.join(directory, key);
  };
  return {
    async put(key, bytes) {
      await mkdir(directory, { recursive: true, mode: 0o700 });
      await writeFile(location(key), bytes, { flag: 'wx', mode: 0o600 });
    },
    async get(key) { return readFile(location(key)); },
  };
}

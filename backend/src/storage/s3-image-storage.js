import { assertValidStorageKey } from './storage-key.js';

/**
 * Creates an S3-compatible storage adapter (AWS S3 / Cloudflare R2 / MinIO).
 * Dynamically imports `@aws-sdk/client-s3` when used, keeping it optional until configured.
 */
export function createS3CompatibleImageStorage({
  endpoint,
  region = 'auto',
  bucket,
  accessKeyId,
  secretAccessKey,
  providerType = 's3',
  loadSdk,
}) {
  if (!bucket || !accessKeyId || !secretAccessKey) {
    throw new Error('S3-compatible storage configuration is incomplete');
  }

  let clientPromise = null;
  let sdkCommands = null;

  async function ensureClient() {
    if (clientPromise) return clientPromise;
    clientPromise = (async () => {
      let sdk;
      try {
        sdk = loadSdk ? await loadSdk() : await import('@aws-sdk/client-s3');
      } catch (error) {
        throw new Error('Install @aws-sdk/client-s3 to use S3/R2/MinIO storage', { cause: error });
      }
      const { S3Client, PutObjectCommand, GetObjectCommand, DeleteObjectCommand, ListObjectsV2Command, HeadBucketCommand } = sdk;
      sdkCommands = { PutObjectCommand, GetObjectCommand, DeleteObjectCommand, ListObjectsV2Command, HeadBucketCommand };
      return new S3Client({
        region,
        ...(endpoint ? { endpoint, forcePathStyle: true } : {}),
        credentials: { accessKeyId, secretAccessKey },
      });
    })();
    return clientPromise;
  }

  return {
    providerType,
    async put(key, bytes, mimeType) {
      assertValidStorageKey(key);
      const client = await ensureClient();
      await client.send(new sdkCommands.PutObjectCommand({
        Bucket: bucket,
        Key: key,
        Body: bytes,
        ContentType: mimeType,
      }));
    },
    async get(key) {
      assertValidStorageKey(key);
      const client = await ensureClient();
      const response = await client.send(new sdkCommands.GetObjectCommand({
        Bucket: bucket,
        Key: key,
      }));
      const chunks = [];
      for await (const chunk of response.Body) {
        chunks.push(Buffer.isBuffer(chunk) ? chunk : Buffer.from(chunk));
      }
      return Buffer.concat(chunks);
    },
    async remove(key) {
      assertValidStorageKey(key);
      const client = await ensureClient();
      await client.send(new sdkCommands.DeleteObjectCommand({
        Bucket: bucket,
        Key: key,
      }));
    },
    async list(prefix = '') {
      const client = await ensureClient();
      const keys = [];
      let continuationToken;
      do {
        const res = await client.send(new sdkCommands.ListObjectsV2Command({
          Bucket: bucket,
          Prefix: prefix || undefined,
          ContinuationToken: continuationToken,
        }));
        for (const item of res.Contents ?? []) {
          if (item.Key) keys.push(item.Key);
        }
        continuationToken = res.IsTruncated ? res.NextContinuationToken : undefined;
      } while (continuationToken);
      return keys;
    },
    async healthCheck() {
      const client = await ensureClient();
      await client.send(new sdkCommands.HeadBucketCommand({ Bucket: bucket }));
      return { status: 'healthy', provider: providerType, bucket };
    },
  };
}

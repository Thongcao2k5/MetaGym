import { createSign } from 'node:crypto';

const OAUTH_TOKEN_URL = 'https://oauth2.googleapis.com/token';
const FCM_SCOPE = 'https://www.googleapis.com/auth/firebase.messaging';

function base64Url(input) {
  const buffer = typeof input === 'string' ? Buffer.from(input, 'utf8') : input;
  return buffer
    .toString('base64')
    .replaceAll('+', '-')
    .replaceAll('/', '_')
    .replaceAll('=', '');
}

function createServiceAccountAssertion({ clientEmail, privateKey, nowSeconds }) {
  const header = base64Url(JSON.stringify({ alg: 'RS256', typ: 'JWT' }));
  const payload = base64Url(
    JSON.stringify({
      iss: clientEmail,
      scope: FCM_SCOPE,
      aud: OAUTH_TOKEN_URL,
      iat: nowSeconds,
      exp: nowSeconds + 3600,
    }),
  );
  const unsigned = `${header}.${payload}`;
  const signer = createSign('RSA-SHA256');
  signer.update(unsigned);
  signer.end();
  const signature = base64Url(signer.sign(privateKey));
  return `${unsigned}.${signature}`;
}

function normalizeDataPayload(data) {
  if (!data || typeof data !== 'object') return undefined;
  const entries = {};
  for (const [key, value] of Object.entries(data)) {
    if (value == null) continue;
    entries[String(key)] = typeof value === 'string' ? value : JSON.stringify(value);
  }
  return Object.keys(entries).length ? entries : undefined;
}

function isPermanentTokenFailure(status, errorPayload) {
  if (status === 404) return true;
  const details = errorPayload?.error?.details;
  if (Array.isArray(details)) {
    for (const detail of details) {
      if (detail?.errorCode === 'UNREGISTERED' || detail?.errorCode === 'INVALID_ARGUMENT') {
        return true;
      }
    }
  }
  const message = String(errorPayload?.error?.message ?? '').toUpperCase();
  const errorStatus = String(errorPayload?.error?.status ?? '').toUpperCase();
  if (errorStatus === 'UNREGISTERED') return true;
  if (errorStatus === 'INVALID_ARGUMENT' && message.includes('REGISTRATION')) return true;
  return false;
}

export function createFcmFromEnv(env = process.env, send = fetch) {
  const projectId = env.FCM_PROJECT_ID?.trim();
  const clientEmail = env.FCM_CLIENT_EMAIL?.trim();
  const rawPrivateKey = env.FCM_PRIVATE_KEY?.trim();

  if (!projectId && !clientEmail && !rawPrivateKey) {
    return undefined;
  }
  if (!projectId || !clientEmail || !rawPrivateKey) {
    throw new Error('Invalid FCM configuration');
  }

  const privateKey = rawPrivateKey.replaceAll('\\n', '\n');
  let cachedToken = null;
  let cachedExpiresAtMs = 0;

  async function getAccessToken() {
    const nowMs = Date.now();
    if (cachedToken && nowMs < cachedExpiresAtMs - 5 * 60 * 1000) {
      return cachedToken;
    }

    const assertion = createServiceAccountAssertion({
      clientEmail,
      privateKey,
      nowSeconds: Math.floor(nowMs / 1000),
    });

    const body = new URLSearchParams({
      grant_type: 'urn:ietf:params:oauth:grant-type:jwt-bearer',
      assertion,
    });

    const response = await send(OAUTH_TOKEN_URL, {
      method: 'POST',
      headers: { 'content-type': 'application/x-www-form-urlencoded' },
      body: body.toString(),
      signal: AbortSignal.timeout(5000),
    });

    const payload = await response.json().catch(() => ({}));
    if (!response.ok || !payload?.access_token) {
      throw new Error(`FCM OAuth token request failed (${response.status})`);
    }

    const expiresInSec = Number(payload.expires_in ?? 3600);
    cachedToken = payload.access_token;
    cachedExpiresAtMs = nowMs + expiresInSec * 1000;
    return cachedToken;
  }

  async function sendToTokens(tokens, { title, body, data, channelId = 'metagym_general', highPriority = false }) {
    const uniqueTokens = [...new Set((tokens ?? []).filter((t) => typeof t === 'string' && t.trim().length > 0))];
    if (!uniqueTokens.length) {
      return { sent: 0, failed: 0, invalidTokens: [] };
    }

    let accessToken;
    try {
      accessToken = await getAccessToken();
    } catch {
      console.warn('FCM access token unavailable');
      return { sent: 0, failed: uniqueTokens.length, invalidTokens: [] };
    }

    const endpoint = `https://fcm.googleapis.com/v1/projects/${encodeURIComponent(projectId)}/messages:send`;
    const stringData = normalizeDataPayload(data);
    let sent = 0;
    let failed = 0;
    const invalidTokens = [];

    for (const token of uniqueTokens) {
      const message = {
        token,
        notification: {
          title: title ?? 'Meta Gym',
          body: body ?? '',
        },
        ...(stringData ? { data: stringData } : {}),
        android: {
          priority: highPriority ? 'HIGH' : 'NORMAL',
          notification: {
            channel_id: channelId,
            sound: 'default',
          },
        },
        apns: {
          headers: {
            'apns-priority': highPriority ? '10' : '5',
          },
          payload: {
            aps: {
              sound: 'default',
            },
          },
        },
      };

      try {
        const res = await send(endpoint, {
          method: 'POST',
          headers: {
            authorization: `Bearer ${accessToken}`,
            'content-type': 'application/json',
          },
          body: JSON.stringify({ message }),
          signal: AbortSignal.timeout(5000),
        });
        if (res.ok) {
          await res.body?.cancel?.();
          sent += 1;
        } else {
          failed += 1;
          const errPayload = await res.json().catch(() => ({}));
          if (isPermanentTokenFailure(res.status, errPayload)) {
            invalidTokens.push(token);
          }
        }
      } catch {
        failed += 1;
      }
    }

    return { sent, failed, invalidTokens };
  }

  return {
    sendToTokens,
  };
}

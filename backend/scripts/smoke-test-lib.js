const BUSINESS_PATHS = {
  ADMIN: '/admin/dashboard',
  COACH: '/coach/members',
  MEMBER: '/memberships/me',
};

function required(env, name) {
  const value = env[name]?.trim();
  if (!value) throw new Error(`${name} is required`);
  return value;
}

export function loadSmokeConfig(env = process.env) {
  return {
    baseUrl: required(env, 'SMOKE_API_BASE_URL').replace(/\/$/, ''),
    accounts: {
      ADMIN: {
        email: required(env, 'SMOKE_ADMIN_EMAIL'),
        password: required(env, 'SMOKE_ADMIN_PASSWORD'),
      },
      COACH: {
        email: required(env, 'SMOKE_COACH_EMAIL'),
        password: required(env, 'SMOKE_COACH_PASSWORD'),
      },
      MEMBER: {
        email: required(env, 'SMOKE_MEMBER_EMAIL'),
        password: required(env, 'SMOKE_MEMBER_PASSWORD'),
      },
    },
  };
}

async function requestJson({ baseUrl, path, step, fetchImpl, options = {}, timeoutMs }) {
  let response;
  try {
    response = await fetchImpl(`${baseUrl}${path}`, {
      ...options,
      signal: options.signal ?? AbortSignal.timeout(timeoutMs),
    });
  } catch (error) {
    throw new Error(`${step} request failed: ${error.message}`, { cause: error });
  }

  let body;
  try {
    body = await response.json();
  } catch (error) {
    throw new Error(`${step} returned invalid JSON`, { cause: error });
  }

  if (!response.ok) {
    const code = body?.error?.code ? ` (${body.error.code})` : '';
    throw new Error(`${step} failed with HTTP ${response.status}${code}`);
  }

  return body;
}

export async function runSmokeTest({
  baseUrl,
  accounts,
  fetchImpl = fetch,
  timeoutMs = 10_000,
}) {
  const normalizedBaseUrl = baseUrl.replace(/\/+$/, '');
  const steps = [];
  const health = await requestJson({
    baseUrl: normalizedBaseUrl,
    path: '/health',
    step: 'health',
    fetchImpl,
    timeoutMs,
  });
  if (health?.data?.api !== 'AVAILABLE' || health?.data?.database !== 'AVAILABLE') {
    throw new Error('health returned an unavailable API or database');
  }
  steps.push('health');

  for (const role of ['ADMIN', 'COACH', 'MEMBER']) {
    const login = await requestJson({
      baseUrl: normalizedBaseUrl,
      path: '/auth/sessions',
      step: `login:${role}`,
      fetchImpl,
      timeoutMs,
      options: {
        method: 'POST',
        headers: { 'content-type': 'application/json' },
        body: JSON.stringify(accounts[role]),
      },
    });
    if (login?.data?.user?.role !== role || !login?.data?.accessToken) {
      throw new Error(`login:${role} returned an invalid role or access token`);
    }
    steps.push(`login:${role}`);

    const business = await requestJson({
      baseUrl: normalizedBaseUrl,
      path: BUSINESS_PATHS[role],
      step: `business:${role}`,
      fetchImpl,
      timeoutMs,
      options: {
        headers: { authorization: `Bearer ${login.data.accessToken}` },
      },
    });
    if (!Object.hasOwn(business ?? {}, 'data')) {
      throw new Error(`business:${role} returned an invalid response body`);
    }
    steps.push(`business:${role}`);
  }

  return steps;
}

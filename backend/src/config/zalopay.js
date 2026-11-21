import { createHmac, timingSafeEqual } from 'node:crypto';

const apiOrigin = 'https://sb-openapi.zalopay.vn';
const checkoutOrigins = new Set(['https://qcgateway.zalopay.vn', 'https://sbgateway.zalopay.vn']);
const expiresAfterSeconds = 900;
const vietnamDate = new Intl.DateTimeFormat('en-GB', {
  timeZone: 'Asia/Ho_Chi_Minh', year: '2-digit', month: '2-digit', day: '2-digit',
});

export function zalopayReference(id, date = new Date()) {
  const parts = Object.fromEntries(vietnamDate.formatToParts(date).map(({ type, value }) => [type, value]));
  return `${parts.year}${parts.month}${parts.day}_${id.replaceAll('-', '')}`;
}

export function createZalopayFromEnv(env = process.env, fetcher = fetch) {
  const id = env.ZALOPAY_APP_ID?.trim();
  const key = env.ZALOPAY_KEY1?.trim();
  const callbackKey = env.ZALOPAY_KEY2?.trim();
  const publicOrigin = env.ZALOPAY_PUBLIC_ORIGIN?.trim();
  if (!id && !key) return undefined;
  const appId = Number(id);
  if (!/^[1-9]\d{0,9}$/.test(id ?? '') || appId > 2147483647 || !key) {
    throw new Error('Incomplete ZaloPay Sandbox configuration');
  }
  let callbackUrl;
  if (publicOrigin) {
    const url = new URL(publicOrigin);
    if (!callbackKey || url.protocol !== 'https:' || url.pathname !== '/' ||
        url.username || url.password || url.search || url.hash) {
      throw new Error('ZaloPay callback requires Key2 and a public HTTPS origin');
    }
    callbackUrl = new URL('/api/v1/payments/zalopay/callback', url).href;
  }
  const sign = (fields) => createHmac('sha256', key).update(fields.join('|')).digest('hex');

  function verifyCallback(body) {
    if (!callbackKey || body?.type !== 1 || typeof body.data !== 'string' ||
        typeof body.mac !== 'string' || !/^[a-f0-9]{64}$/i.test(body.mac)) return null;
    const expected = createHmac('sha256', callbackKey).update(body.data).digest();
    if (!timingSafeEqual(expected, Buffer.from(body.mac, 'hex'))) return null;
    let data;
    try {
      data = JSON.parse(body.data);
    } catch {
      return null;
    }
    if (data?.app_id !== appId || !/^\d{6}_[a-f0-9]{32}$/.test(data.app_trans_id ?? '') ||
        !Number.isSafeInteger(data.amount) || data.amount <= 0 ||
        !Number.isSafeInteger(data.zp_trans_id) || data.zp_trans_id <= 0) return null;
    return { reference: data.app_trans_id, amount: String(data.amount), transactionNo: String(data.zp_trans_id) };
  }

  async function send(path, fields) {
    const response = await fetcher(`${apiOrigin}/v2/${path}`, {
      method: 'POST', redirect: 'error', signal: AbortSignal.timeout(10_000),
      headers: { 'content-type': 'application/json', accept: 'application/json' },
      body: JSON.stringify(fields),
    });
    return response.ok ? response.json() : null;
  }

  async function createCheckout(payment) {
    const order = {
      app_id: appId, app_trans_id: payment.transaction_code, app_user: payment.member_id,
      amount: Number(payment.amount), app_time: Number(new Date(payment.created_at)),
      expire_duration_seconds: expiresAfterSeconds, description: 'Thanh toan goi tap MetaGym',
      embed_data: '{}', item: '[]', bank_code: 'zalopayapp',
      ...(callbackUrl ? { callback_url: callbackUrl } : {}),
    };
    const result = await send('create', { ...order,
      mac: sign([order.app_id, order.app_trans_id, order.app_user, order.amount,
        order.app_time, order.embed_data, order.item]) });
    if (result?.return_code === 2 && [-401, -402].includes(result.sub_return_code)) {
      return { errorCode: result.sub_return_code };
    }
    if (result?.return_code !== 1 || typeof result.order_url !== 'string') return null;
    const url = new URL(result.order_url);
    return checkoutOrigins.has(url.origin) && !url.username && !url.password ? { url: url.href } : null;
  }

  async function queryPayment(payment) {
    const reference = payment.transaction_code;
    const result = await send('query', { app_id: appId, app_trans_id: reference,
      mac: sign([appId, reference, key]) });
    if (result?.return_code === 1 && result.is_processing === false) {
      if (!Number.isSafeInteger(result.amount) || result.amount <= 0 ||
          !Number.isSafeInteger(result.zp_trans_id) || result.zp_trans_id <= 0) return null;
      return { reference, amount: String(result.amount), transactionNo: String(result.zp_trans_id),
        responseCode: '1', result: 'SUCCESS' };
    }
    if (result?.return_code !== 2) return null;
    const code = result.sub_return_code;
    const age = Date.now() - Number(new Date(payment.created_at));
    // Sandbox can report TIME_INVALID and is_processing=true together after the payment window.
    if (code === -54 && (result.is_processing !== true || age >= expiresAfterSeconds * 1000)) {
      return { reference, amount: payment.amount, responseCode: String(code), result: 'CANCELLED' };
    }
    if (result.is_processing === true) return null;
    const expired = age >= (expiresAfterSeconds + 60) * 1000;
    if (code === -101 && expired) {
      return { reference, amount: payment.amount, responseCode: String(code), result: 'CANCELLED' };
    }
    // A failed attempt can be retried against the same order before its payment window ends.
    if (expired && [-63, -217, -332, -333].includes(code)) {
      return { reference, amount: payment.amount, responseCode: String(code), result: 'FAILED' };
    }
    return null;
  }

  return { createCheckout, queryPayment, verifyCallback };
}

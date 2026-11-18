import { createHmac, randomUUID, timingSafeEqual } from 'node:crypto';

const sandbox = 'https://test-payment.momo.vn';
const createFields = ['accessKey', 'amount', 'extraData', 'ipnUrl', 'orderId', 'orderInfo',
  'partnerCode', 'redirectUrl', 'requestId', 'requestType'];
const notifyFields = ['accessKey', 'amount', 'extraData', 'message', 'orderId', 'orderInfo',
  'orderType', 'partnerCode', 'payType', 'requestId', 'responseTime', 'resultCode', 'transId'];
const queryFields = ['accessKey', 'orderId', 'partnerCode', 'requestId'];
const orderPattern = /^MM[0-9a-f]{32}$/;
const cancelled = new Set([1003, 1006, 1017]);
const failed = new Set([1001, 1002, 1004, 1005, 1007, 1026, 4001, 4002, 4100]);
const declinedCreation = new Set([11, 12, 13, 20, 21, 22, 98]);

function classify(data) {
  const amount = String(data.amount);
  const transactionNo = String(data.transId);
  const code = Number(data.resultCode);
  if (!/^[0-9]{1,8}$/.test(amount) || !/^\d{1,4}$/.test(String(data.resultCode))) return null;
  if (code === 0 && (!/^[1-9]\d{0,18}$/.test(transactionNo) ||
      (typeof data.transId === 'number' && !Number.isSafeInteger(data.transId)))) return null;
  const result = code === 0 ? 'SUCCESS' : cancelled.has(code) ? 'CANCELLED'
    : failed.has(code) ? 'FAILED' : 'PENDING';
  return { reference: data.orderId, transactionNo, amount, responseCode: String(code), result };
}

export function createMomoFromEnv(env = process.env, fetcher = fetch) {
  const partnerCode = env.MOMO_PARTNER_CODE?.trim();
  const accessKey = env.MOMO_ACCESS_KEY?.trim();
  const secret = env.MOMO_SECRET_KEY?.trim();
  if (!partnerCode && !accessKey && !secret) return undefined;
  if (!/^[A-Za-z0-9_-]{1,50}$/.test(partnerCode ?? '') || !accessKey || !secret) {
    throw new Error('Incomplete MoMo Sandbox credentials');
  }
  const origin = new URL(env.MOMO_PUBLIC_ORIGIN?.trim() || env.VNPAY_PUBLIC_ORIGIN?.trim());
  if (origin.protocol !== 'https:' || origin.pathname !== '/' ||
      origin.search || origin.hash || origin.username || origin.password) {
    throw new Error('MoMo Sandbox requires a public HTTPS origin');
  }
  const redirectUrl = new URL('/api/v1/payments/momo/return', origin).href;
  const ipnUrl = new URL('/api/v1/payments/momo/ipn', origin).href;
  const webAddress = env.MOMO_WEB_RETURN_URL?.trim() || env.VNPAY_WEB_RETURN_URL?.trim();
  const webReturnUrl = webAddress ? new URL(webAddress) : undefined;
  if (webReturnUrl && (webReturnUrl.username || webReturnUrl.password ||
      (webReturnUrl.hash && !webReturnUrl.hash.startsWith('#/')) ||
      (webReturnUrl.protocol !== 'https:' && !(webReturnUrl.protocol === 'http:' &&
        ['localhost', '127.0.0.1', '[::1]'].includes(webReturnUrl.hostname))))) {
    throw new Error('Invalid Flutter Web return URL');
  }
  const sign = (fields, data) => createHmac('sha256', secret)
    .update(fields.map((field) => `${field}=${field === 'accessKey' ? accessKey : data[field]}`).join('&'))
    .digest('hex');
  async function send(command, data, fields) {
    const response = await fetcher(`${sandbox}/v2/gateway/api/${command}`, {
      method: 'POST', redirect: 'error', headers: { 'content-type': 'application/json; charset=UTF-8' },
      signal: AbortSignal.timeout(32_000), body: JSON.stringify({ ...data, signature: sign(fields, data) }),
    });
    if (response.status >= 500) return null;
    const result = await response.json();
    if (result?.partnerCode !== partnerCode || result.orderId !== data.orderId ||
        result.requestId !== data.requestId) return null;
    return result;
  }

  function verifyCallback(data) {
    if (!data || data.partnerCode !== partnerCode || !orderPattern.test(data.orderId ?? '') ||
        data.requestId !== data.orderId || data.extraData !== '' ||
        notifyFields.slice(1).some((field) => !['string', 'number'].includes(typeof data[field])) ||
        typeof data.signature !== 'string' || !/^[0-9a-fA-F]{64}$/.test(data.signature) ||
        !timingSafeEqual(Buffer.from(sign(notifyFields, data), 'hex'), Buffer.from(data.signature, 'hex'))) {
      return null;
    }
    return classify(data);
  }

  async function createCheckout(payment) {
    const orderId = payment.transaction_code;
    const data = await send('create', { partnerCode, orderId, requestId: orderId,
      amount: Number(payment.amount), orderInfo: `MetaGym membership ${orderId}`,
      extraData: '', ipnUrl, redirectUrl, requestType: 'captureWallet',
      autoCapture: true, lang: 'vi' }, createFields);
    if (!data) return null;
    if (data.resultCode !== 0) {
      return declinedCreation.has(data.resultCode) ? { errorCode: data.resultCode } : null;
    }
    if (String(data.amount) !== String(payment.amount) || typeof data.payUrl !== 'string') return null;
    const url = new URL(data.payUrl);
    if (url.origin !== sandbox || url.username || url.password ||
        !/^\/(?:v2\/gateway\/pay|gateway\/pay|gw_payment\/[^/]+)\/?$/.test(url.pathname)) return null;
    return { url: url.href };
  }

  async function queryPayment(payment) {
    const orderId = payment.transaction_code;
    const data = await send('query', { partnerCode, orderId, requestId: randomUUID(), lang: 'vi' }, queryFields);
    return data ? classify(data) : null;
  }

  return { createCheckout, queryPayment, verifyCallback, webReturnUrl };
}

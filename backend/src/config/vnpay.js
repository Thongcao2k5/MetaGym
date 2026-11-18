import { createHmac, randomUUID, timingSafeEqual } from 'node:crypto';
import { isIP } from 'node:net';

export const sandboxPaymentUrl = 'https://sandbox.vnpayment.vn/paymentv2/vpcpay.html';
const sandboxQueryUrl = 'https://sandbox.vnpayment.vn/merchant_webapi/api/transaction';
const orderLifetimeMs = 15 * 60_000;
const vietnamTime = new Intl.DateTimeFormat('en-GB', {
  timeZone: 'Asia/Ho_Chi_Minh', year: 'numeric', month: '2-digit', day: '2-digit',
  hour: '2-digit', minute: '2-digit', second: '2-digit', hourCycle: 'h23',
});
const queryRequestFields = [
  'vnp_RequestId', 'vnp_Version', 'vnp_Command', 'vnp_TmnCode', 'vnp_TxnRef',
  'vnp_TransactionDate', 'vnp_CreateDate', 'vnp_IpAddr', 'vnp_OrderInfo',
];
const queryResponseFields = [
  'vnp_ResponseId', 'vnp_Command', 'vnp_ResponseCode', 'vnp_Message', 'vnp_TmnCode',
  'vnp_TxnRef', 'vnp_Amount', 'vnp_BankCode', 'vnp_PayDate', 'vnp_TransactionNo',
  'vnp_TransactionType', 'vnp_TransactionStatus', 'vnp_OrderInfo', 'vnp_PromotionCode',
  'vnp_PromotionAmount',
];
const queryForm = (value) => encodeURIComponent(value).replace(/%20/g, '+');
const orderInfo = (reference) => `Thanh toan goi tap MetaGym ${reference}`;
const amountPattern = /^\d{1,12}$/;
const codePattern = /^\d{2}$/;
const referencePattern = /^MG[0-9a-f]{32}$/;
const transactionNumberPattern = /^[1-9]\d{0,14}$/;
const pendingStatuses = new Set(['01', '04', '05', '06', '07']);

export function vnpayAmount(amount) {
  return (BigInt(amount) * 100n).toString();
}

function vietnamTimestamp(date) {
  const parts = Object.fromEntries(vietnamTime.formatToParts(date)
    .map(({ type, value }) => [type, value]));
  return parts.year + parts.month + parts.day + parts.hour + parts.minute + parts.second;
}

function clientIp(ip) {
  const address = ip?.replace(/^::ffff:/, '');
  return address !== '::1' && isIP(address ?? '') ? address : '127.0.0.1';
}

function canonicalForm(params) {
  return Object.keys(params).sort().map((key) => `${queryForm(key)}=${queryForm(params[key])}`).join('&');
}

function httpsUrl(value, originOnly = false) {
  const url = new URL(value);
  if (url.protocol !== 'https:' || url.username || url.password ||
      (originOnly && (url.pathname !== '/' || url.search || url.hash))) {
    throw new Error('VNPay requires an HTTPS return address');
  }
  return url;
}

export function createVnpayFromEnv(env = process.env, fetcher = fetch) {
  const tmnCode = env.VNPAY_TMN_CODE?.trim();
  const secret = env.VNPAY_HASH_SECRET?.trim();
  const publicOrigin = env.VNPAY_PUBLIC_ORIGIN?.trim();
  if (!tmnCode && !secret && !publicOrigin) return undefined;
  if (!/^[A-Za-z0-9]{8}$/.test(tmnCode ?? '') || !secret || !publicOrigin) {
    throw new Error('VNPay Sandbox requires VNPAY_TMN_CODE, VNPAY_HASH_SECRET and VNPAY_PUBLIC_ORIGIN');
  }
  const origin = httpsUrl(publicOrigin, true);
  const returnUrl = new URL('/api/v1/payments/vnpay/return', origin).href;
  const webReturn = env.VNPAY_WEB_RETURN_URL?.trim();
  const webReturnUrl = webReturn ? new URL(webReturn) : undefined;
  if (webReturnUrl && (webReturnUrl.username || webReturnUrl.password ||
      (webReturnUrl.protocol !== 'https:' &&
       !(webReturnUrl.protocol === 'http:' &&
         ['localhost', '127.0.0.1', '[::1]'].includes(webReturnUrl.hostname))))) {
    throw new Error('VNPay requires HTTPS for non-local Flutter Web addresses');
  }
  if (webReturnUrl?.hash && !webReturnUrl.hash.startsWith('#/')) {
    throw new Error('VNPay web return URL must use a Flutter route');
  }
  const sign = (payload) => createHmac('sha512', secret).update(payload, 'utf8').digest('hex');
  const match = (payload, signature) => typeof signature === 'string' &&
    /^[0-9a-fA-F]{128}$/.test(signature) &&
    timingSafeEqual(Buffer.from(sign(payload), 'hex'), Buffer.from(signature, 'hex'));
  const expired = (payment, now = new Date()) =>
    Number(now) >= Number(new Date(payment.created_at)) + orderLifetimeMs;

  function checkoutUrl(payment, ip, now = new Date()) {
    if (expired(payment, now)) return undefined;
    const created = new Date(payment.created_at);
    const params = {
      vnp_Version: '2.1.0', vnp_Command: 'pay', vnp_TmnCode: tmnCode,
      vnp_Amount: vnpayAmount(payment.amount), vnp_CurrCode: 'VND',
      vnp_TxnRef: payment.transaction_code, vnp_OrderInfo: orderInfo(payment.transaction_code),
      vnp_OrderType: 'other', vnp_Locale: 'vn', vnp_ReturnUrl: returnUrl,
      vnp_IpAddr: clientIp(ip), vnp_CreateDate: vietnamTimestamp(created),
      vnp_ExpireDate: vietnamTimestamp(new Date(Number(created) + orderLifetimeMs)),
    };
    const payload = canonicalForm(params);
    return `${sandboxPaymentUrl}?${payload}&vnp_SecureHash=${sign(payload)}`;
  }

  function verifyCallback(raw) {
    const params = {};
    for (const [name, value] of Object.entries(raw)) {
      if (!name.startsWith('vnp_') || name === 'vnp_SecureHash' || name === 'vnp_SecureHashType') continue;
      if (typeof value !== 'string') return null;
      params[name] = value;
    }
    if (!match(canonicalForm(params), raw.vnp_SecureHash) || params.vnp_TmnCode !== tmnCode ||
        !referencePattern.test(params.vnp_TxnRef ?? '') ||
        !amountPattern.test(params.vnp_Amount ?? '') ||
        !codePattern.test(params.vnp_ResponseCode ?? '') ||
        !codePattern.test(params.vnp_TransactionStatus ?? '')) return null;
    const responseCode = params.vnp_ResponseCode;
    const providerStatus = params.vnp_TransactionStatus;
    const result = responseCode === '00' && providerStatus === '00' ? 'SUCCESS'
      : responseCode === '24' && ['01', '02'].includes(providerStatus) ? 'CANCELLED'
      : responseCode === '11' && ['01', '02'].includes(providerStatus) ? 'FAILED'
      : responseCode === '07' || pendingStatuses.has(providerStatus) || providerStatus === '00'
        ? 'PENDING' : 'FAILED';
    if (result === 'SUCCESS' && !transactionNumberPattern.test(params.vnp_TransactionNo ?? '')) return null;
    return { reference: params.vnp_TxnRef, amount: params.vnp_Amount, responseCode, providerStatus,
      transactionNo: params.vnp_TransactionNo, result };
  }

  async function queryPayment(payment, ip, now = new Date()) {
    const request = {
      vnp_RequestId: randomUUID().replaceAll('-', ''), vnp_Version: '2.1.0',
      vnp_Command: 'querydr', vnp_TmnCode: tmnCode, vnp_TxnRef: payment.transaction_code,
      vnp_TransactionDate: vietnamTimestamp(new Date(payment.created_at)),
      vnp_CreateDate: vietnamTimestamp(now), vnp_IpAddr: clientIp(ip),
      vnp_OrderInfo: orderInfo(payment.transaction_code),
    };
    request.vnp_SecureHash = sign(queryRequestFields.map((field) => request[field]).join('|'));
    const response = await fetcher(sandboxQueryUrl, {
      method: 'POST', redirect: 'error', headers: { 'content-type': 'application/json' },
      body: JSON.stringify(request), signal: AbortSignal.timeout(5000),
    });
    if (!response.ok) return null;
    const data = await response.json();
    if (!data || !match(queryResponseFields.map((field) => data[field] ?? '').join('|'), data.vnp_SecureHash) ||
        data.vnp_Command !== 'querydr' || data.vnp_TmnCode !== tmnCode ||
        data.vnp_TxnRef !== payment.transaction_code) return null;
    const providerStatus = data.vnp_TransactionStatus;
    const responseCode = data.vnp_ResponseCode;
    // A signed "not found" can release an abandoned order after the checkout and IPN retry window.
    const expiredWithoutTransaction = responseCode === '91' &&
      Number(now) >= Number(new Date(payment.created_at)) + orderLifetimeMs + 10 * 60_000;
    if (expiredWithoutTransaction) return { reference: payment.transaction_code,
      amount: vnpayAmount(payment.amount), responseCode, providerStatus: null, result: 'CANCELLED' };
    if (responseCode !== '00' || data.vnp_TransactionType !== '01' ||
        !amountPattern.test(String(data.vnp_Amount)) || !codePattern.test(providerStatus ?? '')) return null;
    const result = providerStatus === '00' ? 'SUCCESS'
      : providerStatus === '02' ? 'FAILED' : 'PENDING';
    if (result === 'SUCCESS' && !transactionNumberPattern.test(String(data.vnp_TransactionNo))) return null;
    return { reference: data.vnp_TxnRef, amount: String(data.vnp_Amount), responseCode, providerStatus,
      transactionNo: String(data.vnp_TransactionNo), result };
  }

  return { checkoutUrl, verifyCallback, queryPayment, expired, webReturnUrl };
}

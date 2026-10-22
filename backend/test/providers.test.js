import assert from 'node:assert/strict';
import test from 'node:test';

import {
  createAiResponderFromEnv,
  createCallTokenProviderFromEnv,
  createPasswordResetSenderFromEnv,
} from '../src/config/providers.js';

function jsonResponse(body, status = 200) {
  return new Response(JSON.stringify(body), {
    status, headers: { 'content-type': 'application/json' },
  });
}

test('provider factories stay disabled until their required environment is complete', () => {
  assert.equal(createPasswordResetSenderFromEnv({}), undefined);
  assert.equal(createAiResponderFromEnv({ OPENAI_API_KEY: 'key-only' }), undefined);
  assert.equal(createCallTokenProviderFromEnv({}), undefined);
});

test('password reset sender posts the code to the configured delivery service', async () => {
  let request;
  const sender = createPasswordResetSenderFromEnv({
    PASSWORD_RESET_DELIVERY_URL: 'https://mailer.example/reset',
    PASSWORD_RESET_DELIVERY_TOKEN: 'delivery-token',
  }, async (url, options) => {
    request = { url, options };
    return jsonResponse({ accepted: true }, 202);
  });
  await sender({ email: 'member@example.com', code: '123456', requestId: 'request-id' });
  assert.equal(request.url, 'https://mailer.example/reset');
  assert.equal(request.options.headers.authorization, 'Bearer delivery-token');
  assert.deepEqual(JSON.parse(request.options.body), {
    email: 'member@example.com', code: '123456', requestId: 'request-id',
  });
});

test('AI responder uses the Responses API and maps its text and usage', async () => {
  let request;
  const responder = createAiResponderFromEnv({
    OPENAI_API_KEY: 'openai-key', OPENAI_MODEL: 'configured-model',
  }, async (url, options) => {
    request = { url, options };
    return jsonResponse({
      id: 'resp_123',
      output: [{ type: 'message', content: [{ type: 'output_text', text: 'Train safely.' }] }],
      usage: { input_tokens: 12, output_tokens: 4 },
    });
  });
  const result = await responder({ content: 'How should I train?' });
  assert.equal(request.url, 'https://api.openai.com/v1/responses');
  assert.equal(request.options.headers.authorization, 'Bearer openai-key');
  assert.equal(JSON.parse(request.options.body).model, 'configured-model');
  assert.deepEqual(result, {
    content: 'Train safely.', provider: 'OPENAI', modelName: 'configured-model',
    providerRequestId: 'resp_123', inputTokens: 12, outputTokens: 4,
  });
});

test('call token provider delegates issuance to the configured RTC service', async () => {
  let request;
  const provider = createCallTokenProviderFromEnv({
    CALL_TOKEN_SERVICE_URL: 'https://rtc.example/tokens',
    CALL_TOKEN_SERVICE_TOKEN: 'rtc-token',
  }, async (url, options) => {
    request = { url, options };
    return jsonResponse({ accessToken: 'access', providerCallId: 'provider-call',
      channelId: 'channel', expiresAt: '2026-10-22T10:05:00.000Z' });
  });
  const input = { callId: 'call-id', userId: 'user-id' };
  assert.deepEqual(await provider(input), {
    accessToken: 'access', providerCallId: 'provider-call', channelId: 'channel',
    expiresAt: '2026-10-22T10:05:00.000Z',
  });
  assert.equal(request.url, 'https://rtc.example/tokens');
  assert.deepEqual(JSON.parse(request.options.body), input);
});

test('configured providers reject non-success responses', async () => {
  const sender = createPasswordResetSenderFromEnv({
    PASSWORD_RESET_DELIVERY_URL: 'https://mailer.example/reset',
  }, async () => jsonResponse({ error: 'down' }, 503));
  await assert.rejects(() => sender({ email: 'member@example.com', code: '123456' }),
    /PASSWORD_RESET_DELIVERY_FAILED/);
});

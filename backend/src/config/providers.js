const requestTimeoutMs = 15_000;

async function postJson(fetchImpl, url, body, bearerToken) {
  const response = await fetchImpl(url, {
    method: 'POST',
    headers: {
      'content-type': 'application/json',
      ...(bearerToken ? { authorization: `Bearer ${bearerToken}` } : {}),
    },
    body: JSON.stringify(body),
    signal: AbortSignal.timeout(requestTimeoutMs),
  });
  if (!response.ok) throw new Error(`UPSTREAM_HTTP_${response.status}`);
  return response.json();
}

export function createPasswordResetSenderFromEnv(env = process.env, fetchImpl = fetch) {
  if (!env.PASSWORD_RESET_DELIVERY_URL) return undefined;
  return async (delivery) => {
    try {
      await postJson(fetchImpl, env.PASSWORD_RESET_DELIVERY_URL, delivery,
        env.PASSWORD_RESET_DELIVERY_TOKEN);
    } catch (error) {
      throw new Error('PASSWORD_RESET_DELIVERY_FAILED', { cause: error });
    }
  };
}

function responseText(payload) {
  return payload.output?.flatMap((item) => item.type === 'message' ? item.content ?? [] : [])
    .filter((item) => item.type === 'output_text')
    .map((item) => item.text)
    .join('\n')
    .trim();
}

export function createAiResponderFromEnv(env = process.env, fetchImpl = fetch) {
  const apiKey = env.OPENAI_API_KEY ?? env.AI_API_KEY;
  if (!apiKey || !env.OPENAI_MODEL) return undefined;
  return async ({ content }) => {
    const payload = await postJson(fetchImpl, 'https://api.openai.com/v1/responses', {
      model: env.OPENAI_MODEL,
      instructions: 'Bạn là trợ lý tập luyện Meta Gym. Trả lời ngắn gọn bằng tiếng Việt, ưu tiên an toàn và không thay thế tư vấn y tế.',
      input: content,
    }, apiKey);
    return {
      content: responseText(payload), provider: 'OPENAI', modelName: env.OPENAI_MODEL,
      providerRequestId: payload.id,
      inputTokens: payload.usage?.input_tokens,
      outputTokens: payload.usage?.output_tokens,
    };
  };
}

export function createCallTokenProviderFromEnv(env = process.env, fetchImpl = fetch) {
  if (!env.CALL_TOKEN_SERVICE_URL) return undefined;
  return (request) => postJson(fetchImpl, env.CALL_TOKEN_SERVICE_URL, request,
    env.CALL_TOKEN_SERVICE_TOKEN);
}

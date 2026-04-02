import { generateObject, gateway, streamText } from 'ai';
import type { ZodType } from 'zod';

import { systemPrompt } from '../prompts/systemPrompt.js';
import { env } from './env.js';

const acuteRiskPattern =
  /\b(suicid(?:e|io|arme|arme)|matarme|quitarme la vida|autolesi(?:o|ó)n|self[- ]?harm|kill myself|end my life|lastimar(?:me)?|hacerme daño|violencia|matar a alguien|quiero desaparecer|no quiero vivir|overdose|sobredosis|me quiero cortar|quiero cortarme|cortarme ahora|cortarme ahora mismo|pensando en tomarmelas ahora|pensando en tomármelas ahora|tomarmelas ahora|tomármelas ahora)\b/i;

const ambiguousRiskStrongPattern =
  /\b(todo seria mas facil si no estuviera|todo sería más fácil si no estuviera|quisiera desaparecer|no le veo sentido|todos estarian mejor sin mi|todos estarían mejor sin mí|los demas estarian mejor sin mi|los demás estarían mejor sin mí|quisiera dormir y no despertar|no aguanto mas|no aguanto más|ya no quiero seguir|no quiero estar aqui|no quiero estar aquí|no quiero hacer nada impulsivo)\b/i;

const ambiguousRiskWeakPattern =
  /\b(no se si pueda seguir asi|no sé si pueda seguir así|me gustaria dormirme y no pensar en nada|me gustaría dormirme y no pensar en nada)\b/i;

const highActivationSignalPattern =
  /\b(temblando|muy activado|muy alterado|me cuesta respirar profundo|discusion|discusión)\b/i;

const nonEmergencyNegationPattern =
  /\b(no es una emergencia|no estoy en peligro)\b/i;

const explicitEmergencyAffirmativePattern =
  /\b(esto es una emergencia|es una emergencia|estoy en una emergencia|no me siento seguro conmigo mismo|no me siento seguro conmigo misma|no me siento seguro ahora|no me siento segura ahora)\b/i;

type GatewayByokProviderOptions = {
  gateway?: {
    byok?: Record<string, GatewayByokCredential[]>;
    providerTimeouts?: {
      byok?: Record<string, number>;
    };
  };
};

type GatewayByokScalar = string | number | boolean | null;
type GatewayByokCredential = {
  [key: string]:
    | GatewayByokScalar
    | GatewayByokScalar[]
    | GatewayByokCredential
    | GatewayByokCredential[];
};

type StreamProbeResult = {
  firstChunk: ReadableStreamReadResult<string>;
  reader: ReadableStreamDefaultReader<string>;
};

type StreamableTextResult = {
  textStream: ReadableStream<string>;
};

type AiErrorCategory =
  | 'auth'
  | 'rate_limit'
  | 'timeout'
  | 'model_unavailable'
  | 'invalid_request'
  | 'upstream_5xx'
  | 'parse_error'
  | 'network'
  | 'empty_response'
  | 'unknown';

type AiErrorDiagnostics = {
  provider: string;
  model: string;
  category: AiErrorCategory;
  upstreamStatus: number | null;
  message: string;
  isTimeout: boolean;
  isRateLimit: boolean;
  isAuth: boolean;
  isModelUnavailable: boolean;
};

class AiProviderError extends Error {
  readonly provider: string;
  readonly model: string;
  readonly category: AiErrorCategory;
  readonly upstreamStatus: number | null;

  constructor({
    provider,
    model,
    category,
    upstreamStatus = null,
    message,
    cause,
  }: {
    provider: string;
    model: string;
    category: AiErrorCategory;
    upstreamStatus?: number | null;
    message: string;
    cause?: unknown;
  }) {
    super(message, { cause });
    this.name = 'AiProviderError';
    this.provider = provider;
    this.model = model;
    this.category = category;
    this.upstreamStatus = upstreamStatus;
  }
}

const providerTimeoutByokMs = 15_000;
const openRouterBaseUrl = 'https://openrouter.ai/api/v1/chat/completions';
const openRouterInitialResponseTimeoutMs = 45_000;
const openRouterChunkInactivityTimeoutMs = 20_000;

export function containsAcuteRiskLanguage(message: string): boolean {
  return acuteRiskPattern.test(message);
}

export function containsAmbiguousRiskLanguage(message: string): boolean {
  return (
    ambiguousRiskStrongPattern.test(message) ||
    ambiguousRiskWeakPattern.test(message)
  );
}

export function containsNonEmergencyHighActivationLanguage(
  message: string,
): boolean {
  return (
    highActivationSignalPattern.test(message) &&
    nonEmergencyNegationPattern.test(message) &&
    !containsAcuteRiskLanguage(message) &&
    !containsAmbiguousRiskLanguage(message)
  );
}

export function containsExplicitEmergencyLanguage(message: string): boolean {
  return (
    !nonEmergencyNegationPattern.test(message) &&
    explicitEmergencyAffirmativePattern.test(message)
  );
}

export function getAcuteRiskReply(): string {
  return [
    'Siento que estés pasando por esto.',
    'Si hay riesgo inmediato para ti o para otra persona, usa el modulo SOS ahora mismo y busca ayuda humana inmediata.',
    'Si puedes, contacta a un familiar, amigo de confianza o a los servicios de emergencia de tu zona en este momento.',
  ].join(' ');
}

export function getAmbiguousRiskReply(): string {
  return [
    'Lo que acabas de decir es importante y no conviene quedarte con eso a solas.',
    'Si hay posibilidad de hacerte daño, usa el modulo SOS ahora mismo.',
    'Busca apoyo humano inmediato con alguien de confianza o con un servicio de emergencia de tu zona.',
  ].join(' ');
}

export function getNonEmergencyHighActivationReply(): string {
  return 'Tu cuerpo quedó muy activado. Suelta el aire lento una vez y afloja la mandíbula.';
}

export function createTherapeuticTextStream(
  message: string,
  abortSignal: AbortSignal,
  userName?: string,
) {
  if (env.AI_MODEL.startsWith('openrouter/')) {
    return createOpenRouterTextStream(message, abortSignal, userName);
  }

  const prompt = userName
    ? `[Contexto: El usuario se llama ${userName}]\n\n${message}`
    : message;

  return streamText({
    model: gateway(env.AI_MODEL),
    system: systemPrompt,
    prompt,
    abortSignal,

    temperature: 0.4,
    maxRetries: 1,
    maxOutputTokens: 350,
    providerOptions: getGatewayProviderOptions(env.AI_MODEL),
  });
}

export async function generateStructuredObject<T>({
  system,
  prompt,
  schema,
  abortSignal,
}: {
  system: string;
  prompt: string;
  schema: ZodType<T>;
  abortSignal: AbortSignal;
}): Promise<T> {
  if (env.AI_MODEL.startsWith('openrouter/')) {
    throw new Error('Structured recommendation is not available for openrouter models');
  }

  const result = await generateObject({
    model: gateway(env.AI_MODEL),
    system,
    prompt,
    schema,
    abortSignal,
    temperature: 0.2,
    maxRetries: 1,
    providerOptions: getGatewayProviderOptions(env.AI_MODEL),
  });

  return result.object;
}

export async function probeTextStream(
  result: StreamableTextResult,
): Promise<StreamProbeResult> {
  const reader = result.textStream.getReader();
  const firstChunk = await reader.read();

  return { firstChunk, reader };
}

export function rebuildTextStreamFromProbe({
  firstChunk,
  reader,
}: StreamProbeResult): ReadableStream<string> {
  let bufferedChunk: ReadableStreamReadResult<string> | null = firstChunk;

  return new ReadableStream<string>({
    async pull(controller) {
      if (bufferedChunk) {
        if (bufferedChunk.done) {
          controller.close();
          bufferedChunk = null;
          return;
        }

        controller.enqueue(bufferedChunk.value);
        bufferedChunk = null;
        return;
      }

      const nextChunk = await reader.read();
      if (nextChunk.done) {
        controller.close();
        return;
      }

      controller.enqueue(nextChunk.value);
    },
    async cancel(reason) {
      await reader.cancel(reason).catch(() => undefined);
    },
  });
}

export function getUpstreamErrorMessage(error: unknown): string {
  const diagnostics = getAiErrorDiagnostics(error);
  const rawMessage = diagnostics.message;

  const normalized = rawMessage.toLowerCase();

  if (
    normalized.includes('customer_verification_required') ||
    normalized.includes('valid credit card') ||
    normalized.includes('billing')
  ) {
    return 'El servicio de IA no esta habilitado correctamente en el backend. Verifica AI Gateway o la configuracion BYOK e intenta de nuevo.';
  }

  if (
    normalized.includes('rate limit') ||
    normalized.includes('too many requests')
  ) {
    return 'El asistente esta temporalmente ocupado. Intenta de nuevo en aproximadamente un minuto.';
  }

  if (
    normalized.includes('invalid api key') ||
    normalized.includes('authentication') ||
    normalized.includes('unauthorized') ||
    normalized.includes('forbidden')
  ) {
    return 'La configuracion del proveedor de IA no es valida en este momento. Revisa las credenciales del backend.';
  }

  if (
    normalized.includes('timeout') ||
    normalized.includes('timed out') ||
    normalized.includes('aborted')
  ) {
    return 'La respuesta del modelo tardo demasiado. Intenta nuevamente en unos instantes.';
  }

  return 'No pude generar una respuesta en este momento. Intenta de nuevo en unos instantes.';
}

export function getAiErrorDiagnostics(error: unknown): AiErrorDiagnostics {
  const rawMessage =
    error instanceof Error
      ? error.message
      : typeof error === 'string'
        ? error
        : JSON.stringify(error);

  const provider =
    error instanceof AiProviderError ? error.provider : inferProviderFromError(rawMessage);
  const model =
    error instanceof AiProviderError ? error.model : env.AI_MODEL;
  const upstreamStatus =
    error instanceof AiProviderError ? error.upstreamStatus : inferStatusCode(rawMessage);
  const normalized = rawMessage.toLowerCase();

  const category =
    error instanceof AiProviderError
      ? error.category
      : inferErrorCategory(normalized, upstreamStatus);

  return {
    provider,
    model,
    category,
    upstreamStatus,
    message: rawMessage,
    isTimeout: category === 'timeout',
    isRateLimit: category === 'rate_limit',
    isAuth: category === 'auth',
    isModelUnavailable: category === 'model_unavailable',
  };
}

function getGatewayProviderOptions(
  modelId: string,
): GatewayByokProviderOptions | undefined {
  if (!env.AI_GATEWAY_ENABLE_BYOK) {
    return undefined;
  }

  const providerPrefix = modelId.split('/')[0]?.trim().toLowerCase();
  if (!providerPrefix) {
    return undefined;
  }

  const byok = getByokForProvider(providerPrefix);
  if (!byok) {
    return undefined;
  }

  return {
    gateway: {
      byok,
      providerTimeouts: {
        byok: Object.fromEntries(
          Object.keys(byok).map(provider => [provider, providerTimeoutByokMs]),
        ),
      },
    },
  };
}

function getByokForProvider(
  providerPrefix: string,
): Record<string, GatewayByokCredential[]> | undefined {
  switch (providerPrefix) {
    case 'openai':
      return env.BYOK_OPENAI_API_KEY
        ? { openai: [{ apiKey: env.BYOK_OPENAI_API_KEY }] }
        : undefined;
    case 'anthropic':
      return env.BYOK_ANTHROPIC_API_KEY
        ? { anthropic: [{ apiKey: env.BYOK_ANTHROPIC_API_KEY }] }
        : undefined;
    case 'google':
      return getVertexByokConfig();
    case 'amazon':
      return getBedrockByokConfig();
    default:
      return undefined;
  }
}

function getVertexByokConfig() {
  if (
    !env.BYOK_VERTEX_PROJECT ||
    !env.BYOK_VERTEX_LOCATION ||
    !env.BYOK_VERTEX_CLIENT_EMAIL ||
    !env.BYOK_VERTEX_PRIVATE_KEY
  ) {
    return undefined;
  }

  return {
    vertex: [
      {
        project: env.BYOK_VERTEX_PROJECT,
        location: env.BYOK_VERTEX_LOCATION,
        googleCredentials: {
          clientEmail: env.BYOK_VERTEX_CLIENT_EMAIL,
          privateKey: env.BYOK_VERTEX_PRIVATE_KEY,
        },
      },
    ],
  };
}

function getBedrockByokConfig() {
  if (
    !env.BYOK_BEDROCK_ACCESS_KEY_ID ||
    !env.BYOK_BEDROCK_SECRET_ACCESS_KEY ||
    !env.BYOK_BEDROCK_REGION
  ) {
    return undefined;
  }

  return {
    bedrock: [
      {
        accessKeyId: env.BYOK_BEDROCK_ACCESS_KEY_ID,
        secretAccessKey: env.BYOK_BEDROCK_SECRET_ACCESS_KEY,
        region: env.BYOK_BEDROCK_REGION,
      },
    ],
  };
}

function createOpenRouterTextStream(
  message: string,
  abortSignal: AbortSignal,
  userName?: string,
): StreamableTextResult {
  const apiKey = process.env.OPENROUTER_API_KEY?.trim();
  const provider = 'openrouter';
  const configuredModel = env.AI_MODEL;

  const prompt = userName
    ? `[Contexto: El usuario se llama ${userName}]\n\n${message}`
    : message;


  if (!apiKey) {
    throw new AiProviderError({
      provider,
      model: configuredModel,
      category: 'auth',
      message: 'OPENROUTER_API_KEY is required for openrouter models',
    });
  }

  const model = getOpenRouterApiModel(configuredModel);

  const textStream = new ReadableStream<string>({
    async start(controller) {
      try {
        const upstreamSignal = AbortSignal.any([
          abortSignal,
          AbortSignal.timeout(openRouterInitialResponseTimeoutMs),
        ]);
        const response = await fetch(openRouterBaseUrl, {
          method: 'POST',
          signal: upstreamSignal,
          headers: {
            Authorization: `Bearer ${apiKey}`,
            'Content-Type': 'application/json',
          },
          body: JSON.stringify({
            model,
            messages: [
              { role: 'system', content: systemPrompt },
              { role: 'user', content: prompt },
            ],
            stream: true,
            temperature: 0.4,
          }),
        });

        if (!response.ok) {
          const errorBody = await response.text().catch(() => '');
          throw new AiProviderError({
            provider,
            model: configuredModel,
            category: inferErrorCategory(errorBody.toLowerCase(), response.status),
            upstreamStatus: response.status,
            message: `OpenRouter upstream error (${response.status}): ${errorBody || response.statusText}`,
          });
        }

        if (!response.body) {
          throw new AiProviderError({
            provider,
            model: configuredModel,
            category: 'empty_response',
            message: 'OpenRouter response body is empty',
          });
        }

        const reader = response.body.getReader();
        const decoder = new TextDecoder();
        let buffer = '';
        let parseErrorCount = 0;
        let emittedChunkCount = 0;

        try {
          while (true) {
            const { done, value } = await readStreamChunkWithTimeout(
              reader,
              openRouterChunkInactivityTimeoutMs,
            );

            if (done) {
              buffer += decoder.decode();
              const finalMetrics = processOpenRouterBuffer(buffer, controller);
              parseErrorCount += finalMetrics.parseErrors;
              emittedChunkCount += finalMetrics.emittedChunks;

              if (emittedChunkCount == 0 && parseErrorCount > 0) {
                throw new AiProviderError({
                  provider,
                  model: configuredModel,
                  category: 'parse_error',
                  message:
                      'OpenRouter stream ended without readable text chunks due to malformed payloads',
                });
              }

              controller.close();
              break;
            }

            buffer += decoder.decode(value, { stream: true });
            const segments = buffer.split('\n\n');
            buffer = segments.pop() ?? '';

            for (const segment of segments) {
              const metrics = processOpenRouterBuffer(segment, controller);
              parseErrorCount += metrics.parseErrors;
              emittedChunkCount += metrics.emittedChunks;
            }
          }
        } finally {
          await reader.cancel().catch(() => undefined);
        }
      } catch (error) {
        if (error instanceof AiProviderError) {
          throw error;
        }

        throw new AiProviderError({
          provider,
          model: configuredModel,
          category: inferErrorCategory(
            error instanceof Error ? error.message.toLowerCase() : '',
            null,
          ),
          message: error instanceof Error ? error.message : String(error),
          cause: error,
        });
      }
    },
    async cancel(reason) {
      abortSignal.throwIfAborted?.();
      return Promise.resolve(reason);
    },
  });

  return { textStream };
}

function inferProviderFromError(message: string): string {
  const normalized = message.toLowerCase();
  if (normalized.includes('openrouter')) {
    return 'openrouter';
  }

  return env.AI_MODEL.split('/')[0] ?? 'unknown';
}

function getOpenRouterApiModel(configuredModel: string): string {
  const trimmed = configuredModel.trim();
  if (trimmed === 'openrouter/auto') {
    return trimmed;
  }

  return trimmed.slice('openrouter/'.length).trim();
}

function inferStatusCode(message: string): number | null {
  const match = message.match(/\((\d{3})\)/);
  if (!match) {
    return null;
  }

  return Number(match[1]);
}

function inferErrorCategory(
  normalizedMessage: string,
  upstreamStatus: number | null,
): AiErrorCategory {
  if (
    upstreamStatus === 401 ||
    upstreamStatus === 403 ||
    normalizedMessage.includes('invalid api key') ||
    normalizedMessage.includes('authentication') ||
    normalizedMessage.includes('unauthorized') ||
    normalizedMessage.includes('forbidden')
  ) {
    return 'auth';
  }

  if (
    upstreamStatus === 429 ||
    normalizedMessage.includes('rate limit') ||
    normalizedMessage.includes('too many requests')
  ) {
    return 'rate_limit';
  }

  if (
    upstreamStatus === 408 ||
    upstreamStatus === 504 ||
    normalizedMessage.includes('timeout') ||
    normalizedMessage.includes('timed out') ||
    normalizedMessage.includes('aborted')
  ) {
    return 'timeout';
  }

  if (
    upstreamStatus === 404 ||
    normalizedMessage.includes('no endpoints found') ||
    normalizedMessage.includes('model not found') ||
    normalizedMessage.includes('model is not available') ||
    normalizedMessage.includes('provider returned no endpoints') ||
    normalizedMessage.includes('unknown model')
  ) {
    return 'model_unavailable';
  }

  if (
    upstreamStatus === 400 ||
    normalizedMessage.includes('bad request') ||
    normalizedMessage.includes('invalid request') ||
    normalizedMessage.includes('invalid payload')
  ) {
    return 'invalid_request';
  }

  if (upstreamStatus != null && upstreamStatus >= 500 && upstreamStatus <= 599) {
    return 'upstream_5xx';
  }

  if (
    normalizedMessage.includes('malformed payload') ||
    normalizedMessage.includes('unexpected token') ||
    normalizedMessage.includes('json parse') ||
    normalizedMessage.includes('without readable text chunks')
  ) {
    return 'parse_error';
  }

  if (
    normalizedMessage.includes('network') ||
    normalizedMessage.includes('fetch failed') ||
    normalizedMessage.includes('ecconnreset') ||
    normalizedMessage.includes('enotfound') ||
    normalizedMessage.includes('econnrefused')
  ) {
    return 'network';
  }

  if (normalizedMessage.includes('response body is empty')) {
    return 'empty_response';
  }

  return 'unknown';
}

function processOpenRouterBuffer(
  rawChunk: string,
  controller: ReadableStreamDefaultController<string>,
): { emittedChunks: number; parseErrors: number } {
  let emittedChunks = 0;
  let parseErrors = 0;
  const lines = rawChunk
    .split('\n')
    .map(line => line.trim())
    .filter(Boolean);

  for (const line of lines) {
    if (!line.startsWith('data:')) {
      continue;
    }

    const payload = line.slice(5).trim();

    if (payload === '[DONE]') {
      continue;
    }

    let parsed: Record<string, unknown>;
    try {
      parsed = JSON.parse(payload) as Record<string, unknown>;
    } catch {
      parseErrors += 1;
      continue;
    }

    const choice = Array.isArray(parsed.choices) ? parsed.choices[0] : undefined;
    const delta =
      choice && typeof choice === 'object' && choice !== null
        ? (choice as Record<string, unknown>).delta
        : undefined;
    const content =
      delta && typeof delta === 'object' && delta !== null
        ? (delta as Record<string, unknown>).content
        : undefined;

    if (typeof content === 'string' && content.length > 0) {
      controller.enqueue(content);
      emittedChunks += 1;
    }
  }

  return { emittedChunks, parseErrors };
}

async function readStreamChunkWithTimeout(
  reader: ReadableStreamDefaultReader<Uint8Array>,
  timeoutMs: number,
): Promise<ReadableStreamReadResult<Uint8Array>> {
  let timer: NodeJS.Timeout | undefined;
  const timeout = new Promise<never>((_, reject) => {
    timer = setTimeout(() => {
      reject(new Error(`Stream chunk timed out after ${timeoutMs}ms`));
    }, timeoutMs);
    timer.unref?.();
  });

  try {
    return await Promise.race([reader.read(), timeout]);
  } finally {
    if (timer != null) {
      clearTimeout(timer);
    }
  }
}

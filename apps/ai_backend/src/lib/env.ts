import 'dotenv/config';

import { z } from 'zod';

function optionalSecret(value: string | undefined) {
  const trimmed = value?.trim();
  return trimmed ? trimmed : undefined;
}

function parseBooleanFlag(value: string | undefined, fallback = false) {
  if (value == null || value.trim() === '') {
    return fallback;
  }

  return ['1', 'true', 'yes', 'on'].includes(value.trim().toLowerCase());
}

function parsePositiveIntegerFlag(
  value: string | undefined,
  fallback: number,
  name: string,
) {
  if (value == null || value.trim() === '') {
    return fallback;
  }

  const parsed = Number(value.trim());
  if (!Number.isInteger(parsed) || parsed <= 0) {
    throw new Error(`${name} must be a valid positive integer`);
  }

  return parsed;
}

const envSchema = z.object({
  PORT: z.string().default('8080'),
  CORS_ORIGIN: z.string().default('http://localhost:5173'),
  AI_RATE_LIMIT_MAX: z.string().optional(),
  AI_RATE_LIMIT_WINDOW_MS: z.string().optional(),
  AI_GATEWAY_API_KEY: z.string().optional(),
  AI_MODEL: z.string().min(1).default('openai/gpt-5-mini'),
  FIREBASE_PROJECT_ID: z.string().min(1, 'FIREBASE_PROJECT_ID is required'),
  FIREBASE_CLIENT_EMAIL: z.string().min(1, 'FIREBASE_CLIENT_EMAIL is required'),
  FIREBASE_PRIVATE_KEY: z.string().min(1, 'FIREBASE_PRIVATE_KEY is required'),
  AI_GATEWAY_ENABLE_BYOK: z.string().optional(),
  BYOK_OPENAI_API_KEY: z.string().optional(),
  BYOK_ANTHROPIC_API_KEY: z.string().optional(),
  BYOK_VERTEX_PROJECT: z.string().optional(),
  BYOK_VERTEX_LOCATION: z.string().optional(),
  BYOK_VERTEX_CLIENT_EMAIL: z.string().optional(),
  BYOK_VERTEX_PRIVATE_KEY: z.string().optional(),
  BYOK_BEDROCK_ACCESS_KEY_ID: z.string().optional(),
  BYOK_BEDROCK_SECRET_ACCESS_KEY: z.string().optional(),
  BYOK_BEDROCK_REGION: z.string().optional(),
});

const parsedEnv = envSchema.parse(process.env);

const port = Number(parsedEnv.PORT);
if (Number.isNaN(port) || port <= 0) {
  throw new Error('PORT must be a valid positive number');
}

const corsOrigin = parsedEnv.CORS_ORIGIN.trim();
const allowedOrigins =
  corsOrigin === '*'
    ? '*'
    : corsOrigin
        .split(',')
        .map(origin => origin.trim())
        .filter(Boolean);

export const env = {
  PORT: port,
  CORS_ORIGIN: corsOrigin,
  ALLOWED_ORIGINS: allowedOrigins,
  AI_RATE_LIMIT_MAX: parsePositiveIntegerFlag(
    parsedEnv.AI_RATE_LIMIT_MAX,
    5,
    'AI_RATE_LIMIT_MAX',
  ),
  AI_RATE_LIMIT_WINDOW_MS: parsePositiveIntegerFlag(
    parsedEnv.AI_RATE_LIMIT_WINDOW_MS,
    60 * 1000,
    'AI_RATE_LIMIT_WINDOW_MS',
  ),
  AI_GATEWAY_API_KEY: optionalSecret(parsedEnv.AI_GATEWAY_API_KEY),
  AI_MODEL: parsedEnv.AI_MODEL.trim(),
  FIREBASE_PROJECT_ID: parsedEnv.FIREBASE_PROJECT_ID.trim(),
  FIREBASE_CLIENT_EMAIL: parsedEnv.FIREBASE_CLIENT_EMAIL.trim(),
  FIREBASE_PRIVATE_KEY: parsedEnv.FIREBASE_PRIVATE_KEY.replace(/\\n/g, '\n'),
  AI_GATEWAY_ENABLE_BYOK: parseBooleanFlag(parsedEnv.AI_GATEWAY_ENABLE_BYOK),
  BYOK_OPENAI_API_KEY: optionalSecret(parsedEnv.BYOK_OPENAI_API_KEY),
  BYOK_ANTHROPIC_API_KEY: optionalSecret(parsedEnv.BYOK_ANTHROPIC_API_KEY),
  BYOK_VERTEX_PROJECT: optionalSecret(parsedEnv.BYOK_VERTEX_PROJECT),
  BYOK_VERTEX_LOCATION: optionalSecret(parsedEnv.BYOK_VERTEX_LOCATION),
  BYOK_VERTEX_CLIENT_EMAIL: optionalSecret(parsedEnv.BYOK_VERTEX_CLIENT_EMAIL),
  BYOK_VERTEX_PRIVATE_KEY: parsedEnv.BYOK_VERTEX_PRIVATE_KEY?.replace(
    /\\n/g,
    '\n',
  ),
  BYOK_BEDROCK_ACCESS_KEY_ID: optionalSecret(
    parsedEnv.BYOK_BEDROCK_ACCESS_KEY_ID,
  ),
  BYOK_BEDROCK_SECRET_ACCESS_KEY: optionalSecret(
    parsedEnv.BYOK_BEDROCK_SECRET_ACCESS_KEY,
  ),
  BYOK_BEDROCK_REGION: optionalSecret(parsedEnv.BYOK_BEDROCK_REGION),
} as const;

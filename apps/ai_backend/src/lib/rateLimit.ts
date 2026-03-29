import rateLimit from 'express-rate-limit';

import { env } from './env.js';

export const aiRateLimit = rateLimit({
  windowMs: env.AI_RATE_LIMIT_WINDOW_MS,
  max: env.AI_RATE_LIMIT_MAX,
  standardHeaders: true,
  legacyHeaders: false,
  message: 'Has alcanzado el limite temporal. Intenta de nuevo en un minuto.',
});

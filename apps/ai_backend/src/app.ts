import cors from 'cors';
import express, {
  type NextFunction,
  type Request,
  type Response,
} from 'express';

import { env } from './lib/env.js';
import { aiRouter } from './routes/ai.js';

function createCorsOptions() {
  if (env.ALLOWED_ORIGINS === '*') {
    return { origin: true };
  }

  return {
    origin(origin: string | undefined, callback: (error: Error | null, allow?: boolean) => void) {
      if (!origin) {
        callback(null, true);
        return;
      }

      const allow = env.ALLOWED_ORIGINS.includes(origin);
      callback(allow ? null : new Error('Origin not allowed by CORS'), allow);
    },
  };
}

export const app = express();

app.set('trust proxy', 1);
app.use(cors(createCorsOptions()));
app.use(express.json({ limit: '10kb' }));

app.get('/health', (_req, res) => {
  res.status(200).json({ ok: true });
});

app.use('/api/ai', aiRouter);

app.use((_req, res) => {
  res.status(404).json({ error: 'Not found' });
});

app.use(
  (
    error: unknown,
    _req: Request,
    res: Response,
    _next: NextFunction,
  ) => {
    console.error('[server] unhandled error', error);

    if (res.headersSent) {
      return;
    }

    const message =
      error instanceof Error && error.message.includes('CORS')
        ? 'Origin not allowed.'
        : 'Internal server error.';

    res.status(500).json({ error: message });
  },
);

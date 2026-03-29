import { AI_CHAT_MAX_MESSAGE_LENGTH } from '@mental-health/shared-contracts';
import { pipeTextStreamToResponse } from 'ai';
import { Router, type Request, type Response } from 'express';
import { z } from 'zod';

import {
  containsAmbiguousRiskLanguage,
  containsExplicitEmergencyLanguage,
  containsNonEmergencyHighActivationLanguage,
  rebuildTextStreamFromProbe,
  containsAcuteRiskLanguage,
  createTherapeuticTextStream,
  generateStructuredObject,
  getAcuteRiskReply,
  getAmbiguousRiskReply,
  getNonEmergencyHighActivationReply,
  getUpstreamErrorMessage,
  probeTextStream,
} from '../lib/ai.js';
import { recommendationSystemPrompt } from '../prompts/recommendationPrompt.js';
import { verifyFirebaseIdToken } from '../lib/firebaseAdmin.js';
import { aiRateLimit } from '../lib/rateLimit.js';

const chatBodySchema = z.object({
  message: z
    .string()
    .trim()
    .min(1, 'message is required')
    .max(
      AI_CHAT_MAX_MESSAGE_LENGTH,
      `message exceeds the ${AI_CHAT_MAX_MESSAGE_LENGTH} character limit`,
    ),
});

const recommendationContextSchema = z.object({
  todayMood: z.number().int().min(-1).max(1).nullable(),
  weeklyMoods: z.array(z.number().int().min(-1).max(1).nullable()).max(7),
  hasDeterioration: z.boolean(),
  sosActivationsLast7d: z.number().int().min(0),
  sosActivationsLast24h: z.number().int().min(0),
  recentSessionFeedback: z.array(
    z.object({
      sessionId: z.string().trim().min(1),
      score: z.number().int().min(-1).max(1),
    }),
  ),
  availableSessions: z.array(
    z.object({
      id: z.string().trim().min(1),
      title: z.string().trim().min(1),
      category: z.string().trim().min(1),
      durationSeconds: z.number().int().min(1),
      isPremium: z.boolean(),
    }),
  ),
  hardRules: z.object({
    preferredDuration: z.enum(['short', 'medium', 'long']),
    supportLevelFloor: z.enum(['standard', 'elevated']),
    candidateCategories: z.array(z.string().trim().min(1)).max(6),
    blockedSessionIds: z.array(z.string().trim().min(1)).max(20),
    forceProfessionalSupportNudge: z.boolean(),
    hasHighRecentLoad: z.boolean(),
    hasElevatedAcuteUsage: z.boolean(),
  }),
});

const recommendationBodySchema = z.object({
  context: recommendationContextSchema,
});

const recommendationResponseSchema = z.object({
  summary: z.string().trim().min(1).max(180),
  recommendedCategories: z.array(z.string().trim().min(1)).max(3),
  recommendedSessionIds: z.array(z.string().trim().min(1)).max(3),
  recommendedDuration: z.enum(['short', 'medium', 'long']),
  supportLevel: z.enum(['standard', 'elevated']),
  showProfessionalSupportNudge: z.boolean(),
  uiMessage: z.string().trim().min(1).max(220),
});

export const aiRouter = Router();

function getBearerToken(request: Request): string | null {
  const authorization = request.header('authorization')?.trim();
  if (!authorization) {
    return null;
  }

  const match = authorization.match(/^Bearer\s+(.+)$/i);
  return match?.[1]?.trim() || null;
}

aiRouter.post(
  '/chat',
  aiRateLimit,
  async (req: Request, res: Response): Promise<void> => {
    const idToken = getBearerToken(req);
    if (!idToken) {
      res
        .status(401)
        .type('text/plain; charset=utf-8')
        .send('No autorizado.');
      return;
    }

    try {
      await verifyFirebaseIdToken(idToken);
    } catch {
      res
        .status(401)
        .type('text/plain; charset=utf-8')
        .send('No autorizado.');
      return;
    }

    const parsedBody = chatBodySchema.safeParse(req.body);

    if (!parsedBody.success) {
      const firstIssue = parsedBody.error.issues[0];
      res
        .status(400)
        .type('text/plain; charset=utf-8')
        .send(firstIssue?.message ?? 'Solicitud invalida.');
      return;
    }

    const { message } = parsedBody.data;

    if (
      containsAcuteRiskLanguage(message) ||
      containsExplicitEmergencyLanguage(message)
    ) {
      res.status(200).type('text/plain; charset=utf-8').send(getAcuteRiskReply());
      return;
    }

    if (containsAmbiguousRiskLanguage(message)) {
      res
        .status(200)
        .type('text/plain; charset=utf-8')
        .send(getAmbiguousRiskReply());
      return;
    }

    if (containsNonEmergencyHighActivationLanguage(message)) {
      res
        .status(200)
        .type('text/plain; charset=utf-8')
        .send(getNonEmergencyHighActivationReply());
      return;
    }

    const abortController = new AbortController();
    const abortStream = () => abortController.abort('client disconnected');
    const cleanup = () => {
      req.off('close', abortStream);
      req.off('aborted', abortStream);
      res.off('close', cleanup);
      res.off('finish', cleanup);
      res.off('error', cleanup);
    };

    req.on('close', abortStream);
    req.on('aborted', abortStream);
    res.on('close', cleanup);
    res.on('finish', cleanup);
    res.on('error', cleanup);

    try {
      req.setTimeout(25_000);
      res.setTimeout(25_000);

      const result = createTherapeuticTextStream(
        message,
        abortController.signal,
      );

      const streamProbe = await probeTextStream(result);

      if (streamProbe.firstChunk.done) {
        cleanup();
        res
          .status(502)
          .type('text/plain; charset=utf-8')
          .send(
            'El proveedor de IA no devolvio contenido. Revisa AI Gateway o la configuracion BYOK e intenta de nuevo.',
          );
        return;
      }

      pipeTextStreamToResponse({
        response: res,
        status: 200,
        headers: {
          'Content-Type': 'text/plain; charset=utf-8',
        },
        textStream: rebuildTextStreamFromProbe(streamProbe),
      });
    } catch (error) {
      cleanup();
      console.error('[ai/chat] stream failure', error);

      if (!res.headersSent) {
        res
          .status(503)
          .type('text/plain; charset=utf-8')
          .send(getUpstreamErrorMessage(error));
      } else {
        res.end();
      }
    }
  },
);

aiRouter.post(
  '/recommendation',
  aiRateLimit,
  async (req: Request, res: Response): Promise<void> => {
    const idToken = getBearerToken(req);
    if (!idToken) {
      res
        .status(401)
        .type('text/plain; charset=utf-8')
        .send('No autorizado.');
      return;
    }

    try {
      await verifyFirebaseIdToken(idToken);
    } catch {
      res
        .status(401)
        .type('text/plain; charset=utf-8')
        .send('No autorizado.');
      return;
    }

    const parsedBody = recommendationBodySchema.safeParse(req.body);
    if (!parsedBody.success) {
      const firstIssue = parsedBody.error.issues[0];
      res
        .status(400)
        .type('text/plain; charset=utf-8')
        .send(firstIssue?.message ?? 'Solicitud invalida.');
      return;
    }

    const abortController = new AbortController();
    const abort = () => abortController.abort('client disconnected');
    req.on('close', abort);
    req.on('aborted', abort);

    try {
      req.setTimeout(25_000);
      res.setTimeout(25_000);

      const prompt = [
        'Genera una recomendacion prudente y estructurada usando este contexto JSON.',
        'Devuelve exclusivamente el objeto solicitado.',
        JSON.stringify(parsedBody.data.context),
      ].join('\n\n');

      const recommendation = await generateStructuredObject({
        system: recommendationSystemPrompt,
        prompt,
        schema: recommendationResponseSchema,
        abortSignal: abortController.signal,
      });

      res.status(200).json(recommendation);
    } catch (error) {
      console.error('[ai/recommendation] failure', error);
      res
        .status(503)
        .type('text/plain; charset=utf-8')
        .send(getUpstreamErrorMessage(error));
    } finally {
      req.off('close', abort);
      req.off('aborted', abort);
    }
  },
);

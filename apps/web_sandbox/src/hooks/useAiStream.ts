import {
  AI_CHAT_MAX_MESSAGE_LENGTH,
  createAiChatRequest,
  type AiChatRequestBody,
} from '@mental-health/shared-contracts';
import { useCallback, useRef, useState } from 'react';

import { buildApiUrl } from '../lib/api';

type UseAiStreamResult = {
  rawText: string;
  loading: boolean;
  error: string | null;
  sendMessage: (message: string) => Promise<void>;
  cancel: () => void;
  reset: () => void;
  abortController: AbortController | null;
};

export function useAiStream(): UseAiStreamResult {
  const [rawText, setRawText] = useState('');
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const abortControllerRef = useRef<AbortController | null>(null);

  const cancel = useCallback(() => {
    abortControllerRef.current?.abort();
    abortControllerRef.current = null;
    setLoading(false);
  }, []);

  const reset = useCallback(() => {
    setRawText('');
    setError(null);
  }, []);

  const sendMessage = useCallback(async (message: string) => {
    const trimmed = message.trim();
    if (!trimmed) {
      setError('Escribe un mensaje para continuar.');
      return;
    }

    if (trimmed.length > AI_CHAT_MAX_MESSAGE_LENGTH) {
      setError(
        `El mensaje no puede superar ${AI_CHAT_MAX_MESSAGE_LENGTH} caracteres.`,
      );
      return;
    }

    abortControllerRef.current?.abort();

    const controller = new AbortController();
    abortControllerRef.current = controller;

    setLoading(true);
    setError(null);
    setRawText('');

    const requestBody: AiChatRequestBody = createAiChatRequest(trimmed);

    try {
      const response = await fetch(buildApiUrl('/api/ai/chat'), {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
        },
        body: JSON.stringify(requestBody),
        signal: controller.signal,
      });

      if (!response.ok) {
        const body = (await response.text()).trim();
        throw new Error(
          body || 'No fue posible obtener una respuesta del servidor.',
        );
      }

      if (!response.body) {
        throw new Error('El servidor no devolvio un stream legible.');
      }

      const reader = response.body.getReader();
      const decoder = new TextDecoder();

      while (true) {
        const { done, value } = await reader.read();

        if (done) {
          break;
        }

        if (!value) {
          continue;
        }

        const chunk = decoder.decode(value, { stream: true });
        if (chunk) {
          setRawText(previous => previous + chunk);
        }
      }

      const finalChunk = decoder.decode();
      if (finalChunk) {
        setRawText(previous => previous + finalChunk);
      }
    } catch (caughtError) {
      if (controller.signal.aborted) {
        setError('Respuesta cancelada.');
        return;
      }

      const message =
        caughtError instanceof Error
          ? caughtError.message
          : 'Ocurrio un error inesperado.';
      setError(message);
    } finally {
      if (abortControllerRef.current === controller) {
        abortControllerRef.current = null;
      }
      setLoading(false);
    }
  }, []);

  return {
    rawText,
    loading,
    error,
    sendMessage,
    cancel,
    reset,
    abortController: abortControllerRef.current,
  };
}

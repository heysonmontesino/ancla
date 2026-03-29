import type { FormEvent, JSX } from 'react';
import { useMemo, useState } from 'react';

import { useAiStream } from '../hooks/useAiStream';
import { AiResponse } from './AiResponse';

const MAX_MESSAGE_LENGTH = 2000;

export function AiChat(): JSX.Element {
  const [message, setMessage] = useState('');
  const { rawText, loading, error, sendMessage, cancel, reset } = useAiStream();

  const remainingCharacters = useMemo(
    () => MAX_MESSAGE_LENGTH - message.length,
    [message.length],
  );

  async function handleSubmit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    await sendMessage(message);
  }

  return (
    <main className="page-shell">
      <section className="chat-card">
        <header className="chat-header">
          <p className="eyebrow">APOYO EMOCIONAL GENERAL</p>
          <h1>Asistente de regulación</h1>
          <p className="header-copy">
            Respuestas breves, contenedoras y orientadas a grounding. No sustituye
            atención profesional ni servicios de emergencia.
          </p>
        </header>

        <div className="warning-banner">
          Esta herramienta brinda apoyo emocional general y no reemplaza atención
          profesional ni servicios de emergencia.
        </div>

        <AiResponse rawText={rawText} loading={loading} error={error} />

        <form className="composer" onSubmit={handleSubmit}>
          <label className="composer-label" htmlFor="ai-message">
            ¿Cómo te sientes o qué necesitas en este momento?
          </label>
          <textarea
            id="ai-message"
            className="composer-input"
            value={message}
            onChange={event => {
              const nextValue = event.target.value.slice(0, MAX_MESSAGE_LENGTH);
              setMessage(nextValue);
            }}
            rows={5}
            placeholder="Ejemplo: me siento muy activado y necesito volver a centrarme."
          />
          <div className="composer-footer">
            <span
              className={`char-counter ${
                remainingCharacters < 120 ? 'char-counter--alert' : ''
              }`}
            >
              {remainingCharacters} caracteres
            </span>
            <div className="composer-actions">
              <button
                type="button"
                className="secondary-button"
                onClick={reset}
                disabled={loading && !rawText}
              >
                Limpiar
              </button>
              {loading ? (
                <button
                  type="button"
                  className="secondary-button"
                  onClick={cancel}
                >
                  Cancelar
                </button>
              ) : null}
              <button
                type="submit"
                className="primary-button"
                disabled={loading || !message.trim()}
              >
                Enviar
              </button>
            </div>
          </div>
        </form>
      </section>
    </main>
  );
}

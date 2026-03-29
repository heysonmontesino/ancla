import type { JSX } from 'react';
import { Streamdown } from 'streamdown';

type AiResponseProps = {
  rawText: string;
  loading: boolean;
  error: string | null;
};

export function AiResponse({
  rawText,
  loading,
  error,
}: AiResponseProps): JSX.Element {
  if (error) {
    return (
      <section className="response-panel response-panel--error" aria-live="polite">
        <p>{error}</p>
      </section>
    );
  }

  if (!rawText && !loading) {
    return (
      <section className="response-panel" aria-live="polite">
        <p className="response-placeholder">
          Cuando envíes un mensaje, la respuesta aparecerá aquí en tiempo real.
        </p>
      </section>
    );
  }

  return (
    <section className="response-panel" aria-live="polite">
      <div className="response-markdown">
        <Streamdown isAnimating={loading}>
          {rawText}
        </Streamdown>
      </div>
      {loading ? <p className="response-status">Escribiendo...</p> : null}
    </section>
  );
}

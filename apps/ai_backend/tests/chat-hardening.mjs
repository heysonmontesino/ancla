import assert from 'node:assert/strict';

process.env.PORT ??= '8080';
process.env.CORS_ORIGIN ??= '*';
process.env.AI_MODEL ??= 'openrouter/auto';
process.env.FIREBASE_PROJECT_ID ??= 'test-project';
process.env.FIREBASE_CLIENT_EMAIL ??= 'test@example.com';
process.env.FIREBASE_PRIVATE_KEY ??=
  '-----BEGIN PRIVATE KEY-----\\nfake\\n-----END PRIVATE KEY-----\\n';

const { getAiErrorDiagnostics, getUpstreamErrorMessage } = await import(
  '../dist/lib/ai.js'
);
const { systemPrompt } = await import('../dist/prompts/systemPrompt.js');

const cases = [
  {
    input: new Error(
      'OpenRouter upstream error (401): {"error":{"message":"User not found.","code":401}}',
    ),
    category: 'auth',
  },
  {
    input: new Error('OpenRouter upstream error (429): rate limit exceeded'),
    category: 'rate_limit',
  },
  {
    input: new Error('Stream chunk timed out after 20000ms'),
    category: 'timeout',
  },
  {
    input: new Error('OpenRouter upstream error (400): invalid request body'),
    category: 'invalid_request',
  },
  {
    input: new Error('OpenRouter upstream error (404): model not found'),
    category: 'model_unavailable',
  },
  {
    input: new Error('OpenRouter upstream error (503): upstream unavailable'),
    category: 'upstream_5xx',
  },
  {
    input: new Error(
      'OpenRouter stream ended without readable text chunks due to malformed payloads',
    ),
    category: 'parse_error',
  },
];

for (const testCase of cases) {
  const diagnostics = getAiErrorDiagnostics(testCase.input);
  assert.equal(diagnostics.provider, 'openrouter');
  assert.equal(diagnostics.model, 'openrouter/auto');
  assert.equal(diagnostics.category, testCase.category);
}

assert.equal(
  getUpstreamErrorMessage(
    new Error('OpenRouter upstream error (429): too many requests'),
  ),
  'El asistente esta temporalmente ocupado. Intenta de nuevo en aproximadamente un minuto.',
);

assert.equal(
  getUpstreamErrorMessage(
    new Error('Stream chunk timed out after 20000ms'),
  ),
  'La respuesta del modelo tardo demasiado. Intenta nuevamente en unos instantes.',
);

assert.equal(
  getUpstreamErrorMessage(
    new Error('OpenRouter upstream error (503): upstream unavailable'),
  ),
  'No pude generar una respuesta en este momento. Intenta de nuevo en unos instantes.',
);

assert.ok(systemPrompt.includes('prioriza naturalidad, criterio y sensibilidad al matiz del usuario'));
assert.ok(systemPrompt.includes('por defecto responde breve: normalmente 2 a 4 frases cortas'));
assert.ok(systemPrompt.includes('no intentes resolver todo en un solo turno'));
assert.ok(systemPrompt.includes('cuando tenga sentido, termina con una pregunta breve para continuar'));
assert.ok(systemPrompt.includes('Responde siempre en el idioma del usuario.'));
assert.ok(systemPrompt.includes('si el usuario escribe en espanol, responde obligatoriamente en espanol neutro, natural y claro'));
assert.ok(systemPrompt.includes('No cambies a ingles ni a otro idioma salvo que el usuario lo pida de forma explicita'));
assert.ok(systemPrompt.includes('la recomendacion no debe contaminar ni romper el flujo del cuerpo principal'));
assert.ok(systemPrompt.includes('abrir o cerrar toda la respuesta con comillas'));
assert.equal(systemPrompt.includes('Ejemplos de estilo deseado'), false);
assert.equal(systemPrompt.includes('Input:'), false);
assert.equal(systemPrompt.includes('Output:'), false);
assert.equal(systemPrompt.includes('idealmente responde en 3 o 4 frases cortas'), false);

console.log('AI chat hardening tests passed');

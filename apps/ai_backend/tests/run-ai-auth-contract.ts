import { mkdir, writeFile } from 'node:fs/promises';
import path from 'node:path';
import process from 'node:process';

type AuthCase = {
  id: string;
  description: string;
  token: string | null;
  expectedStatus: number;
};

type AuthResult = {
  id: string;
  description: string;
  expectedStatus: number;
  actualStatus: number | null;
  passed: boolean;
  responseText: string;
};

const BASE_URL =
  process.env.AI_CHAT_TEST_BASE_URL?.trim().replace(/\/+$/, '') ??
  'http://localhost:8080';
const ENDPOINT_URL = `${BASE_URL}/api/ai/chat`;
const VALID_BEARER_TOKEN =
  process.env.AI_CHAT_TEST_BEARER_TOKEN?.trim() ?? '';
const VALID_CASE_MESSAGE = 'Quiero hacerme daño';

async function readResponseText(response: Response): Promise<string> {
  return (await response.text()).trim();
}

function buildCases(): AuthCase[] {
  return [
    {
      id: 'missing_token',
      description: 'Rechaza requests sin Authorization Bearer',
      token: null,
      expectedStatus: 401,
    },
    {
      id: 'invalid_token',
      description: 'Rechaza requests con token Bearer invalido',
      token: 'invalid-test-token',
      expectedStatus: 401,
    },
    {
      id: 'valid_token',
      description: 'Acepta requests con token Bearer valido',
      token: VALID_BEARER_TOKEN,
      expectedStatus: 200,
    },
  ];
}

async function runCase(testCase: AuthCase): Promise<AuthResult> {
  if (testCase.id == 'valid_token' && !testCase.token) {
    return {
      id: testCase.id,
      description: testCase.description,
      expectedStatus: testCase.expectedStatus,
      actualStatus: null,
      passed: false,
      responseText: 'Missing required env var: AI_CHAT_TEST_BEARER_TOKEN',
    };
  }

  try {
    const headers: Record<string, string> = {
      'Content-Type': 'application/json',
    };

    if (testCase.token) {
      headers.Authorization = `Bearer ${testCase.token}`;
    }

    const response = await fetch(ENDPOINT_URL, {
      method: 'POST',
      headers,
      body: JSON.stringify({ message: VALID_CASE_MESSAGE }),
    });

    const responseText = await readResponseText(response);

    return {
      id: testCase.id,
      description: testCase.description,
      expectedStatus: testCase.expectedStatus,
      actualStatus: response.status,
      passed: response.status == testCase.expectedStatus,
      responseText,
    };
  } catch (error) {
    const responseText =
      error instanceof Error ? error.message : 'Unknown auth contract error';

    return {
      id: testCase.id,
      description: testCase.description,
      expectedStatus: testCase.expectedStatus,
      actualStatus: null,
      passed: false,
      responseText,
    };
  }
}

function printSummary(results: AuthResult[]) {
  console.log('\nAI Auth Contract Summary');
  console.log(`Endpoint: ${ENDPOINT_URL}`);

  for (const result of results) {
    const mark = result.passed ? 'PASS' : 'FAIL';
    console.log(
      `[${mark}] ${result.id} | expected=${result.expectedStatus} | actual=${result.actualStatus ?? 'ERR'}`,
    );
    if (!result.passed) {
      console.log(`  ${result.responseText}`);
    }
  }
}

async function writeReport(results: AuthResult[]) {
  const resultsDir = path.resolve('tests/results');
  await mkdir(resultsDir, { recursive: true });
  const timestamp = new Date().toISOString().replace(/[:.]/g, '-');
  const reportPath = path.join(
    resultsDir,
    `ai-auth-contract-${timestamp}.json`,
  );
  await writeFile(reportPath, JSON.stringify(results, null, 2), 'utf8');
  console.log(`Saved JSON report to ${reportPath}`);
}

async function main() {
  const cases = buildCases();
  const results: AuthResult[] = [];

  for (const testCase of cases) {
    const result = await runCase(testCase);
    results.push(result);
  }

  printSummary(results);
  await writeReport(results);

  if (results.some(result => !result.passed)) {
    process.exitCode = 1;
  }
}

main().catch(error => {
  console.error('Failed to run AI auth contract tests', error);
  process.exit(1);
});

import path from 'node:path';

import { uploadFileToCloudflare } from './cloudflare_audio_uploader.mjs';

function parseArgs(argv) {
  const args = {};

  for (let index = 0; index < argv.length; index += 1) {
    const current = argv[index];
    if (!current.startsWith('--')) {
      continue;
    }

    const key = current.slice(2);
    const value = argv[index + 1];
    if (!value || value.startsWith('--')) {
      args[key] = true;
      continue;
    }

    args[key] = value;
    index += 1;
  }

  return args;
}

function requireArg(args, name) {
  const value = args[name]?.trim();
  if (!value) {
    throw new Error(`Missing required argument: --${name}`);
  }
  return value;
}

async function main() {
  const args = parseArgs(process.argv.slice(2));
  const filePath = path.resolve(requireArg(args, 'file'));
  const objectKey = requireArg(args, 'key');

  const result = await uploadFileToCloudflare(filePath, objectKey);

  console.log(
    JSON.stringify(
      {
        ok: true,
        filePath,
        objectKey: result.objectKey,
        publicUrl: result.publicUrl,
      },
      null,
      2,
    ),
  );
}

import { fileURLToPath } from 'node:url';

if (process.argv[1] === fileURLToPath(import.meta.url)) {
  main().catch(error => {
    const message = error instanceof Error ? error.message : 'Unknown error';
    console.error(
      JSON.stringify(
        {
          ok: false,
          error: message,
        },
        null,
        2,
      ),
    );
    process.exitCode = 1;
  });
}

import path from 'node:path';

import {
  uploadAudioToCloudflare,
  deleteAudioFromCloudflare,
} from './cloudflare_audio_uploader.mjs';
import { createSessionDocument } from './firestore_session_registry.mjs';
import { parseCommonArgs, formatResult } from './cli_utils.mjs';

function requireArg(args, name) {
  const value = args[name]?.trim();
  if (!value) {
    throw new Error(`Missing required argument: --${name}`);
  }
  return value;
}

async function main() {
  const { args, force, error } = parseCommonArgs(process.argv.slice(2));

  if (error) {
    throw new Error(error);
  }

  const file = requireArg(args, 'file');
  const documentId = args.id?.trim() || args.documentId?.trim();
  const title = requireArg(args, 'title');
  const category = requireArg(args, 'category');
  const duration = Number(requireArg(args, 'duration'));
  const description = args.description?.trim();
  const coverImageUrl =
    args.coverImageUrl?.trim() || args.imageUrl?.trim();
  const coverVariant = args.coverVariant?.trim();
  const coverPromptVersion = args.coverPromptVersion?.trim();
  const coverStatus = args.coverStatus?.trim();

  const absoluteFilePath = path.resolve(file);
  const uploadResult = await uploadAudioToCloudflare(absoluteFilePath);

  try {
    const firestoreResult = await createSessionDocument({
      documentId,
      title,
      description,
      category,
      duration,
      audioUrl: uploadResult.publicUrl,
      coverImageUrl,
      coverVariant,
      coverPromptVersion,
      coverStatus,
      overwrite: force,
    });

    const result = formatResult({ 
      documentId: firestoreResult.id, 
      title: title 
    }, 'success');

    console.log(JSON.stringify({
      ok: true,
      filePath: absoluteFilePath,
      objectKey: uploadResult.objectKey,
      audioUrl: uploadResult.publicUrl,
      firestore: {
        collection: firestoreResult.collection,
        documentId: firestoreResult.id,
      },
      ...result,
    }, null, 2));
  } catch (firestoreError) {
    const r2Key = uploadResult.objectKey;
    console.warn(`[Pipeline] Firestore failed. Rolling back R2: ${r2Key}`);
    try {
      await deleteAudioFromCloudflare(r2Key);
      console.warn('[Pipeline] R2 rollback successful.');
      firestoreError.rollback = 'success';
    } catch (r2Error) {
      console.error(`[Pipeline] FATAL: R2 rollback also failed! Orphan asset: ${r2Key}`);
      console.error(`R2 Error: ${r2Error.message}`);
      firestoreError.rollback = 'failed';
      firestoreError.rollbackError = r2Error.message;
      firestoreError.orphanAsset = r2Key;
    }
    throw firestoreError;
  }
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
          ...(error.rollback ? { rollback: error.rollback } : {}),
          ...(error.rollbackError ? { rollbackError: error.rollbackError } : {}),
          ...(error.orphanAsset ? { orphanAsset: error.orphanAsset } : {}),
        },
        null,
        2,
      ),
    );
    process.exitCode = 1;
  });
}

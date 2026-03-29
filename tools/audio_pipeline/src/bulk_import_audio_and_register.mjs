import { access, readFile, writeFile } from 'node:fs/promises';
import path from 'node:path';
import process from 'node:process';

import {
  uploadAudioToCloudflare,
  deleteAudioFromCloudflare,
} from './cloudflare_audio_uploader.mjs';
import { createSessionDocument } from './firestore_session_registry.mjs';
import { 
  parseCommonArgs, 
  formatResult, 
  printSummary, 
  VALID_CATEGORIES 
} from './cli_utils.mjs';

function requireArg(args, name) {
  const value = args[name]?.trim() || args[name];
  if (!value) {
    throw new Error(`Missing required argument: --${name}`);
  }
  return value;
}

function parseDuration(rawDuration, fileName) {
  const duration = Number(rawDuration);
  if (!Number.isInteger(duration) || duration <= 0) {
    throw new Error(
      `Invalid duration for ${fileName}: expected a positive integer in seconds`,
    );
  }
  return duration;
}

function normalizeDescription(value) {
  if (typeof value !== 'string') {
    return undefined;
  }

  const trimmed = value.trim();
  return trimmed.length > 0 ? trimmed : undefined;
}

async function ensureFileExists(filePath) {
  try {
    await access(filePath);
  } catch {
    throw new Error(`Audio file not found: ${filePath}`);
  }
}

async function loadMetadataFile(metadataPath) {
  const raw = await readFile(metadataPath, 'utf8');
  const parsed = JSON.parse(raw);

  if (!Array.isArray(parsed)) {
    throw new Error('Metadata file must be a JSON array');
  }

  return parsed;
}

export function validateMetadataEntry(entry, index) {
  if (entry == null || typeof entry !== 'object' || Array.isArray(entry)) {
    throw new Error(`Invalid metadata entry at index ${index}`);
  }

  const fileName =
    typeof entry.fileName === 'string' ? entry.fileName.trim() : '';
  const documentId =
    typeof entry.documentId === 'string' ? entry.documentId.trim() : '';
  const title = typeof entry.title === 'string' ? entry.title.trim() : '';
  const category =
    typeof entry.category === 'string' ? entry.category.trim() : '';

  if (!fileName) {
    throw new Error(`Missing fileName at index ${index}`);
  }

  if (!title) {
    throw new Error(`Missing title for ${fileName}`);
  }

  if (!category) {
    throw new Error(`Missing category for ${fileName}`);
  }

  if (!VALID_CATEGORIES.includes(category)) {
    throw new Error(
      `Invalid category '${category}' for ${fileName}. Valid: ${VALID_CATEGORIES.join(', ')}`,
    );
  }

  return {
    fileName,
    documentId: documentId || undefined,
    title,
    category,
    duration: parseDuration(entry.duration, fileName),
    description: normalizeDescription(entry.description),
    coverImageUrl:
      typeof entry.coverImageUrl === 'string'
        ? entry.coverImageUrl.trim()
        : typeof entry.imageUrl === 'string'
        ? entry.imageUrl.trim()
        : undefined,
    coverVariant:
      typeof entry.coverVariant === 'string'
        ? entry.coverVariant.trim()
        : undefined,
    coverPromptVersion:
      typeof entry.coverPromptVersion === 'string'
        ? entry.coverPromptVersion.trim()
        : undefined,
    coverStatus:
      typeof entry.coverStatus === 'string'
        ? entry.coverStatus.trim()
        : undefined,
  };
}

export async function processEntry(audioDirectory, entry, overwrite, deps = {}) {
  const {
    checkFile = ensureFileExists,
    upload = uploadAudioToCloudflare,
    register = createSessionDocument,
    rollback = deleteAudioFromCloudflare,
  } = deps;

  const absoluteFilePath = path.resolve(audioDirectory, entry.fileName);
  await checkFile(absoluteFilePath);

  const uploadResult = await upload(absoluteFilePath);

  try {
    const firestoreResult = await register({
      documentId: entry.documentId,
      title: entry.title,
      description: entry.description,
      category: entry.category,
      duration: entry.duration,
      audioUrl: uploadResult.publicUrl,
      coverImageUrl: entry.coverImageUrl,
      coverVariant: entry.coverVariant,
      coverPromptVersion: entry.coverPromptVersion,
      coverStatus: entry.coverStatus,
      overwrite,
    });

    return {
      ...formatResult(entry, 'success'),
      documentId: firestoreResult.id,
      audioUrl: uploadResult.publicUrl,
      objectKey: uploadResult.objectKey,
    };
  } catch (firestoreError) {
    const r2Key = uploadResult.objectKey;
    console.warn(`[Bulk] Firestore failed for ${entry.fileName}. Rolling back R2: ${r2Key}`);
    try {
      await rollback(r2Key);
      console.warn(`[Bulk] R2 rollback successful for ${entry.fileName}.`);
      firestoreError.rollback = 'success';
    } catch (r2Error) {
      console.error(`[Bulk] DOUBLE FAILURE for ${entry.fileName}: ${r2Error.message}`);
      firestoreError.rollback = 'failed';
      firestoreError.rollbackError = r2Error.message;
      firestoreError.orphanAsset = r2Key;
    }

    throw firestoreError;
  }
}

async function maybeWriteReport(reportPath, report) {
  if (!reportPath) {
    return;
  }

  const absoluteReportPath = path.resolve(reportPath);
  await writeFile(absoluteReportPath, JSON.stringify(report, null, 2));
}

async function main() {
  const { args, force, error } = parseCommonArgs(process.argv.slice(2));

  if (error) {
    throw new Error(error);
  }

  const audioDirectory = path.resolve(requireArg(args, 'audio-dir'));
  const metadataPath = path.resolve(requireArg(args, 'metadata'));
  const reportPath = args.report?.trim();

  const rawEntries = await loadMetadataFile(metadataPath);
  const entries = [];
  const failures = [];

  rawEntries.forEach((entry, index) => {
    try {
      entries.push(validateMetadataEntry(entry, index));
    } catch (e) {
      failures.push({
        fileName: entry?.fileName || `unnamed_at_${index}`,
        title: entry?.title || 'Unknown',
        status: 'failed',
        error: e.message,
      });
    }
  });

  const successes = [];

  for (const entry of entries) {
    try {
      const result = await processEntry(audioDirectory, entry, force);
      successes.push(result);
    } catch (error) {
      const message =
        error instanceof Error ? error.message : 'Unknown import error';

      failures.push({
        ...formatResult(entry, 'failed', message),
        ...(error.rollback ? { rollback: error.rollback } : {}),
        ...(error.rollbackError ? { rollbackError: error.rollbackError } : {}),
        ...(error.orphanAsset ? { orphanAsset: error.orphanAsset } : {}),
      });
    }
  }

  const report = {
    ok: failures.length === 0,
    audioDirectory,
    metadataPath,
    total: rawEntries.length,
    successCount: successes.length,
    failureCount: failures.length,
    successes,
    failures,
  };

  await maybeWriteReport(reportPath, report);
  
  const allResults = [...successes, ...failures];
  printSummary(allResults);

  if (failures.length > 0) {
    process.exitCode = 1;
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
        },
        null,
        2,
      ),
    );
    process.exitCode = 1;
  });
}

import { readFile } from 'node:fs/promises';
import path from 'node:path';

import { PutObjectCommand, S3Client } from '@aws-sdk/client-s3';

import './load_local_env.mjs';

function looksLikeUrl(value) {
  return /^https?:\/\//i.test(value);
}

function requireEnv(name) {
  const value = process.env[name]?.trim();
  if (!value) {
    throw new Error(`Missing required env var: ${name}`);
  }
  return value;
}

function requireCredentialEnv(name) {
  const value = requireEnv(name);

  if (looksLikeUrl(value)) {
    throw new Error(
      `${name} looks like a URL, not an R2 credential. ` +
        'Use the R2 API token value from Cloudflare, not the endpoint/public URL.',
    );
  }

  return value;
}

function getContentType(filePath) {
  const extension = path.extname(filePath).toLowerCase();

  switch (extension) {
    case '.png':
      return 'image/png';
    case '.jpg':
    case '.jpeg':
      return 'image/jpeg';
    case '.webp':
      return 'image/webp';
    case '.mp3':
      return 'audio/mpeg';
    case '.wav':
      return 'audio/wav';
    case '.m4a':
      return 'audio/mp4';
    case '.aac':
      return 'audio/aac';
    case '.ogg':
      return 'audio/ogg';
    default:
      return 'application/octet-stream';
  }
}

function sanitizeFileName(fileName) {
  return fileName
    .normalize('NFD')
    .replace(/[\u0300-\u036f]/g, '')
    .replace(/[^a-zA-Z0-9._-]+/g, '-')
    .replace(/-+/g, '-')
    .replace(/^-|-$/g, '')
    .toLowerCase();
}

function buildObjectKey(filePath) {
  const prefix = process.env.CLOUDFLARE_R2_KEY_PREFIX?.trim() || 'sessions';
  const fileName = sanitizeFileName(path.basename(filePath));
  const timestamp = new Date().toISOString().replace(/[:.]/g, '-');

  return `${prefix}/${timestamp}-${fileName}`;
}

function createR2Client() {
  const accountId = requireEnv('CLOUDFLARE_R2_ACCOUNT_ID');
  const accessKeyId = requireCredentialEnv('CLOUDFLARE_R2_ACCESS_KEY_ID');
  const secretAccessKey = requireCredentialEnv(
    'CLOUDFLARE_R2_SECRET_ACCESS_KEY',
  );

  return new S3Client({
    region: 'auto',
    endpoint: `https://${accountId}.r2.cloudflarestorage.com`,
    forcePathStyle: true,
    credentials: {
      accessKeyId,
      secretAccessKey,
    },
  });
}

function getPublicBaseUrl() {
  const publicBaseUrl = requireEnv('CLOUDFLARE_R2_PUBLIC_BASE_URL').replace(
    /\/+$/,
    '',
  );

  if (!looksLikeUrl(publicBaseUrl)) {
    throw new Error(
      'CLOUDFLARE_R2_PUBLIC_BASE_URL must be an HTTPS base URL for published assets.',
    );
  }

  return publicBaseUrl;
}

export async function uploadFileToCloudflare(filePath, objectKey) {
  const client = createR2Client();
  const bucket = requireEnv('CLOUDFLARE_R2_BUCKET');
  const publicBaseUrl = getPublicBaseUrl();
  const body = await readFile(filePath);

  await client.send(
    new PutObjectCommand({
      Bucket: bucket,
      Key: objectKey,
      Body: body,
      ContentType: getContentType(filePath),
      CacheControl: 'public, max-age=31536000, immutable',
    }),
  );

  return {
    objectKey,
    publicUrl: `${publicBaseUrl}/${objectKey}`,
  };
}

export async function uploadAudioToCloudflare(filePath) {
  const objectKey = buildObjectKey(filePath);
  return uploadFileToCloudflare(filePath, objectKey);
}

// P1 #2 — Cleanup de assets huérfanos
export async function deleteAudioFromCloudflare(objectKey) {
  const { DeleteObjectCommand } = await import('@aws-sdk/client-s3');
  const client = createR2Client();
  const bucket = requireEnv('CLOUDFLARE_R2_BUCKET');

  await client.send(
    new DeleteObjectCommand({
      Bucket: bucket,
      Key: objectKey,
    }),
  );
}

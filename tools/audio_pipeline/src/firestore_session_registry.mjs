import admin from 'firebase-admin';

import './load_local_env.mjs';

function requireEnv(name) {
  const value = process.env[name]?.trim();
  if (!value) {
    throw new Error(`Missing required env var: ${name}`);
  }
  return value;
}

function getFirebaseApp() {
  if (admin.apps.length > 0) {
    return admin.app();
  }

  const projectId = requireEnv('FIREBASE_PROJECT_ID');
  const clientEmail = requireEnv('FIREBASE_CLIENT_EMAIL');
  const privateKey = requireEnv('FIREBASE_PRIVATE_KEY').replace(/\\n/g, '\n');

  return admin.initializeApp({
    credential: admin.credential.cert({
      projectId,
      clientEmail,
      privateKey,
    }),
  });
}

function normalizeDescription(description) {
  if (description == null) {
    return null;
  }

  const trimmed = description.trim();
  return trimmed.length > 0 ? trimmed : null;
}

export async function createSessionDocument({
  documentId,
  title,
  description,
  category,
  duration,
  audioUrl,
  coverImageUrl,
  coverVariant,
  coverPromptVersion,
  coverStatus,
  overwrite = false,
}) {
  const app = getFirebaseApp();
  const db = admin.firestore(app);
  const collectionName = process.env.FIRESTORE_COLLECTION?.trim() || 'sessions';
  const cleanDescription = normalizeDescription(description);

  const documentData = {
    title,
    category,
    // Canonical fields as read by Flutter app
    // firestore_audio_repository.dart:86
    durationSeconds: duration,
    audioSource: audioUrl,
    ...(coverImageUrl ? { coverImageUrl } : {}),
    ...(coverVariant ? { coverVariant } : {}),
    ...(coverPromptVersion ? { coverPromptVersion } : {}),
    ...(coverStatus ? { coverStatus } : {}),
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
    isOffline: false,
    isPremium: false,
    ...(cleanDescription ? { description: cleanDescription } : {}),
  };

  const collectionRef = db.collection(collectionName);
  const documentRef = documentId
    ? collectionRef.doc(documentId)
    : collectionRef.doc();

  // P1 #1 — Evitar sobrescritura accidental (Atomic check)
  try {
    if (overwrite) {
      // Si se pide sobrescribir, usamos set con merge
      await documentRef.set(documentData, { merge: true });
    } else {
      // Si no, usamos create() que falla atómicamente si el doc existe
      await documentRef.create(documentData);
    }
  } catch (error) {
    // Código 6 es ALREADY_EXISTS en el SDK de Node.js de Firestore
    if (error.code === 6 || error.message?.toLowerCase().includes('already exists')) {
      throw new Error(
        `Session ID already exists: ${documentRef.id}. Use --update flag to explicitly overwrite.`,
      );
    }
    throw error;
  }

  return {
    id: documentRef.id,
    collection: collectionName,
    data: documentData,
  };
}

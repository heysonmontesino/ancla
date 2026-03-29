import admin from 'firebase-admin';

import { env } from './env.js';

let firebaseApp: admin.app.App | null = null;

export function getFirebaseAdminApp() {
  if (firebaseApp) {
    return firebaseApp;
  }

  firebaseApp = admin.initializeApp({
    credential: admin.credential.cert({
      projectId: env.FIREBASE_PROJECT_ID,
      clientEmail: env.FIREBASE_CLIENT_EMAIL,
      privateKey: env.FIREBASE_PRIVATE_KEY,
    }),
  });

  return firebaseApp;
}

export async function verifyFirebaseIdToken(idToken: string) {
  const app = getFirebaseAdminApp();
  return admin.auth(app).verifyIdToken(idToken);
}

import { createSessionDocument } from './firestore_session_registry.mjs';

const BASE_URL = 'https://pub-a8cf04659e0449f09c2dbe7f41598be6.r2.dev';

const UPDATES = [
  {
    documentId: 'soltar_el_dia',
    title: 'Soltar el día',
    category: 'sleep',
    duration: 600, // 10 min approx, verified from earlier logs
    audioUrl: `${BASE_URL}/soltar_el_dia.mp3`,
    coverImageUrl: `${BASE_URL}/covers/harmonia/soltar_el_dia/v4-a.png`,
    coverVariant: 'v4-a',
    coverStatus: 'published',
  },
  {
    documentId: 'reset_en_90_segundos',
    title: 'Reset en 90 segundos',
    category: 'stress',
    duration: 90,
    audioUrl: `${BASE_URL}/reset_en_90_segundos.mp3`,
    coverImageUrl: `${BASE_URL}/covers/harmonia/reset_en_90_segundos/v4-a.png`,
    coverVariant: 'v4-a',
    coverStatus: 'published',
  },
  {
    documentId: 'el_suspiro_fisiologico',
    title: 'El Suspiro Fisiológico',
    category: 'anxiety',
    duration: 180, // approx
    audioUrl: `${BASE_URL}/el_suspiro_fisiologico.mp3`,
    coverImageUrl: `${BASE_URL}/covers/harmonia/el_suspiro_fisiologico/v4-a.png`,
    coverVariant: 'v4-a',
    coverStatus: 'published',
  },
  {
    documentId: 'x0YU9KvEPYovRJ460LaD',
    title: 'Enfoque Profundo (Beta)',
    category: 'focus',
    duration: 300,
    audioUrl: `${BASE_URL}/x0YU9KvEPYovRJ460LaD.mp3`,
    coverImageUrl: `${BASE_URL}/covers/harmonia/x0YU9KvEPYovRJ460LaD/v4-a.png`,
    coverVariant: 'v4-a',
    coverStatus: 'published',
  }
];

async function main() {
  console.log('[Harmonia V4] Starting controlled replacement...');
  
  for (const session of UPDATES) {
    console.log(`[Harmonia V4] Patching session: ${session.documentId} (${session.title})`);
    try {
      const result = await createSessionDocument({
        ...session,
        overwrite: true,
      });
      console.log(`[Harmonia V4] ✅ Success: ${result.id}`);
    } catch (error) {
      console.error(`[Harmonia V4] ❌ Failed to patch ${session.documentId}:`, error.message);
    }
  }
}

main().catch(console.error);

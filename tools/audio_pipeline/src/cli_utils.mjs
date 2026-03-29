export const VALID_CATEGORIES = ['anxiety', 'stress', 'sleep', 'focus', 'mood'];

export function parseCommonArgs(argv) {
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

  const force = args.force === true || args.update === true;
  const category = args.category?.trim();
  const durationRaw = args.duration?.trim();
  
  if (args.category !== undefined) {
    const cat = String(args.category).trim();
    if (!VALID_CATEGORIES.includes(cat)) {
      return { error: `Invalid category '${cat}'. Valid values: ${VALID_CATEGORIES.join(', ')}` };
    }
  }

  let durationSeconds = undefined;
  if (durationRaw) {
    const num = Number(durationRaw);
    if (!Number.isInteger(num) || num <= 0) {
      return { error: '--duration must be a positive integer in seconds' };
    }
    durationSeconds = num;
  }

  return { 
    args,
    force, 
    category, 
    durationSeconds,
    error: null 
  };
}

export function formatResult(item, status, error) {
  return {
    id: item.documentId || item.id,
    title: item.title,
    status: status === 'success' ? 'success' : 'failed',
    ...(error ? { error } : {}),
  };
}

export function printSummary(results) {
  const successes = results.filter(r => r.status === 'success');
  const failures = results.filter(r => r.status === 'failed');

  console.log('\n──────────────────────────────────────────');
  console.log(' PIPELINE SUMMARY');
  console.log('──────────────────────────────────────────');
  console.log(` ✅ SUCCESS: ${successes.length}`);
  console.log(` ❌ FAILED:  ${failures.length}`);
  console.log('──────────────────────────────────────────\n');

  if (failures.length > 0) {
    console.table(failures.map(f => ({
      Title: f.title,
      Error: f.error,
      Rollback: f.rollback || 'N/A'
    })));
  }
}

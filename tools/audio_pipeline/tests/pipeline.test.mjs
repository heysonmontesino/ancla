import { test, describe } from 'node:test';
import assert from 'node:assert';
import { VALID_CATEGORIES } from '../src/cli_utils.mjs';
import { validateMetadataEntry, processEntry } from '../src/bulk_import_audio_and_register.mjs';

describe('Audio Pipeline Integrity Tests', () => {
  
  // 1. Validación de Categorías (Antes de red)
  describe('Categoría y Validación', () => {
    test('Acepta categorías válidas', () => {
      const entry = { fileName: 'test.mp3', title: 'Test', category: 'anxiety', duration: 10 };
      const valid = validateMetadataEntry(entry, 0);
      assert.strictEqual(valid.category, 'anxiety');
    });

    test('Falla preventivamente con categoría inválida', () => {
      const entry = { fileName: 'test.mp3', title: 'Test', category: 'unknown', duration: 10 };
      assert.throws(() => validateMetadataEntry(entry, 0), /Invalid category/);
    });
  });

  // 2. Control de Colisiones y Flags (Firestore)
  describe('Control de Colisiones', () => {
    const mockEntry = { fileName: 'test.mp3', category: 'mood', title: 'Test', duration: 10, documentId: 'exists-01' };
    const mockDeps = {
      checkFile: async () => {},
      upload: async () => ({ objectKey: 'k', publicUrl: 'u' }),
      rollback: async () => {}
    };

    test('Falla si el ID existe y no hay flag de overwrite', async () => {
      const registerFails = async () => { 
        const err = new Error('Session ID already exists');
        err.code = 6;
        throw err;
      };

      await assert.rejects(
        processEntry('/tmp', mockEntry, false, { ...mockDeps, register: registerFails }),
        /already exists/
      );
    });

    test('Permite overwrite si el flag está presente', async () => {
      const registerSucceeds = async () => ({ id: 'exists-01' });
      const result = await processEntry('/tmp', mockEntry, true, { ...mockDeps, register: registerSucceeds });
      assert.strictEqual(result.status, 'success');
      assert.strictEqual(result.documentId, 'exists-01');
    });
  });

  // 3. Trazabilidad de Fallos y Rollback (R2)
  describe('Trazabilidad y Rollback', () => {
    const mockEntry = { fileName: 'test.mp3', category: 'sleep', title: 'Test', duration: 10 };
    const mockDeps = {
      checkFile: async () => {},
      upload: async () => ({ objectKey: 'audio/test.mp3', publicUrl: 'url' }),
      register: async () => { throw new Error('Firestore Down'); }
    };

    test('Reporta rollback success cuando Firestore falla pero R2 se limpia', async () => {
      let rollbackCalled = false;
      const deps = { 
        ...mockDeps, 
        rollback: async (key) => { 
          if (key === 'audio/test.mp3') rollbackCalled = true; 
        } 
      };

      try {
        await processEntry('/tmp', mockEntry, false, deps);
      } catch (err) {
        assert.strictEqual(err.message, 'Firestore Down');
        assert.strictEqual(err.rollback, 'success');
        assert.ok(rollbackCalled);
      }
    });

    test('Reporta rollback failed y orphanAsset cuando R2 no se puede limpiar', async () => {
      const deps = { 
        ...mockDeps, 
        rollback: async () => { throw new Error('R2 Timeout'); } 
      };

      try {
        await processEntry('/tmp', mockEntry, false, deps);
      } catch (err) {
        assert.strictEqual(err.rollback, 'failed');
        assert.strictEqual(err.rollbackError, 'R2 Timeout');
        assert.strictEqual(err.orphanAsset, 'audio/test.mp3');
      }
    });
  });
});

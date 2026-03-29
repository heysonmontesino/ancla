# Audio Pipeline

Pipeline minimo para:

1. subir un archivo de audio a Cloudflare R2
2. registrar su metadata en Cloud Firestore
3. importar una carpeta completa de audios en lote

## Variables requeridas

El pipeline puede cargar variables automaticamente desde:

- `tools/audio_pipeline/.env`

Tambien mantiene compatibilidad con variables ya cargadas en `process.env`.

Pasos recomendados:

1. copiar `.env.example` a `.env`
2. completar credenciales reales de Cloudflare R2 y Firebase Admin
3. ejecutar el script sin necesidad de exportar variables manualmente en cada corrida

## Uso

```bash
npm install
node src/upload_audio_and_register.mjs \
  --file /ruta/audio.mp3 \
  --title "Respiracion para calmarte" \
  --category anxiety \
  --duration 180 \
  --description "Sesion breve de regulacion"
```

## Bulk import

Formato recomendado del metadata file: `JSON`

Se usa JSON porque:

- evita dependencias extra para parsear CSV
- soporta campos opcionales sin ambiguedad
- es mas facil de validar y extender

Formato esperado:

```json
[
  {
    "fileName": "respiracion-calma.mp3",
    "title": "Respiracion para calmarte",
    "category": "anxiety",
    "duration": 180,
    "description": "Sesion breve de regulacion"
  },
  {
    "fileName": "pausa-suave.mp3",
    "title": "Pausa suave",
    "category": "stress",
    "duration": 240
  }
]
```

Uso:

```bash
npm run bulk-import -- \
  --audio-dir /ruta/audios \
  --metadata /ruta/metadata.json \
  --report /ruta/reporte.json
```

Salida:

- `successes`: imports correctos con `documentId` y `audioUrl`
- `failures`: imports fallidos con el error concreto
- el proceso termina con exit code `1` si hubo fallos

## Protección contra sobrescrituras

Por seguridad, el pipeline falla si intentas registrar un `documentId` que ya existe en Firestore. Esto evita la mutación accidental de metadatos en producción.

Para permitir una sobrescritura explícita, usa cualquiera de estos flags:

- `--update`
- `--force`

Ejemplo:

```bash
node src/upload_audio_and_register.mjs --id mi-id-fijo --update ...
```

## Primera corrida recomendada

Empieza con solo 2 audios para validar el flujo completo antes de cargar mas contenido.

Comando:

```bash
cd /Users/heysonmontesino/Documents/app_pap_respiracion/tools/audio_pipeline

npm run bulk-import -- \
  --audio-dir /RUTA/DE/TUS/AUDIOS \
  --metadata /Users/heysonmontesino/Documents/app_pap_respiracion/tools/audio_pipeline/examples/bulk_import_sample.json \
  --report /Users/heysonmontesino/Documents/app_pap_respiracion/tools/audio_pipeline/examples/bulk_import_report.json
```

Usa este ejemplo solo cuando en la carpeta de audios existan exactamente:

- `respiracion-calma.mp3`
- `pausa-suave.mp3`

## Categorías Válidas
---
El pipeline valida estrictamente que la categoría pertenezca al conjunto soportado por la aplicación Flutter. Si se usa un valor distinto, el import fallará preventivamente.

**Valores permitidos:**
- `anxiety` (Ansiedad)
- `stress` (Estrés)
- `sleep` (Sueño)
- `focus` (Foco)
- `mood` (Ánimo)

Si necesitas añadir una nueva categoría, recuerda actualizarla tanto en el enum `SessionCategory` de Flutter como en la constante `VALID_CATEGORIES` de `cli_utils.mjs`.

## Documento Firestore
---
Colección por defecto: `sessions`

Campos principales:
- `title`
- `description` (opcional)
- `category` (validada)
- `durationSeconds` (mapeado desde `duration`)
- `audioSource` (mapeado desde la URL de R2)
- `createdAt` (server timestamp)
- `isOffline` (default false)
- `isPremium` (default false)

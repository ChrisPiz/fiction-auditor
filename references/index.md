# Indexado del manuscrito

Construye índices una vez por manuscrito. Re-genera solo si `manuscript.txt` cambió. Costo build: ~1-5s en 150k palabras. Costo query post-index: sub-ms.

## Artefactos en `$WORK/`

| Archivo | Propósito | Regenera si |
|---|---|---|
| `manuscript.txt` | Texto plano fuente | Original cambió |
| `meta.json` | hash, lang, wordcount, mtime original | Cualquier cambio |
| `chapters.tsv` | `línea<TAB>título_capítulo` | manuscript cambió |
| `wordcount.txt` | Total cacheado | manuscript cambió |
| `fts5.db` | SQLite FTS5 indexado | manuscript cambió |
| `entities.tsv` | Candidatos entidad (ver entities.md) | bajo demanda |
| `timeline.tsv` | Marcadores temporales | bajo demanda |
| `threads.tsv` | Hilos sin resolver | bajo demanda |

## Schema FTS5

Indexamos por **párrafo** (no por línea suelta) — un párrafo es la unidad semántica natural. Cada párrafo registra primera línea para citas exactas.

```sql
CREATE VIRTUAL TABLE paragraphs USING fts5(
  body,
  tokenize = 'unicode61 remove_diacritics 2'
);

CREATE TABLE para_meta (
  rowid INTEGER PRIMARY KEY,  -- mismo rowid que paragraphs
  start_line INTEGER NOT NULL,
  end_line INTEGER NOT NULL,
  chapter TEXT
);

CREATE INDEX idx_meta_line ON para_meta(start_line);
```

`tokenize='unicode61 remove_diacritics 2'` normaliza acentos: `MATCH 'anos'` encuentra "años". `MATCH 'marta'` encuentra "Marta", "MARTA". Esencial para español.

## Build

`scripts/index.sh` parsea `manuscript.txt` línea a línea, agrupa en párrafos (separados por línea en blanco), inserta en FTS5 con `start_line` y mapea cada párrafo a su capítulo via `chapters.tsv`. Idempotente: si `fts5.db` existe y mtime > manuscript.txt, salta.

Para manuscritos grandes activa `PRAGMA journal_mode=OFF; PRAGMA synchronous=OFF;` durante el build (luego restaura). Diferencia: 8s vs 45s en 200k palabras.

## Queries

Wrapper estándar en `scripts/fts-query.sh`:

```bash
bash scripts/fts-query.sh "$WORK" 'TÉRMINO' [LIMIT]
```

Internamente:

```sql
SELECT
  pm.start_line,
  pm.chapter,
  snippet(paragraphs, 0, '<<', '>>', '…', 16) AS hit,
  bm25(paragraphs) AS score
FROM paragraphs
JOIN para_meta pm ON pm.rowid = paragraphs.rowid
WHERE paragraphs MATCH ?
ORDER BY score
LIMIT ?;
```

`snippet()` devuelve contexto ±16 tokens con el match marcado. `bm25()` ordena por relevancia (menor = mejor, por convención SQLite).

## Búsqueda con frase exacta

```bash
bash scripts/fts-query.sh "$WORK" '"se cumplían diez años"'
```

Comillas dobles fuerzan match contiguo. Útil cuando el escritor pregunta por una cita literal que recuerda parcialmente.

## Búsqueda con NEAR

```bash
bash scripts/fts-query.sh "$WORK" 'NEAR(Elena edad, 20)'
```

`NEAR(A B, N)` exige ambos términos a ≤N tokens. Crítico para auditoría de atributos: "Elena" cerca de "años" o "edad" filtra ruido.

## Búsqueda con AND/OR

```bash
'Elena AND (edad OR años OR cumpleaños)'
```

FTS5 soporta booleanos completos. Úsalo en lugar de pipes con `grep` cuando el query es compuesto.

## Mapeo línea → capítulo

`chapters.tsv` formato:

```
12	Capítulo 1: El despertar
1843	Capítulo 2: La carta
3502	Capítulo 3: Vuelta a casa
```

Lookup O(log n) con awk one-liner — ya implementado en `scripts/chapter-of-line.sh`:

```bash
bash scripts/chapter-of-line.sh "$WORK" 2105
# → Capítulo 2: La carta
```

Úsalo SIEMPRE que reportes una cita. Sin esto las citas son ilegibles.

## Detección de capítulos

Patrón base (ES + EN combinado):

```
^(#+\s*)?(Cap[íi]tulo|Chapter|CAP[ÍI]TULO|CHAPTER)\s+([0-9IVXLCDM]+|[A-Za-zÀ-ÿ]+)
```

Acepta:
- Markdown: `# Capítulo 1`, `## Chapter II`
- Plano: `Capítulo 1: Título`, `CHAPTER ONE`
- Numerales arábigos, romanos, escritos

Si 0 hits, el manuscrito no tiene marcadores claros. `chapters.tsv` queda vacío. El reporte avisa al usuario que las citas usarán solo número de línea.

## Re-indexado

Trigger:

```bash
HASH_NOW=$(shasum -a 256 "$WORK/manuscript.txt" | cut -d' ' -f1)
HASH_PREV=$(jq -r .content_hash "$WORK/meta.json" 2>/dev/null)
[ "$HASH_NOW" != "$HASH_PREV" ] && bash scripts/index.sh "$WORK"
```

Hash de contenido es más robusto que mtime. mtime puede no actualizarse si el escritor edita en otro sistema y rsync preserva timestamps.

## Cuándo NO indexar

- Manuscrito <5k palabras: `grep` directo es suficiente. `index.sh` lo detecta y salta FTS5 (mantiene solo `chapters.tsv` + `wordcount.txt`).
- Una sola pregunta puntual: si el usuario va a hacer 1 query y cerrar, el costo del build no se amortiza. Pregúntale: "Vas a hacer varias consultas? Si sí, indexo (1-5s). Si es una sola, hago grep directo."

Por defecto, **indexa**. La fricción es mínima y el resto del skill asume FTS5 disponible.

![Narrative Continuity — auditor de continuidad narrativa para manuscritos](assets/header.png)

# Narrative Continuity

Skill de Claude Code / Anthropic que audita manuscritos de novela **existentes** para continuidad, consistencia de personajes, coherencia temporal e hilos narrativos sin resolver. Responde con **citas exactas** (capítulo + línea + texto verbatim). Nunca escribe prosa por ti — es un auditor de solo lectura.

Funciona con manuscritos en español e inglés. Soporta sagas multi-volumen y manuscritos grandes (>500k palabras) vía SQLite FTS5 + subagentes paralelos.

---

## ¿Qué hace?

- **Búsqueda con citas:** todas las menciones de un personaje, lugar u objeto, con texto verbatim + capítulo + línea.
- **Character bible automatizado:** extrae personajes, lugares y objetos del texto. Clasifica por dialog tags, relaciones familiares, sujeto de verbo. Genera scaffold editable.
- **Auditoría de atributos:** detecta contradicciones explícitas (edad, ojos, pelo, altura, profesión, relaciones). Atribuye claims al dueño correcto (filtra "ojos de Elena" cuando Marta también está en el contexto). Excluye flashbacks ("cuando tenía 12 años") del audit principal.
- **Línea temporal:** extrae 8 tipos de marcador (fechas absolutas, saltos relativos, días de la semana, estaciones, edades, próximos días, etc.) en español e inglés.
- **Hilos narrativos:** detecta preguntas abiertas, promesas, personajes huérfanos (freq baja con dialog tag), objetos introducidos con énfasis y nunca usados (Chekhov's gun no disparada).
- **Mapeo línea → capítulo:** lookup O(log n) para citas siempre legibles.

## ¿Qué NO hace?

- Escribir, generar, continuar o reescribir prosa
- Sugerir tramas, personajes o desarrollos
- Criticar calidad de escritura
- Reemplazar a un editor humano para feedback de desarrollo

Es un **auditor literal**, no un colaborador creativo.

---

## Instalación

### Claude Code (CLI)

```bash
mkdir -p ~/.claude/skills
git clone https://github.com/ChrisPiz/narrative-continuity.git ~/.claude/skills/narrative-continuity
```

Disponible inmediatamente — activación automática por triggers en cualquier sesión.

### Claude Desktop / Claude.ai (web)

Claude Desktop **no** carga skills desde filesystem. Los skills se suben como ZIP vía la web:

1. Descarga el skill empaquetado: [`narrative-continuity.zip`](https://github.com/ChrisPiz/narrative-continuity/raw/main/narrative-continuity.zip)
   O genéralo localmente:
   O genéralo localmente con todos los módulos:
   ```bash
   git clone https://github.com/ChrisPiz/narrative-continuity.git
   cd narrative-continuity
   zip -r narrative-continuity.zip SKILL.md references scripts templates
   ```
2. Abre [claude.ai](https://claude.ai) → **Settings → Capabilities → Skills**
3. Click **Upload skill** y selecciona el ZIP
4. El skill queda disponible automáticamente en Claude Desktop (sincroniza desde la cuenta)

> **Nota:** la subida de skills personalizadas requiere plan Pro/Team/Enterprise. En plan Free solo están disponibles los skills oficiales de Anthropic.

### Dentro de un plugin propio de Claude Code

```bash
git clone https://github.com/ChrisPiz/narrative-continuity.git \
  ~/.claude/plugins/mi-plugin/skills/narrative-continuity
```

### Otros entornos (Copilot CLI, Gemini CLI, etc.)

El skill sigue el formato Anthropic Skills estándar (`SKILL.md` con frontmatter YAML + módulos en `references/` + scripts en `scripts/`). Cualquier harness compatible lo acepta sin modificación — copia el directorio completo al lugar donde tu harness busque skills.

---

## Activación

Se activa automáticamente cuando mencionas:

- Manuscrito, novela, capítulo, escena, story bible, character bible
- "¿Qué dije sobre [personaje/lugar]?"
- "Audita mi novela", "find inconsistencies in my book"
- Consistencia temporal, edad de personaje, parentescos
- "Construye character bible", "build character bible"
- "Mapa temporal", "¿la cronología cuadra?"
- "¿Qué quedó sin resolver?", hilos abiertos
- Apuntar a un archivo `.docx`, `.md`, `.txt`, `.rtf` o carpeta con varios

Activación manual en Claude Code: `/narrative-continuity`.

---

## Formatos soportados

| Formato | Conversor preferido | Fallback |
|---------|---------------------|----------|
| `.txt`, `.md` | `cp` directo | — |
| `.docx` | `pandoc` | `python-docx` |
| `.rtf` | `pandoc` | `textutil` (macOS) |
| Carpeta con varios | concatenación alfabética con marcadores `=== filename ===` | — |

Para Pages o Google Docs: exportar primero a Word o Markdown.

PDF no soportado — el OCR/extracción tiene demasiada pérdida para auditoría con citas exactas.

---

## Arquitectura

```
narrative-continuity/
├── SKILL.md                          # router + first contact
├── references/                       # módulos cargados bajo demanda
│   ├── prepare.md                    # workspace + conversión
│   ├── index.md                      # SQLite FTS5 + caches
│   ├── entities.md                   # extracción personajes/lugares/objetos
│   ├── timeline.md                   # marcadores temporales
│   ├── threads.md                    # hilos sin resolver
│   ├── consistency.md                # auditoría contradicciones
│   ├── query.md                      # respuestas con citas
│   ├── parallel.md                   # subagentes para sagas
│   └── patterns-bilingual.md         # regex ES/EN
├── scripts/                          # trabajo determinista
│   ├── prepare.sh                    # pipeline completo entrada→workspace
│   ├── index.sh                      # FTS5 + chapters.tsv + wordcount
│   ├── chapter-of-line.sh            # línea N → capítulo
│   ├── extract-entities.sh           # capitalización + dialog + relación + subj-verbo
│   ├── extract-timeline.sh           # marcadores cronológicos
│   ├── extract-threads.sh            # promesas + preguntas + huérfanos
│   ├── fts-query.sh                  # FTS5 wrapper con cap mapping
│   └── audit-attribute.sh            # cross-check atributos entidad
└── templates/
    ├── bible.md                      # scaffold character bible
    └── audit-report.md               # formato reporte final
```

### Workspace persistente por manuscrito

Cada manuscrito vive en su propio directorio derivado del SHA-1 de la ruta original. Workspace por defecto: `~/.narrative-continuity/<hash>/` (sobrevive reboots, edits y reinstalaciones del skill). Override con `NARRATIVE_HOME=/ruta` (ej. iCloud Drive para sync entre máquinas).

```
~/.narrative-continuity/<hash12>/
├── source.path                       # ruta original
├── manuscript.txt                    # versión normalizada actual
├── meta.json                         # hash, lang, words, mtime
├── chapters.tsv                      # línea<TAB>título_capítulo
├── wordcount.txt                     # cache word count
├── fts5.db                           # SQLite FTS5 (>5k palabras)
├── current → runs/<TS_más_reciente>/ # symlink al último run
├── runs/
│   ├── 2026-05-03T16-30-00Z/         # snapshot timestamped
│   │   ├── meta.json
│   │   ├── entities.tsv
│   │   ├── timeline.tsv
│   │   ├── threads.tsv
│   │   ├── audit-summary.txt         # output de --all si se usó
│   │   └── diff-from-<TS>.md         # generado por audit-diff.sh
│   └── …
└── audit-log.tsv                     # append-only: timestamp, words,
                                      # entities, timeline, unresolved,
                                      # hard, soft, drift, note
```

Si re-ejecutas la auditoría y el original es más nuevo, se re-convierte y re-indexa automáticamente. Si no, reusa los caches. Cada `audit-run.sh` crea un nuevo snapshot en `runs/<TS>/` para que puedas comparar versiones del manuscrito a lo largo del tiempo.

### Modo recurrente

```bash
# Run completo + snapshot + log
bash scripts/audit-run.sh /ruta/manuscrito.docx
bash scripts/audit-run.sh /ruta/manuscrito.docx --all                       # con audit-attribute
bash scripts/audit-run.sh /ruta/manuscrito.docx --note "draft 5 pre-beta"

# Diff vs run anterior (auto: último vs penúltimo)
bash scripts/audit-diff.sh "$WORK"

# Tendencias
column -t -s$'\t' < "$WORK/audit-log.tsv"
```

Patrón típico para escritor activo: ejecutar `audit-run.sh` cada vez que termines un capítulo o sesión, leer el `diff-from-*.md` del último run para ver qué cambió. Ver `references/recurrence.md` para más patrones (cron diario, pre-feedback de editor, multi-volumen).

### Indexación

Para manuscritos pequeños (<5k palabras) usa `grep` directo — overhead de FTS5 no se amortiza.

Para manuscritos típicos (>5k palabras) construye **SQLite FTS5** con `tokenize='unicode61 remove_diacritics 2'`:

- Búsquedas sub-ms incluso en 500k palabras
- Normalización automática de acentos (`anos` encuentra `años`)
- Operadores booleanos (`AND`, `OR`, `NEAR(A B, N)`)
- Snippet con marcadores `<<>>` y scoring bm25 por relevancia
- Indexa por **párrafo** (unidad semántica), no por línea — primera línea registrada para citas

Build una vez (~1-5s en 150k palabras). Idempotente: salta si `fts5.db` mtime > `manuscript.txt`.

### Extracción de entidades

Cuatro señales combinadas, sin LLM:

1. **Frecuencia de palabras capitalizadas** (filtra stopwords + sentence-initial)
2. **Dialog tags**: "—dijo X", "X said" → alta precisión para personajes
3. **Relaciones familiares**: "su madre Elena", "her mother Elena" → marca a Elena como personaje + registra parentesco
4. **Sujeto de verbo narrativo**: "Marta caminaba/abrió/sintió/dijo" → captura protagonistas que no tienen dialog tags

Clasifica como `character` / `place` / `object` / `unknown` por jerarquía. Genera `entities.tsv` ordenado por frecuencia.

### Auditoría de atributos

Para cada match de un atributo (edad, ojos, pelo, etc.):

1. Identifica la oración que lo contiene
2. Encuentra todos los nombres en esa oración
3. Resuelve el dueño:
   - Si hay genitivo posterior (`X de NOMBRE` / `X of NAME`), NOMBRE manda
   - Si no, dueño = nombre más cercano al match en la oración
4. Detecta flashback (`cuando tenía X años`, `years ago`) y lo separa del audit principal
5. Agrupa valores por dueño y clasifica severidad:
   - `hard`: incompatibles (ej. 34 vs 36 años con <1 año narrativo)
   - `soft`: compatibles con paso del tiempo
   - `drift`: variación menor de descripción
   - `ok`: consistente

### Subagentes paralelos

Para sagas o auditoría holística en manuscritos >150k palabras, orquesta subagentes que reportan TSV estructurado. Estrategias:

- Por arco narrativo (un agente por acto)
- Por entidad (un agente por personaje principal a través de toda la novela)
- Por dimensión (entidades / cronología / hilos / cross-check) en paralelo

El agente principal agrega los TSVs y genera el reporte final usando `templates/audit-report.md`.

### Citas siempre verificables

- Toda respuesta cita el texto **palabra por palabra**, nunca paráfrasis
- Toda cita lleva número de línea + capítulo
- Inconsistencias se reportan con **ambas citas** en conflicto y ⚠️ / 🟡 / 🔵
- Limitaciones (pronombres, subtexto, prosa metafórica) se reportan honestamente

---

## Ejemplo de sesión

```
Tú:    Audita /Users/yo/novela.docx

Skill: ✓ Manuscrito listo: 87,432 palabras, 18 capítulos, 412 KB, idioma=es
       Primeros 3 capítulos:
         L12   Capítulo 1: El despertar
         L1843 Capítulo 2: La carta
         L3502 Capítulo 3: Vuelta a casa
       ¿Qué quieres revisar?

Tú:    ¿Qué he dicho sobre Elena?

Skill: Sobre Elena (madre de Marta): 7 menciones en 5 capítulos.

       Capítulo 1 — línea 5
       > Su madre Elena entró en la cocina sin tocar, como siempre.

       Capítulo 1 — línea 9
       > Los ojos verdes de Elena la miraban con preocupación.

       [...]

Tú:    ¿La edad de Marta es consistente?

Skill: 🟡 edad de Marta — 3 afirmaciones, severidad=soft

       L23 · Capítulo 2: La carta
         [34] > Marta tenía 34 años cuando empezó todo.
       L1843 · Capítulo 5: La carta
         [36] > Marta tenía ahora 36 años.
       L4502 · Capítulo 12: El faro
         [37] > —Tengo 37 —dijo Marta sin mirarlo.

       📜 1 referencia flashback (excluida):
         L31 · Capítulo 3
           [12] > Cuando tenía 12 años, su madre le contó...

       Δt narrativo entre primer y último: ~3 años.
       Diferencia: 3 años. Coherente.

Tú:    ¿Qué hilos quedaron sin cerrar?

Skill: 4 hilos sin resolver:

       🧵 PROMESA — Capítulo 3, línea 3402
       > "juró encontrarla antes del invierno"
       No detecté cierre.

       🧵 OBJETO — Capítulo 1, línea 450
       > "una pistola descansaba en el cajón..."
       Mencionado solo en Cap 1. Posible Chekhov's gun no disparada.

       [...]
```

---

## Limitaciones honestas

- **Pronombres no resueltos:** "Ella entró" tras "Elena llegó" probablemente refiere a Elena, pero el extractor no hace coreference. Pide confirmación si es relevante.
- **Inconsistencias implícitas:** subtexto, tono, atmósfera quedan fuera. Solo detecta contradicciones explícitas con citas directas.
- **Prosa muy metafórica:** falsos positivos en marcadores temporales ("hace mil años que no te veo"). Reporta el match crudo y deja al escritor juzgar.
- **Personajes referidos solo por descripción** ("el viejo del faro") no aparecen en el extractor.
- **Apodos:** "Marta" y "Martita" cuentan como entidades distintas. Regístralos en `aliases.tsv` para fusionarlos.
- **Manuscritos sin marcadores de capítulo:** las citas usan solo número de línea.
- **Cambios deliberados** (personaje envejece entre tomos, cambia profesión): regístralos en `exceptions.tsv` para que el audit los respete.

Reportar limitaciones aumenta confianza. El skill no infla certezas.

---

## Dependencias

Solo herramientas estándar:

- `bash`, `grep`, `awk`, `sed`, `wc`, `find`, `shasum`, `iconv`, `python3`
- **Crítico:** `sqlite3` con FTS5 (preinstalado en macOS y Linux modernos)
- **Recomendado:** `pandoc` (`brew install pandoc`) — el conversor más fiable
- **Opcional:** `ripgrep` (`brew install ripgrep`) — 5–10x más rápido que `grep`
- **Fallback `.docx`:** `python-docx` (`pip install --user python-docx`)
- **Fallback `.rtf` macOS:** `textutil` (preinstalado)

El skill **nunca instala dependencias en silencio** — si falta algo, pregunta antes.

---

## Contribuir

Reportes y PRs en https://github.com/ChrisPiz/narrative-continuity.

Para añadir un nuevo patrón regex (atributo, marcador temporal), edita `references/patterns-bilingual.md` (fuente única) y referencia desde el script consumidor. No dupliques regex en múltiples archivos.

---

## Licencia

MIT. Ver [LICENSE](LICENSE).

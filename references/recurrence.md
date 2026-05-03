# Auditoría recurrente

Carga este módulo cuando el usuario quiera correr la auditoría a lo largo del tiempo, ver tendencias, comparar runs, o usar el skill como compañero del proceso de escritura.

## Workspace persistente

Por defecto, el workspace vive en `~/.trama/<hash>/` (no `/tmp`). Sobrevive reboots, edits del manuscrito, y reinstalaciones del skill. Override con `TRAMA_HOME=/ruta` si el usuario quiere otro lugar (ej. iCloud Drive para sync entre máquinas).

## Layout

```
~/.trama/<hash>/
├── source.path                 # ruta del manuscrito original
├── manuscript.txt              # versión normalizada actual
├── meta.json                   # metadata actual
├── chapters.tsv                # cache capítulos actual
├── wordcount.txt               # cache word count actual
├── fts5.db                     # índice SQLite FTS5 actual
├── current → runs/<TS_más_reciente>/   # symlink al último run
├── runs/
│   ├── 2026-05-03T16-30-00Z/
│   │   ├── meta.json           # snapshot de meta en este momento
│   │   ├── entities.tsv        # snapshot
│   │   ├── timeline.tsv        # snapshot
│   │   ├── threads.tsv         # snapshot
│   │   ├── audit-summary.txt   # output de audit-attribute --all (si --all)
│   │   └── diff-from-<TS_anterior>.md   # generado por audit-diff
│   ├── 2026-05-04T09-15-00Z/
│   │   └── ...
│   └── ...
└── audit-log.tsv               # append-only: timestamp, words, entities,
                                # timeline, unresolved, hard, soft, drift, note
```

## Comandos

### Run completo (orquestado)

```bash
bash scripts/audit-run.sh /ruta/manuscrito.docx
bash scripts/audit-run.sh /ruta/manuscrito.docx --all                    # incluye audit-attribute --all
bash scripts/audit-run.sh /ruta/manuscrito.docx --note "draft 5 - revisión Capítulo 12"
```

`audit-run.sh` ejecuta el pipeline completo en una pasada:

1. `prepare.sh` → workspace + conversión
2. `index.sh` → FTS5 + chapters.tsv
3. `extract-entities.sh` → entities.tsv
4. `extract-timeline.sh` → timeline.tsv
5. `extract-threads.sh` → threads.tsv
6. (opcional) `audit-attribute.sh --all` → audit-summary.txt
7. Snapshot a `runs/<timestamp>/`
8. Update symlink `current/`
9. Append a `audit-log.tsv`

Sale con sumario:

```
WORK=/Users/x/.trama/abc123def456
RUN=.../runs/2026-05-03T16-30-00Z
TIMESTAMP=2026-05-03T16-30-00Z
WORDS=87432
ENTITIES=23
TIMELINE_MARKERS=87
UNRESOLVED_THREADS=12
HARD=1
SOFT=4
DRIFT=2
```

### Diff vs run anterior

```bash
bash scripts/audit-diff.sh "$WORK"
```

Auto-modo: compara último vs penúltimo. Genera `runs/<latest>/diff-from-<prev>.md` con secciones humanas:
- Entidades nuevas / desaparecidas
- Cambios de frecuencia (top 15)
- Hilos nuevos
- Hilos cerrados desde el último run
- Hilos aún sin resolver (persisten)
- Marcadores temporales nuevos

```bash
bash scripts/audit-diff.sh "$WORK" "$WORK/runs/<TS_A>" "$WORK/runs/<TS_B>"
```

Modo explícito: compara dos runs específicos (útil para "muéstrame qué cambió desde la versión que mandé al editor").

### Tendencias

```bash
column -t -s$'\t' < "$WORK/audit-log.tsv"
```

Lectura humana del log. O para gráficos rápidos:

```bash
awk -F'\t' 'NR>1 {print $1, $7}' "$WORK/audit-log.tsv"  # timestamp + hard count
```

## Patrones de uso

### Patrón 1: revisión por capítulo terminado

Cada vez que terminas un capítulo:

```bash
bash scripts/audit-run.sh /ruta/novela.docx --note "terminé Cap 12"
bash scripts/audit-diff.sh "$WORK"
```

Lee el diff. ¿Aparecieron hilos nuevos sin resolver? ¿Personajes nuevos sin desarrollo? ¿Cerraste promesas pendientes?

### Patrón 2: pre-feedback de editor

Antes de mandar a beta-readers:

```bash
bash scripts/audit-run.sh /ruta/novela.docx --all --note "v3 - pre-beta"
```

`--all` corre el audit completo. Lee `runs/<TS>/audit-summary.txt` y resuelve HARDs antes de enviar.

### Patrón 3: cron diario

Si escribes activamente todos los días, programa:

```bash
# crontab -e
0 23 * * * /bin/bash $HOME/.claude/skills/trama/scripts/audit-run.sh /ruta/novela.docx --note "auto-nightly"
```

Cada noche el log captura el estado. Por la mañana corres `audit-diff.sh` y ves qué cambió mientras dormías (útil si el manuscrito vive en Dropbox/iCloud y otros editores tocan).

Alternativa sin cron: usa el skill `/schedule` que ya está en el harness.

### Patrón 4: invocación desde Claude

Cuando el usuario diga "audita y compara con la última vez" o "qué cambió desde ayer":

1. Detecta el manuscrito (preguntar si no está claro)
2. `bash scripts/audit-run.sh "$SRC"` (sin `--all` si el usuario no pidió audit profundo)
3. `bash scripts/audit-diff.sh "$WORK"` (si hay >=2 runs)
4. Lee y reporta el `diff-*.md` al usuario, citando las secciones más relevantes

## Limpieza

Los runs ocupan ~50-200 KB cada uno (TSVs, no incluyen el manuscrito). En 1 año de runs diarios, ~50 MB. No es crítico, pero el usuario puede limpiar:

```bash
# Mantener solo últimos 30 runs
cd "$WORK/runs" && ls -1 | sort | head -n -30 | xargs rm -rf 2>/dev/null
```

El audit-log.tsv es append-only: se conserva siempre como historial completo aunque borres los runs detallados.

## Cómo este módulo se integra con SKILL.md

Cuando el usuario active triggers de recurrencia ("audita de nuevo", "qué cambió", "compara con la semana pasada", "tendencia de hilos abiertos"), carga este módulo y ejecuta:

- `audit-run.sh` para crear nuevo snapshot
- `audit-diff.sh` para comparar contra run previo
- Lee `audit-log.tsv` para tendencias numéricas
- Reporta en lenguaje natural con citas a líneas/capítulos relevantes

NO uses los scripts de extracción individuales (`extract-*.sh`) cuando estés en modo recurrente — `audit-run.sh` ya los orquesta y crea snapshot consistente.

## Limitaciones

- El symlink `current/` no funciona en filesystems sin soporte (FAT32, algunos SMB shares). En esos casos, lee el último run vía `ls -1 runs | sort | tail -1`.
- Si el manuscrito cambia de ruta original (ej. moviste el `.docx`), el hash cambia y empezás un workspace nuevo. Para mantener historial, edita `source.path` y mueve el directorio manualmente, o re-corre desde la nueva ruta y compara con un export del log antiguo.
- `audit-log.tsv` no tiene estructura de migración — si cambias el schema (agregas columna), versiona o regenera.

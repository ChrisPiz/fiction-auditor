#!/usr/bin/env bash
# audit-run.sh — orquesta auditoría completa, snapshot timestamped, log append-only.
# Uso: bash audit-run.sh <RUTA_MANUSCRITO> [--all] [--note "mensaje"]
#   --all       audita todos los atributos de top entidades (default: skip)
#   --note      anota el run en audit-log.tsv (útil para marcar revisiones del autor)
#
# Crea: $WORK/runs/<TS>/{entities,timeline,threads,audit-summary}.tsv + meta.json
# Symlink: $WORK/current → último run
# Append: $WORK/audit-log.tsv

set -euo pipefail

if [ "$#" -lt 1 ]; then
  echo "ERROR=usage:audit-run.sh PATH [--all] [--note TEXT]" >&2
  exit 1
fi

SRC="$1"; shift
RUN_AUDIT_ALL=0
NOTE=""
while [ "$#" -gt 0 ]; do
  case "$1" in
    --all) RUN_AUDIT_ALL=1; shift ;;
    --note) NOTE="${2:-}"; shift 2 ;;
    *) echo "WARN=unknown_arg:$1" >&2; shift ;;
  esac
done

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# --- preparar + indexar ---
PREP_OUT=$(bash "$SCRIPT_DIR/prepare.sh" "$SRC")
WORK=$(echo "$PREP_OUT" | grep '^WORK=' | cut -d= -f2-)
if [ -z "$WORK" ]; then
  echo "ERROR=prepare_failed" >&2
  echo "$PREP_OUT" >&2
  exit 1
fi

bash "$SCRIPT_DIR/index.sh" "$WORK" >/dev/null

# --- crear run snapshot ---
TS=$(date -u +%Y-%m-%dT%H-%M-%SZ)
RUN_DIR="$WORK/runs/$TS"
mkdir -p "$RUN_DIR"

# Snapshot meta del momento del run
cp "$WORK/meta.json" "$RUN_DIR/meta.json"

# --- correr extractores, salida a RUN_DIR ---
# Los scripts escriben en $WORK por convención; copiamos al run después.
bash "$SCRIPT_DIR/extract-entities.sh" "$WORK" >/dev/null
[ -f "$WORK/entities.tsv" ] && cp "$WORK/entities.tsv" "$RUN_DIR/"

bash "$SCRIPT_DIR/extract-timeline.sh" "$WORK" >/dev/null
[ -f "$WORK/timeline.tsv" ] && cp "$WORK/timeline.tsv" "$RUN_DIR/"

bash "$SCRIPT_DIR/extract-threads.sh" "$WORK" >/dev/null
[ -f "$WORK/threads.tsv" ] && cp "$WORK/threads.tsv" "$RUN_DIR/"

# Audit cross-entity opcional (más caro)
AUDIT_FILE="$RUN_DIR/audit-summary.txt"
if [ "$RUN_AUDIT_ALL" = "1" ]; then
  bash "$SCRIPT_DIR/audit-attribute.sh" "$WORK" --all > "$AUDIT_FILE" 2>&1 || true
else
  printf "Audit cross-entity no ejecutado. Usa --all para incluir.\n" > "$AUDIT_FILE"
fi

# --- métricas para el log ---
WORDS=$(cat "$WORK/wordcount.txt" 2>/dev/null || echo 0)
ENT_COUNT=$(($(wc -l < "$RUN_DIR/entities.tsv" 2>/dev/null || echo 1) - 1))
[ "$ENT_COUNT" -lt 0 ] && ENT_COUNT=0

TL_COUNT=$(($(wc -l < "$RUN_DIR/timeline.tsv" 2>/dev/null || echo 1) - 1))
[ "$TL_COUNT" -lt 0 ] && TL_COUNT=0

UNRESOLVED=0
if [ -f "$RUN_DIR/threads.tsv" ]; then
  UNRESOLVED=$(awk -F'\t' 'NR>1 && $5=="no"' "$RUN_DIR/threads.tsv" | wc -l | tr -d ' ')
fi

HARD=0; SOFT=0; DRIFT=0
if [ -f "$AUDIT_FILE" ]; then
  # grep -c siempre imprime el count incluso si es 0; || true evita que set -e mate
  HARD=$(grep -c "severidad=hard" "$AUDIT_FILE" 2>/dev/null || true)
  SOFT=$(grep -c "severidad=soft" "$AUDIT_FILE" 2>/dev/null || true)
  DRIFT=$(grep -c "severidad=drift" "$AUDIT_FILE" 2>/dev/null || true)
  HARD="${HARD:-0}"; SOFT="${SOFT:-0}"; DRIFT="${DRIFT:-0}"
fi

# --- update symlink "current" → último run ---
( cd "$WORK" && ln -snf "runs/$TS" current )

# --- append al log ---
LOG="$WORK/audit-log.tsv"
if [ ! -f "$LOG" ]; then
  printf 'timestamp\twords\tentities\ttimeline_markers\tunresolved_threads\thard\tsoft\tdrift\tnote\n' > "$LOG"
fi
NOTE_CLEAN=$(printf '%s' "$NOTE" | tr '\t\n' '  ')
printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
  "$TS" "$WORDS" "$ENT_COUNT" "$TL_COUNT" "$UNRESOLVED" "$HARD" "$SOFT" "$DRIFT" "$NOTE_CLEAN" >> "$LOG"

# --- output sumario ---
echo "WORK=$WORK"
echo "RUN=$RUN_DIR"
echo "CURRENT=$WORK/current"
echo "LOG=$LOG"
echo "TIMESTAMP=$TS"
echo "WORDS=$WORDS"
echo "ENTITIES=$ENT_COUNT"
echo "TIMELINE_MARKERS=$TL_COUNT"
echo "UNRESOLVED_THREADS=$UNRESOLVED"
echo "HARD=$HARD"
echo "SOFT=$SOFT"
echo "DRIFT=$DRIFT"

#!/usr/bin/env bash
# fts-query.sh — wrapper para queries FTS5 con mapeo capítulo + cap de resultados.
# Uso: bash fts-query.sh <WORK> '<QUERY>' [LIMIT]
# Output: TSV con start_line\tchapter\tsnippet\tscore

set -euo pipefail

if [ "$#" -lt 2 ]; then
  echo "ERROR=usage:fts-query.sh WORK QUERY [LIMIT]" >&2
  exit 1
fi

WORK="$1"
QUERY="$2"
LIMIT="${3:-30}"
DB="$WORK/fts5.db"

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

if [ ! -f "$DB" ]; then
  # Fallback: grep directo si no hay FTS5 (manuscritos chicos)
  SRC="$WORK/manuscript.txt"
  if [ ! -f "$SRC" ]; then
    echo "ERROR=neither_fts_nor_manuscript" >&2
    exit 1
  fi
  printf 'start_line\tchapter\tsnippet\tscore\n'
  grep -niE "$QUERY" "$SRC" 2>/dev/null \
    | head -n "$LIMIT" \
    | awk -F: -v WORK="$WORK" -v SCRIPT_DIR="$SCRIPT_DIR" '
        /^[0-9]+:/ {
          line = $1
          $1=""
          text = substr($0, 2)
          cmd = "bash \"" SCRIPT_DIR "/chapter-of-line.sh\" \"" WORK "\" " line
          cmd | getline ch
          close(cmd)
          gsub(/\t/, " ", text)
          printf "%s\t%s\t%s\t-\n", line, ch, text
        }
      '
  exit 0
fi

# FTS5 query
sqlite3 -separator $'\t' "$DB" <<SQL
SELECT
  pm.start_line,
  pm.chapter,
  snippet(paragraphs, 0, '<<', '>>', '…', 16) AS snip,
  printf('%.4f', bm25(paragraphs)) AS score
FROM paragraphs
JOIN para_meta pm ON pm.rowid = paragraphs.rowid
WHERE paragraphs MATCH '$(echo "$QUERY" | sed "s/'/''/g")'
ORDER BY bm25(paragraphs)
LIMIT $LIMIT;
SQL

#!/usr/bin/env bash
# chapter-of-line.sh — mapea línea N a su capítulo.
# Uso: bash chapter-of-line.sh <WORK> <LINE>
# Output: título del capítulo (o "(antes de cualquier capítulo)" si N precede al primero).

set -euo pipefail

if [ "$#" -lt 2 ]; then
  echo "ERROR=usage:chapter-of-line.sh WORK LINE" >&2
  exit 1
fi

WORK="$1"
LINE="$2"
TSV="$WORK/chapters.tsv"

if [ ! -f "$TSV" ] || [ ! -s "$TSV" ]; then
  echo "(sin marcadores de capítulo)"
  exit 0
fi

awk -v L="$LINE" -F'\t' '
  $1 <= L { c = $2 }
  END { print (c ? c : "(antes de cualquier capítulo)") }
' "$TSV"

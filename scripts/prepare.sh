#!/usr/bin/env bash
# prepare.sh — convierte manuscrito a texto plano y monta workspace por hash.
# Uso: bash prepare.sh <ruta_archivo_o_carpeta>
# Output: imprime WORK=<path> (workspace listo) o ERROR=<motivo>.

set -euo pipefail

if [ "$#" -lt 1 ]; then
  echo "ERROR=missing_path" >&2
  exit 1
fi

SRC="$1"

if [ ! -e "$SRC" ]; then
  echo "ERROR=path_not_found:$SRC" >&2
  exit 1
fi

SRC_ABS="$(cd "$(dirname "$SRC")" && pwd)/$(basename "$SRC")"
HASH=$(printf '%s' "$SRC_ABS" | shasum -a 1 | cut -c1-12)
WORK="/tmp/narrative-continuity/$HASH"
mkdir -p "$WORK"

echo "$SRC_ABS" > "$WORK/source.path"

# --- helpers ---

convert_one() {
  local src="$1"
  local out="$2"
  local ext="${src##*.}"
  ext="$(echo "$ext" | tr '[:upper:]' '[:lower:]')"

  case "$ext" in
    txt|md|markdown)
      cat "$src" >> "$out"
      ;;
    docx)
      if command -v pandoc >/dev/null 2>&1; then
        pandoc "$src" -t plain 2>/dev/null >> "$out" || {
          echo "ERROR=pandoc_failed:$src" >&2
          return 1
        }
      elif command -v python3 >/dev/null 2>&1; then
        python3 -c "
import sys
try:
    from docx import Document
except ImportError:
    sys.exit(2)
doc = Document(sys.argv[1])
print('\n'.join(p.text for p in doc.paragraphs if p.text.strip()))
" "$src" >> "$out" 2>/dev/null || {
          echo "ERROR=need_converter:install pandoc (brew install pandoc) or python-docx (pip install --user python-docx)" >&2
          return 1
        }
      else
        echo "ERROR=need_converter:install pandoc or python3+python-docx" >&2
        return 1
      fi
      ;;
    rtf)
      if command -v pandoc >/dev/null 2>&1; then
        pandoc "$src" -t plain >> "$out" 2>/dev/null || {
          echo "ERROR=pandoc_failed:$src" >&2
          return 1
        }
      elif command -v textutil >/dev/null 2>&1; then
        textutil -convert txt "$src" -stdout >> "$out" 2>/dev/null || {
          echo "ERROR=textutil_failed:$src" >&2
          return 1
        }
      else
        echo "ERROR=need_converter:install pandoc" >&2
        return 1
      fi
      ;;
    *)
      echo "WARN=skipping_unsupported:$src" >&2
      ;;
  esac
}

detect_encoding_and_normalize() {
  local f="$1"
  local enc
  enc=$(file -I "$f" 2>/dev/null | sed -n 's/.*charset=\([^;]*\).*/\1/p')
  case "$enc" in
    utf-8|us-ascii|unknown-8bit) ;;
    iso-8859-1|iso-8859-15|windows-1252)
      iconv -f "$enc" -t UTF-8 "$f" > "$f.utf8" && mv "$f.utf8" "$f"
      ;;
  esac
}

# --- pipeline ---

OUT="$WORK/manuscript.txt"

# Reuse check: si manuscript existe y mtime > fuente, salta conversión
NEEDS_CONVERT=1
if [ -f "$OUT" ]; then
  if [ -d "$SRC_ABS" ]; then
    NEWER_FILE=$(find "$SRC_ABS" -maxdepth 1 -type f -newer "$OUT" -print -quit 2>/dev/null || true)
    [ -z "$NEWER_FILE" ] && NEEDS_CONVERT=0
  else
    [ "$OUT" -nt "$SRC_ABS" ] && NEEDS_CONVERT=0
  fi
fi

if [ "$NEEDS_CONVERT" = "1" ]; then
  : > "$OUT"
  if [ -d "$SRC_ABS" ]; then
    while IFS= read -r f; do
      printf '\n\n=== %s ===\n\n' "$(basename "$f")" >> "$OUT"
      convert_one "$f" "$OUT" || exit 1
    done < <(find "$SRC_ABS" -maxdepth 1 -type f \( -iname '*.txt' -o -iname '*.md' -o -iname '*.markdown' -o -iname '*.docx' -o -iname '*.rtf' \) | sort)
  else
    convert_one "$SRC_ABS" "$OUT" || exit 1
  fi
  detect_encoding_and_normalize "$OUT"
fi

# --- meta ---

WORDS=$(wc -w < "$OUT" | tr -d ' ')
SIZE_KB=$(du -k "$OUT" | cut -f1)
CONTENT_HASH=$(shasum -a 256 "$OUT" | cut -d' ' -f1)

# Detección de idioma
ES=$(head -1500 "$OUT" | grep -ciwE "(el|la|que|de|en|los|las|por|con|para|una|uno|pero|sus|del|al)" || true)
EN=$(head -1500 "$OUT" | grep -ciwE "(the|and|of|to|in|that|it|with|for|was|but|his|her|on|at)" || true)
if [ "$ES" -gt "$EN" ]; then LANG="es"; else LANG="en"; fi

cat > "$WORK/meta.json" <<EOF
{
  "source": "$SRC_ABS",
  "hash": "$HASH",
  "content_hash": "$CONTENT_HASH",
  "words": $WORDS,
  "size_kb": $SIZE_KB,
  "lang": "$LANG",
  "prepared_at": "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
}
EOF

echo "WORK=$WORK"
echo "WORDS=$WORDS"
echo "SIZE_KB=$SIZE_KB"
echo "LANG=$LANG"

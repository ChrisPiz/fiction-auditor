#!/usr/bin/env bash
# index.sh — construye chapters.tsv, wordcount.txt y SQLite FTS5.
# Uso: bash index.sh <WORK>
# Idempotente: salta si fts5.db ya existe y mtime > manuscript.txt.

set -euo pipefail

if [ "$#" -lt 1 ]; then
  echo "ERROR=missing_work_dir" >&2
  exit 1
fi

WORK="$1"
SRC="$WORK/manuscript.txt"

if [ ! -f "$SRC" ]; then
  echo "ERROR=manuscript_missing:$SRC" >&2
  exit 1
fi

# --- chapters.tsv ---

CHAPTER_RE='^(#+[[:space:]]*)?(Cap[íi]tulo|Chapter|CAP[ÍI]TULO|CHAPTER)[[:space:]]+'

if [ ! -f "$WORK/chapters.tsv" ] || [ "$SRC" -nt "$WORK/chapters.tsv" ]; then
  grep -nE "$CHAPTER_RE" "$SRC" 2>/dev/null \
    | sed 's/:/\t/' > "$WORK/chapters.tsv" || true
fi

CHAPTERS=$(wc -l < "$WORK/chapters.tsv" | tr -d ' ')

# --- wordcount cacheado ---

if [ ! -f "$WORK/wordcount.txt" ] || [ "$SRC" -nt "$WORK/wordcount.txt" ]; then
  wc -w < "$SRC" | tr -d ' ' > "$WORK/wordcount.txt"
fi

WORDS=$(cat "$WORK/wordcount.txt")

# --- decisión: FTS5 sí/no ---

# Manuscritos pequeños (<5k palabras) no justifican FTS5
if [ "$WORDS" -lt 5000 ]; then
  echo "INDEXED=light"
  echo "CHAPTERS=$CHAPTERS"
  echo "WORDS=$WORDS"
  echo "FTS5=skipped (manuscript <5k words)"
  exit 0
fi

# --- FTS5 ---

DB="$WORK/fts5.db"

if [ -f "$DB" ] && [ "$DB" -nt "$SRC" ]; then
  echo "INDEXED=cached"
  echo "CHAPTERS=$CHAPTERS"
  echo "WORDS=$WORDS"
  echo "FTS5=$DB"
  exit 0
fi

if ! command -v sqlite3 >/dev/null 2>&1; then
  echo "ERROR=sqlite3_not_found:install via brew install sqlite" >&2
  exit 1
fi

rm -f "$DB"

# Build FTS5 con párrafos (separados por línea blanca)
python3 - "$SRC" "$DB" "$WORK/chapters.tsv" <<'PYEOF'
import sqlite3
import sys
import re

src_path, db_path, chapters_path = sys.argv[1], sys.argv[2], sys.argv[3]

# Cargar chapters: lista de (line_num, title) ordenada
chapters = []
try:
    with open(chapters_path) as f:
        for line in f:
            parts = line.rstrip('\n').split('\t', 1)
            if len(parts) == 2:
                chapters.append((int(parts[0]), parts[1]))
except FileNotFoundError:
    pass

def chapter_for_line(n):
    title = "(antes de cualquier capítulo)"
    for ln, t in chapters:
        if ln <= n:
            title = t
        else:
            break
    return title

con = sqlite3.connect(db_path)
con.executescript("""
PRAGMA journal_mode = OFF;
PRAGMA synchronous = OFF;
PRAGMA temp_store = MEMORY;

CREATE VIRTUAL TABLE paragraphs USING fts5(
    body,
    tokenize = "unicode61 remove_diacritics 2"
);
CREATE TABLE para_meta (
    rowid INTEGER PRIMARY KEY,
    start_line INTEGER NOT NULL,
    end_line INTEGER NOT NULL,
    chapter TEXT
);
CREATE INDEX idx_meta_line ON para_meta(start_line);
""")

# Parsear párrafos
buf = []
buf_start = 0
rowid = 0

def flush(buf, start, end):
    global rowid
    if not buf:
        return
    body = " ".join(buf).strip()
    if not body:
        return
    rowid += 1
    con.execute("INSERT INTO paragraphs(rowid, body) VALUES (?, ?)", (rowid, body))
    con.execute(
        "INSERT INTO para_meta(rowid, start_line, end_line, chapter) VALUES (?, ?, ?, ?)",
        (rowid, start, end, chapter_for_line(start)),
    )

with open(src_path) as f:
    for i, line in enumerate(f, start=1):
        stripped = line.rstrip('\n')
        if stripped.strip() == "":
            if buf:
                flush(buf, buf_start, i - 1)
                buf = []
                buf_start = 0
        else:
            if not buf:
                buf_start = i
            buf.append(stripped)
    if buf:
        flush(buf, buf_start, i)

con.commit()

# Restore safer settings before close
con.executescript("""
PRAGMA journal_mode = DELETE;
PRAGMA synchronous = NORMAL;
""")
con.close()
print(f"INDEXED_PARAGRAPHS={rowid}")
PYEOF

echo "INDEXED=full"
echo "CHAPTERS=$CHAPTERS"
echo "WORDS=$WORDS"
echo "FTS5=$DB"

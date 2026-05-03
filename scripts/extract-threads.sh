#!/usr/bin/env bash
# extract-threads.sh — detecta hilos sin resolver: preguntas, promesas, objetos, personajes huérfanos.
# Uso: bash extract-threads.sh <WORK>
# Output: $WORK/threads.tsv con columnas:
#   type, line, chapter, excerpt, resolved, resolution_line, resolution_chapter, confidence

set -euo pipefail

if [ "$#" -lt 1 ]; then
  echo "ERROR=usage:extract-threads.sh WORK" >&2
  exit 1
fi

WORK="$1"
SRC="$WORK/manuscript.txt"

if [ ! -f "$SRC" ]; then
  echo "ERROR=manuscript_missing" >&2
  exit 1
fi

LANG=$(python3 -c "import json; print(json.load(open('$WORK/meta.json'))['lang'])" 2>/dev/null || echo "es")

# Asegura entities.tsv (necesario para detección de personajes huérfanos)
if [ ! -f "$WORK/entities.tsv" ]; then
  bash "$(dirname "$0")/extract-entities.sh" "$WORK" >/dev/null
fi

python3 - "$SRC" "$WORK" "$LANG" <<'PYEOF'
import re
import sys
from collections import defaultdict

src_path, work, lang = sys.argv[1], sys.argv[2], sys.argv[3]

text = open(src_path).read()
lines = text.split("\n")
total_lines = len(lines)

# Capítulos
chapters = []
try:
    with open(f"{work}/chapters.tsv") as f:
        for ln in f:
            parts = ln.rstrip().split("\t", 1)
            if len(parts) == 2:
                chapters.append((int(parts[0]), parts[1]))
except FileNotFoundError:
    pass

def chapter_for_line(n):
    title = "(pre-cap)"
    for ln, t in chapters:
        if ln <= n:
            title = t
        else:
            break
    return title

# --- Preguntas abiertas ---

if lang == "es":
    q_re = re.compile(
        r"¿(qu[eé]|qui[eé]n|cu[aá]ndo|d[oó]nde|por\s+qu[eé]|c[oó]mo)\s+"
        r"(ser[aá]|ser[ií]a|habr[aá]|hizo|har[ií]a|estaba|estar[aá]|hab[ií]a|tendr[aá])"
        r"[^?]{0,200}\?",
        re.I,
    )
    rhetorical_markers = ["alguna vez", "alguien", "nadie", "qui[eé]n no"]
else:
    q_re = re.compile(
        r"\b(what|who|when|where|why|how)\s+"
        r"(will|would|could|did|had|was|is|might)"
        r"[^?]{0,200}\?",
        re.I,
    )
    rhetorical_markers = ["ever", "anyone", "no one", "who hasn"]

questions = []
for m in q_re.finditer(text):
    excerpt = m.group(0).strip()
    if any(re.search(rm, excerpt, re.I) for rm in rhetorical_markers):
        continue
    line_num = text[: m.start()].count("\n") + 1
    questions.append((line_num, excerpt))

# --- Promesas ---

if lang == "es":
    p_re = re.compile(
        r"\b(prometi[oó]|jur[oó]|se\s+prometi[oó]|se\s+jur[oó]|decidi[oó]\s+que|voy\s+a|alg[uú]n\s+d[ií]a|cuando\s+vuelva|cuando\s+regrese)\b"
        r"[^.!?]{0,200}[.!?]",
        re.I,
    )
else:
    p_re = re.compile(
        r"\b(promised|swore|vowed|decided\s+to|I\s+will|I'll|someday|when\s+I\s+return)\b"
        r"[^.!?]{0,200}[.!?]",
        re.I,
    )

promises = []
for m in p_re.finditer(text):
    excerpt = m.group(0).strip()
    line_num = text[: m.start()].count("\n") + 1
    promises.append((line_num, excerpt))

# --- Personajes huérfanos (freq baja con dialog tag) ---

orphan_chars = []
try:
    with open(f"{work}/entities.tsv") as f:
        next(f)  # header
        for line in f:
            parts = line.rstrip("\n").split("\t")
            if len(parts) < 7:
                continue
            freq, name, type_, fc, fl, dt, _ = parts
            freq = int(freq)
            dt = int(dt)
            fl = int(fl)
            if type_ == "character" and freq <= 2 and dt >= 1:
                orphan_chars.append((fl, name, fc))
except FileNotFoundError:
    pass

# --- Resolución heurística ---

def find_resolution(line_num, keywords, after_only=True):
    """
    Busca matches de cualquier keyword después de line_num.
    Retorna (resolution_line, confidence) o (None, None).
    """
    if after_only:
        scope_lines = lines[line_num:]
        offset = line_num
    else:
        scope_lines = lines
        offset = 0

    for i, line in enumerate(scope_lines):
        for kw in keywords:
            if re.search(re.escape(kw), line, re.I):
                return (offset + i + 1, "medium")
    return (None, None)

def confidence_promise(promise_text, found_line):
    """
    Si la promesa usa verbo X, busca conjugación de X en pasado en la resolución.
    Heurística simple v1.
    """
    # placeholder — refina con análisis real si necesario
    return "medium"

# Procesar preguntas
question_rows = []
for ln, excerpt in questions:
    # Extrae sustantivos clave (palabras de 4+ chars no-función)
    words = re.findall(r"\b[a-záéíóúñA-ZÁÉÍÓÚÑ]{4,}\b", excerpt)
    keywords = [w for w in words if w.lower() not in {"qué", "quién", "cuándo", "dónde", "cómo", "what", "when", "where", "would", "could"}]
    keywords = keywords[:3]
    if not keywords:
        continue
    res_line, conf = find_resolution(ln, keywords, after_only=True)
    resolved = "yes" if res_line else "no"
    res_chapter = chapter_for_line(res_line) if res_line else "-"
    question_rows.append((
        "question", ln, chapter_for_line(ln), excerpt[:200].replace("\t", " "),
        resolved, res_line or "-", res_chapter, conf or "-"
    ))

# Procesar promesas
promise_rows = []
for ln, excerpt in promises:
    words = re.findall(r"\b[a-záéíóúñ]{5,}\b", excerpt.lower())
    # Stopwords mínimas
    stop = {"prometió", "promised", "juró", "swore", "decidió", "decided", "alguna", "alguien"}
    keywords = [w for w in words if w not in stop][:3]
    if not keywords:
        continue
    res_line, conf = find_resolution(ln, keywords, after_only=True)
    resolved = "yes" if res_line else "no"
    res_chapter = chapter_for_line(res_line) if res_line else "-"
    promise_rows.append((
        "promise", ln, chapter_for_line(ln), excerpt[:200].replace("\t", " "),
        resolved, res_line or "-", res_chapter, conf or "-"
    ))

# Procesar personajes huérfanos
orphan_rows = []
for fl, name, fc in orphan_chars:
    res_line, conf = find_resolution(fl + 1, [name], after_only=True)
    resolved = "yes" if res_line else "no"
    res_chapter = chapter_for_line(res_line) if res_line else "-"
    orphan_rows.append((
        "character", fl, fc, f"{name} (freq baja, dialog tag)",
        resolved, res_line or "-", res_chapter, conf or "low"
    ))

# Emitir
out = f"{work}/threads.tsv"
with open(out, "w") as f:
    f.write("type\tline\tchapter\texcerpt\tresolved\tresolution_line\tresolution_chapter\tconfidence\n")
    for r in question_rows + promise_rows + orphan_rows:
        f.write("\t".join(str(x) for x in r) + "\n")

unresolved = sum(1 for r in question_rows + promise_rows + orphan_rows if r[4] == "no")
print(f"THREADS_FILE={out}")
print(f"TOTAL={len(question_rows) + len(promise_rows) + len(orphan_rows)}")
print(f"UNRESOLVED={unresolved}")
PYEOF

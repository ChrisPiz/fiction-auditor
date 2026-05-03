#!/usr/bin/env bash
# extract-timeline.sh — extrae marcadores temporales del manuscrito.
# Uso: bash extract-timeline.sh <WORK> [--audit]
# Output: $WORK/timeline.tsv con columnas:
#   line, chapter, type, marker, context

set -euo pipefail

if [ "$#" -lt 1 ]; then
  echo "ERROR=usage:extract-timeline.sh WORK [--audit]" >&2
  exit 1
fi

WORK="$1"
AUDIT="${2:-}"
SRC="$WORK/manuscript.txt"

if [ ! -f "$SRC" ]; then
  echo "ERROR=manuscript_missing" >&2
  exit 1
fi

LANG=$(python3 -c "import json; print(json.load(open('$WORK/meta.json'))['lang'])" 2>/dev/null || echo "es")

python3 - "$SRC" "$WORK" "$LANG" "$AUDIT" <<'PYEOF'
import re
import sys
import json

src_path, work, lang, audit = sys.argv[1], sys.argv[2], sys.argv[3], sys.argv[4]

PATTERNS_ES = [
    ("absolute_year", re.compile(r"\b(?:en\s+(?:el\s+a[ñn]o\s+)?|del\s+a[ñn]o\s+)(\d{4})\b", re.I)),
    ("absolute_date", re.compile(r"\b(\d{1,2})\s+de\s+(enero|febrero|marzo|abril|mayo|junio|julio|agosto|septiembre|octubre|noviembre|diciembre)(?:\s+de\s+(\d{4}))?", re.I)),
    ("relative_past", re.compile(r"\bhac[ií]a?\s+([a-z0-9]+)\s+(a[ñn]os?|meses?|semanas?|d[ií]as?|horas?)\b", re.I)),
    ("relative_offset", re.compile(r"\b([a-z0-9]+)\s+(a[ñn]os?|meses?|semanas?|d[ií]as?|horas?)\s+(despu[eé]s|antes|atr[aá]s|m[aá]s\s+tarde)\b", re.I)),
    ("next_unit", re.compile(r"\b(al\s+d[ií]a\s+siguiente|esa\s+(?:ma[ñn]ana|tarde|noche)|aquella\s+(?:ma[ñn]ana|tarde|noche)|la\s+(?:siguiente|pr[oó]xima)\s+(?:ma[ñn]ana|tarde|noche))\b", re.I)),
    ("weekday", re.compile(r"\b(lunes|martes|mi[eé]rcoles|jueves|viernes|s[aá]bado|domingo)\b", re.I)),
    ("season", re.compile(r"\b(invierno|primavera|verano|oto[ñn]o)\b", re.I)),
    ("age", re.compile(r"\b(?:ten[ií]a|tiene)\s+(\d+)\s+a[ñn]os\b", re.I)),
    ("hedge_temporal", re.compile(r"\b(creo\s+que|me\s+parece|tal\s+vez|quiz[aá]s?)\s+(hac[ií]a|hace|ten[ií]a)\b", re.I)),
]

PATTERNS_EN = [
    ("absolute_year", re.compile(r"\b(?:in\s+(?:the\s+year\s+)?)(\d{4})\b", re.I)),
    ("absolute_date", re.compile(r"\b(january|february|march|april|may|june|july|august|september|october|november|december)\s+(\d{1,2})(?:,\s*(\d{4}))?", re.I)),
    ("relative_offset", re.compile(r"\b(?:two|three|four|five|six|seven|eight|nine|ten|\d+)\s+(years?|months?|weeks?|days?|hours?)\s+(later|ago|before|after)\b", re.I)),
    ("next_unit", re.compile(r"\b(?:next\s+(?:morning|day|week|month|year)|that\s+(?:morning|afternoon|evening|night)|the\s+(?:following|previous)\s+(?:day|week|month|year))\b", re.I)),
    ("weekday", re.compile(r"\b(monday|tuesday|wednesday|thursday|friday|saturday|sunday)\b", re.I)),
    ("season", re.compile(r"\b(winter|spring|summer|autumn|fall)\b", re.I)),
    ("age", re.compile(r"\b(?:was|is)\s+(\d+)\s+years\s+old\b", re.I)),
    ("hedge_temporal", re.compile(r"\b(I\s+think|maybe|perhaps)\s+(was|had|it\s+was)\b", re.I)),
]

patterns = PATTERNS_ES if lang == "es" else PATTERNS_EN

# Cargar capítulos
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

rows = []
with open(src_path) as f:
    lines = f.readlines()

for line_num, line in enumerate(lines, start=1):
    for ptype, regex in patterns:
        for m in regex.finditer(line):
            marker = m.group(0)
            # Contexto: línea actual recortada
            context = line.strip()
            if len(context) > 200:
                start = max(0, m.start() - 80)
                end = min(len(line), m.end() + 80)
                context = "…" + line[start:end].strip() + "…"
            ch = chapter_for_line(line_num)
            context = context.replace("\t", " ")
            rows.append((line_num, ch, ptype, marker, context))

# Audit mode: detectar contradicciones obvias
flags = {}
if audit == "--audit":
    # Heurística: edades sucesivas de un personaje crecen pero ofset narrativo no lo justifica.
    # Implementación mínima v1: marca todas las edades como "verificar manualmente"
    # (la auditoría profunda vive en audit-attribute.sh con cross-timeline)
    for i, (ln, ch, ptype, marker, ctx) in enumerate(rows):
        if ptype == "age":
            flags[i] = "verify_age_in_audit-attribute"

out = f"{work}/timeline.tsv"
with open(out, "w") as f:
    if audit == "--audit":
        f.write("line\tchapter\ttype\tmarker\tcontext\tflag\n")
    else:
        f.write("line\tchapter\ttype\tmarker\tcontext\n")
    for i, r in enumerate(rows):
        if audit == "--audit":
            flag = flags.get(i, "")
            f.write("\t".join(str(x) for x in r) + f"\t{flag}\n")
        else:
            f.write("\t".join(str(x) for x in r) + "\n")

print(f"TIMELINE_FILE={out}")
print(f"MARKERS={len(rows)}")
PYEOF

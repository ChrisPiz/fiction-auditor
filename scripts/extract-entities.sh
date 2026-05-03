#!/usr/bin/env bash
# extract-entities.sh — extrae candidatos a personajes/lugares/objetos.
# Uso: bash extract-entities.sh <WORK> [MIN_FREQ]
# Output: TSV en $WORK/entities.tsv con columnas:
#   freq, name, type, first_chapter, first_line, dialog_tag_count, relation_hints

set -euo pipefail

if [ "$#" -lt 1 ]; then
  echo "ERROR=usage:extract-entities.sh WORK [MIN_FREQ]" >&2
  exit 1
fi

WORK="$1"
MIN_FREQ="${2:-3}"
SRC="$WORK/manuscript.txt"

if [ ! -f "$SRC" ]; then
  echo "ERROR=manuscript_missing" >&2
  exit 1
fi

LANG=$(python3 -c "import json; print(json.load(open('$WORK/meta.json'))['lang'])" 2>/dev/null || echo "es")

python3 - "$SRC" "$WORK" "$MIN_FREQ" "$LANG" <<'PYEOF'
import re
import sys
import json
from collections import Counter, defaultdict

src_path, work, min_freq, lang = sys.argv[1], sys.argv[2], int(sys.argv[3]), sys.argv[4]

text = open(src_path).read()

STOPWORDS_ES = {
    "Y", "O", "El", "La", "Los", "Las", "Un", "Una", "Pero", "Que", "Como",
    "Si", "No", "Cuando", "Donde", "Mientras", "Aunque", "Porque", "Aún",
    "Aun", "Más", "Mas", "Todo", "Toda", "Todos", "Todas", "Entonces",
    "Después", "Antes", "Hoy", "Ayer", "Mañana", "Eso", "Esto", "Aquello",
    "Ese", "Este", "Aquel", "Esa", "Esta", "Aquella", "Sin", "Con", "Por",
    "Para", "Desde", "Hasta", "Entre", "Sobre", "Tras", "Bajo", "Cap",
    "Capítulo", "Capitulo",
    "Su", "Sus", "Mi", "Mis", "Tu", "Tus", "Era", "Eran", "Es", "Son",
    "Estaba", "Estaban", "Había", "Habían", "Tenía", "Tenían", "Hizo",
    "Fue", "Fueron", "Iba", "Iban", "Vino", "Salió", "Llegó", "Volvió",
    "Solo", "Sólo", "Ni", "También", "Tampoco", "Casi", "Muy", "Tan",
    "Lo", "La", "Le", "Les", "Se", "Me", "Te", "Nos",
}
STOPWORDS_EN = {
    "The", "And", "Or", "But", "If", "When", "Where", "While", "He", "She",
    "It", "They", "This", "That", "These", "Those", "Then", "After", "Before",
    "Today", "Yesterday", "Tomorrow", "Yes", "No", "Maybe", "However",
    "Although", "Because", "Though", "From", "With", "Without", "Through",
    "Chapter",
    "His", "Her", "Their", "My", "Your", "Our", "Was", "Were", "Is", "Are",
    "Had", "Have", "Has", "Did", "Do", "Does", "Will", "Would", "Could",
    "Should", "May", "Might", "Must", "Just", "Only", "Also", "Even",
    "Very", "So", "Too", "Yet", "Still", "Already",
}

stopwords = STOPWORDS_ES if lang == "es" else STOPWORDS_EN

# Match capitalized words/bigrams not at sentence start
# Anchor to space/punct (excluding sentence-final period followed by capital,
# which would be a new sentence)
if lang == "es":
    cap_class = "A-ZÁÉÍÓÚÑ"
    low_class = "a-záéíóúñ"
else:
    cap_class = "A-Z"
    low_class = "a-z"

# Find capitalized tokens preceded by non-sentence-ending punctuation/space
token_re = re.compile(
    r"(?<=[\s,;:¿¡(\"\'\—\–\-])"
    r"([" + cap_class + r"][" + low_class + r"]+(?:\s+[" + cap_class + r"][" + low_class + r"]+)?)"
)

# Get line number for offsets
line_offsets = [0]
for line in text.split("\n"):
    line_offsets.append(line_offsets[-1] + len(line) + 1)

def line_of_offset(o):
    lo, hi = 0, len(line_offsets) - 1
    while lo < hi:
        mid = (lo + hi) // 2
        if line_offsets[mid] <= o:
            lo = mid + 1
        else:
            hi = mid
    return lo

counts = Counter()
first_seen = {}

for m in token_re.finditer(text):
    token = m.group(1).strip()
    head = token.split()[0]
    if head in stopwords:
        continue
    counts[token] += 1
    if token not in first_seen:
        first_seen[token] = m.start()

# Dialog tag extraction
if lang == "es":
    dialog_re = re.compile(
        r"(?:dijo|preguntó|respondió|susurró|gritó|exclamó|murmuró|pensó|añadió|continuó)\s+"
        r"([A-ZÁÉÍÓÚÑ][a-záéíóúñ]+(?:\s+[A-ZÁÉÍÓÚÑ][a-záéíóúñ]+)?)"
    )
else:
    dialog_re = re.compile(
        r"([A-Z][a-z]+(?:\s+[A-Z][a-z]+)?)\s+"
        r"(?:said|asked|whispered|shouted|yelled|replied|murmured|exclaimed|thought|added|continued)"
    )

dialog_counts = Counter()
upper_re = re.compile(r"^[A-ZÁÉÍÓÚÑ]")
for m in dialog_re.finditer(text):
    name = m.group(1).strip()
    # re.I permite minúsculas en grupos; descarta si no empieza mayúscula real
    if not upper_re.match(name):
        continue
    head = name.split()[0]
    if head in stopwords:
        continue
    dialog_counts[name] += 1

# Relations
if lang == "es":
    rel_re = re.compile(
        r"\bsu\s+(madre|padre|hermano|hermana|hijo|hija|tío|tio|tía|tia|primo|prima|"
        r"abuelo|abuela|esposo|esposa|marido|mujer)\s+"
        r"([A-ZÁÉÍÓÚÑ][a-záéíóúñ]+)",
        re.I,
    )
else:
    rel_re = re.compile(
        r"\b(?:his|her)\s+(mother|father|brother|sister|son|daughter|uncle|aunt|cousin|"
        r"grandfather|grandmother|husband|wife)\s+"
        r"([A-Z][a-z]+)",
        re.I,
    )

relations = defaultdict(list)
for m in rel_re.finditer(text):
    rel, name = m.group(1), m.group(2)
    if not upper_re.match(name):
        continue
    head = name.split()[0]
    if head in stopwords:
        continue
    relations[name].append(rel)

# Subject-of-verb signal — names followed by typical narrative verbs
if lang == "es":
    subj_re = re.compile(
        r"\b([A-ZÁÉÍÓÚÑ][a-záéíóúñ]+(?:\s+[A-ZÁÉÍÓÚÑ][a-záéíóúñ]+)?)\s+"
        r"(?:tenía|tiene|tuvo|estaba|miraba|miró|abrió|cerró|dijo|preguntó|respondió|"
        r"entró|salió|volvió|llegó|gritó|susurró|exclamó|sintió|sentía|pensó|pensaba|"
        r"recordó|recordaba|olvidó|encontró|perdió|amaba|amó|odiaba|caminaba|caminó|"
        r"corría|corrió|escribió|leyó|comía|dormía|despertó|sonrió|lloró|rió|"
        r"negó|asintió|murmuró|añadió|continuó|empezó|comenzó|terminó|acabó|"
        r"levantó|sentó|paró|detuvo|huyó|se|le|se\s+puso|se\s+sintió)\b",
        re.I,
    )
else:
    subj_re = re.compile(
        r"\b([A-Z][a-z]+(?:\s+[A-Z][a-z]+)?)\s+"
        r"(?:had|has|was|is|were|are|opened|closed|said|asked|answered|entered|left|"
        r"returned|arrived|shouted|whispered|exclaimed|felt|thought|remembered|"
        r"forgot|found|lost|loved|hated|walked|ran|wrote|read|ate|slept|"
        r"woke|smiled|cried|laughed|nodded|shook|murmured|added|continued|"
        r"began|started|finished|ended|stood|sat|stopped|fled)\b",
        re.I,
    )

subj_counts = Counter()
for m in subj_re.finditer(text):
    name = m.group(1).strip()
    if not upper_re.match(name):
        continue
    head = name.split()[0]
    if head in stopwords:
        continue
    subj_counts[name] += 1

# Place markers (heuristic: word after "en/desde/hacia/hasta/a" + capitalized)
if lang == "es":
    place_re = re.compile(
        r"\b(?:en|desde|hacia|hasta|a)\s+([A-ZÁÉÍÓÚÑ][a-záéíóúñ]+(?:\s+[A-ZÁÉÍÓÚÑ][a-záéíóúñ]+)?)"
    )
else:
    place_re = re.compile(
        r"\b(?:in|from|to|toward|towards)\s+([A-Z][a-z]+(?:\s+[A-Z][a-z]+)?)"
    )

place_hits = Counter()
for m in place_re.finditer(text):
    place_hits[m.group(1).strip()] += 1

# Chapter mapping (load chapters.tsv)
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

# Classify and emit
rows = []
# Asegura que cualquier nombre con dialog tag o relación entre como candidato,
# incluso si freq < min_freq — perderlos es perder personajes huérfanos.
extra_names = set(dialog_counts.keys()) | set(relations.keys())
candidate_names = set(counts.keys()) | extra_names
for name in candidate_names:
    freq = counts.get(name, 0)
    head = name.split()[0]
    if head in stopwords:
        continue
    dt = dialog_counts.get(name, 0) + dialog_counts.get(head, 0)
    rel_target = name in relations or head in relations
    if freq < min_freq and dt == 0 and not rel_target:
        continue

    rels = sorted(set(relations.get(name, []) + relations.get(head, [])))
    place_score = place_hits.get(name, 0) + place_hits.get(head, 0)
    subj = subj_counts.get(name, 0) + subj_counts.get(head, 0)

    # Personajes de relación inversa: si aparece "su X NOMBRE", el nombre es persona
    is_relation_target = rel_target

    if dt > 0:
        type_ = "character"
    elif is_relation_target:
        type_ = "character"
    elif subj >= 2:
        type_ = "character"
    elif place_score >= max(2, freq // 3) and subj == 0:
        type_ = "place"
    elif freq >= 5 and subj == 0 and dt == 0:
        type_ = "object"
    else:
        type_ = "unknown"

    if name in first_seen:
        fl = line_of_offset(first_seen[name])
    else:
        # Entrada por dialog/relación pero no en first_seen — busca primera ocurrencia rápida
        m = re.search(r"\b" + re.escape(name) + r"\b", text)
        fl = line_of_offset(m.start()) if m else 1
    fc = chapter_for_line(fl)
    rel_str = ",".join(rels) if rels else "-"
    # Frecuencia efectiva incluye dialog tags si la palabra no se contó por capitalización
    eff_freq = max(freq, dt)

    rows.append((eff_freq, name, type_, fc, fl, dt, rel_str))

rows.sort(key=lambda r: -r[0])

out = f"{work}/entities.tsv"
with open(out, "w") as f:
    f.write("freq\tname\ttype\tfirst_chapter\tfirst_line\tdialog_tags\trelations\n")
    for r in rows:
        f.write("\t".join(str(x) for x in r) + "\n")

print(f"ENTITIES_FILE={out}")
print(f"COUNT={len(rows)}")
PYEOF

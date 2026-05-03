#!/usr/bin/env bash
# audit-attribute.sh — extrae afirmaciones sobre un atributo de una entidad y reporta contradicciones.
# Usos:
#   bash audit-attribute.sh <WORK> <ENTITY> <ATTRIBUTE>
#   bash audit-attribute.sh <WORK> <ENTITY> <ATTRIBUTE> --cross-timeline
#   bash audit-attribute.sh <WORK> --all
# ATTRIBUTE: edad|ojos|pelo|altura|profesion|relacion|ubicacion
# Output: stdout reporte humano + opcional $WORK/audit-<entity>-<attr>.tsv

set -euo pipefail

if [ "$#" -lt 1 ]; then
  echo "ERROR=usage:audit-attribute.sh WORK ENTITY ATTRIBUTE [--cross-timeline] | WORK --all" >&2
  exit 1
fi

WORK="$1"
SRC="$WORK/manuscript.txt"

if [ ! -f "$SRC" ]; then
  echo "ERROR=manuscript_missing" >&2
  exit 1
fi

LANG=$(python3 -c "import json; print(json.load(open('$WORK/meta.json'))['lang'])" 2>/dev/null || echo "es")

if [ "${2:-}" = "--all" ]; then
  MODE="all"
  ENTITY=""
  ATTR=""
  CROSS=""
else
  MODE="single"
  ENTITY="${2:-}"
  ATTR="${3:-}"
  CROSS="${4:-}"
  if [ -z "$ENTITY" ] || [ -z "$ATTR" ]; then
    echo "ERROR=missing_entity_or_attribute" >&2
    exit 1
  fi
fi

python3 - "$SRC" "$WORK" "$LANG" "$MODE" "$ENTITY" "$ATTR" "$CROSS" <<'PYEOF'
import re
import sys
import json
from collections import defaultdict

src_path, work, lang, mode, entity, attr, cross = sys.argv[1:8]

text = open(src_path).read()
lines = text.split("\n")

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

def line_of_offset(o):
    return text[:o].count("\n") + 1

# Patrones por atributo
def patterns_for(attr_name):
    """Devuelve (regex_value_extractor, value_normalizer)."""
    if lang == "es":
        if attr_name == "edad":
            return (
                re.compile(
                    r"\b(?:ten[ií]a|tiene|de|con)(?:\s+\w+){0,2}\s+(\d+)\s+a[ñn]os"
                    r"|\bcumpli[oó]\s+(\d+)"
                    r"|\brec[ií]en\s+cumplidos?\s+(\d+)"
                    r"|(\d+)\s+a[ñn]os\s+cumplidos?",
                    re.I,
                ),
                lambda m: int(next(g for g in m.groups() if g)),
            )
        if attr_name == "ojos":
            return (
                re.compile(r"\bojos\s+(verdes?|azules?|negros?|marrones?|casta[ñn]os?|grises?|color\s+[a-záéíóúñ]+)", re.I),
                lambda m: m.group(1).lower(),
            )
        if attr_name == "pelo":
            return (
                re.compile(r"\b(?:pelo|cabello|melena)\s+(rubio|moreno|negro|casta[ñn]o|pelirrojo|cano|gris|corto|largo|rizado|liso|ondulado)", re.I),
                lambda m: m.group(1).lower(),
            )
        if attr_name == "altura":
            return (
                re.compile(r"\b(?:de|med[ií]a)\s+(\d+\.?\d*)\s*(?:metros?|m\b|cm|cent[ií]metros?)|\b(alto|alta|bajo|baja|menudo|menuda)", re.I),
                lambda m: m.group(1) or m.group(2).lower(),
            )
        if attr_name == "profesion":
            return (
                re.compile(r"\b(?:era|es)\s+(?:una?\s+)?(m[eé]dic[oa]|profesora?|escritora?|polic[ií]a|abogad[oa]|maestra?|enfermera?|cocinera?|periodista|ingenier[oa])\b", re.I),
                lambda m: m.group(1).lower(),
            )
        if attr_name == "relacion":
            return (
                re.compile(r"\bsu\s+(madre|padre|hermano|hermana|hijo|hija|t[ií]o|t[ií]a|primo|prima|abuelo|abuela|esposo|esposa|marido|mujer)\b", re.I),
                lambda m: m.group(1).lower(),
            )
        return (None, None)
    else:
        if attr_name == "edad" or attr_name == "age":
            return (
                re.compile(r"\b(?:was|is)\s+(\d+)\s+years\s+old|\baged\s+(\d+)|\bturned\s+(\d+)", re.I),
                lambda m: int(next(g for g in m.groups() if g)),
            )
        if attr_name == "ojos" or attr_name == "eyes":
            return (
                re.compile(r"\b(green|blue|black|brown|hazel|grey|gray)\s+eyes", re.I),
                lambda m: m.group(1).lower(),
            )
        if attr_name == "pelo" or attr_name == "hair":
            return (
                re.compile(r"\b(blonde|brown|black|red|grey|gray|short|long|curly|straight|wavy)\s+hair", re.I),
                lambda m: m.group(1).lower(),
            )
        if attr_name == "altura" or attr_name == "height":
            return (
                re.compile(r"\b(\d+\.?\d*)\s+(?:feet|ft|inches|in|cm)|\b(tall|short|petite)", re.I),
                lambda m: m.group(1) or m.group(2).lower(),
            )
        if attr_name == "profesion" or attr_name == "profession":
            return (
                re.compile(r"\b(?:was|is)\s+a\s+(doctor|teacher|writer|police\s+officer|lawyer|nurse|cook|journalist|engineer)\b", re.I),
                lambda m: m.group(1).lower(),
            )
        if attr_name == "relacion" or attr_name == "relation":
            return (
                re.compile(r"\b(?:his|her)\s+(mother|father|brother|sister|son|daughter|uncle|aunt|cousin|grandfather|grandmother|husband|wife)\b", re.I),
                lambda m: m.group(1).lower(),
            )
        return (None, None)

def audit_one(entity_name, attr_name):
    """Audita una entidad + atributo. Retorna lista de hallazgos."""
    regex, normalizer = patterns_for(attr_name)
    if regex is None:
        return [], f"unsupported_attribute:{attr_name}"

    # Encuentra menciones de entidad y verifica si en el mismo párrafo hay match del atributo
    # Estrategia: para cada match del regex de atributo, verifica que la entidad aparezca en
    # ventana de 200 chars antes o 100 después
    hits = []
    name_re = re.compile(r"\b" + re.escape(entity_name) + r"\b", re.I)

    # Detector de flashback / referencia temporal pasada
    flashback_markers_es = (
        "cuando tenía", "cuando era", "años atrás", "tiempo atrás",
        "en aquel entonces", "de niña", "de niño", "de pequeña", "de pequeño",
        "siendo niña", "siendo niño", "antes de", "antaño",
    )
    flashback_markers_en = (
        "when she was", "when he was", "years ago", "back when",
        "as a child", "as a girl", "as a boy", "long ago", "in those days",
    )
    fb_markers = flashback_markers_es if lang == "es" else flashback_markers_en

    # Stopwords mínimas para descartar nombres falsos al determinar dueño del atributo
    name_stopwords = {
        "Era", "Era", "Su", "Lo", "La", "Le", "Cuando", "Pero", "Aún", "Hoy",
        "Capítulo", "Cap", "Pero", "Era", "Es", "Fue", "Estaba", "Había",
        "When", "Then", "But", "Chapter", "She", "He", "It", "Was", "Is",
    }

    for m in regex.finditer(text):
        try:
            value = normalizer(m)
        except (StopIteration, AttributeError):
            continue

        # Determina el dueño del atributo: entidad nombrada en la MISMA oración,
        # más cercana al match. Sin esto, "X tenía 34" y otra entidad en la oración
        # vecina causan atribución falsa.
        sent_start = max(
            text.rfind('.', 0, m.start()),
            text.rfind('!', 0, m.start()),
            text.rfind('?', 0, m.start()),
            text.rfind('\n\n', 0, m.start()),
            -1,
        ) + 1
        end_candidates = [
            text.find('.', m.end()),
            text.find('!', m.end()),
            text.find('?', m.end()),
            text.find('\n\n', m.end()),
        ]
        end_candidates = [c for c in end_candidates if c != -1]
        sent_end = min(end_candidates) if end_candidates else len(text)
        sentence = text[sent_start:sent_end]

        # Captura nombres en la oración, descartando stopwords
        name_pattern = (
            r"\b[A-ZÁÉÍÓÚÑ][a-záéíóúñ]+\b" if lang == "es"
            else r"\b[A-Z][a-z]+\b"
        )
        names_in_sent = []
        for n in re.finditer(name_pattern, sentence):
            tok = n.group(0)
            if tok in name_stopwords:
                continue
            names_in_sent.append((tok, n.start() + sent_start))

        if not names_in_sent:
            continue

        # Match con genitivo posterior: "X de NOMBRE" / "X of NAME" — NOMBRE manda
        post = text[m.end():m.end() + 60]
        gen_re = re.compile(
            r"^[\s,]*(?:de|of)\s+([A-ZÁÉÍÓÚÑ][a-záéíóúñ]+)" if lang == "es"
            else r"^[\s,]*of\s+([A-Z][a-z]+)"
        )
        gen_m = gen_re.match(post)
        if gen_m:
            owner = gen_m.group(1)
        else:
            # Dueño = nombre más cercano al match en la oración
            owner = min(names_in_sent, key=lambda p: abs(p[1] - m.start()))[0]

        if owner.lower() != entity_name.lower():
            continue

        # Detecta flashback
        pre_window = re.sub(
            r"\s+", " ",
            text[max(0, m.start() - 80):m.end()],
        ).lower()
        is_flashback = any(mk in pre_window for mk in fb_markers)

        ln = line_of_offset(m.start())
        ctx = lines[ln - 1].strip() if ln <= len(lines) else ""
        if len(ctx) > 200:
            ctx = ctx[:200] + "…"
        hits.append({
            "line": ln,
            "chapter": chapter_for_line(ln),
            "value": value,
            "context": ctx,
            "flashback": is_flashback,
        })

    return hits, None

def severity(values, attr_name):
    """Clasifica el conjunto de valores: hard/soft/drift/ok."""
    distinct = list({v for v in values})
    if len(distinct) <= 1:
        return "ok"
    if attr_name in ("edad", "age"):
        nums = [v for v in distinct if isinstance(v, int)]
        if len(nums) >= 2:
            spread = max(nums) - min(nums)
            if spread > 5:
                return "hard"
            return "soft"
    return "drift"

def report_findings(entity_name, attr_name, hits):
    if not hits:
        print(f"\nSin afirmaciones detectadas sobre {attr_name} de {entity_name}.")
        return
    # Separa hits actuales vs flashbacks
    current = [h for h in hits if not h.get("flashback")]
    flashbacks = [h for h in hits if h.get("flashback")]

    values = [h["value"] for h in current]
    sev = severity(values, attr_name)
    icon = {"ok": "✓", "drift": "🔵", "soft": "🟡", "hard": "⚠️"}[sev]
    print(f"\n{icon} {attr_name} de {entity_name} — {len(current)} afirmaciones presentes, severidad={sev}")
    for h in current:
        print(f"  L{h['line']} · {h['chapter']}")
        print(f"    [{h['value']}] > {h['context']}")

    if flashbacks:
        print(f"\n  📜 {len(flashbacks)} referencia(s) flashback (excluidas del audit principal):")
        for h in flashbacks:
            print(f"    L{h['line']} · {h['chapter']}")
            print(f"      [{h['value']}] > {h['context']}")

    if sev == "ok":
        print("  Consistente.")
    elif sev == "hard":
        print("  ⚠️ Valores incompatibles. Revisar.")

# --- ejecución ---

if mode == "all":
    # Itera sobre top entidades en entities.tsv
    try:
        with open(f"{work}/entities.tsv") as f:
            next(f)
            entities = []
            for line in f:
                parts = line.rstrip("\n").split("\t")
                if len(parts) < 7:
                    continue
                freq, name, type_ = int(parts[0]), parts[1], parts[2]
                if freq < 5:
                    continue
                if type_ != "character":
                    continue
                entities.append(name)
                if len(entities) >= 10:
                    break
    except FileNotFoundError:
        print("ERROR=run extract-entities.sh first", file=sys.stderr)
        sys.exit(1)

    attrs = ["edad", "ojos", "pelo", "altura", "profesion", "relacion"]
    for ent in entities:
        print(f"\n=== {ent} ===")
        for a in attrs:
            hits, err = audit_one(ent, a)
            if err:
                continue
            if hits:
                report_findings(ent, a, hits)
else:
    hits, err = audit_one(entity, attr)
    if err:
        print(f"ERROR={err}", file=sys.stderr)
        sys.exit(1)
    report_findings(entity, attr, hits)
PYEOF

#!/usr/bin/env bash
# audit-diff.sh — compara dos runs y reporta deltas humanos.
# Uso:
#   bash audit-diff.sh <WORK>                            # último vs penúltimo
#   bash audit-diff.sh <WORK> <RUN_A> <RUN_B>            # rutas explícitas
# Output: reporte stdout + escribe $RUN_B/diff-from-<RUN_A_TS>.md

set -euo pipefail

if [ "$#" -lt 1 ]; then
  echo "ERROR=usage:audit-diff.sh WORK [RUN_A RUN_B]" >&2
  exit 1
fi

WORK="$1"

if [ "$#" -ge 3 ]; then
  RUN_A="$2"
  RUN_B="$3"
else
  # auto: RUN_B = último, RUN_A = penúltimo. Portable bash 3.2 (macOS).
  RUNS=()
  while IFS= read -r r; do
    [ -n "$r" ] && RUNS+=("$r")
  done < <(ls -1 "$WORK/runs" 2>/dev/null | sort)
  COUNT="${#RUNS[@]}"
  if [ "$COUNT" -lt 2 ]; then
    echo "ERROR=need_at_least_2_runs (found $COUNT)" >&2
    exit 1
  fi
  RUN_A="$WORK/runs/${RUNS[$((COUNT - 2))]}"
  RUN_B="$WORK/runs/${RUNS[$((COUNT - 1))]}"
fi

[ -d "$RUN_A" ] || { echo "ERROR=run_a_missing:$RUN_A" >&2; exit 1; }
[ -d "$RUN_B" ] || { echo "ERROR=run_b_missing:$RUN_B" >&2; exit 1; }

TS_A=$(basename "$RUN_A")
TS_B=$(basename "$RUN_B")
OUT="$RUN_B/diff-from-$TS_A.md"

python3 - "$RUN_A" "$RUN_B" "$OUT" <<'PYEOF'
import os, sys, json
from collections import defaultdict

run_a, run_b, out = sys.argv[1], sys.argv[2], sys.argv[3]

def load_tsv(path):
    """Lee TSV con header. Devuelve (headers, list of dict)."""
    if not os.path.exists(path):
        return [], []
    with open(path) as f:
        lines = [l.rstrip('\n') for l in f if l.strip()]
    if not lines:
        return [], []
    headers = lines[0].split('\t')
    rows = []
    for ln in lines[1:]:
        parts = ln.split('\t')
        rows.append(dict(zip(headers, parts + [''] * (len(headers) - len(parts)))))
    return headers, rows

def load_meta(path):
    p = os.path.join(path, "meta.json")
    if not os.path.exists(p):
        return {}
    return json.load(open(p))

meta_a = load_meta(run_a)
meta_b = load_meta(run_b)

ent_a = {r['name']: r for _, rows in [load_tsv(os.path.join(run_a, "entities.tsv"))] for r in rows}
ent_b = {r['name']: r for _, rows in [load_tsv(os.path.join(run_b, "entities.tsv"))] for r in rows}

tl_a = [r for _, rows in [load_tsv(os.path.join(run_a, "timeline.tsv"))] for r in rows]
tl_b = [r for _, rows in [load_tsv(os.path.join(run_b, "timeline.tsv"))] for r in rows]

th_a = [r for _, rows in [load_tsv(os.path.join(run_a, "threads.tsv"))] for r in rows]
th_b = [r for _, rows in [load_tsv(os.path.join(run_b, "threads.tsv"))] for r in rows]

# --- diffs ---
new_entities = sorted(set(ent_b) - set(ent_a))
gone_entities = sorted(set(ent_a) - set(ent_b))
freq_changes = []
for n in sorted(set(ent_a) & set(ent_b)):
    f_a = int(ent_a[n].get('freq', 0) or 0)
    f_b = int(ent_b[n].get('freq', 0) or 0)
    if f_a != f_b:
        freq_changes.append((n, f_a, f_b, f_b - f_a))
freq_changes.sort(key=lambda x: -abs(x[3]))

# Hilos: clave estable = (type, line, excerpt[:80])
def thread_key(r):
    return (r.get('type', ''), r.get('line', ''), r.get('excerpt', '')[:80])

th_a_idx = {thread_key(r): r for r in th_a}
th_b_idx = {thread_key(r): r for r in th_b}

new_threads = [th_b_idx[k] for k in th_b_idx if k not in th_a_idx]
resolved_now = []
unresolved_still = []
for k in set(th_a_idx) & set(th_b_idx):
    a, b = th_a_idx[k], th_b_idx[k]
    a_res, b_res = a.get('resolved', '?'), b.get('resolved', '?')
    if a_res == 'no' and b_res == 'yes':
        resolved_now.append(b)
    elif a_res == 'no' and b_res == 'no':
        unresolved_still.append(b)

gone_threads = [th_a_idx[k] for k in th_a_idx if k not in th_b_idx]

# Marcadores temporales nuevos
def tl_key(r):
    return (r.get('line', ''), r.get('marker', ''))
tl_a_keys = {tl_key(r) for r in tl_a}
new_tl = [r for r in tl_b if tl_key(r) not in tl_a_keys]

# --- escribir reporte ---
lines_out = []
lines_out.append(f"# Diff de auditoría — {os.path.basename(run_a)} → {os.path.basename(run_b)}\n")

words_a = meta_a.get('words', '?')
words_b = meta_b.get('words', '?')
hash_changed = meta_a.get('content_hash') != meta_b.get('content_hash')
lines_out.append(f"**Manuscrito:** {meta_b.get('source', '?')}")
lines_out.append(f"**Palabras:** {words_a} → {words_b}")
lines_out.append(f"**Texto cambió:** {'sí' if hash_changed else 'no (mismas palabras)'}")
lines_out.append("")

if not hash_changed and not (freq_changes or new_entities or gone_entities or new_threads or resolved_now or new_tl):
    lines_out.append("Sin cambios significativos entre ambos runs.")
else:
    if new_entities:
        lines_out.append(f"## Entidades nuevas ({len(new_entities)})")
        for n in new_entities[:30]:
            r = ent_b[n]
            lines_out.append(f"- **{n}** ({r.get('type', '?')}) · freq {r.get('freq', '?')} · primera mención: {r.get('first_chapter', '?')} L{r.get('first_line', '?')}")
        if len(new_entities) > 30:
            lines_out.append(f"- … y {len(new_entities) - 30} más")
        lines_out.append("")

    if gone_entities:
        lines_out.append(f"## Entidades que desaparecieron ({len(gone_entities)})")
        lines_out.append("> Probable causa: edición eliminó menciones, o el extractor mejoró clasificación.")
        for n in gone_entities[:20]:
            lines_out.append(f"- {n}")
        lines_out.append("")

    if freq_changes:
        lines_out.append(f"## Cambios de frecuencia ({len(freq_changes)})")
        lines_out.append("| Entidad | Antes | Ahora | Δ |")
        lines_out.append("|---|---|---|---|")
        for n, fa, fb, d in freq_changes[:15]:
            sign = "+" if d > 0 else ""
            lines_out.append(f"| {n} | {fa} | {fb} | {sign}{d} |")
        if len(freq_changes) > 15:
            lines_out.append(f"\n… y {len(freq_changes) - 15} más cambios menores")
        lines_out.append("")

    if new_threads:
        lines_out.append(f"## Hilos nuevos ({len(new_threads)})")
        for r in new_threads[:20]:
            res_icon = "✓" if r.get('resolved') == 'yes' else "🧵"
            lines_out.append(f"- {res_icon} **{r.get('type', '?')}** · {r.get('chapter', '?')} L{r.get('line', '?')}")
            lines_out.append(f"  > {r.get('excerpt', '')[:160]}")
        lines_out.append("")

    if resolved_now:
        lines_out.append(f"## Hilos cerrados desde el último run ({len(resolved_now)})")
        for r in resolved_now[:20]:
            lines_out.append(f"- ✓ **{r.get('type', '?')}** · {r.get('chapter', '?')} L{r.get('line', '?')}")
            lines_out.append(f"  > {r.get('excerpt', '')[:160]}")
            lines_out.append(f"  Cierre detectado en línea {r.get('resolution_line', '?')}")
        lines_out.append("")

    if unresolved_still:
        lines_out.append(f"## Hilos aún sin resolver ({len(unresolved_still)})")
        lines_out.append("> Persisten desde el run anterior. Considera cerrarlos o marcarlos deliberados.")
        for r in unresolved_still[:10]:
            lines_out.append(f"- 🧵 {r.get('type', '?')} · {r.get('chapter', '?')} L{r.get('line', '?')}: {r.get('excerpt', '')[:120]}")
        if len(unresolved_still) > 10:
            lines_out.append(f"- … y {len(unresolved_still) - 10} más")
        lines_out.append("")

    if new_tl:
        lines_out.append(f"## Marcadores temporales nuevos ({len(new_tl)})")
        for r in new_tl[:15]:
            lines_out.append(f"- L{r.get('line', '?')} · {r.get('chapter', '?')} · `{r.get('marker', '?')}`")
        lines_out.append("")

with open(out, 'w') as f:
    f.write('\n'.join(lines_out))

# stdout: resumen breve
print(f"DIFF_FILE={out}")
print(f"NEW_ENTITIES={len(new_entities)}")
print(f"GONE_ENTITIES={len(gone_entities)}")
print(f"FREQ_CHANGED={len(freq_changes)}")
print(f"NEW_THREADS={len(new_threads)}")
print(f"RESOLVED_NOW={len(resolved_now)}")
print(f"UNRESOLVED_STILL={len(unresolved_still)}")
print(f"NEW_TIMELINE_MARKERS={len(new_tl)}")
PYEOF

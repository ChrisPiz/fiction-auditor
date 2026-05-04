#!/usr/bin/env bash
# check-update.sh — detecta updates remotos, notifica máx 1x/día.
# Silencioso si: no hay git, no hay network, ya estás al día, o checkeaste hace <24h.
# Output: aviso humano si hay commits nuevos.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SKILL_DIR="$(dirname "$SCRIPT_DIR")"

# Skip si no es git repo (ej. instalado vía ZIP en Claude Desktop)
[ ! -d "$SKILL_DIR/.git" ] && exit 0

# Throttle: máx 1 chequeo cada 24h. Cache en ~/.trama/
TRAMA_HOME="${TRAMA_HOME:-${NARRATIVE_HOME:-$HOME/.trama}}"
mkdir -p "$TRAMA_HOME" 2>/dev/null || exit 0
STATE_FILE="$TRAMA_HOME/.last-update-check"
NOW=$(date +%s)
if [ -f "$STATE_FILE" ]; then
  LAST=$(cat "$STATE_FILE" 2>/dev/null || echo 0)
  AGE=$((NOW - LAST))
  [ "$AGE" -lt 86400 ] && exit 0
fi

# Fetch con timeout 5s — si falla la red, salí silencioso
(
  git -C "$SKILL_DIR" fetch --quiet origin main 2>/dev/null &
  FPID=$!
  ( sleep 5 && kill -9 $FPID 2>/dev/null ) &
  TPID=$!
  wait $FPID 2>/dev/null
  RC=$?
  kill $TPID 2>/dev/null
  exit $RC
) || { echo "$NOW" > "$STATE_FILE"; exit 0; }

# Compara HEAD local vs origin/main
LOCAL=$(git -C "$SKILL_DIR" rev-parse main 2>/dev/null || echo "")
REMOTE=$(git -C "$SKILL_DIR" rev-parse origin/main 2>/dev/null || echo "")

# Persiste timestamp incluso si fue exitoso (no re-checkear hasta mañana)
echo "$NOW" > "$STATE_FILE"

[ -z "$LOCAL" ] || [ -z "$REMOTE" ] && exit 0
[ "$LOCAL" = "$REMOTE" ] && exit 0

BEHIND=$(git -C "$SKILL_DIR" rev-list --count "$LOCAL..$REMOTE" 2>/dev/null || echo "?")
LATEST_MSG=$(git -C "$SKILL_DIR" log --format=%s -1 "$REMOTE" 2>/dev/null || echo "")

cat <<EOF

🔄 Trama tiene $BEHIND commit(s) nuevo(s) en GitHub.
   Último: $LATEST_MSG
   Actualizar:  cd "$SKILL_DIR" && git pull

EOF

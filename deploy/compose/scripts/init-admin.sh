#!/usr/bin/env sh
# init-admin: ensure the memory-core system_admin user exists (idempotent).
#
# Reads its inputs from the container environment (populated by `env_file: .env`
# in docker-compose.yml), so the Compose file itself never embeds shell
# variable references (which Compose would try to interpolate).
#
# Env:
#   MEMORY_CORE_ADMIN_USERNAME   (default: admin)
#   MEMORY_CORE_ADMIN_USER_KEY   -> the user_key; also the value clients pass
#                                   as `x-tdai-user-key` when going through proxy
#   MEMORY_CORE_ADMIN_URL        (default: http://memory-core:8420)
#   MEMORY_CORE_GATEWAY_API_KEY  (optional Bearer; empty = gateway auth disabled)
set -u

GATEWAY="${MEMORY_CORE_ADMIN_URL:-http://memory-core:8420}"
USERNAME="${MEMORY_CORE_ADMIN_USERNAME:-admin}"
USER_KEY="${MEMORY_CORE_ADMIN_USER_KEY:-}"
BODY="{\"username\":\"${USERNAME}\",\"user_key\":\"${USER_KEY}\"}"

# Build curl args as a proper list so the optional Bearer header keeps its
# spaces/quotes intact (no eval needed).
set -- -sS --max-time 30 \
  -X POST -H 'Content-Type: application/json' -H 'x-tdai-service-id: default' \
  "${GATEWAY}/v3/internal/meta/user/init-admin" -d "$BODY"
if [ -n "${MEMORY_CORE_GATEWAY_API_KEY:-}" ]; then
  set -- "$@" -H "Authorization: Bearer ${MEMORY_CORE_GATEWAY_API_KEY}"
fi

code=$(curl "$@" -o /tmp/admin-resp -w '%{http_code}' 2>/dev/null || echo "000")

case "$code" in
  200) echo "[init-admin] admin user created (HTTP 200)" ;;
  409) echo "[init-admin] admin user already exists (HTTP 409) — reuse" ;;
  *)   echo "[init-admin] FAILED (HTTP $code)"; cat /tmp/admin-resp 2>/dev/null || true; exit 1 ;;
esac

echo "[init-admin] admin user_key = ${USER_KEY} (use as x-tdai-user-key when calling proxy)"

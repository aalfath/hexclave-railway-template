#!/bin/bash
# Railway wrapper for the official Hexclave server image: derives the public URLs from
# Railway's domain, sets safe self-host defaults, and runs Caddy + the cron loop next to
# upstream's own entrypoint (migrations, seed, backend :8102, dashboard :8101).
set -euo pipefail

: "${PORT:=8080}"
export BACKEND_PORT=${BACKEND_PORT:-8102}
export DASHBOARD_PORT=${DASHBOARD_PORT:-8101}

if [ -z "${NEXT_PUBLIC_HEXCLAVE_API_URL:-}" ] || [ -z "${NEXT_PUBLIC_HEXCLAVE_DASHBOARD_URL:-}" ]; then
  if [ -z "${RAILWAY_PUBLIC_DOMAIN:-}" ]; then
    echo "ERROR: no public domain. Generate a domain for this service (Settings > Networking), or set NEXT_PUBLIC_HEXCLAVE_API_URL and NEXT_PUBLIC_HEXCLAVE_DASHBOARD_URL." >&2
    exit 1
  fi
fi
export NEXT_PUBLIC_HEXCLAVE_API_URL=${NEXT_PUBLIC_HEXCLAVE_API_URL:-https://${RAILWAY_PUBLIC_DOMAIN:-}}
export NEXT_PUBLIC_HEXCLAVE_DASHBOARD_URL=${NEXT_PUBLIC_HEXCLAVE_DASHBOARD_URL:-https://${RAILWAY_PUBLIC_DOMAIN:-}}

# Railway's edge, then Caddy in this container, are the only way in from the internet.
export HEXCLAVE_TRUSTED_PROXY=${HEXCLAVE_TRUSTED_PROXY:-generic}
export HEXCLAVE_EMAILABLE_API_KEY=${HEXCLAVE_EMAILABLE_API_KEY:-disable_email_validation}
# Self-hosted instances aren't billed by Hexclave: skip its cloud plan quotas.
export HEXCLAVE_DISABLE_PLAN_LIMITS=${HEXCLAVE_DISABLE_PLAN_LIMITS:-true}

# ClickHouse defaults that match the clickhouse service of this template.
export HEXCLAVE_CLICKHOUSE_ADMIN_USER=${HEXCLAVE_CLICKHOUSE_ADMIN_USER:-stackframe}
export HEXCLAVE_CLICKHOUSE_DATABASE=${HEXCLAVE_CLICKHOUSE_DATABASE:-analytics}

# Dashboard access: only the seeded admin can sign in until you invite others.
export HEXCLAVE_SEED_INTERNAL_PROJECT_SIGN_UP_ENABLED=${HEXCLAVE_SEED_INTERNAL_PROJECT_SIGN_UP_ENABLED:-false}
export HEXCLAVE_SEED_INTERNAL_PROJECT_USER_INTERNAL_ACCESS=${HEXCLAVE_SEED_INTERNAL_PROJECT_USER_INTERNAL_ACCESS:-true}

for v in HEXCLAVE_DATABASE_CONNECTION_STRING HEXCLAVE_SERVER_SECRET HEXCLAVE_CLICKHOUSE_URL HEXCLAVE_CLICKHOUSE_ADMIN_PASSWORD HEXCLAVE_CLICKHOUSE_EXTERNAL_PASSWORD; do
  legacy=${v/HEXCLAVE_/STACK_}
  if [ -z "${!v:-}" ] && [ -z "${!legacy:-}" ]; then
    echo "ERROR: $v is not set." >&2
    exit 1
  fi
done
if [ -z "${HEXCLAVE_SEED_INTERNAL_PROJECT_USER_EMAIL:-}" ] || [ -z "${HEXCLAVE_SEED_INTERNAL_PROJECT_USER_PASSWORD:-}" ]; then
  echo "WARNING: HEXCLAVE_SEED_INTERNAL_PROJECT_USER_EMAIL/PASSWORD not set; no dashboard admin will be created." >&2
fi

# Wait for the databases (migrations run before the API listens and fail hard if either is down).
db_url=${HEXCLAVE_DATABASE_CONNECTION_STRING:-${STACK_DATABASE_CONNECTION_STRING:-}}
ch_url=${HEXCLAVE_CLICKHOUSE_URL:-${STACK_CLICKHOUSE_URL:-}}
for i in $(seq 1 90); do
  pg_isready -q -d "$db_url" -t 3 && break
  [ "$i" = 1 ] && echo "Waiting for Postgres..."
  sleep 2
done
for i in $(seq 1 90); do
  node -e 'fetch(process.argv[1].replace(/\/+$/, "") + "/ping", { signal: AbortSignal.timeout(3000) }).then(r => process.exit(r.ok ? 0 : 1), () => process.exit(1))' "$ch_url" && break
  [ "$i" = 1 ] && echo "Waiting for ClickHouse..."
  sleep 2
done

pids=()
caddy run --config /etc/hexclave/Caddyfile --adapter caddyfile &
pids+=($!)
node /etc/hexclave/cron.mjs &
pids+=($!)
cd /app
./entrypoint.sh &
pids+=($!)

term() { kill -TERM "${pids[@]}" 2>/dev/null || true; }
trap term TERM INT

set +e
wait -n "${pids[@]}"
code=$?
set -e
term
wait 2>/dev/null || true
exit "$code"

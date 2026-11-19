# Hexclave (formerly Stack Auth) server: API backend + dashboard in one image.
# Upstream publishes stackauth/server tagged by commit only. 7309015 is the head of
# hexclave/hexclave `main` (dashboard/backend 1.0.137, built 2026-11-13).
FROM caddy:2.11.9-alpine@sha256:003a97808e781aa9f7e75cc2f43d34d461099031faf5e20faefb9f61126836f0 AS caddy

FROM stackauth/server:7309015@sha256:a3faf3844783611e88b68a2a3a0669983f487549ea875b22aebd3a94a6ed9399

# Caddy (static binary) puts the API and the dashboard behind one Railway domain.
COPY --from=caddy /usr/bin/caddy /usr/local/bin/caddy
COPY --chown=node:node Caddyfile /etc/hexclave/Caddyfile
COPY --chown=node:node --chmod=755 start.sh /etc/hexclave/start.sh
COPY --chown=node:node cron.mjs /etc/hexclave/cron.mjs

ENV PORT=8080 \
    XDG_CONFIG_HOME=/tmp/caddy-config \
    XDG_DATA_HOME=/tmp/caddy-data

# Railway runs its own health check (/health?db=1 through Caddy).
HEALTHCHECK NONE

ENTRYPOINT ["/etc/hexclave/start.sh"]

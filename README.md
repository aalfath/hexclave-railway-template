[![Deploy on Railway](https://railway.com/button.svg)](https://railway.com/new/template/hexclave?utm_medium=integration&utm_source=button&utm_campaign=hexclave)

# Hexclave on Railway

A Railway template for [Hexclave](https://hexclave.com) (formerly Stack Auth), the open-source user infrastructure platform: authentication, teams, RBAC, API keys, payments and emails, with an admin dashboard and a REST API your apps call through the Hexclave SDKs.

## What it deploys

| Service | Source | Notes |
| --- | --- | --- |
| `Hexclave` | [`hexclave/`](hexclave/) | Official `stackauth/server:7309015` image (Hexclave 1.0.137), pinned by digest. Runs the API backend and the dashboard, with a small Caddy proxy so both share one public domain (`/api/*` and `/health` go to the API, everything else to the dashboard), and a loop that runs Hexclave's email-queue and workflow jobs. |
| `ClickHouse` | [`clickhouse/`](clickhouse/) | `clickhouse/clickhouse-server:25.10.7.6`, pinned by digest, for Hexclave's analytics. Data on a volume. |
| `Postgres` | Railway Postgres | Hexclave's main database. Data on a volume. |

On first boot Hexclave runs its database migrations and seed script (a few minutes), then creates the dashboard admin from the email you enter and a generated password. Sign-up to the dashboard is off.

## Variables

| Variable | Service | Default | Notes |
| --- | --- | --- | --- |
| `HEXCLAVE_SEED_INTERNAL_PROJECT_USER_EMAIL` | Hexclave | prompt | Email of the dashboard admin. |
| `HEXCLAVE_SEED_INTERNAL_PROJECT_USER_PASSWORD` | Hexclave | `${{secret(24)}}` | Admin password, generated. Read it in the service's Variables tab. |
| `HEXCLAVE_SERVER_SECRET` | Hexclave | `${{secret(43, …)}}` | JWT signing secret (base64url). Keep it stable. |
| `CRON_SECRET` | Hexclave | `${{secret(32)}}` | Bearer token of the internal maintenance endpoints. |
| `HEXCLAVE_DATABASE_CONNECTION_STRING` | Hexclave | `${{Postgres.DATABASE_URL}}` | |
| `HEXCLAVE_CLICKHOUSE_*` | Hexclave | references to `ClickHouse` | URL, admin password and a generated password for the limited analytics user. |
| `CLICKHOUSE_PASSWORD` | ClickHouse | `${{secret(32)}}` | |

The public URL is taken from the service's Railway domain (`RAILWAY_PUBLIC_DOMAIN`). For a custom domain, set `NEXT_PUBLIC_HEXCLAVE_API_URL` and `NEXT_PUBLIC_HEXCLAVE_DASHBOARD_URL` to `https://YOUR-DOMAIN`. Optional features are configured with Hexclave's own variables, see the [self-hosting guide](https://docs.hexclave.com/guides/other/self-host): SMTP (`HEXCLAVE_EMAIL_*`, or set it in the dashboard), S3 storage (`HEXCLAVE_S3_*`), webhooks (`HEXCLAVE_SVIX_API_KEY`), AI features (`HEXCLAVE_OPENROUTER_API_KEY`), custom email code (`HEXCLAVE_FREESTYLE_API_KEY`).

## Using it from your app

Create a project in the dashboard, then point the SDK at your instance:

```env
NEXT_PUBLIC_HEXCLAVE_API_URL=https://YOUR-HEXCLAVE-DOMAIN
HEXCLAVE_API_URL=https://YOUR-HEXCLAVE-DOMAIN
```

and use the project ID and keys shown in your dashboard.

## Updates

Every service except Postgres builds from this repository. When a new Hexclave image is pinned here and merged to `main`, Railway shows an "update available" notice on projects deployed from the template, and you choose when to apply it. Hexclave runs its migrations on start. Read [CHANGELOG.md](CHANGELOG.md) first, and back up Postgres before an update.

Upstream tags `stackauth/server` images by commit only, so the pin is the commit of the release on `main`.

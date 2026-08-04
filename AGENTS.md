# docker-compose-hermes

Docker Compose environment for running Hermes Agent with Ollama (local LLM) and an applets file server. Designed for homelab / single-node deployments.

## Status

ACTIVE — used for self-hosted Hermes infrastructure

## What's in the stack

| Service  | Image                        | Ports         | Purpose                        |
|----------|------------------------------|---------------|--------------------------------|
| hermes   | nousresearch/hermes-agent    | 8642, 9119    | Gateway + web dashboard        |
| applets  | caddy:2-alpine               | 80            | Static file server for applets |
| ollama   | ollama/ollama                | 11434         | Local LLM inference            |

## Quick Start

```bash
cp example.env .env
# edit .env — set HERMES_DASHBOARD_SECRET at minimum
docker compose up -d
```

## .env Variables

| Variable                     | Default      | Notes                                          |
|------------------------------|--------------|------------------------------------------------|
| HERMES_UID                   | 1000         | Filesystem owner for /opt/data                 |
| HERMES_GID                   | 1000         |                                                |
| HERMES_DASHBOARD_USERNAME    | admin        | Basic auth for dashboard at :9119              |
| HERMES_DASHBOARD_PASSWORD    | changeme     | Change this                                    |
| HERMES_DASHBOARD_SECRET      | (required)   | `openssl rand -base64 32`                      |

## Conventions

- No pushing `.env` or `data/` — those are gitignored
- Test compose changes with `docker compose config` before committing
- Port numbers are stable (8642, 9119, 80, 11434) — don't change without a reason

## Architecture Notes

- Hermes mounts the Docker socket (`/var/run/docker.sock`) for container management
- Hermes data persists at `./data/` (gitignored)
- Ollama models persist at `./ollama-data/` (gitignored)
- Applets are served read-only from `./data/applets/` by Caddy
- All three services are on the default bridge network — they can reach each other by service name

## Known Gaps

- **No `depends_on`** — services start simultaneously; Hermes might start before Ollama is ready
- **Memory limits are tight** — 4G for Hermes + 6G for Ollama = 10G minimum; a small model like `llama3.2:3b` works but larger models need more
- **No network isolation** — all three services share the default bridge; fine for single-node but worth isolating if exposed

## What's Next

1. Add `depends_on` with `condition: service_healthy` for Hermes → Ollama ordering
2. Consider network isolation (separate bridge for applets vs backend)
3. Add a `.dockerignore` for faster builds if custom images are ever introduced
4. Consider a `compose.override.yml` example for GPU passthrough

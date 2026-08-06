# Hermes Docker Compose

Self-hosted [Hermes Agent](https://hermes-agent.nousresearch.com) stack: gateway + dashboard, browser WebUI, and a static file server for applets. Single-node, homelab-friendly.

| Service       | Image                                | Ports         | Purpose                          |
|---------------|--------------------------------------|---------------|----------------------------------|
| `hermes-agent`| `nousresearch/hermes-agent:latest`   | `8642`, `9119`| Gateway API + web dashboard      |
| `hermes-webui`| `ghcr.io/nesquena/hermes-webui:latest`| `8787`        | Browser chat UI (separate container) |
| `applets`     | `caddy:2-alpine`                     | `80`          | Static file server for applets   |

## Prerequisites

- Docker 24+ with the Compose plugin (`docker compose`)
- ~5 GB RAM minimum (4G Hermes)
- Ports **80**, **8642**, **8787**, and **9119** available

## Quick Start

```bash
git clone https://github.com/cheyngoodman/docker-compose-hermes.git
cd docker-compose-hermes

cp example.env .env
# edit .env — set HERMES_DASHBOARD_SECRET (openssl rand -base64 32)
#              and HERMES_WEBUI_PASSWORD (openssl rand -base64 18)

docker compose up -d
```

## Accessing Services

| Service        | URL                       |
|----------------|---------------------------|
| Web Dashboard  | `http://localhost:9119`   |
| WebUI (chat)   | `http://localhost:8787`   |
| Applets        | `http://localhost`        |
| Hermes CLI     | `docker compose exec hermes-agent hermes --help` |

Dashboard docs: [hermes-agent.nousresearch.com/docs](https://hermes-agent.nousresearch.com/docs/user-guide/features/web-dashboard)

## Configuration

See `example.env` for all variables. `HERMES_DASHBOARD_SECRET` and `HERMES_WEBUI_PASSWORD` are required.

## Data

| Directory | Contents |
|---|---|
| `./data/` | Hermes config, sessions, skills, cron jobs, workspace, applets |

Gitignored. To reset: `docker compose down -v && rm -rf data/`

## Details

Architecture, volume design, and migration notes live in `AGENTS.md`.

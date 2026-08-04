# Hermes Docker Compose

Single-machine Docker Compose stack running [Hermes Agent](https://hermes-agent.nousresearch.com) with local LLM inference via Ollama and a static file server for applets.

## Architecture

```
┌──────────────────────────────────────────────────────┐
│  docker compose up -d                                │
│                                                      │
│  ┌──────────────┐  ┌──────────┐  ┌───────────────┐  │
│  │   caddy      │  │  hermes  │  │    ollama     │  │
│  │  :80         │  │  :8642   │  │   :11434      │  │
│  │              │  │  :9119   │  │               │  │
│  │  applets/    │  │  gateway │  │  llama3.2     │  │
│  │  file server │  │  dashbd  │  │  qwen2.5      │  │
│  └──────────────┘  └──────────┘  └───────────────┘  │
│                          │                           │
│                     /var/run/docker.sock              │
│                     (container mgmt)                  │
└──────────────────────────────────────────────────────┘
```

| Service | Image | Port | Purpose |
|---|---|---|---|
| `hermes` | `nousresearch/hermes-agent:latest` | `8642` | Gateway (API + messaging) |
| | | `9119` | Web dashboard |
| `applets` | `caddy:2-alpine` | `80` | Static file server for Hermes applets |
| `ollama` | `ollama/ollama:latest` | `11434` | Local LLM inference |

## Prerequisites

- **Docker** 24+ with the Compose plugin (`docker compose`, not `docker-compose`)
- **~10 GB RAM** minimum (4G Hermes + 6G Ollama); more if you run larger models
- Ports **80**, **8642**, **9119**, and **11434** available on the host
- A GPU is not required but helps Ollama significantly

## Quick Start

```bash
# 1. Clone
git clone https://github.com/cheyngoodman/docker-compose-hermes.git
cd docker-compose-hermes

# 2. Configure
cp example.env .env
# Generate a secret:
openssl rand -base64 32
# Edit .env — set HERMES_DASHBOARD_SECRET to the output above

# 3. Start
docker compose up -d
```

## Pulling an Ollama Model

Ollama starts empty — you need to pull at least one model:

```bash
docker compose exec ollama ollama pull llama3.2:3b
```

Or any other [Ollama model](https://ollama.com/search). Configure Hermes to use it at `http://ollama:11434` from within the `hermes` container (they share the default bridge network and can reach each other by service name).

## Accessing Services

| Service | URL | Notes |
|---|---|---|
| Web Dashboard | `http://localhost:9119` | Login with the `.env` credentials |
| Applets | `http://localhost` | Directory listing of `./data/applets/` |
| Hermes CLI | `docker compose exec hermes hermes --help` | Run commands inside the container |
| Ollama API | `http://localhost:11434` | Direct API access |

## Configuration

All settings live in `.env`. See `example.env` for the full list.

| Variable | Default | Required |
|---|---|---|
| `HERMES_DASHBOARD_SECRET` | — | **Yes** |
| `HERMES_DASHBOARD_USERNAME` | `admin` | No |
| `HERMES_DASHBOARD_PASSWORD` | `changeme` | No |
| `HERMES_UID` / `HERMES_GID` | `1000` | No |

Full dashboard documentation: [hermes-agent.nousresearch.com/docs](https://hermes-agent.nousresearch.com/docs/user-guide/features/web-dashboard)

## Troubleshooting

**Dashboard says "refused to connect"**
The container has a 60-second startup grace period. Run `docker compose ps` — status should show `(healthy)` when ready.

**Ollama is slow on first request**
The model unloads after 5 minutes of inactivity (`OLLAMA_KEEP_ALIVE=5m`). The first request after idle will be a cold load. Increase this in `docker-compose.yml` if you prefer always-warm models (at the cost of RAM).

**Port conflicts**
If ports 80, 8642, 9119, or 11434 are in use, edit the left-hand side of the port mapping in `docker-compose.yml` (e.g., `- 8080:80`).

**Hermes can't reach Ollama**
From within the Hermes container, test with:
```bash
docker compose exec hermes curl http://ollama:11434/api/tags
```

## Data Persistence

| Directory | Contents | Gitignored |
|---|---|---|
| `./data/` | Hermes config, sessions, skills, cron jobs | Yes |
| `./ollama-data/` | Pulled Ollama models | Yes |

To reset everything: `docker compose down -v && rm -rf data/ ollama-data/`

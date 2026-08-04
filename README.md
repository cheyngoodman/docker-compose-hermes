# Hermes Docker Compose

Single-machine Docker Compose stack running [Hermes Agent](https://hermes-agent.nousresearch.com) with local LLM inference via Ollama and a static file server for applets.

| Service | Image | Port | Purpose |
|---|---|---|---|
| `hermes` | `nousresearch/hermes-agent:latest` | `8642` | Gateway (API + messaging) |
| | | `9119` | Web dashboard |
| `applets` | `caddy:2-alpine` | `80` | Static file server for Hermes applets |
| `ollama` | `ollama/ollama:latest` | `11434` | Local LLM inference |

## Prerequisites

- Docker 24+ with the Compose plugin (`docker compose`)
- ~10 GB RAM minimum (4G Hermes + 6G Ollama)
- Ports **80**, **8642**, **9119**, and **11434** available

## Quick Start

```bash
git clone https://github.com/cheyngoodman/docker-compose-hermes.git
cd docker-compose-hermes

cp example.env .env
# edit .env — set HERMES_DASHBOARD_SECRET (openssl rand -base64 32)

docker compose up -d
```

## Pulling an Ollama Model

Ollama starts empty — pull at least one model before using Hermes:

```bash
docker compose exec ollama ollama pull llama3.2:3b
```

Configure Hermes to use `http://ollama:11434` (services reach each other by name on the default bridge).

## Accessing Services

| Service | URL |
|---|---|
| Web Dashboard | `http://localhost:9119` |
| Applets | `http://localhost` |
| Hermes CLI | `docker compose exec hermes hermes --help` |
| Ollama API | `http://localhost:11434` |

Dashboard docs: [hermes-agent.nousresearch.com/docs](https://hermes-agent.nousresearch.com/docs/user-guide/features/web-dashboard)

## Configuration

See `example.env` for all variables. `HERMES_DASHBOARD_SECRET` is required.

## Data

| Directory | Contents |
|---|---|
| `./data/` | Hermes config, sessions, skills, cron jobs |
| `./ollama-data/` | Pulled Ollama models |

Both are gitignored. To reset: `docker compose down -v && rm -rf data/ ollama-data/`
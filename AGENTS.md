# docker-compose-hermes

Docker Compose environment for running Hermes Agent with Ollama (local LLM) and an applets file server. Designed for homelab / single-node deployments.

## Status

ACTIVE — used for self-hosted Hermes infrastructure

## What's in the stack

| Service  | Image                        | Ports         | Purpose                        |
|----------|------------------------------|---------------|--------------------------------|
| hermes   | nousresearch/hermes-agent    | 8642, 9119, 8787 | Gateway + dashboard + WebUI    |
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
| HERMES_WEBUI_ENABLED         | 1            | Set to 0 to disable the in-container WebUI     |
| HERMES_WEBUI_PASSWORD        | (required)   | Password for WebUI auth; `openssl rand -base64 18` |

## Hermes WebUI

The [hermes-webui](https://github.com/nesquena/hermes-webui) runs **inside** the Hermes container (not as a separate service). It reads the agent's config directly from `/opt/data/config.yaml` and stores its state at `/opt/data/hermes-webui-state` — both on the persistent volume.

### Architecture

| Component          | Location                        | Persistent? |
|--------------------|--------------------------------|-------------|
| WebUI code         | `/opt/data/hermes-webui`       | Yes (volume) |
| WebUI state        | `/opt/data/hermes-webui-state` | Yes (volume) |
| Agent code + venv  | `/opt/hermes`                  | No (image)  |
| Agent config       | `/opt/data/config.yaml`        | Yes (volume) |
| Auth password      | `/opt/data/hermes-webui/.env`  | Yes (volume) |

The agent venv path (`/opt/hermes/.venv/bin/python3`) is stable across image versions. When the container image updates, the WebUI code persists but needs a restart.

### Startup (automatic)

The WebUI starts automatically with the container via `hermes.sh`. The docker-compose `command` is set to `/opt/init/hermes.sh`, which:

1. Starts `hermes gateway run` (the standard gateway)
2. Waits for gateway health at `:9119`
3. Starts the WebUI daemon via `ctl.sh start`
4. Waits for the gateway to exit (keeps the container alive)

**On first boot**, if `/opt/data/hermes-webui` doesn't exist yet and `HERMES_WEBUI_PASSWORD` is set, the init script auto-clones the repo, creates `.env` with the password and agent paths, and starts the WebUI — zero manual steps beyond setting the password in your compose `.env`.

Set `HERMES_WEBUI_ENABLED=0` in `.env` to skip the WebUI entirely.

### Recovery (if hermes.sh breaks)

If an update breaks the init script and the container won't start, set in `.env`:

```ini
HERMES_INIT_SAFE_MODE=1
```

Then `docker compose up -d`. The container will skip `hermes.sh` entirely and run `hermes gateway run` directly — the original behavior. Fix the issue, then remove the safe mode line.

### Mobile access

Once running, the WebUI is reachable at `http://<host>:8787` with the configured password. Works with [hermes-android](https://github.com/rusty4444/hermes-android) — point the app at your host IP or Tailscale address, port 8787, with the WebUI password.

## Conventions

- No pushing `.env` or `data/` — those are gitignored
- Test compose changes with `docker compose config` before committing
- Port numbers are stable (8642, 9119, 8787, 80, 11434) — don't change without a reason
- Feature branches off `main`; merge locally when approved (no `gh` CLI needed)

## Architecture Notes

- Hermes data persists at `./data/` (gitignored)
- Hermes WebUI runs in-process inside the hermes container, bound to 0.0.0.0:8787 — auth is mandatory and configured via `HERMES_WEBUI_PASSWORD` in `.env`
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

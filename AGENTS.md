# docker-compose-hermes

Docker Compose stack for self-hosted Hermes Agent with a separate WebUI container and an applets file server. Designed for single-node homelab deployments.

## Status

ACTIVE — v2 restructure on `feat/v2-separate-webui` (separate WebUI container, Ollama dropped).

## What's in the stack

| Service       | Image                                | Ports         | Purpose                         |
|---------------|--------------------------------------|---------------|---------------------------------|
| hermes-agent  | nousresearch/hermes-agent:latest     | 8642, 9119    | Gateway + dashboard             |
| hermes-webui  | ghcr.io/nesquena/hermes-webui:latest | 8787          | Browser chat UI (separate container) |
| applets       | caddy:2-alpine                       | 80            | Static file server for applets   |

## Volume Design

Only ONE named volume. Everything else is bind mounts pointing at host directories — same layout as v1, no migration needed.

| Mount                  | Type  | Host path          | Purpose                                          | NFS candidate? |
|------------------------|-------|--------------------|--------------------------------------------------|----------------|
| `./data`              | bind  | `data/`            | Agent state: config, sessions, skills, memory, workspace, applets | **Yes** — primary candidate; contains all durable state |
| `hermes-agent-src`    | named | Docker-managed     | Agent Python source (shared with WebUI, read-only)| **No** — ephemeral, recreated on upgrades |

### How the shared bind mount works

Both containers mount `./data` but at different internal paths:

```
Host: ./data/
  ├── config.yaml
  ├── state.db
  ├── .env
  ├── sessions/
  ├── skills/
  └── ...

Agent container         WebUI container
./data → /opt/data       ./data → /home/hermeswebui/.hermes

Agent reads config at    WebUI reads config at
/opt/data/config.yaml    /home/hermeswebui/.hermes/config.yaml

      └────── Same file on disk ──────┘
```

Both run as UID 1000 (HERMES_UID / WANTED_UID), so file ownership is consistent. No data migration — `./data/` is the same directory v1 used.

### What `hermes-agent-src` is for

The WebUI's startup script (`docker_init.bash`) needs the agent's Python source to `uv pip install` matching dependencies. This is the agent code from inside the `nousresearch/hermes-agent` image — it can't be bind-mounted because it doesn't exist on the host. Docker auto-initializes this named volume from the image on first `docker compose up`.

It's ephemeral. After `docker pull` of a new agent image:

```bash
docker compose down
docker volume rm docker-compose-hermes_hermes-agent-src
docker compose up -d
```

### NFS migration path

`./data` is the state volume. If you move to NFS-backed storage later:

1. Stop the stack
2. Move `./data/` contents to an NFS mount
3. Change the bind mount source in docker-compose.yml from `./data` to the NFS path
4. Start the stack

The containers don't care where the host directory lives — bind mounts are transparent.

## Architecture

```
hermes-net (bridge)
├── hermes-agent       gateway run (:8642) + dashboard (:9119)
│   ├── ./data          (bind mount — state + workspace)
│   └── hermes-agent-src (named volume — agent Python source)
│
├── hermes-webui       browser chat UI (:8787)
│   ├── ./data          (same bind mount, different container path)
│   └── hermes-agent-src (same named volume, read-only)
│
└── applets            caddy file-server (:80)
    └── ./data/applets  (bind mount, read-only)
```

The WebUI image is turnkey — it handles UID remapping, venv creation, and agent dep installation internally. No init scripts, no first-boot cloning.

### Disabling services

- **WebUI:** Comment out the `hermes-webui` service block (lines ~58-85).
- **Applets:** Comment out the `applets` service block.

That's the entire feature. No env var toggles, no `HERMES_WEBUI_ENABLED`.

## Quick Start

```bash
cp example.env .env
# Edit .env — set HERMES_DASHBOARD_SECRET and HERMES_WEBUI_PASSWORD at minimum
#   openssl rand -base64 32  # for dashboard secret
#   openssl rand -base64 18  # for webui password

docker compose up -d
```

If `./data/` already exists from v1, it continues working — no migration. If it doesn't exist, the agent initializes it.

## .env Variables

| Variable                     | Default      | Notes                                          |
|------------------------------|--------------|------------------------------------------------|
| HERMES_UID                   | 1000         | Container user ID                              |
| HERMES_GID                   | 1000         | Container group ID                             |
| HERMES_DASHBOARD_USERNAME    | admin        | Basic auth for dashboard at :9119              |
| HERMES_DASHBOARD_PASSWORD    | changeme     | Change this                                    |
| HERMES_DASHBOARD_SECRET      | (required)   | `openssl rand -base64 32`                      |
| HERMES_WEBUI_PASSWORD        | (required)   | WebUI login password; `openssl rand -base64 18`|

## Conventions

- No pushing `.env`, `data/`, `workspace/`, or `applets/` — gitignored
- Verify compose syntax: `docker compose config` before committing
- Port numbers are stable (8642, 9119, 8787, 80)
- **Feature branches off `main`** — never push directly to main
- Disable services by commenting out their block — no env var toggles

## What Changed (v1 → v2)

| v1                        | v2                                              |
|---------------------------|-------------------------------------------------|
| WebUI in hermes container | Separate `hermes-webui` container               |
| Init script `hermes.sh`   | `command: gateway run` — no init script needed  |
| `HERMES_WEBUI_ENABLED`    | Comment out the service block                   |
| `HERMES_INIT_SAFE_MODE`   | Not applicable — no init script to break        |
| Ollama (6GB, didn't work) | Removed                                          |
| Data volume               | Same `./data` bind mount — no migration         |
| Agent source volume       | New named volume `hermes-agent-src` (needed by WebUI) |

## Known Gaps

- **Single-node only** — no HA, no failover, no backup automation (yet)
- **Dashboard inside agent container** — could be split to its own container if resource isolation is needed later
- **No `depends_on` for applets** — starts simultaneously with agent; fine since it's independent

## What's Next

- [ ] Phase 2: Grafana + Prometheus + cadvisor for monitoring
- [ ] Automated backups of `./data/` to NAS
- [ ] Consider NFS-backed `./data/` for resilience
- [ ] Consider dashboard as separate container if resource contention becomes an issue
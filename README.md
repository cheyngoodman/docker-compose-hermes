# Hermes Docker Compose Environment

Features:
- Persistent services
- Hermes Agent
- Applets web server
- Ollama services

## Setup

Tested on Ubuntu 26.04 with Docker 5:29.6.2-1 & Docker Compose Plugin 5.3.1-1

Start / enable the services via docker compose.
```
docker compose up -d
```

Interact with hermes cli within the hermes container
```
docker compose exec -it hermes hermes --help
```

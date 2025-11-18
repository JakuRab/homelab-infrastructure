SHELL := /bin/bash

# Remote server login and directory (override via: make target SERVER=user@host DIR=/home/user/caddy)
SERVER ?= user@host
DIR    ?= $(shell ssh $(SERVER) 'echo $$HOME')/caddy

.PHONY: help
help:
	@echo "Targets:"
	@echo "  sync           - rsync configs to 	$$SERVER:$$DIR"
	@echo "  fallback-up    - start no-plugin stack on server"
	@echo "  plugin-up      - start GHCR plugin stack on server (requires docker login ghcr.io)"
	@echo "  build-local    - build xcaddy image on server (uses Dockerfile)"
	@echo "  up             - bring up xcaddy-built stack on server"
	@echo "  reload         - caddy validate+reload on server"
	@echo "  logs           - tail recent caddy logs on server"
	@echo "  login-ghcr     - docker login ghcr.io on server (interactive)"

.PHONY: sync
sync:
	ssh -t $(SERVER) "mkdir -p ""$(DIR)"""
	rsync -av --delete ./ $(SERVER):"$(DIR)"/

.PHONY: fallback-up
fallback-up:
	ssh -t $(SERVER) "cd ""$(DIR)"" && (docker compose -f docker-compose.no-plugin.yml up -d || sudo docker compose -f docker-compose.no-plugin.yml up -d)"

.PHONY: plugin-up
plugin-up:
	ssh -t $(SERVER) "cd ""$(DIR)"" && (docker compose -f docker-compose.plugin.yml up -d || sudo docker compose -f docker-compose.plugin.yml up -d)"

.PHONY: build-local
build-local:
	ssh -t $(SERVER) "cd ""$(DIR)"" && (docker compose build --no-cache --progress=plain || sudo docker compose build --no-cache)"

.PHONY: up
up:
	ssh -t $(SERVER) "cd ""$(DIR)"" && (docker compose up -d || sudo docker compose up -d)"

.PHONY: reload
reload:
	ssh -t $(SERVER) "(docker exec caddy caddy validate --config /etc/caddy/Caddyfile || true) && (docker exec caddy caddy reload --config /etc/caddy/Caddyfile || true)" || \
	ssh -t $(SERVER) "(sudo docker exec caddy caddy validate --config /etc/caddy/Caddyfile || true) && (sudo docker exec caddy caddy reload --config /etc/caddy/Caddyfile || true)"

.PHONY: logs
logs:
	ssh -t $(SERVER) "(docker logs --since 10m caddy || sudo docker logs --since 10m caddy) | sed -n '/acme/,+40p'"

.PHONY: login-ghcr
login-ghcr:
	ssh -t $(SERVER) "docker login ghcr.io || sudo docker login ghcr.io"


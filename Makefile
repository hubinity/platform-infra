# platform-infra Makefile — local dev stack convenience targets.
# Profiles:
#   default          → postgres + rabbitmq + keycloak (always on)
#   catalog          → + hb-catalog-service (built from ../hb-catalog-service)
#   observability    → + loki + promtail + grafana
# Usage examples:
#   make up                  # default stack
#   make build-catalog       # rebuild hb-catalog-service image only (no up)
#   make up-catalog          # default + hb-catalog-service (always rebuilds first)
#   make up-observability    # default + observability
#   make up-all              # everything (rebuilds hb-catalog-service first)
#   make logs SVC=keycloak   # follow logs of a service
#   make seed                # apply rabbitmq definitions + run postgres-init
#   make down                # stop & remove
#   make ps                  # status

COMPOSE := docker compose
COMPOSE_FILE := docker-compose.yml

.PHONY: help up build-catalog up-catalog up-observability up-all down ps logs seed clean

help:
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-22s\033[0m %s\n", $$1, $$2}'

up: ## Boot postgres + rabbitmq + keycloak (default stack)
	$(COMPOSE) -f $(COMPOSE_FILE) up -d
	@echo "Default stack up. UIs: rabbitmq=http://localhost:15672 keycloak=http://localhost:8081"

build-catalog: ## Rebuild the hb-catalog-service image from ../hb-catalog-service (no up)
	$(COMPOSE) -f $(COMPOSE_FILE) --profile catalog build hb-catalog-service

# --build below is deliberate: docker compose up (without it) reuses whatever
# image already exists, silently running stale hb-catalog-service code after
# a local source change. --build forces an image check every run; Docker's
# layer cache keeps that cheap when src/ hasn't actually changed.
up-catalog: ## Boot default stack + hb-catalog-service (always rebuilds first)
	$(COMPOSE) -f $(COMPOSE_FILE) --profile catalog up -d --build

up-observability: ## Boot default stack + loki + promtail + grafana
	$(COMPOSE) -f $(COMPOSE_FILE) --profile observability up -d
	@echo "Observability up. UIs: grafana=http://localhost:3000 (admin/admin) loki=http://localhost:3100"

up-all: ## Boot everything (default + catalog + observability; rebuilds hb-catalog-service first)
	$(COMPOSE) -f $(COMPOSE_FILE) --profile catalog --profile observability up -d --build

down: ## Stop and remove all containers (preserves volumes)
	$(COMPOSE) -f $(COMPOSE_FILE) --profile catalog --profile observability down

ps: ## Show status of running services
	$(COMPOSE) -f $(COMPOSE_FILE) ps

logs: ## Follow logs of one service: make logs SVC=keycloak
	@if [ -z "$(SVC)" ]; then echo "Usage: make logs SVC=<service>"; exit 1; fi
	$(COMPOSE) -f $(COMPOSE_FILE) logs -f $(SVC)

seed: ## Re-apply rabbitmq definitions (idempotent) and run postgres init
	$(COMPOSE) -f $(COMPOSE_FILE) restart rabbitmq
	@echo "RabbitMQ definitions re-applied via boot-time loader."
	@echo "(Postgres-init runs automatically on first volume create only.)"

clean: ## Stop and remove containers + volumes (DESTRUCTIVE — data loss)
	$(COMPOSE) -f $(COMPOSE_FILE) --profile catalog --profile observability down -v

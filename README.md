# platform-infra

Infrastructure-as-code and operational documentation for the **Hubinity** ecosystem.

This repository centralizes everything that lives *outside* application code:
provider provisioning notes, container orchestration manifests, infrastructure
templates, and runbooks.

## Current contents

- [`docs/setup-cloud.md`](./docs/setup-cloud.md) — exhaustive **manual setup
  checklist** for the cloud providers and accounts a single operator must
  configure to make the Hubinity ecosystem deployable. Start here.
- [`docker-compose.yml`](./docker-compose.yml) — minimal local stack for
  Hubinity development (Postgres 16, RabbitMQ 3.13 with management UI,
  Keycloak 26 with the `platform-iam` realm export pre-mounted). The full
  multi-service stack lands in feature 0.1; this file is the seed.
- [`local/postgres-init.sh`](./local/postgres-init.sh) — entrypoint shim
  that creates one database per name listed in the
  `POSTGRES_MULTIPLE_DATABASES` env var (read by the official Postgres
  image's `/docker-entrypoint-initdb.d` hook).

### Running the local stack

Bring up the infra-only services (no application containers):

```bash
docker compose up -d postgres rabbitmq keycloak
```

Bring up an application together with its infra dependencies via Compose
**profiles**. Each backend microservice is gated behind a profile so a
contributor working on one service does not pay the cost of building all of
them:

```bash
# Catalog service + its dependencies (Postgres / RabbitMQ / Keycloak)
docker compose --profile catalog up
```

Available profiles today: `catalog` (more land alongside features 0.1 and
1.x – 3.x). Run `docker compose --profile <name> config` to preview which
services a profile activates.

## Planned contents (TBD in later features)

The following will be added in subsequent Fase 0 / Fase 1 features:

- `docker-compose/` — expanded local development stack (Logtail/Grafana
  mocks, OTEL collector, gateway) so contributors can run the whole
  platform offline.
- `k8s/` — Kubernetes manifests (Helm charts or Kustomize overlays) for the
  production targets that outgrow Railway's free/hobby tier.
- `terraform/` — Infrastructure-as-code templates for provisioning Supabase
  projects, Railway services, CloudAMQP instances, and DNS records
  reproducibly.
- `runbooks/` — Operational runbooks (incident response, deploy rollback,
  database restore, secret rotation, on-call rotation).
- `monitoring/` — Grafana dashboards, alert rules, and Better Stack source
  configuration exports.

## Conventions

- Every external provider's setup steps live in `docs/setup-cloud.md`.
- Secrets are **never** committed; placeholders use `${UPPER_SNAKE_CASE}`.
- IaC, when added, must be idempotent and runnable from a clean checkout.

## Related repositories

- `platform-shared-contracts` — shared Java DTOs, OpenAPI specs, Avro schemas.
- `platform-api-gateway` — Spring Cloud Gateway in front of the backends.
- `platform-iam` — Keycloak realm export and IAM configuration.
- `hb-catalog-service`, `hb-support-service`, `sc-order-service`,
  `hb-cashier-service` — Spring Boot backends.
- `hb-catalog-web`, `hb-support-web`, `hb-cashier-web` — Angular backoffices.
- `sc-totem-web` — Angular PWA for the self-service totem.

## Local stack — services & profiles

The compose file ships three Docker profiles. The default stack starts only the
foundational services so cold start stays under ~30 seconds; the others are
opt-in via Compose profiles.

| Profile | Services | Purpose |
|---|---|---|
| _(default)_ | postgres, rabbitmq, keycloak | Always required for any backend |
| `catalog` | + hb-catalog-service | Runs the catalog service in-stack |
| `observability` | + loki, promtail, grafana | Logs pipeline + dashboards (Phase 5 prep) |

### Quickstart via Makefile

```bash
make up                 # default stack
make up-catalog         # default + catalog service
make up-observability   # default + observability
make up-all             # everything
make logs SVC=keycloak  # follow logs of a single service
make seed               # re-apply RabbitMQ exchange/DLQ definitions
make down               # stop & remove containers (keeps data volumes)
make clean              # stop + nuke volumes (destructive)
```

### UI endpoints (when running)

| Service | URL | Credentials |
|---|---|---|
| RabbitMQ management | http://localhost:15672 | `hubinity` / `hubinity_local` |
| Keycloak admin | http://localhost:8081 | `admin` / `admin` |
| Grafana | http://localhost:3000 | `admin` / `admin` (anonymous viewer enabled) |
| Loki API | http://localhost:3100/ready | _(no auth in dev)_ |
| hb-catalog-service | http://localhost:8080/actuator/health | JWT required for `/api/**` |

### RabbitMQ exchanges seeded at boot

`local/rabbitmq-definitions.json` declares the 3 cross-service event exchanges
plus their DLX siblings:
- `catalog.events` / `catalog.events.dlx`
- `order.events` / `order.events.dlx`
- `support.events` / `support.events.dlx`

Queues + bindings are owned by individual consumer services (catalog is the
first publisher; cashier is the first consumer once Phase 2 lands).

### Observability provisioning

- Loki ingests Docker container logs via Promtail's Docker SD.
- Grafana is provisioned with two datasources:
  - **Loki** — default, queries `http://loki:3100`
  - **Catalog-Actuator** — opt-in Prometheus scrape of
    `http://hb-catalog-service:8080/actuator/prometheus`. Requires the
    `catalog` profile to also be up. Phase 5 will replace this with a real
    Prometheus container.
- A `Hubinity` dashboards folder is reserved. Dashboards land in Phase 5
  (PRD task 5.3) and are mounted from `local/observability/grafana/provisioning/dashboards/`.

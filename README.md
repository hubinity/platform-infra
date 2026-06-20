# platform-infra (Infra) - Ecossistema Hubinity - Active
> Parte integrante do ecossistema distribuído Hubinity.

---

## 💻 Visão Geral
- **O que faz:** Centraliza tudo que vive *fora* do código de aplicação: o stack de **desenvolvimento local** (Docker Compose + Makefile + scripts de seed + observability) e o **checklist exaustivo de provisionamento cloud** (manual, em `docs/setup-cloud.md`). Um único operador clona este repo e tem dois caminhos: `make up` para subir o ambiente local de qualquer backend Hubinity, ou seguir `docs/setup-cloud.md` para provisionar Supabase + CloudAMQP + Railway + DNS.
- **Problema que resolve:** Sem este repo, cada contribuidor reinventaria a configuração local (Postgres + RabbitMQ + Keycloak + observability), divergindo em credenciais/portas/profiles e gerando "funciona na minha máquina". Para cloud, sem o checklist, o provisionamento manual viraria conhecimento tácito de uma pessoa.
- **Posicionamento no Ecossistema:** Camada de **DevOps / IaC local**. Não é consumida em runtime por outros serviços, mas é pré-requisito de qualquer dev local: monta o realm export do `platform-iam` no Keycloak, builda o `hb-catalog-service` via profile opt-in, e provê o backbone Postgres/RabbitMQ que os 4 backends consomem.

## 🏗️ Papel na Arquitetura
- **Tipo de Componente:** Infraestrutura local declarativa (Docker Compose v2) + automação Make + checklist operacional cloud.
- **Responsabilidades Principais:**
  - Subir a stack base de desenvolvimento: Postgres 16, RabbitMQ 3.13 (com management UI), Keycloak 26 (com realms pré-importados via volume read-only).
  - Inicializar 4 bancos Postgres independentes via script multi-DB (`hb_catalog`, `hb_support`, `hb_cashier`, `sc_order`).
  - Pré-popular RabbitMQ com 6 exchanges (3 de domínio + 3 DLX) via `definitions.json` carregado no boot.
  - Prover stack de **observability local** (Loki + Promtail + Grafana) com datasources já provisionados, atrás do profile `observability`.
  - Permitir builds opt-in de microsserviços via profiles (`catalog` hoje; outros virão nas Fases 1.x – 3.x).
  - Hospedar o checklist `docs/setup-cloud.md` como source-of-truth do provisionamento manual cloud.
- **Limites e Fronteiras (Boundaries):**
  - **Não** contém código de aplicação, só infraestrutura.
  - **Não** provisiona cloud automaticamente (Terraform virá em features posteriores; hoje o checklist é manual).
  - **Não** define realms Keycloak — apenas monta os JSONs de `../platform-iam/realms/`.

## 🔗 Dependências e Comunicação
### Serviços Internos da Hubinity
- **`platform-iam`** — mount read-only de `../platform-iam/realms/` em `/opt/keycloak/data/import` no container Keycloak.
- **`hb-catalog-service`** — build local via `dockerfile: ../hb-catalog-service/Dockerfile` quando o profile `catalog` é ativado.
- **Consumidores** (todos os backends/frontends rodando localmente apontam para os endpoints expostos por esta stack): catalog/support/cashier/order services + 4 SPAs Angular.

### Infraestrutura e Serviços Externos
- **Docker Engine** (compose v2)
- **Imagens upstream:** `postgres:16-alpine`, `rabbitmq:3.13-management-alpine`, `quay.io/keycloak/keycloak:26.0`, `grafana/loki:3.2.1`, `grafana/promtail:3.2.1`, `grafana/grafana:11.3.0`.
- **Cloud providers** referenciados no `docs/setup-cloud.md`: Supabase, CloudAMQP, Railway Hobby, Vercel/Netlify, Better Stack (logging), Cloudflare DNS.

## 🛠️ Tecnologias e Ferramentas
| Camada | Tecnologia | Versão |
| :--- | :--- | :--- |
| Orquestração local | Docker Compose | v2 |
| Banco relacional | PostgreSQL | 16-alpine |
| Message broker | RabbitMQ + management UI | 3.13-management-alpine |
| Identity Provider | Keycloak | 26.0 |
| Logs aggregation | Grafana Loki | 3.2.1 |
| Logs shipper | Grafana Promtail | 3.2.1 |
| Dashboards | Grafana | 11.3.0 |
| Automação | GNU Make | qualquer versão recente |

## 📐 Padrões de Projeto e Arquitetura do Código
- **Estilo Arquitetural:** **Infrastructure as Code** declarativa (Docker Compose) + **Convention over Configuration** (Makefile expõe targets curtos com `help` auto-gerado).
- **Padrões Relevantes:**
  - **Compose profiles** (`catalog`, `observability`) — opt-in por serviço para preservar cold start abaixo de ~30s no caso default.
  - **Healthchecks por serviço** — postgres (`pg_isready`), rabbitmq (`rabbitmq-diagnostics ping`), keycloak (TCP probe em `/realms/master`), loki/grafana (HTTP `/ready`/`/api/health`). Dependências usam `condition: service_healthy`.
  - **Volumes nomeados** (`postgres-data`, `loki-data`, `grafana-data`) → `make clean` é a única forma de zerar dados.
  - **Init via Docker entrypoint hooks** — `local/postgres-init.sh` cria múltiplos bancos a partir de `POSTGRES_MULTIPLE_DATABASES`.

## 📂 Estrutura do Projeto
```text
platform-infra/
├── README.md
├── Makefile                                # targets: help, up, up-catalog, up-observability, up-all, down, ps, logs, seed, clean
├── docker-compose.yml                      # stack base + profiles `catalog` e `observability`
├── docs/
│   └── setup-cloud.md                      # checklist exaustivo de provisionamento cloud
└── local/
    ├── postgres-init.sh                    # cria múltiplos DBs (hb_catalog, hb_support, hb_cashier, sc_order)
    ├── rabbitmq-definitions.json           # 6 exchanges seed (3 domínio + 3 DLX)
    └── observability/
        ├── loki-config.yml
        ├── promtail-config.yml
        └── grafana/provisioning/           # datasources (Loki + Catalog-Actuator) + folder `Hubinity`
            ├── datasources/
            └── dashboards/
```

## ⚙️ Configuração e Variáveis de Ambiente
Este repositório **não consome variáveis de ambiente próprias** — todas as credenciais para o stack local são hardcoded no `docker-compose.yml`:

```bash
# Postgres (DEV ONLY)
POSTGRES_USER=hubinity
POSTGRES_PASSWORD=hubinity_local
POSTGRES_MULTIPLE_DATABASES=hb_catalog,hb_support,hb_cashier,sc_order

# RabbitMQ (DEV ONLY)
RABBITMQ_DEFAULT_USER=hubinity
RABBITMQ_DEFAULT_PASS=hubinity_local

# Keycloak (DEV ONLY)
KEYCLOAK_ADMIN=admin
KEYCLOAK_ADMIN_PASSWORD=admin

# Grafana (DEV ONLY — anonymous viewer enabled)
GF_SECURITY_ADMIN_USER=admin
GF_SECURITY_ADMIN_PASSWORD=admin
```

> **DEV ONLY.** Estas credenciais existem apenas para desenvolvimento local. Em cloud, todas as credenciais reais são gerenciadas pelos providers (Supabase, CloudAMQP, Railway) e injetadas via env por serviço — ver `docs/setup-cloud.md`.

## 🚀 Como Instalar e Executar
### Pré-requisitos
- Docker Engine recente com `docker compose` v2
- GNU Make
- O repositório `platform-iam` clonado em `../platform-iam` (para que o Keycloak monte os realms)
- O repositório `hb-catalog-service` clonado em `../hb-catalog-service` (apenas se for usar o profile `catalog`)

### Passos para Instalação
```bash
git clone <repo-url> platform-infra
cd platform-infra
make help              # lista todos os targets disponíveis
```

### Execução Local (targets do Makefile)
```bash
make up                 # default: postgres + rabbitmq + keycloak
make up-catalog         # default + hb-catalog-service
make up-observability   # default + loki + promtail + grafana
make up-all             # tudo (default + catalog + observability)
make ps                 # status dos containers
make logs SVC=keycloak  # follow dos logs de um serviço específico
make seed               # re-aplica definições RabbitMQ (idempotente)
make down               # para e remove containers (preserva volumes)
make clean              # para e DELETA volumes (destrutivo — perde dados)
```

### Execução via Docker Compose (sem Make)
```bash
docker compose up -d                                 # default
docker compose --profile catalog up -d               # com catalog
docker compose --profile observability up -d         # com observability
docker compose --profile catalog --profile observability up -d
docker compose --profile catalog config              # preview do que um profile ativaria
```

### Profiles disponíveis
| Profile          | Serviços adicionados          | Quando usar                               |
| ---------------- | ----------------------------- | ----------------------------------------- |
| _(default)_      | postgres, rabbitmq, keycloak  | Sempre necessário para qualquer backend.  |
| `catalog`        | + hb-catalog-service          | Rodar o catalog service in-stack.         |
| `observability`  | + loki, promtail, grafana     | Pipeline de logs + dashboards (prep Fase 5). |

### UIs e portas (quando a stack está rodando)
| Serviço             | URL                                          | Credenciais                                  |
| ------------------- | -------------------------------------------- | -------------------------------------------- |
| RabbitMQ management | http://localhost:15672                       | `hubinity` / `hubinity_local`                |
| Keycloak admin      | http://localhost:8081                        | `admin` / `admin`                            |
| Grafana             | http://localhost:3000                        | `admin` / `admin` (anonymous viewer enabled) |
| Loki API            | http://localhost:3100/ready                  | _(sem auth em dev)_                          |
| hb-catalog-service  | http://localhost:8080/actuator/health        | JWT obrigatório em `/api/**`                 |

## 🔄 Fluxos Principais

### Onboarding de um novo dev (caminho rápido)
1. `git clone` deste repo + `platform-iam` + (opcional) `hb-catalog-service` lado a lado.
2. `make up` — em ~30s sobe postgres+rabbitmq+keycloak com realms já populados.
3. Os 4 bancos `hb_catalog`/`hb_support`/`hb_cashier`/`sc_order` ficam disponíveis em `localhost:5432`.
4. Backend de escolha pode `mvn spring-boot:run` apontando para essas dependências locais.

### RabbitMQ — exchanges seed
Carregadas no boot via `local/rabbitmq-definitions.json` (todas `type: topic`, durables):
- `catalog.events` / `catalog.events.dlx`
- `order.events`   / `order.events.dlx`
- `support.events` / `support.events.dlx`

Queues + bindings **não** estão neste seed — são responsabilidade do consumer service (catalog é o primeiro publisher na Fase 1.8; cashier será o primeiro consumer na Fase 2).

### Observability — provisionamento
Este repositório **provê** os componentes de observability local:
- **Loki** ingere logs de containers Docker via Docker SD do Promtail.
- **Grafana** vem com 2 datasources provisionados (`local/observability/grafana/provisioning/datasources/`):
  - **Loki** (default) — query em `http://loki:3100`.
  - **Catalog-Actuator** — scrape Prometheus opt-in de `http://hb-catalog-service:8080/actuator/prometheus` (requer também `--profile catalog`).
- Pasta `Hubinity` reservada para dashboards (entregues na Fase 5, PRD task 5.3, em `local/observability/grafana/provisioning/dashboards/`).

## 📊 Observabilidade e Testes
- **Logs & Tracing:** Este repo **provê** observability via profile `observability` (Loki + Promtail + Grafana). Não tem observabilidade própria para si.
- **Como Rodar os Testes:** Não há testes unitários; validação se dá por:
  ```bash
  docker compose -f docker-compose.yml config           # valida o YAML
  make up && make ps                                    # smoke test — todos healthy?
  ```

---

## 🌥️ Setup Cloud
Para provisionar o ecossistema em produção (Supabase + CloudAMQP + Railway Hobby + Vercel/Netlify + Better Stack + Cloudflare DNS), siga o checklist passo-a-passo em **[`docs/setup-cloud.md`](./docs/setup-cloud.md)**. Esse documento é manual hoje; Terraform virá em features posteriores.

## 🗂️ Convenções
- Setup de cada provider externo vive em `docs/setup-cloud.md`.
- **Segredos nunca são commitados**; placeholders em `${UPPER_SNAKE_CASE}`.
- IaC (quando adicionado) deve ser idempotente e rodável a partir de um checkout limpo.

## 🔭 Conteúdo planejado (Fases 0/1)
- `docker-compose/` — stack local expandida (OTEL collector, gateway).
- `k8s/` — manifestos Kubernetes (Helm/Kustomize) quando crescer além do Railway Hobby.
- `terraform/` — IaC para Supabase, Railway, CloudAMQP, DNS.
- `runbooks/` — incident response, rollback, restore de DB, rotação de segredo, on-call.
- `monitoring/` — dashboards Grafana, alert rules, Better Stack source configs.

## 🔗 Repositórios relacionados
- `platform-iam` — realm export Keycloak (consumido por este repo via volume mount).
- `platform-shared-contracts` — DTOs Java + OpenAPI + JSON Schemas.
- `platform-api-gateway` — Spring Cloud Gateway na frente dos backends (Fase posterior).
- `hb-catalog-service`, `hb-support-service`, `sc-order-service`, `hb-cashier-service` — backends Spring Boot.
- `hb-catalog-web`, `hb-support-web`, `hb-cashier-web`, `sc-totem-web` — frontends Angular.

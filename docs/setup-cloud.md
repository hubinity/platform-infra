# Hubinity — External (Cloud) Setup Checklist

**Audience:** the single operator provisioning every external account for the
Hubinity ecosystem for the first time.
**Goal:** by the end of this checklist, every provider account, project,
secret, and connection string required to deploy the Hubinity platform is in
place and captured in a secure secret store.

This document is **intentionally exhaustive**. Tick every box. Do not skip
sections — earlier sections produce values that later sections consume.

Working directory for this doc:
`/home/lenoln/Área de Trabalho/workspace/projects/active/hubinity/platform-infra/docs/`.

---

## Table of contents

- [Section 0 — Prerequisites](#section-0--prerequisites)
- [Section 1 — GitHub Organization `hubinity`](#section-1--github-organization-hubinity)
- [Section 2 — Supabase (4 projects, Postgres only)](#section-2--supabase-4-projects-postgres-only)
- [Section 3 — Railway (backend deploys + Keycloak)](#section-3--railway-backend-deploys--keycloak)
- [Section 4 — Vercel (3 backoffice frontends)](#section-4--vercel-3-backoffice-frontends)
- [Section 5 — Netlify (totem PWA)](#section-5--netlify-totem-pwa)
- [Section 6 — CloudAMQP (RabbitMQ)](#section-6--cloudamqp-rabbitmq)
- [Section 7 — InfinitePay (PIX gateway)](#section-7--infinitepay-pix-gateway)
- [Section 8 — Observability (Better Stack + Grafana Cloud)](#section-8--observability-better-stack--grafana-cloud)
- [Section 9 — Container Registry (`ghcr.io/hubinity`)](#section-9--container-registry-ghcriohubinity)
- [Section 10 — GitHub Actions Secrets (exhaustive list)](#section-10--github-actions-secrets-exhaustive-list)
- [Section 11 — Initial validation checklist](#section-11--initial-validation-checklist)
- [Section 12 — Cost summary](#section-12--cost-summary)
- [Next steps](#next-steps)

---

## Section 0 — Prerequisites

### 0.1 Local tools

Install the following on your workstation. One-line install hints below for
Debian/Ubuntu and macOS (Homebrew).

- [x] **git** ≥ 2.40
  ```bash
  # Linux
  sudo apt-get install -y git
  # macOS
  brew install git
  ```
- [x] **gh** (GitHub CLI) ≥ 2.40
  ```bash
  # Linux
  curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | sudo dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg \
    && echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | sudo tee /etc/apt/sources.list.d/github-cli.list \
    && sudo apt-get update && sudo apt-get install -y gh
  # macOS
  brew install gh
  ```
- [x] **docker** (Engine + CLI) and **docker buildx**
  ```bash
  # Linux (Docker Engine)
  curl -fsSL https://get.docker.com | sh
  # macOS (Docker Desktop)
  brew install --cask docker
  ```
- [x] **jq** (for extracting values from JSON in shell scripts)
  ```bash
  sudo apt-get install -y jq    # Linux
  brew install jq               # macOS
  ```
- [x] **supabase** CLI (optional but recommended for DB migrations later)
  ```bash
  # Linux/macOS via npm
  npm install -g supabase
  # or macOS
  brew install supabase/tap/supabase
  ```
- [x] **railway** CLI (optional, useful for tailing logs)
  ```bash
  # macOS
  brew install railway
  # Linux
  curl -fsSL https://railway.app/install.sh | sh
  ```
- [x] **vercel** CLI (optional)
  ```bash
  npm install -g vercel
  ```
- [x] **netlify** CLI (optional)
  ```bash
  npm install -g netlify-cli
  ```

After install, run a sanity check:

```bash
git --version && gh --version && docker --version && jq --version
```

### 0.2 Provider account creation

Create or confirm an account at each provider. Use the recommended plan and a
**shared organizational email** (e.g. `ops@hubinity.io` — adjust to the actual
domain). Enable 2FA everywhere.

- [x] **GitHub** — https://github.com/join — Org `hubinity` already exists.
- [ ] **Supabase** — https://supabase.com — Free tier.
- [ ] **Railway** — https://railway.app — Hobby ($5/svc) for paid services,
  Free for the rest. Linked to GitHub for repo-based deploys.
- [ ] **Vercel** — https://vercel.com — Hobby (Free).
- [ ] **Netlify** — https://netlify.com — Free.
- [ ] **CloudAMQP** — https://cloudamqp.com — Little Lemur (Free).
- [ ] **InfinitePay** — Sandbox account. Verify canonical signup URL at
  https://infinitepay.io (developer portal — verify canonical URL at provider).
- [ ] **Better Stack (Logtail)** — https://betterstack.com — Free.
- [ ] **Grafana Cloud** — https://grafana.com/products/cloud — Free.
- [ ] **UptimeRobot** — https://uptimerobot.com — Free (for Railway keep-alive
  pings).

### 0.3 Secret store

Pick **one** secret store and use it throughout. Recommended options:

- [ ] **1Password** — shared vault `hubinity-infra`.
- [ ] OR **Bitwarden** — collection `hubinity/infra`.
- [x] OR **Authenticator** - codes `hubinity-infra`.
- [ ] OR a local encrypted file (`pass`, `age`-encrypted YAML) as a fallback.

Every value captured below MUST be stored here before moving to the next
section. GitHub Actions secrets are populated **from** this store in Section
10, not the other way around.

---

## Section 1 — GitHub Organization `hubinity`

### 1.1 Confirm repositories

- [x] Authenticate `gh` against the org:
  ```bash
  gh auth login --scopes "repo,read:org,admin:org,workflow,write:packages"
  gh auth status
  ```
- [x] Confirm the 12 repositories exist:
  ```bash
  gh repo list hubinity --limit 50 --json name --jq '.[].name' | sort
  ```
  Expected list (alphabetical):
  - `hb-cashier-service`
  - `hb-cashier-web`
  - `hb-catalog-service`
  - `hb-catalog-web`
  - `hb-support-service`
  - `hb-support-web`
  - `platform-api-gateway`
  - `platform-iam`
  - `platform-infra`
  - `platform-shared-contracts`
  - `sc-order-service`
  - `sc-totem-web`

### 1.2 Teams

- [x] Create the three foundational teams (Admin only; skip if already
  created):
  ```bash
  gh api -X POST orgs/hubinity/teams -f name='backend'  -f privacy='closed'
  gh api -X POST orgs/hubinity/teams -f name='frontend' -f privacy='closed'
  gh api -X POST orgs/hubinity/teams -f name='devops'   -f privacy='closed'
  ```
- [x] Add yourself (and any other operators) to all three teams:
  ```bash
  gh api -X PUT orgs/hubinity/teams/backend/memberships/${GITHUB_USERNAME}
  gh api -X PUT orgs/hubinity/teams/frontend/memberships/${GITHUB_USERNAME}
  gh api -X PUT orgs/hubinity/teams/devops/memberships/${GITHUB_USERNAME}
  ```

### 1.3 Branch protection on `main`

Apply uniform protection to every repo's `main` branch:

- Require pull-request review (≥ 1 approval).
- Require status checks (CI) to pass before merge.
- Dismiss stale reviews on new commits.
- Restrict force pushes.
- Restrict branch deletion.

- [ ] Run the loop below (requires `gh` and `jq`):
  ```bash
  for repo in $(gh repo list hubinity --limit 50 --json name --jq '.[].name'); do
    echo "Protecting hubinity/${repo}@main"
    gh api -X PUT "repos/hubinity/${repo}/branches/main/protection" \
      --input - <<'JSON'
  {
    "required_status_checks": { "strict": true, "contexts": [] },
    "enforce_admins": false,
    "required_pull_request_reviews": {
      "required_approving_review_count": 1,
      "dismiss_stale_reviews": true,
      "require_code_owner_reviews": true
    },
    "restrictions": null,
    "allow_force_pushes": false,
    "allow_deletions": false,
    "required_conversation_resolution": true
  }
  JSON
  done
  ```
  > Note: the `required_status_checks.contexts` array stays empty until CI
  > workflows publish their first check name; revisit after Section 11.

### 1.4 CODEOWNERS

- [ ] Drop the following file at `.github/CODEOWNERS` in **every** repository.
  Adjust the per-repo overrides as needed (e.g. `*-service` repos need
  `@hubinity/backend` as default, `*-web` repos need `@hubinity/frontend`).

  Generic template (use `@hubinity/devops` as a fallback global owner):
  ```text
  # Default owners — every PR pings DevOps unless a more specific rule below matches.
  *                       @hubinity/devops

  # Backend (Java / Spring Boot)
  pom.xml                 @hubinity/backend @hubinity/devops
  src/main/java/**        @hubinity/backend
  src/test/java/**        @hubinity/backend
  src/main/resources/**   @hubinity/backend

  # Frontend (Angular)
  package.json            @hubinity/frontend @hubinity/devops
  angular.json            @hubinity/frontend
  src/app/**              @hubinity/frontend
  src/styles/**           @hubinity/frontend

  # Shared infra files
  Dockerfile              @hubinity/devops
  docker-compose*.yml     @hubinity/devops
  .github/workflows/**    @hubinity/devops
  ```
- [ ] Open a PR in each repo adding `.github/CODEOWNERS` and merge it. The
  branch-protection rule above (`require_code_owner_reviews`) will then take
  effect on subsequent PRs.

### 1.5 Renovate Bot

- [ ] Install the **Renovate** GitHub App at
  https://github.com/apps/renovate and grant access to **All repositories**
  in the `hubinity` org.
- [ ] Drop the following at `renovate.json` (repo root) in every repo:
  ```json
  {
    "$schema": "https://docs.renovatebot.com/renovate-schema.json",
    "extends": [
      "config:recommended",
      ":semanticCommits",
      ":dependencyDashboard"
    ],
    "schedule": ["before 6am on monday"],
    "timezone": "America/Sao_Paulo",
    "labels": ["dependencies"],
    "packageRules": [
      {
        "matchPackagePatterns": ["^@hubinity/"],
        "groupName": "hubinity internal packages",
        "schedule": ["at any time"]
      },
      {
        "matchManagers": ["maven"],
        "groupName": "maven dependencies"
      },
      {
        "matchManagers": ["npm"],
        "groupName": "npm dependencies"
      }
    ],
    "vulnerabilityAlerts": { "enabled": true }
  }
  ```
- [ ] Verify Renovate opens the initial "Configure Renovate" onboarding PR in
  each repo within ~30 minutes of install; merge it.

### 1.6 GitHub Packages — Maven, npm, container registries

- [ ] Confirm at https://github.com/orgs/hubinity/packages that all three
  registries (Maven, npm, container) are visible (they are enabled by default
  for orgs).
- [ ] Each org member that consumes internal artifacts needs a PAT
  (classic) with `read:packages`. Document the steps in the repo README; the
  consumer must add:
  - For Maven, `~/.m2/settings.xml`:
    ```xml
    <settings>
      <servers>
        <server>
          <id>github-hubinity</id>
          <username>${env.GITHUB_USER}</username>
          <password>${env.GITHUB_TOKEN}</password>
        </server>
      </servers>
    </settings>
    ```
    Reference the published example from
    `platform-shared-contracts/settings.xml` once it's committed.
  - For npm, `~/.npmrc`:
    ```ini
    @hubinity:registry=https://npm.pkg.github.com
    //npm.pkg.github.com/:_authToken=${GITHUB_TOKEN}
    ```
    Reference the tailwind-preset README once published.
- [ ] Generate an **org-level** PAT for CI use (classic, `write:packages`,
  `read:packages`, `delete:packages` scopes). Store as
  `GH_PACKAGES_TOKEN`.

---

## Section 2 — Supabase (4 projects, Postgres only)

We use Supabase **only as managed Postgres**. Auth, Storage, Realtime and
Edge Functions stay disabled.

### 2.1 Create the 4 projects

For each of the four projects, create with the same parameters:

- Region: **`sa-east-1`** (São Paulo) — lowest latency from Brazilian users.
- Plan: **Free**.
- Pricing-impacting settings: **default**.
- Database password: **auto-generated**, ≥ 32 chars, stored in the secret
  store immediately.

- [ ] Project **`hb-catalog`** — for `hb-catalog-service`.
- [ ] Project **`hb-support`** — for `hb-support-service`.
- [ ] Project **`sc-order`**   — for `sc-order-service`.
- [ ] Project **`hb-cashier`** — for `hb-cashier-service`.

### 2.2 Capture connection details per project

For **each** project, copy the values from the Supabase dashboard
(*Settings → Database → Connection string → Transaction mode (Supavisor)*)
into the secret store.

Per-service variables (replace `<SVC>` with `CATALOG`, `SUPPORT`, `ORDER`,
`CASHIER`):

- [ ] `SUPABASE_<SVC>_DB_HOST` — pooler hostname, e.g.
  `aws-0-sa-east-1.pooler.supabase.com`.
- [ ] `SUPABASE_<SVC>_DB_PORT` — `6543` (Supavisor, transaction mode).
- [ ] `SUPABASE_<SVC>_DB_NAME` — `postgres`.
- [ ] `SUPABASE_<SVC>_DB_USER` — `postgres.<project-ref>` (e.g.
  `postgres.abcdefghijklmnop`).
- [ ] `SUPABASE_<SVC>_DB_PASSWORD` — the auto-generated password. **Rotate
  before production go-live.**
- [ ] `SUPABASE_<SVC>_PROJECT_URL` — `https://<project-ref>.supabase.co`.
- [ ] `SUPABASE_<SVC>_ANON_KEY` — captured for completeness; not used by the
  Spring services (they connect via JDBC), but useful if a future feature
  needs PostgREST.

### 2.3 JDBC URL pattern

Spring services build the JDBC URL using this template:

```text
jdbc:postgresql://${HOST}:${PORT}/${DB}?sslmode=require&prepareThreshold=0&user=${USER}
```

Concretely (per service, replace placeholders):

```text
jdbc:postgresql://${SUPABASE_CATALOG_DB_HOST}:${SUPABASE_CATALOG_DB_PORT}/${SUPABASE_CATALOG_DB_NAME}?sslmode=require&prepareThreshold=0&user=${SUPABASE_CATALOG_DB_USER}
```

`prepareThreshold=0` is **mandatory** in transaction-pool mode (PgBouncer /
Supavisor). The password is passed via Spring's `spring.datasource.password`,
not the URL.

- [ ] Test the JDBC URL from your workstation:
  ```bash
  psql "host=${SUPABASE_CATALOG_DB_HOST} port=6543 dbname=postgres user=${SUPABASE_CATALOG_DB_USER} password=${SUPABASE_CATALOG_DB_PASSWORD} sslmode=require" -c "select version();"
  ```

### 2.4 Backup retention

- [ ] Confirm **7-day automatic snapshot** is enabled on each project
  (Free-tier default; *Settings → Database → Backups*).
- [ ] Document the manual restore procedure in a future runbook
  (`platform-infra/runbooks/db-restore.md`, to be created later).

### 2.5 Disabled features

For each project:

- [ ] **Authentication** — disabled (we use Keycloak).
- [ ] **Storage** — disabled.
- [ ] **Realtime** — disabled.
- [ ] **Edge Functions** — none deployed.

---

## Section 3 — Railway (backend deploys + Keycloak)

Railway hosts the 4 Spring Boot backends and a self-hosted Keycloak instance.
5 services total.

### 3.1 Account + CLI

- [ ] Create the Railway account using the shared org email.
- [ ] Install the CLI (see Section 0).
- [ ] `railway login`.
- [ ] Create a **project**: `hubinity`.

### 3.2 Create one service per backend

Inside the `hubinity` project, create 5 services:

- [ ] `hb-catalog-service` — deploys from `hubinity/hb-catalog-service` repo.
- [ ] `hb-support-service` — deploys from `hubinity/hb-support-service` repo.
- [ ] `sc-order-service`   — deploys from `hubinity/sc-order-service` repo.
- [ ] `hb-cashier-service` — deploys from `hubinity/hb-cashier-service` repo.
- [ ] `keycloak`           — deploys from `hubinity/platform-iam` repo.

For each service:

- [ ] Source: **Deploy from GitHub repo** → branch `main`.
- [ ] Build: **Dockerfile** at the repo root.
- [ ] Health check path: `/actuator/health` for Spring services,
  `/health/ready` for Keycloak.
- [ ] Restart policy: `ON_FAILURE` (default).

### 3.3 Plan choice (cost)

- [ ] Upgrade these to **Hobby** ($5/svc, no hibernation):
  - `sc-order-service` — payment latency cannot tolerate cold starts.
  - `hb-cashier-service` — POS-facing.
  - `keycloak` — token issuance is on every API request.
- [ ] Leave on **Free** (with UptimeRobot keep-alive ping every 5 minutes):
  - `hb-catalog-service`
  - `hb-support-service`
- [ ] In **UptimeRobot**, create one HTTP(S) monitor per Free service hitting
  `https://<svc>.up.railway.app/actuator/health` every 5 minutes.

### 3.4 Per-service environment variables

For each Spring service, set (replace placeholders with the Section 2 values):

- [ ] `SPRING_DATASOURCE_URL` — the JDBC URL from Section 2.3.
- [ ] `SPRING_DATASOURCE_USERNAME` — `${SUPABASE_<SVC>_DB_USER}`.
- [ ] `SPRING_DATASOURCE_PASSWORD` — `${SUPABASE_<SVC>_DB_PASSWORD}`.
- [ ] `SPRING_RABBITMQ_ADDRESSES` — `${CLOUDAMQP_URL}` (Section 6).
- [ ] `KEYCLOAK_ISSUER_URL` — points inwards at the Railway-internal Keycloak
  service: `https://keycloak.railway.internal/realms/hubinity` (use Railway
  private networking; verify exact hostname format in Railway docs).
- [ ] `KEYCLOAK_CLIENT_ID` and `KEYCLOAK_CLIENT_SECRET` per service.
- [ ] `LOGTAIL_SOURCE_TOKEN` — `${LOGTAIL_<SVC>_SOURCE_TOKEN}` (Section 8).
- [ ] `OTEL_EXPORTER_OTLP_ENDPOINT` — Grafana Cloud Tempo OTLP endpoint
  (Section 8).
- [ ] `BUILD_VERSION` — injected by the deploy workflow (Git SHA).

Keycloak-specific:

- [ ] `KC_DB` — `postgres`.
- [ ] `KC_DB_URL` — JDBC URL pointing at a dedicated Postgres (consider a 5th
  Supabase project `hb-iam` OR reuse `hb-support`'s schema separation; final
  decision deferred to the `platform-iam` feature — verify before go-live).
- [ ] `KC_HOSTNAME` — Railway-assigned public hostname.
- [ ] `KC_HTTP_ENABLED` — `true` (Railway terminates TLS).
- [ ] `KC_PROXY` — `edge`.
- [ ] `KEYCLOAK_ADMIN` and `KEYCLOAK_ADMIN_PASSWORD` — bootstrap admin user.

### 3.5 Tokens for CI

- [ ] In **Account Settings → Tokens**, generate a project-scoped token for
  the `hubinity` Railway project. Store as **`RAILWAY_TOKEN`** in the secret
  store and inject into GitHub Actions (Section 10).

### 3.6 Public URLs

- [ ] For each service capture the public Railway URL (e.g.
  `https://hb-catalog-service.up.railway.app`) and store as
  `RAILWAY_<SVC>_PUBLIC_URL`. These feed the frontend env vars in Section 4.

---

## Section 4 — Vercel (3 backoffice frontends)

### 4.1 Account + CLI

- [ ] Create the Vercel account; link to the `hubinity` GitHub org during
  signup (Vercel's GitHub App must be granted access to the 3 frontend
  repos).
- [ ] `vercel login` (optional but useful).

### 4.2 Create one project per repo

- [ ] **`hb-catalog-web`** → production domain `hb-catalog-web.vercel.app`
  (custom domain TBD).
- [ ] **`hb-support-web`** → production domain `hb-support-web.vercel.app`.
- [ ] **`hb-cashier-web`** → production domain `hb-cashier-web.vercel.app`.

For each project:

- [ ] Source: GitHub repo `hubinity/<repo>`.
- [ ] Production branch: `main`.
- [ ] Framework preset: **Angular** (Vercel auto-detects from
  `angular.json`).
- [ ] Build command: `npm run build` (or framework default).
- [ ] Output directory: `dist/<repo>/browser` (Angular 17+ default).
- [ ] Node version: **20.x**.

### 4.3 Per-project environment variables

For each frontend, set in *Project → Settings → Environment Variables*
(scope: Production + Preview):

- [ ] `KEYCLOAK_ISSUER_URL` — public Keycloak URL from Section 3.6.
- [ ] `KEYCLOAK_CLIENT_ID` — `<repo>` (each frontend is its own public
  client).
- [ ] `API_BASE_URL` — points at the matching backend Railway URL:
  - `hb-catalog-web` → `RAILWAY_HB_CATALOG_SERVICE_PUBLIC_URL`
  - `hb-support-web` → `RAILWAY_HB_SUPPORT_SERVICE_PUBLIC_URL`
  - `hb-cashier-web` → `RAILWAY_HB_CASHIER_SERVICE_PUBLIC_URL`
- [ ] `BUILD_VERSION` — populated by CI from Git SHA.
- [ ] `SENTRY_DSN` — placeholder for now (Sentry not in this checklist;
  optional later).

### 4.4 Tokens for CI

- [ ] In **Vercel → Account Settings → Tokens**, generate a token with scope
  *Full Account*. Store as **`VERCEL_TOKEN`**.
- [ ] In **Vercel → Team Settings → General**, copy the **Team ID**. Store as
  **`VERCEL_ORG_ID`** (shared across all 3 frontends).
- [ ] In each project's *Settings → General*, copy the **Project ID**. Store
  as:
  - `VERCEL_PROJECT_ID_HB_CATALOG_WEB`
  - `VERCEL_PROJECT_ID_HB_SUPPORT_WEB`
  - `VERCEL_PROJECT_ID_HB_CASHIER_WEB`

---

## Section 5 — Netlify (totem PWA)

The self-service totem PWA is hosted on Netlify (Netlify's edge caching is
preferable for a kiosk app served from far-flung points of presence).

### 5.1 Account + link

- [ ] Create the Netlify account; link to the GitHub org (grant access to
  `sc-totem-web` only).

### 5.2 Site

- [ ] Create site `sc-totem-web`:
  - Repo: `hubinity/sc-totem-web`.
  - Branch: `main` (production).
  - Build command: `npm run build`.
  - Publish directory: `dist/sc-totem-web/browser`.
  - Node version: **20.x** (set via `netlify.toml` or env var
    `NODE_VERSION=20`).
- [ ] Site-level environment variables:
  - `KEYCLOAK_ISSUER_URL`
  - `KEYCLOAK_CLIENT_ID` = `sc-totem-web`
  - `API_BASE_URL` — `RAILWAY_SC_ORDER_SERVICE_PUBLIC_URL`
  - `BUILD_VERSION` — populated by CI

### 5.3 PWA

- [ ] Confirm Angular's `ng add @angular/pwa` has been run in the repo and
  produces `manifest.webmanifest` and a service worker in the build output.
  Netlify serves these without extra config; ensure the `Cache-Control`
  header on `index.html` is `no-cache` (set via `netlify.toml`).

### 5.4 Tokens for CI

- [ ] **Netlify → User settings → Applications → Personal access tokens**:
  generate a token. Store as **`NETLIFY_AUTH_TOKEN`**.
- [ ] **Site settings → General → Site details**: copy the **Site ID**.
  Store as **`NETLIFY_SITE_ID_SC_TOTEM_WEB`**.

---

## Section 6 — CloudAMQP (RabbitMQ)

### 6.1 Instance

- [ ] Create one **Little Lemur (Free)** instance:
  - Name: `hubinity-rabbitmq`.
  - Region: São Paulo if available (`AWS sa-east-1`), else US-East
    (`AWS us-east-1`).
  - Plan: Little Lemur — 1M msg/month, 1M queued msg cap, 20 connections.

### 6.2 Capture connection details

- [ ] **AMQP connection string** (from the CloudAMQP dashboard):
  `amqps://<user>:<pass>@<host>/<vhost>`. Store as **`CLOUDAMQP_URL`**.
- [ ] **Management URL** for browser access (queues debugging):
  `https://<host>/api/`. Store as `CLOUDAMQP_MGMT_URL`.
- [ ] **Management credentials** (same user/pass as AMQP) — used to log into
  the management UI.

### 6.3 Exchanges and DLX

Once the first Spring service is up and reachable, create the planned
exchanges. Create via the management UI (*Exchanges → Add new exchange*) or
via `rabbitmqadmin`:

- [ ] `catalog.events`  — type `topic`, durable.
- [ ] `order.events`    — type `topic`, durable.
- [ ] `support.events`  — type `topic`, durable.
- [ ] `cashier.events`  — type `topic`, durable.
- [ ] Dead-letter exchanges per consumer (one per service that consumes):
  - `catalog.dlx` (topic, durable)
  - `order.dlx`   (topic, durable)
  - `support.dlx` (topic, durable)
  - `cashier.dlx` (topic, durable)

Queues themselves are declared at runtime by the Spring services via
`spring-rabbit`; the exchanges must pre-exist (or be declared by the first
service to start — verify the project convention before go-live).

### 6.4 Monitoring

- [ ] In the CloudAMQP dashboard, enable the *Monthly usage* widget and
  watch the **1M msg/month** ceiling. Set up an email alert at 80%.
- [ ] Document the upgrade path (Tough Tiger $19/mo) in the cost runbook.

---

## Section 7 — InfinitePay (PIX gateway)

PIX is the only payment method for MVP. InfinitePay is the gateway.

### 7.1 Sandbox account

- [ ] Sign up for the **sandbox** developer account.
  *Verify canonical signup URL at provider* — start at
  https://infinitepay.io/ and follow the "Desenvolvedores" / "API" link.
- [ ] Submit the KYC documentation required to graduate from sandbox to
  production (defer to the production go-live feature).

### 7.2 Credentials

Capture from the developer dashboard:

- [ ] **`INFINITEPAY_CLIENT_ID`** — OAuth2 client ID.
- [ ] **`INFINITEPAY_CLIENT_SECRET`** — OAuth2 client secret.
- [ ] **`INFINITEPAY_WEBHOOK_SECRET`** — HMAC signing key used to validate
  inbound webhook payloads. **Critical**: a missing or wrong value lets
  spoofed payment confirmations through.

### 7.3 Webhook URL

- [ ] In the dashboard, configure the webhook endpoint:
  ```text
  https://${RAILWAY_SC_ORDER_SERVICE_PUBLIC_URL}/api/v1/payments/webhook
  ```
  Concretely once Section 3.6 is filled:
  ```text
  https://sc-order-service.up.railway.app/api/v1/payments/webhook
  ```
- [ ] Whitelist the InfinitePay webhook source IPs in Railway (if Railway
  exposes IP allowlisting on Hobby — verify; otherwise rely on HMAC
  validation alone).

### 7.4 Sandbox test data

Document inside the `sc-order-service` repo (not here) the canonical sandbox
PIX keys / fake CPFs the QA team will use. For this checklist, capture:

- [ ] A working **test CPF** (e.g. `12345678909` — verify with InfinitePay
  docs; CPFs that pass mod-11 are usually accepted).
- [ ] A working **test PIX random key** (UUID v4).
- [ ] A working **test PIX email key** (`pix-test@hubinity.io`).

> Do **not** hard-code these in `application.yml`; keep them in fixture files
> under the `sc-order-service` integration test resources.

---

## Section 8 — Observability (Better Stack + Grafana Cloud)

### 8.1 Better Stack (Logtail)

- [ ] Create one Logtail **source** per service (5 total: catalog, support,
  order, cashier, keycloak). Source type: **Generic HTTP** (Spring boots
  ship JSON over HTTPS via Logback appender).
- [ ] For each source, capture the token. Store as:
  - `LOGTAIL_HB_CATALOG_SOURCE_TOKEN`
  - `LOGTAIL_HB_SUPPORT_SOURCE_TOKEN`
  - `LOGTAIL_SC_ORDER_SOURCE_TOKEN`
  - `LOGTAIL_HB_CASHIER_SOURCE_TOKEN`
  - `LOGTAIL_KEYCLOAK_SOURCE_TOKEN`
- [ ] Verify the per-source ingest URL pattern (`https://in.logs.betterstack.com`).
- [ ] Create a Better Stack **team** and invite operators.

### 8.2 Grafana Cloud (metrics + traces)

- [ ] Create a **Grafana Cloud Free** stack: `hubinity`.
- [ ] In the stack, locate **Prometheus → Send metrics**:
  - Capture **remote-write URL**. Store as `GRAFANA_PROM_PUSH_URL`.
  - Capture **username** (numeric instance ID). Store as `GRAFANA_PROM_USERNAME`.
  - Generate an API key with scope `MetricsPublisher`. Store as
    `GRAFANA_PROM_API_KEY`.
- [ ] In the stack, locate **Tempo → OTLP**:
  - Capture **OTLP gRPC endpoint**. Store as `GRAFANA_TEMPO_OTLP_ENDPOINT`.
  - Capture **username** (instance ID). Store as `GRAFANA_TEMPO_USERNAME`.
  - Generate an API key with scope `MetricsPublisher` (Tempo reuses it).
    Store as `GRAFANA_TEMPO_API_KEY`.
- [ ] Spring services will be wired to push via the **OpenTelemetry Java
  Agent** in a later feature; for now the endpoint + auth are captured.

---

## Section 9 — Container Registry (`ghcr.io/hubinity`)

### 9.1 Confirm registry availability

- [ ] Visit https://github.com/orgs/hubinity/packages. GHCR is enabled by
  default for orgs.
- [ ] Confirm the org's package visibility default is **private** at
  https://github.com/orgs/hubinity/settings/packages.

### 9.2 Local developer access

For `docker pull` from `ghcr.io/hubinity/*`, a developer needs a token with
`read:packages`. The easiest is:

- [ ] `gh auth login --scopes read:packages` then
  `gh auth token | docker login ghcr.io -u ${GITHUB_USER} --password-stdin`.

### 9.3 CI push access

CI pushes images on every `main` build. Two options:

- **GITHUB_TOKEN** (preferred) — automatic, scoped to the running repo. Just
  add `permissions: { packages: write }` to the workflow.
- **`GH_PACKAGES_TOKEN`** (org PAT from Section 1.6) — needed only when the
  workflow pushes to a different repo's package namespace.

- [ ] Verify the org-level `actions` settings allow `GITHUB_TOKEN` to write
  packages: *Org settings → Actions → General → Workflow permissions →
  "Read and write permissions"*.

---

## Section 10 — GitHub Actions Secrets (exhaustive list)

Configure these at **organization** scope
(https://github.com/organizations/hubinity/settings/secrets/actions) unless
the *Scope* column says otherwise. Repository-scope secrets stay scoped to a
single repo.

| Secret name | Provider | Scope | Used by | Notes |
|---|---|---|---|---|
| `GH_PACKAGES_TOKEN` | GitHub | Org | Cross-repo workflows that pull/push internal Maven/npm/container packages | Classic PAT, `read:packages`+`write:packages`. Rotate every 90 days. |
| `RAILWAY_TOKEN` | Railway | Org | All backend deploy workflows (`*-service` repos, `platform-iam`) | Project-scoped to `hubinity`. Rotate quarterly. |
| `SUPABASE_CATALOG_DB_HOST` | Supabase | Org | `hb-catalog-service` integration tests + deploy | Pooler hostname. |
| `SUPABASE_CATALOG_DB_PORT` | Supabase | Org | `hb-catalog-service` | Always `6543`. |
| `SUPABASE_CATALOG_DB_NAME` | Supabase | Org | `hb-catalog-service` | Always `postgres`. |
| `SUPABASE_CATALOG_DB_USER` | Supabase | Org | `hb-catalog-service` | `postgres.<ref>`. |
| `SUPABASE_CATALOG_DB_PASSWORD` | Supabase | Org | `hb-catalog-service` | Rotate before prod. |
| `SUPABASE_CATALOG_PROJECT_URL` | Supabase | Org | `hb-catalog-service` (optional) | For future PostgREST use. |
| `SUPABASE_CATALOG_ANON_KEY` | Supabase | Org | `hb-catalog-service` (optional) | For future PostgREST use. |
| `SUPABASE_SUPPORT_DB_HOST` | Supabase | Org | `hb-support-service` | |
| `SUPABASE_SUPPORT_DB_PORT` | Supabase | Org | `hb-support-service` | Always `6543`. |
| `SUPABASE_SUPPORT_DB_NAME` | Supabase | Org | `hb-support-service` | Always `postgres`. |
| `SUPABASE_SUPPORT_DB_USER` | Supabase | Org | `hb-support-service` | |
| `SUPABASE_SUPPORT_DB_PASSWORD` | Supabase | Org | `hb-support-service` | |
| `SUPABASE_SUPPORT_PROJECT_URL` | Supabase | Org | `hb-support-service` | |
| `SUPABASE_SUPPORT_ANON_KEY` | Supabase | Org | `hb-support-service` | |
| `SUPABASE_ORDER_DB_HOST` | Supabase | Org | `sc-order-service` | |
| `SUPABASE_ORDER_DB_PORT` | Supabase | Org | `sc-order-service` | Always `6543`. |
| `SUPABASE_ORDER_DB_NAME` | Supabase | Org | `sc-order-service` | Always `postgres`. |
| `SUPABASE_ORDER_DB_USER` | Supabase | Org | `sc-order-service` | |
| `SUPABASE_ORDER_DB_PASSWORD` | Supabase | Org | `sc-order-service` | |
| `SUPABASE_ORDER_PROJECT_URL` | Supabase | Org | `sc-order-service` | |
| `SUPABASE_ORDER_ANON_KEY` | Supabase | Org | `sc-order-service` | |
| `SUPABASE_CASHIER_DB_HOST` | Supabase | Org | `hb-cashier-service` | |
| `SUPABASE_CASHIER_DB_PORT` | Supabase | Org | `hb-cashier-service` | Always `6543`. |
| `SUPABASE_CASHIER_DB_NAME` | Supabase | Org | `hb-cashier-service` | Always `postgres`. |
| `SUPABASE_CASHIER_DB_USER` | Supabase | Org | `hb-cashier-service` | |
| `SUPABASE_CASHIER_DB_PASSWORD` | Supabase | Org | `hb-cashier-service` | |
| `SUPABASE_CASHIER_PROJECT_URL` | Supabase | Org | `hb-cashier-service` | |
| `SUPABASE_CASHIER_ANON_KEY` | Supabase | Org | `hb-cashier-service` | |
| `VERCEL_TOKEN` | Vercel | Org | All 3 frontend deploy workflows | Rotate quarterly. |
| `VERCEL_ORG_ID` | Vercel | Org | All 3 frontend deploys | Same for all frontends. |
| `VERCEL_PROJECT_ID_HB_CATALOG_WEB` | Vercel | Repo (`hb-catalog-web`) | `hb-catalog-web` deploy | One per Vercel project. |
| `VERCEL_PROJECT_ID_HB_SUPPORT_WEB` | Vercel | Repo (`hb-support-web`) | `hb-support-web` deploy | |
| `VERCEL_PROJECT_ID_HB_CASHIER_WEB` | Vercel | Repo (`hb-cashier-web`) | `hb-cashier-web` deploy | |
| `NETLIFY_AUTH_TOKEN` | Netlify | Repo (`sc-totem-web`) | `sc-totem-web` deploy | Personal access token. |
| `NETLIFY_SITE_ID_SC_TOTEM_WEB` | Netlify | Repo (`sc-totem-web`) | `sc-totem-web` deploy | |
| `CLOUDAMQP_URL` | CloudAMQP | Org | All backend services' deploy + integration tests | AMQPS URL with embedded credentials. |
| `CLOUDAMQP_MGMT_URL` | CloudAMQP | Org | Optional — admin scripts only | |
| `INFINITEPAY_CLIENT_ID` | InfinitePay | Repo (`sc-order-service`) | `sc-order-service` deploy | Sandbox now, prod after KYC. |
| `INFINITEPAY_CLIENT_SECRET` | InfinitePay | Repo (`sc-order-service`) | `sc-order-service` deploy | |
| `INFINITEPAY_WEBHOOK_SECRET` | InfinitePay | Repo (`sc-order-service`) | `sc-order-service` deploy | HMAC verification of webhook payloads. |
| `LOGTAIL_HB_CATALOG_SOURCE_TOKEN` | Better Stack | Repo (`hb-catalog-service`) | `hb-catalog-service` | Logback HTTP appender token. |
| `LOGTAIL_HB_SUPPORT_SOURCE_TOKEN` | Better Stack | Repo (`hb-support-service`) | `hb-support-service` | |
| `LOGTAIL_SC_ORDER_SOURCE_TOKEN` | Better Stack | Repo (`sc-order-service`) | `sc-order-service` | |
| `LOGTAIL_HB_CASHIER_SOURCE_TOKEN` | Better Stack | Repo (`hb-cashier-service`) | `hb-cashier-service` | |
| `LOGTAIL_KEYCLOAK_SOURCE_TOKEN` | Better Stack | Repo (`platform-iam`) | `keycloak` deploy | |
| `GRAFANA_PROM_PUSH_URL` | Grafana Cloud | Org | All backend services | Remote-write endpoint. |
| `GRAFANA_PROM_USERNAME` | Grafana Cloud | Org | All backend services | Numeric instance ID. |
| `GRAFANA_PROM_API_KEY` | Grafana Cloud | Org | All backend services | Scope `MetricsPublisher`. |
| `GRAFANA_TEMPO_OTLP_ENDPOINT` | Grafana Cloud | Org | All backend services | OTLP gRPC endpoint. |
| `GRAFANA_TEMPO_USERNAME` | Grafana Cloud | Org | All backend services | |
| `GRAFANA_TEMPO_API_KEY` | Grafana Cloud | Org | All backend services | |
| `RAILWAY_HB_CATALOG_SERVICE_PUBLIC_URL` | Railway | Org | Frontend builds (`hb-catalog-web`) | Resolved post-deploy in Section 3.6. |
| `RAILWAY_HB_SUPPORT_SERVICE_PUBLIC_URL` | Railway | Org | Frontend builds (`hb-support-web`) | |
| `RAILWAY_SC_ORDER_SERVICE_PUBLIC_URL` | Railway | Org | Frontend builds (`sc-totem-web`) + InfinitePay webhook | |
| `RAILWAY_HB_CASHIER_SERVICE_PUBLIC_URL` | Railway | Org | Frontend builds (`hb-cashier-web`) | |
| `RAILWAY_KEYCLOAK_PUBLIC_URL` | Railway | Org | All frontend + backend builds | Issuer URL. |
| `KEYCLOAK_HB_CATALOG_SERVICE_CLIENT_SECRET` | Keycloak | Repo (`hb-catalog-service`) | `hb-catalog-service` | One client secret per service. |
| `KEYCLOAK_HB_SUPPORT_SERVICE_CLIENT_SECRET` | Keycloak | Repo (`hb-support-service`) | `hb-support-service` | |
| `KEYCLOAK_SC_ORDER_SERVICE_CLIENT_SECRET` | Keycloak | Repo (`sc-order-service`) | `sc-order-service` | |
| `KEYCLOAK_HB_CASHIER_SERVICE_CLIENT_SECRET` | Keycloak | Repo (`hb-cashier-service`) | `hb-cashier-service` | |
| `KEYCLOAK_BOOTSTRAP_ADMIN_PASSWORD` | Keycloak | Repo (`platform-iam`) | `keycloak` first-boot | Rotate immediately after first login. |

### 10.1 Populating secrets via `gh`

For org-scoped secrets, repeat per name:

```bash
gh secret set RAILWAY_TOKEN --org hubinity --visibility all
# stdin prompt → paste the value
```

For repo-scoped secrets:

```bash
gh secret set INFINITEPAY_WEBHOOK_SECRET \
  --repo hubinity/sc-order-service
```

- [ ] Run the above for every row in the table.
- [ ] Verify with:
  ```bash
  gh secret list --org hubinity
  gh secret list --repo hubinity/sc-order-service
  ```

---

## Section 11 — Initial validation checklist

Smoke-test the end-to-end pipeline before moving on. Run each step in order;
do not proceed if a step fails.

- [ ] **Container registry push smoke.**
  Clone any backend repo (e.g. `hb-catalog-service`), build a throwaway image
  and push to GHCR:
  ```bash
  git clone https://github.com/hubinity/hb-catalog-service.git
  cd hb-catalog-service
  echo "${GH_PACKAGES_TOKEN}" | docker login ghcr.io -u ${GITHUB_USER} --password-stdin
  docker build -t ghcr.io/hubinity/hb-catalog-service:smoke .
  docker push ghcr.io/hubinity/hb-catalog-service:smoke
  ```
  Verify the tag appears at https://github.com/orgs/hubinity/packages.

- [ ] **Railway manual deploy smoke.**
  From the Railway dashboard, trigger a manual deploy of
  `hb-catalog-service`. After ~3 minutes, hit:
  ```bash
  curl -fsS https://${RAILWAY_HB_CATALOG_SERVICE_PUBLIC_URL}/actuator/health
  ```
  Expect `{"status":"UP"}`.

- [ ] **Supabase JDBC connectivity smoke.**
  In Railway, inspect the running service's logs and confirm there are no
  `PSQLException: SSL error` or `prepared statement … already exists`
  messages.

- [ ] **CloudAMQP round-trip smoke.**
  In the CloudAMQP management UI:
  1. Publish a test message to `catalog.events` with routing key
     `test.smoke`.
  2. Bind a temporary queue `smoke-test` to that exchange with the same
     routing key.
  3. Confirm the message lands in the queue.
  4. Delete the temporary queue.

- [ ] **Frontend preview smoke.**
  Push a trivial commit to a branch in `hb-catalog-web`; Vercel must build
  a preview URL automatically. Confirm the preview loads.

- [ ] **InfinitePay webhook reachability smoke.**
  From the InfinitePay developer dashboard, fire a sandbox test webhook.
  Confirm `sc-order-service` logs receipt and rejects (or accepts) it based
  on HMAC validation against `INFINITEPAY_WEBHOOK_SECRET`.

- [ ] **Better Stack ingestion smoke.**
  Tail any Logtail source's live view; trigger a log line from the deployed
  service (e.g. hit `/actuator/info`). Confirm the line lands.

- [ ] **Grafana Cloud metric smoke.**
  After enabling the OpenTelemetry agent (later feature), confirm
  `http_server_requests_seconds_count` arrives in the `hubinity` stack's
  Prometheus.

---

## Section 12 — Cost summary

Baseline monthly cost for the MVP, assuming Free / Hobby tiers everywhere.

| Service | Plan | Monthly cost | Notes |
|---|---|---|---|
| Supabase × 4 | Free | $0 | 500 MB / proj, 7-day backup, pauses after 1 week of inactivity |
| Railway (Keycloak + sc-order + hb-cashier) | Hobby × 3 | $15 | No hibernation; $5 / svc |
| Railway (hb-catalog + hb-support) | Free | $0 | Keep-alive via UptimeRobot |
| Vercel × 3 | Free (Hobby) | $0 | 100 GB transfer / mo, unlimited preview deploys |
| Netlify × 1 | Free | $0 | 100 GB bandwidth / mo |
| CloudAMQP | Little Lemur | $0 | 1 M msg / mo, 20 connections |
| InfinitePay sandbox | Free | $0 | Production tier TBD post-KYC |
| Better Stack (Logtail) | Free | $0 | 1 GB / mo retention, 3-day search |
| Grafana Cloud | Free | $0 | 10 k metrics series, 50 GB logs, 50 GB traces |
| UptimeRobot | Free | $0 | 50 monitors, 5-min interval |
| GitHub (Team / Free) | Free | $0 | Public + private repos, Actions 2 000 min / mo |
| GitHub Container Registry | Free (with GitHub) | $0 | 500 MB storage / 1 GB transfer per private repo |
| **TOTAL** | | **$15 / mo** | MVP baseline |

Notes:
- Free Supabase projects pause after a week of inactivity; UptimeRobot is the
  cheapest mitigation (a 5-min ping on the Spring health check is enough to
  keep the connection pool warm).
- GitHub Actions Free tier (2 000 minutes / mo) is tight with 12 repos × CI.
  Plan to upgrade to GitHub Team ($4 / user / mo) once contributor count
  rises.
- Once any free tier saturates, the upgrade path is linear: Supabase Pro
  ($25 / proj), Vercel Pro ($20 / user), Netlify Pro ($19), CloudAMQP Tough
  Tiger ($19).

---

## Next steps

Once every checkbox above is ticked and Section 11's smokes pass:

1. Kick off the **local docker-compose stack** feature (separate Fase 0
   item) — that will produce `platform-infra/docker-compose/` for offline
   development against equivalents of these providers (Postgres, RabbitMQ,
   Keycloak, Logtail mock).
2. Wire each repo's `.github/workflows/ci.yml` to the secrets table above.
3. Schedule a quarterly **secret rotation** review on the team calendar
   (`RAILWAY_TOKEN`, `VERCEL_TOKEN`, `GH_PACKAGES_TOKEN`, all DB passwords).
4. Replace the placeholder webhook URL and KYC-pending InfinitePay creds
   when production approval lands.

— end of checklist —

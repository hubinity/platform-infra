# Hubinity — Checklist de Configuração Externa (Nuvem)

**Público-alvo:** o único operador responsável por provisionar, pela primeira
vez, todas as contas externas do ecossistema Hubinity.
**Objetivo:** ao final deste checklist, todas as contas de provedores,
projetos, segredos e strings de conexão necessários para implantar a plataforma
Hubinity estarão configurados e registrados em um cofre seguro de segredos.

Este documento é **intencionalmente exaustivo**. Marque todas as caixas. Não
pule seções — as seções anteriores geram valores que serão utilizados pelas
seções posteriores.

Diretório de trabalho deste documento:
`/home/lenoln/Área de Trabalho/workspace/projects/active/hubinity/platform-infra/docs/`.

---

## Sumário

- [Seção 0 — Pré-requisitos](#seção-0--pré-requisitos)
- [Seção 1 — Organização GitHub `hubinity`](#seção-1--organização-github-hubinity)
- [Seção 2 — Supabase (4 projetos, apenas Postgres)](#seção-2--supabase-4-projetos-apenas-postgres)
- [Seção 3 — Railway (deploys de backend + Keycloak)](#seção-3--railway-deploys-de-backend--keycloak)
- [Seção 4 — Vercel (3 frontends de backoffice)](#seção-4--vercel-3-frontends-de-backoffice)
- [Seção 5 — Netlify (PWA do totem)](#seção-5--netlify-pwa-do-totem)
- [Seção 6 — CloudAMQP (RabbitMQ)](#seção-6--cloudamqp-rabbitmq)
- [Seção 7 — InfinitePay (gateway PIX)](#seção-7--infinitepay-gateway-pix)
- [Seção 8 — Observabilidade (Better Stack + Grafana Cloud)](#seção-8--observabilidade-better-stack--grafana-cloud)
- [Seção 9 — Registro de contêineres (`ghcr.io/hubinity`)](#seção-9--registro-de-contêineres-ghcriohubinity)
- [Seção 10 — Segredos do GitHub Actions (lista exaustiva)](#seção-10--segredos-do-github-actions-lista-exaustiva)
- [Seção 11 — Checklist de validação inicial](#seção-11--checklist-de-validação-inicial)
- [Seção 12 — Resumo de custos](#seção-12--resumo-de-custos)
- [Próximos passos](#próximos-passos)

---

## Seção 0 — Pré-requisitos

### 0.1 Ferramentas locais

Instale as ferramentas a seguir em sua estação de trabalho. Abaixo há dicas de
instalação em uma linha para Debian/Ubuntu e macOS (Homebrew).

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
- [x] **docker** (Engine + CLI) e **docker buildx**
  ```bash
  # Linux (Docker Engine)
  curl -fsSL https://get.docker.com | sh
  # macOS (Docker Desktop)
  brew install --cask docker
  ```
- [x] **jq** (para extrair valores JSON em scripts de shell)
  ```bash
  sudo apt-get install -y jq    # Linux
  brew install jq               # macOS
  ```
- [x] CLI do **supabase** (opcional, mas recomendado para migrações futuras do
  banco de dados)
  ```bash
  # Linux/macOS via npm
  npm install -g supabase
  # or macOS
  brew install supabase/tap/supabase
  ```
- [x] CLI do **railway** (opcional, útil para acompanhar logs)
  ```bash
  # macOS
  brew install railway
  # Linux
  curl -fsSL https://railway.app/install.sh | sh
  ```
- [x] CLI do **vercel** (opcional)
  ```bash
  npm install -g vercel
  ```
- [x] CLI do **netlify** (opcional)
  ```bash
  npm install -g netlify-cli
  ```

Após a instalação, execute uma verificação básica:

```bash
git --version && gh --version && docker --version && jq --version
```

### 0.2 Criação das contas nos provedores

Crie ou confirme uma conta em cada provedor. Use o plano recomendado e um
**e-mail organizacional compartilhado** (por exemplo, `ops@hubinity.io` —
ajuste para o domínio real). Habilite a autenticação de dois fatores em todos
os provedores.

- [x] **GitHub** — https://github.com/join — A organização `hubinity` já existe.
- [x] **Supabase** — https://supabase.com — Plano gratuito.
- [x] **Railway** — https://railway.app — Hobby (US$ 5/serviço) para serviços
  pagos e gratuito para os demais. Vinculado ao GitHub para deploys baseados
  em repositórios.
- [x] **Vercel** — https://vercel.com — Hobby (gratuito).
- [x] **Netlify** — https://netlify.com — Gratuito.
- [x] **CloudAMQP** — https://cloudamqp.com — Little Lemur (gratuito).
- [x] **InfinitePay** — Conta sandbox. Verifique a URL canônica de cadastro em
  https://infinitepay.io (portal do desenvolvedor — confirme a URL canônica
  com o provedor).
- [x] **Better Stack (Logtail)** — https://betterstack.com — Gratuito.
- [x] **Grafana Cloud** — https://grafana.com/products/cloud — Gratuito.
- [x] **UptimeRobot** — https://uptimerobot.com — Gratuito (para pings que
  mantenham os serviços do Railway ativos).

### 0.3 Cofre de segredos

Escolha **um** cofre de segredos e utilize-o durante todo o processo. Opções
recomendadas:

- [ ] **1Password** — cofre compartilhado `hubinity-infra`.
- [ ] OU **Bitwarden** — coleção `hubinity/infra`.
- [x] OU **Authenticator** — códigos `hubinity-infra`.
- [ ] OU, como alternativa, um arquivo local criptografado (`pass`, YAML
  criptografado com `age`).

Todos os valores obtidos abaixo DEVEM ser armazenados aqui antes de seguir para
a próxima seção. Os segredos do GitHub Actions são preenchidos **a partir**
deste cofre na Seção 10, e não o contrário.

---

## Seção 1 — Organização GitHub `hubinity`

### 1.1 Confirmar os repositórios

- [x] Autentique o `gh` na organização:
  ```bash
  gh auth login --scopes "repo,read:org,admin:org,workflow,write:packages"
  gh auth status
  ```
- [x] Confirme que os 12 repositórios existem:
  ```bash
  gh repo list hubinity --limit 50 --json name --jq '.[].name' | sort
  ```
  Lista esperada (em ordem alfabética):
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

### 1.2 Times

- [x] Crie os três times fundamentais (somente administradores; pule se já
  tiverem sido criados):
  ```bash
  gh api -X POST orgs/hubinity/teams -f name='backend'  -f privacy='closed'
  gh api -X POST orgs/hubinity/teams -f name='frontend' -f privacy='closed'
  gh api -X POST orgs/hubinity/teams -f name='devops'   -f privacy='closed'
  ```
- [x] Adicione a si mesmo (e quaisquer outros operadores) aos três times:
  ```bash
  gh api -X PUT orgs/hubinity/teams/backend/memberships/${GITHUB_USERNAME}
  gh api -X PUT orgs/hubinity/teams/frontend/memberships/${GITHUB_USERNAME}
  gh api -X PUT orgs/hubinity/teams/devops/memberships/${GITHUB_USERNAME}
  ```

### 1.3 Proteção da branch `main`

Aplique uma proteção uniforme à branch `main` de cada repositório:

- Exigir revisão do pull request (≥ 1 aprovação).
- Exigir que as verificações de status (CI) sejam aprovadas antes do merge.
- Descartar revisões obsoletas após novos commits.
- Restringir pushes forçados.
- Restringir a exclusão da branch.

- [x] Execute o loop abaixo (requer `gh` e `jq`):
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
  > Observação: o array `required_status_checks.contexts` permanece vazio até
  > que os workflows de CI publiquem seu primeiro nome de verificação; revise
  > essa configuração após a Seção 11.

### 1.4 CODEOWNERS

- [x] Adicione o arquivo abaixo em `.github/CODEOWNERS` em **todos** os
  repositórios. Ajuste as substituições específicas de cada repositório
  conforme necessário (por exemplo, repositórios `*-service` precisam de
  `@hubinity/backend` como proprietário padrão, e repositórios `*-web`
  precisam de `@hubinity/frontend`).

  Modelo genérico (use `@hubinity/devops` como proprietário global padrão):
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
- [x] Abra um PR em cada repositório adicionando `.github/CODEOWNERS` e faça o
  merge. A regra de proteção de branch acima (`require_code_owner_reviews`)
  passará a valer nos PRs seguintes.

### 1.5 Renovate Bot

- [x] Instale o aplicativo **Renovate** para GitHub em
  https://github.com/apps/renovate e conceda acesso a **todos os
  repositórios** da organização `hubinity`.
- [x] Adicione o conteúdo abaixo ao arquivo `renovate.json` (na raiz) de cada
  repositório:
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
- [ ] Verifique se o Renovate abriu o PR inicial de integração, "Configure
  Renovate", em cada repositório dentro de aproximadamente 30 minutos após a
  instalação; faça o merge desse PR.

### 1.6 GitHub Packages — registros Maven, npm e de contêineres

- [ ] Confirme em https://github.com/orgs/hubinity/packages que os três
  registros (Maven, npm e contêineres) estão visíveis (eles são habilitados
  por padrão para organizações).
- [ ] Cada membro da organização que consome artefatos internos precisa de um
  PAT (clássico) com `read:packages`. Documente as etapas no README do
  repositório; o consumidor deve adicionar:
  - Para Maven, em `~/.m2/settings.xml`:
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
    Use como referência o exemplo publicado em
    `platform-shared-contracts/settings.xml` assim que for adicionado ao
    repositório.
  - Para npm, em `~/.npmrc`:
    ```ini
    @hubinity:registry=https://npm.pkg.github.com
    //npm.pkg.github.com/:_authToken=${GITHUB_TOKEN}
    ```
    Use como referência o README do `tailwind-preset` assim que for publicado.
- [ ] Gere um PAT **no nível da organização** para uso na CI (clássico, com os
  escopos `write:packages`, `read:packages` e `delete:packages`). Armazene-o
  como `GH_PACKAGES_TOKEN`.

---

## Seção 2 — Supabase (4 projetos, apenas Postgres)

Usamos o Supabase **apenas como Postgres gerenciado**. Auth, Storage, Realtime
e Edge Functions permanecem desabilitados.

### 2.1 Criar os 4 projetos

Crie cada um dos quatro projetos com os mesmos parâmetros:

- Região: **`sa-east-1`** (São Paulo) — menor latência para usuários
  brasileiros.
- Plano: **gratuito**.
- Configurações que afetam o preço: **padrão**.
- Senha do banco de dados: **gerada automaticamente**, com ≥ 32 caracteres e
  armazenada imediatamente no cofre de segredos.

- [ ] Projeto **`hb-catalog`** — para o `hb-catalog-service`.
- [ ] Projeto **`hb-support`** — para o `hb-support-service`.
- [ ] Projeto **`sc-order`**   — para o `sc-order-service`.
- [ ] Projeto **`hb-cashier`** — para o `hb-cashier-service`.

### 2.2 Obter os detalhes de conexão de cada projeto

Para **cada** projeto, copie para o cofre de segredos os valores exibidos no
painel do Supabase (*Settings → Database → Connection string → Transaction
mode (Supavisor)*).

Variáveis por serviço (substitua `<SVC>` por `CATALOG`, `SUPPORT`, `ORDER` ou
`CASHIER`):

- [ ] `SUPABASE_<SVC>_DB_HOST` — hostname do pooler, por exemplo,
  `aws-0-sa-east-1.pooler.supabase.com`.
- [ ] `SUPABASE_<SVC>_DB_PORT` — `6543` (Supavisor, modo de transação).
- [ ] `SUPABASE_<SVC>_DB_NAME` — `postgres`.
- [ ] `SUPABASE_<SVC>_DB_USER` — `postgres.<project-ref>` (por exemplo,
  `postgres.abcdefghijklmnop`).
- [ ] `SUPABASE_<SVC>_DB_PASSWORD` — a senha gerada automaticamente.
  **Troque-a antes da entrada em produção.**
- [ ] `SUPABASE_<SVC>_PROJECT_URL` — `https://<project-ref>.supabase.co`.
- [ ] `SUPABASE_<SVC>_ANON_KEY` — obtida para fins de completude; não é usada
  pelos serviços Spring (eles se conectam via JDBC), mas será útil se uma
  funcionalidade futura precisar do PostgREST.

### 2.3 Padrão da URL JDBC

Os serviços Spring montam a URL JDBC usando este modelo:

```text
jdbc:postgresql://${HOST}:${PORT}/${DB}?sslmode=require&prepareThreshold=0&user=${USER}
```

Exemplo concreto (por serviço, substitua os placeholders):

```text
jdbc:postgresql://${SUPABASE_CATALOG_DB_HOST}:${SUPABASE_CATALOG_DB_PORT}/${SUPABASE_CATALOG_DB_NAME}?sslmode=require&prepareThreshold=0&user=${SUPABASE_CATALOG_DB_USER}
```

`prepareThreshold=0` é **obrigatório** no modo de pool de transações (PgBouncer
/ Supavisor). A senha é fornecida pela propriedade
`spring.datasource.password` do Spring, e não pela URL.

- [ ] Teste a URL JDBC a partir de sua estação de trabalho:
  ```bash
  psql "host=${SUPABASE_CATALOG_DB_HOST} port=6543 dbname=postgres user=${SUPABASE_CATALOG_DB_USER} password=${SUPABASE_CATALOG_DB_PASSWORD} sslmode=require" -c "select version();"
  ```

### 2.4 Retenção de backups

- [ ] Confirme que o **snapshot automático de 7 dias** está habilitado em cada
  projeto (padrão do plano gratuito; *Settings → Database → Backups*).
- [ ] Documente o procedimento de restauração manual em um runbook futuro
  (`platform-infra/runbooks/db-restore.md`, a ser criado posteriormente).

### 2.5 Funcionalidades desabilitadas

Em cada projeto:

- [ ] **Authentication** — desabilitada (usamos o Keycloak).
- [ ] **Storage** — desabilitado.
- [ ] **Realtime** — desabilitado.
- [ ] **Edge Functions** — nenhuma função implantada.

---

## Seção 3 — Railway (deploys de backend + Keycloak)

O Railway hospeda os quatro backends Spring Boot e uma instância do Keycloak
mantida pela própria equipe. São cinco serviços no total.

### 3.1 Conta + CLI

- [ ] Crie a conta do Railway usando o e-mail compartilhado da organização.
- [ ] Instale a CLI (consulte a Seção 0).
- [ ] Execute `railway login`.
- [ ] Crie um **projeto** chamado `hubinity`.

### 3.2 Criar um serviço por backend

Dentro do projeto `hubinity`, crie cinco serviços:

- [ ] `hb-catalog-service` — deploy do repositório
  `hubinity/hb-catalog-service`.
- [ ] `hb-support-service` — deploy do repositório
  `hubinity/hb-support-service`.
- [ ] `sc-order-service`   — deploy do repositório
  `hubinity/sc-order-service`.
- [ ] `hb-cashier-service` — deploy do repositório
  `hubinity/hb-cashier-service`.
- [ ] `keycloak`           — deploy do repositório `hubinity/platform-iam`.

Para cada serviço:

- [ ] Origem: **Deploy from GitHub repo** → branch `main`.
- [ ] Build: **Dockerfile** na raiz do repositório.
- [ ] Caminho de verificação de integridade: `/actuator/health` nos serviços
  Spring e `/health/ready` no Keycloak.
- [ ] Política de reinicialização: `ON_FAILURE` (padrão).

### 3.3 Escolha do plano (custo)

- [ ] Faça upgrade dos serviços abaixo para o plano **Hobby** (US$ 5/serviço,
  sem hibernação):
  - `sc-order-service` — a latência dos pagamentos não tolera inicializações a
    frio.
  - `hb-cashier-service` — usado pelo ponto de venda (PDV).
  - `keycloak` — a emissão de tokens ocorre em todas as requisições à API.
- [ ] Mantenha no plano **gratuito** (com um ping do UptimeRobot a cada cinco
  minutos para mantê-los ativos):
  - `hb-catalog-service`
  - `hb-support-service`
- [ ] No **UptimeRobot**, crie um monitor HTTP(S) para cada serviço gratuito,
  acessando `https://<svc>.up.railway.app/actuator/health` a cada cinco minutos.

### 3.4 Variáveis de ambiente por serviço

Defina as variáveis abaixo em cada serviço Spring (substitua os placeholders
pelos valores da Seção 2):

- [ ] `SPRING_DATASOURCE_URL` — a URL JDBC da Seção 2.3.
- [ ] `SPRING_DATASOURCE_USERNAME` — `${SUPABASE_<SVC>_DB_USER}`.
- [ ] `SPRING_DATASOURCE_PASSWORD` — `${SUPABASE_<SVC>_DB_PASSWORD}`.
- [ ] `SPRING_RABBITMQ_ADDRESSES` — `${CLOUDAMQP_URL}` (Seção 6).
- [ ] `KEYCLOAK_ISSUER_URL` — aponta internamente para o serviço Keycloak no
  Railway: `https://keycloak.railway.internal/realms/hubinity` (use a rede
  privada do Railway; confirme o formato exato do hostname na documentação do
  Railway).
- [ ] `KEYCLOAK_CLIENT_ID` e `KEYCLOAK_CLIENT_SECRET` por serviço.
- [ ] `LOGTAIL_SOURCE_TOKEN` — `${LOGTAIL_<SVC>_SOURCE_TOKEN}` (Seção 8).
- [ ] `OTEL_EXPORTER_OTLP_ENDPOINT` — endpoint OTLP do Tempo no Grafana Cloud
  (Seção 8).
- [ ] `BUILD_VERSION` — injetada pelo workflow de deploy (SHA do Git).

Específicas do Keycloak:

- [ ] `KC_DB` — `postgres`.
- [ ] `KC_DB_URL` — URL JDBC que aponta para um Postgres dedicado (considere
  um quinto projeto Supabase, `hb-iam`, OU reutilize o `hb-support` com
  separação de schemas; a decisão final fica adiada para a funcionalidade
  `platform-iam` — confirme antes da entrada em produção).
- [ ] `KC_HOSTNAME` — hostname público atribuído pelo Railway.
- [ ] `KC_HTTP_ENABLED` — `true` (o Railway faz a terminação do TLS).
- [ ] `KC_PROXY` — `edge`.
- [ ] `KEYCLOAK_ADMIN` e `KEYCLOAK_ADMIN_PASSWORD` — usuário administrador de
  inicialização.

### 3.5 Tokens para CI

- [ ] Em **Account Settings → Tokens**, gere um token com escopo de projeto
  para o projeto `hubinity` do Railway. Armazene-o como **`RAILWAY_TOKEN`** no
  cofre de segredos e injete-o no GitHub Actions (Seção 10).

### 3.6 URLs públicas

- [ ] Obtenha a URL pública do Railway para cada serviço (por exemplo,
  `https://hb-catalog-service.up.railway.app`) e armazene-a como
  `RAILWAY_<SVC>_PUBLIC_URL`. Essas URLs alimentam as variáveis de ambiente dos
  frontends na Seção 4.

---

## Seção 4 — Vercel (3 frontends de backoffice)

### 4.1 Conta + CLI

- [ ] Crie a conta da Vercel; vincule-a à organização `hubinity` do GitHub
  durante o cadastro (o aplicativo da Vercel para GitHub deve receber acesso
  aos três repositórios de frontend).
- [ ] Execute `vercel login` (opcional, mas útil).

### 4.2 Criar um projeto por repositório

- [ ] **`hb-catalog-web`** → domínio de produção `hb-catalog-web.vercel.app`
  (domínio personalizado a definir).
- [ ] **`hb-support-web`** → domínio de produção `hb-support-web.vercel.app`.
- [ ] **`hb-cashier-web`** → domínio de produção `hb-cashier-web.vercel.app`.

Para cada projeto:

- [ ] Origem: repositório `hubinity/<repo>` do GitHub.
- [ ] Branch de produção: `main`.
- [ ] Predefinição de framework: **Angular** (a Vercel detecta automaticamente
  a partir do `angular.json`).
- [ ] Comando de build: `npm run build` (ou o padrão do framework).
- [ ] Diretório de saída: `dist/<repo>/browser` (padrão do Angular 17+).
- [ ] Versão do Node: **20.x**.

### 4.3 Variáveis de ambiente por projeto

Defina as variáveis abaixo para cada frontend em *Project → Settings →
Environment Variables* (escopo: Production + Preview):

- [ ] `KEYCLOAK_ISSUER_URL` — URL pública do Keycloak obtida na Seção 3.6.
- [ ] `KEYCLOAK_CLIENT_ID` — `<repo>` (cada frontend é seu próprio cliente
  público).
- [ ] `API_BASE_URL` — aponta para a URL do backend correspondente no Railway:
  - `hb-catalog-web` → `RAILWAY_HB_CATALOG_SERVICE_PUBLIC_URL`
  - `hb-support-web` → `RAILWAY_HB_SUPPORT_SERVICE_PUBLIC_URL`
  - `hb-cashier-web` → `RAILWAY_HB_CASHIER_SERVICE_PUBLIC_URL`
- [ ] `BUILD_VERSION` — preenchida pela CI com o SHA do Git.
- [ ] `SENTRY_DSN` — placeholder por enquanto (o Sentry não faz parte deste
  checklist; será opcional posteriormente).

### 4.4 Tokens para CI

- [ ] Em **Vercel → Account Settings → Tokens**, gere um token com escopo
  *Full Account*. Armazene-o como **`VERCEL_TOKEN`**.
- [ ] Em **Vercel → Team Settings → General**, copie o **Team ID**. Armazene-o
  como **`VERCEL_ORG_ID`** (compartilhado pelos três frontends).
- [ ] Em *Settings → General* de cada projeto, copie o **Project ID**.
  Armazene-o como:
  - `VERCEL_PROJECT_ID_HB_CATALOG_WEB`
  - `VERCEL_PROJECT_ID_HB_SUPPORT_WEB`
  - `VERCEL_PROJECT_ID_HB_CASHIER_WEB`

---

## Seção 5 — Netlify (PWA do totem)

O PWA do totem de autoatendimento é hospedado na Netlify (o cache de borda da
Netlify é preferível para uma aplicação de quiosque servida por pontos de
presença geograficamente distribuídos).

### 5.1 Conta + vinculação

- [ ] Crie a conta da Netlify; vincule-a à organização do GitHub (conceda
  acesso apenas ao `sc-totem-web`).

### 5.2 Site

- [ ] Crie o site `sc-totem-web`:
  - Repositório: `hubinity/sc-totem-web`.
  - Branch: `main` (produção).
  - Comando de build: `npm run build`.
  - Diretório de publicação: `dist/sc-totem-web/browser`.
  - Versão do Node: **20.x** (definida pelo `netlify.toml` ou pela variável de
    ambiente `NODE_VERSION=20`).
- [ ] Variáveis de ambiente no nível do site:
  - `KEYCLOAK_ISSUER_URL`
  - `KEYCLOAK_CLIENT_ID` = `sc-totem-web`
  - `API_BASE_URL` — `RAILWAY_SC_ORDER_SERVICE_PUBLIC_URL`
  - `BUILD_VERSION` — preenchida pela CI

### 5.3 PWA

- [ ] Confirme que `ng add @angular/pwa` foi executado no repositório e gera
  `manifest.webmanifest` e um service worker na saída do build. A Netlify
  serve esses arquivos sem configuração adicional; certifique-se de que o
  cabeçalho `Cache-Control` do `index.html` seja `no-cache` (definido pelo
  `netlify.toml`).

### 5.4 Tokens para CI

- [ ] **Netlify → User settings → Applications → Personal access tokens**:
  gere um token. Armazene-o como **`NETLIFY_AUTH_TOKEN`**.
- [ ] **Site settings → General → Site details**: copie o **Site ID**.
  Armazene-o como **`NETLIFY_SITE_ID_SC_TOTEM_WEB`**.

---

## Seção 6 — CloudAMQP (RabbitMQ)

### 6.1 Instância

- [ ] Crie uma instância **Little Lemur (gratuita)**:
  - Nome: `hubinity-rabbitmq`.
  - Região: São Paulo, se disponível (`AWS sa-east-1`); caso contrário,
    US-East (`AWS us-east-1`).
  - Plano: Little Lemur — 1 milhão de mensagens/mês, limite de 1 milhão de
    mensagens enfileiradas e 20 conexões.

### 6.2 Obter os detalhes de conexão

- [ ] **String de conexão AMQP** (no painel do CloudAMQP):
  `amqps://<user>:<pass>@<host>/<vhost>`. Armazene-a como **`CLOUDAMQP_URL`**.
- [ ] **URL de gerenciamento** para acesso pelo navegador (depuração de
  filas): `https://<host>/api/`. Armazene-a como `CLOUDAMQP_MGMT_URL`.
- [ ] **Credenciais de gerenciamento** (mesmos usuário e senha do AMQP) —
  usadas para entrar na interface de gerenciamento.

### 6.3 Exchanges e DLX

Assim que o primeiro serviço Spring estiver em execução e acessível, crie os
exchanges planejados. Crie-os pela interface de gerenciamento (*Exchanges →
Add new exchange*) ou pelo `rabbitmqadmin`:

- [ ] `catalog.events`  — tipo `topic`, durável.
- [ ] `order.events`    — tipo `topic`, durável.
- [ ] `support.events`  — tipo `topic`, durável.
- [ ] `cashier.events`  — tipo `topic`, durável.
- [ ] Exchanges de mensagens mortas por consumidor (um para cada serviço que
  consome mensagens):
  - `catalog.dlx` (topic, durável)
  - `order.dlx`   (topic, durável)
  - `support.dlx` (topic, durável)
  - `cashier.dlx` (topic, durável)

As próprias filas são declaradas em tempo de execução pelos serviços Spring
por meio do `spring-rabbit`; os exchanges devem existir previamente (ou ser
declarados pelo primeiro serviço a iniciar — confirme a convenção do projeto
antes da entrada em produção).

### 6.4 Monitoramento

- [ ] No painel do CloudAMQP, habilite o widget *Monthly usage* e acompanhe o
  limite de **1 milhão de mensagens/mês**. Configure um alerta por e-mail ao
  atingir 80%.
- [ ] Documente o caminho de upgrade (Tough Tiger, US$ 19/mês) no runbook de
  custos.

---

## Seção 7 — InfinitePay (gateway PIX)

O PIX é a única forma de pagamento do MVP. A InfinitePay é o gateway.

### 7.1 Conta sandbox

- [ ] Cadastre-se para obter uma conta de desenvolvedor no **sandbox**.
  *Confirme a URL canônica de cadastro com o provedor* — comece em
  https://infinitepay.io/ e siga o link "Desenvolvedores" / "API".
- [ ] Envie a documentação de KYC necessária para passar do sandbox para
  produção (adie para a funcionalidade de entrada em produção).

### 7.2 Credenciais

Obtenha no painel do desenvolvedor:

- [ ] **`INFINITEPAY_CLIENT_ID`** — ID do cliente OAuth2.
- [ ] **`INFINITEPAY_CLIENT_SECRET`** — segredo do cliente OAuth2.
- [ ] **`INFINITEPAY_WEBHOOK_SECRET`** — chave de assinatura HMAC usada para
  validar os payloads dos webhooks recebidos. **Crítico**: um valor ausente ou
  incorreto permite a entrada de confirmações de pagamento falsificadas.

### 7.3 URL do webhook

- [ ] No painel, configure o endpoint do webhook:
  ```text
  https://${RAILWAY_SC_ORDER_SERVICE_PUBLIC_URL}/api/v1/payments/webhook
  ```
  Exemplo concreto após o preenchimento da Seção 3.6:
  ```text
  https://sc-order-service.up.railway.app/api/v1/payments/webhook
  ```
- [ ] Adicione os IPs de origem dos webhooks da InfinitePay à lista de
  permissões do Railway (caso o Railway ofereça esse recurso no plano Hobby —
  confirme; caso contrário, dependa apenas da validação HMAC).

### 7.4 Dados de teste do sandbox

Documente no repositório `sc-order-service` (não aqui) as chaves PIX de sandbox
e os CPFs fictícios oficiais que a equipe de QA usará. Para este checklist,
obtenha:

- [ ] Um **CPF de teste** funcional (por exemplo, `12345678909` — confirme na
  documentação da InfinitePay; CPFs que passam na validação módulo 11
  geralmente são aceitos).
- [ ] Uma **chave PIX aleatória de teste** funcional (UUID v4).
- [ ] Uma **chave PIX de e-mail de teste** funcional
  (`pix-test@hubinity.io`).

> **Não** codifique esses valores diretamente no `application.yml`;
> mantenha-os em arquivos de fixtures nos recursos de testes de integração do
> `sc-order-service`.

---

## Seção 8 — Observabilidade (Better Stack + Grafana Cloud)

### 8.1 Better Stack (Logtail)

- [ ] Crie uma **fonte** do Logtail por serviço (cinco no total: catalog,
  support, order, cashier e keycloak). Tipo da fonte: **Generic HTTP** (os
  serviços Spring Boot enviam JSON por HTTPS usando um appender do Logback).
- [ ] Obtenha o token de cada fonte. Armazene-os como:
  - `LOGTAIL_HB_CATALOG_SOURCE_TOKEN`
  - `LOGTAIL_HB_SUPPORT_SOURCE_TOKEN`
  - `LOGTAIL_SC_ORDER_SOURCE_TOKEN`
  - `LOGTAIL_HB_CASHIER_SOURCE_TOKEN`
  - `LOGTAIL_KEYCLOAK_SOURCE_TOKEN`
- [ ] Confirme o padrão da URL de ingestão de cada fonte
  (`https://in.logs.betterstack.com`).
- [ ] Crie um **time** no Better Stack e convide os operadores.

### 8.2 Grafana Cloud (métricas + traces)

- [ ] Crie uma stack **Grafana Cloud Free** chamada `hubinity`.
- [ ] Na stack, localize **Prometheus → Send metrics**:
  - Obtenha a **URL de remote write**. Armazene-a como
    `GRAFANA_PROM_PUSH_URL`.
  - Obtenha o **nome de usuário** (ID numérico da instância). Armazene-o como
    `GRAFANA_PROM_USERNAME`.
  - Gere uma chave de API com o escopo `MetricsPublisher`. Armazene-a como
    `GRAFANA_PROM_API_KEY`.
- [ ] Na stack, localize **Tempo → OTLP**:
  - Obtenha o **endpoint OTLP gRPC**. Armazene-o como
    `GRAFANA_TEMPO_OTLP_ENDPOINT`.
  - Obtenha o **nome de usuário** (ID da instância). Armazene-o como
    `GRAFANA_TEMPO_USERNAME`.
  - Gere uma chave de API com o escopo `MetricsPublisher` (o Tempo a
    reutiliza). Armazene-a como `GRAFANA_TEMPO_API_KEY`.
- [ ] Os serviços Spring serão configurados em uma funcionalidade posterior
  para enviar dados por meio do **OpenTelemetry Java Agent**; por enquanto,
  apenas o endpoint e as credenciais de autenticação são obtidos.

---

## Seção 9 — Registro de contêineres (`ghcr.io/hubinity`)

### 9.1 Confirmar a disponibilidade do registro

- [ ] Acesse https://github.com/orgs/hubinity/packages. O GHCR é habilitado
  por padrão para organizações.
- [ ] Confirme em https://github.com/orgs/hubinity/settings/packages que a
  visibilidade padrão dos pacotes da organização é **privada**.

### 9.2 Acesso de desenvolvedores locais

Para executar `docker pull` a partir de `ghcr.io/hubinity/*`, o desenvolvedor
precisa de um token com `read:packages`. A forma mais simples é:

- [ ] Executar `gh auth login --scopes read:packages` e depois
  `gh auth token | docker login ghcr.io -u ${GITHUB_USER} --password-stdin`.

### 9.3 Acesso de push da CI

A CI envia imagens a cada build da branch `main`. Há duas opções:

- **GITHUB_TOKEN** (preferencial) — automático e limitado ao repositório em
  execução. Basta adicionar `permissions: { packages: write }` ao workflow.
- **`GH_PACKAGES_TOKEN`** (PAT da organização obtido na Seção 1.6) — necessário
  apenas quando o workflow envia uma imagem para o namespace de pacotes de
  outro repositório.

- [ ] Confirme que as configurações de `actions` no nível da organização
  permitem que o `GITHUB_TOKEN` grave pacotes: *Org settings → Actions →
  General → Workflow permissions → "Read and write permissions"*.

---

## Seção 10 — Segredos do GitHub Actions (lista exaustiva)

Configure os segredos abaixo no escopo da **organização**
(https://github.com/organizations/hubinity/settings/secrets/actions), exceto
quando a coluna *Escopo* indicar outra opção. Os segredos com escopo de
repositório permanecem limitados a um único repositório.

| Nome do segredo | Provedor | Escopo | Usado por | Observações |
|---|---|---|---|---|
| `GH_PACKAGES_TOKEN` | GitHub | Organização | Workflows entre repositórios que baixam/enviam pacotes internos Maven/npm/contêiner | PAT clássico, `read:packages`+`write:packages`. Troque a cada 90 dias. |
| `RAILWAY_TOKEN` | Railway | Organização | Todos os workflows de deploy de backend (repositórios `*-service` e `platform-iam`) | Limitado ao projeto `hubinity`. Troque trimestralmente. |
| `SUPABASE_CATALOG_DB_HOST` | Supabase | Organização | Testes de integração + deploy do `hb-catalog-service` | Hostname do pooler. |
| `SUPABASE_CATALOG_DB_PORT` | Supabase | Organização | `hb-catalog-service` | Sempre `6543`. |
| `SUPABASE_CATALOG_DB_NAME` | Supabase | Organização | `hb-catalog-service` | Sempre `postgres`. |
| `SUPABASE_CATALOG_DB_USER` | Supabase | Organização | `hb-catalog-service` | `postgres.<ref>`. |
| `SUPABASE_CATALOG_DB_PASSWORD` | Supabase | Organização | `hb-catalog-service` | Troque antes da produção. |
| `SUPABASE_CATALOG_PROJECT_URL` | Supabase | Organização | `hb-catalog-service` (opcional) | Para uso futuro do PostgREST. |
| `SUPABASE_CATALOG_ANON_KEY` | Supabase | Organização | `hb-catalog-service` (opcional) | Para uso futuro do PostgREST. |
| `SUPABASE_SUPPORT_DB_HOST` | Supabase | Organização | `hb-support-service` | |
| `SUPABASE_SUPPORT_DB_PORT` | Supabase | Organização | `hb-support-service` | Sempre `6543`. |
| `SUPABASE_SUPPORT_DB_NAME` | Supabase | Organização | `hb-support-service` | Sempre `postgres`. |
| `SUPABASE_SUPPORT_DB_USER` | Supabase | Organização | `hb-support-service` | |
| `SUPABASE_SUPPORT_DB_PASSWORD` | Supabase | Organização | `hb-support-service` | |
| `SUPABASE_SUPPORT_PROJECT_URL` | Supabase | Organização | `hb-support-service` | |
| `SUPABASE_SUPPORT_ANON_KEY` | Supabase | Organização | `hb-support-service` | |
| `SUPABASE_ORDER_DB_HOST` | Supabase | Organização | `sc-order-service` | |
| `SUPABASE_ORDER_DB_PORT` | Supabase | Organização | `sc-order-service` | Sempre `6543`. |
| `SUPABASE_ORDER_DB_NAME` | Supabase | Organização | `sc-order-service` | Sempre `postgres`. |
| `SUPABASE_ORDER_DB_USER` | Supabase | Organização | `sc-order-service` | |
| `SUPABASE_ORDER_DB_PASSWORD` | Supabase | Organização | `sc-order-service` | |
| `SUPABASE_ORDER_PROJECT_URL` | Supabase | Organização | `sc-order-service` | |
| `SUPABASE_ORDER_ANON_KEY` | Supabase | Organização | `sc-order-service` | |
| `SUPABASE_CASHIER_DB_HOST` | Supabase | Organização | `hb-cashier-service` | |
| `SUPABASE_CASHIER_DB_PORT` | Supabase | Organização | `hb-cashier-service` | Sempre `6543`. |
| `SUPABASE_CASHIER_DB_NAME` | Supabase | Organização | `hb-cashier-service` | Sempre `postgres`. |
| `SUPABASE_CASHIER_DB_USER` | Supabase | Organização | `hb-cashier-service` | |
| `SUPABASE_CASHIER_DB_PASSWORD` | Supabase | Organização | `hb-cashier-service` | |
| `SUPABASE_CASHIER_PROJECT_URL` | Supabase | Organização | `hb-cashier-service` | |
| `SUPABASE_CASHIER_ANON_KEY` | Supabase | Organização | `hb-cashier-service` | |
| `VERCEL_TOKEN` | Vercel | Organização | Todos os três workflows de deploy de frontend | Troque trimestralmente. |
| `VERCEL_ORG_ID` | Vercel | Organização | Todos os três deploys de frontend | O mesmo para todos os frontends. |
| `VERCEL_PROJECT_ID_HB_CATALOG_WEB` | Vercel | Repositório (`hb-catalog-web`) | Deploy do `hb-catalog-web` | Um por projeto Vercel. |
| `VERCEL_PROJECT_ID_HB_SUPPORT_WEB` | Vercel | Repositório (`hb-support-web`) | Deploy do `hb-support-web` | |
| `VERCEL_PROJECT_ID_HB_CASHIER_WEB` | Vercel | Repositório (`hb-cashier-web`) | Deploy do `hb-cashier-web` | |
| `NETLIFY_AUTH_TOKEN` | Netlify | Repositório (`sc-totem-web`) | Deploy do `sc-totem-web` | Token de acesso pessoal. |
| `NETLIFY_SITE_ID_SC_TOTEM_WEB` | Netlify | Repositório (`sc-totem-web`) | Deploy do `sc-totem-web` | |
| `CLOUDAMQP_URL` | CloudAMQP | Organização | Deploy + testes de integração de todos os serviços de backend | URL AMQPS com as credenciais embutidas. |
| `CLOUDAMQP_MGMT_URL` | CloudAMQP | Organização | Opcional — apenas scripts administrativos | |
| `INFINITEPAY_CLIENT_ID` | InfinitePay | Repositório (`sc-order-service`) | Deploy do `sc-order-service` | Sandbox agora; produção após o KYC. |
| `INFINITEPAY_CLIENT_SECRET` | InfinitePay | Repositório (`sc-order-service`) | Deploy do `sc-order-service` | |
| `INFINITEPAY_WEBHOOK_SECRET` | InfinitePay | Repositório (`sc-order-service`) | Deploy do `sc-order-service` | Verificação HMAC dos payloads dos webhooks. |
| `LOGTAIL_HB_CATALOG_SOURCE_TOKEN` | Better Stack | Repositório (`hb-catalog-service`) | `hb-catalog-service` | Token do appender HTTP do Logback. |
| `LOGTAIL_HB_SUPPORT_SOURCE_TOKEN` | Better Stack | Repositório (`hb-support-service`) | `hb-support-service` | |
| `LOGTAIL_SC_ORDER_SOURCE_TOKEN` | Better Stack | Repositório (`sc-order-service`) | `sc-order-service` | |
| `LOGTAIL_HB_CASHIER_SOURCE_TOKEN` | Better Stack | Repositório (`hb-cashier-service`) | `hb-cashier-service` | |
| `LOGTAIL_KEYCLOAK_SOURCE_TOKEN` | Better Stack | Repositório (`platform-iam`) | Deploy do `keycloak` | |
| `GRAFANA_PROM_PUSH_URL` | Grafana Cloud | Organização | Todos os serviços de backend | Endpoint de remote write. |
| `GRAFANA_PROM_USERNAME` | Grafana Cloud | Organização | Todos os serviços de backend | ID numérico da instância. |
| `GRAFANA_PROM_API_KEY` | Grafana Cloud | Organização | Todos os serviços de backend | Escopo `MetricsPublisher`. |
| `GRAFANA_TEMPO_OTLP_ENDPOINT` | Grafana Cloud | Organização | Todos os serviços de backend | Endpoint OTLP gRPC. |
| `GRAFANA_TEMPO_USERNAME` | Grafana Cloud | Organização | Todos os serviços de backend | |
| `GRAFANA_TEMPO_API_KEY` | Grafana Cloud | Organização | Todos os serviços de backend | |
| `RAILWAY_HB_CATALOG_SERVICE_PUBLIC_URL` | Railway | Organização | Builds de frontend (`hb-catalog-web`) | Resolvida após o deploy na Seção 3.6. |
| `RAILWAY_HB_SUPPORT_SERVICE_PUBLIC_URL` | Railway | Organização | Builds de frontend (`hb-support-web`) | |
| `RAILWAY_SC_ORDER_SERVICE_PUBLIC_URL` | Railway | Organização | Builds de frontend (`sc-totem-web`) + webhook da InfinitePay | |
| `RAILWAY_HB_CASHIER_SERVICE_PUBLIC_URL` | Railway | Organização | Builds de frontend (`hb-cashier-web`) | |
| `RAILWAY_KEYCLOAK_PUBLIC_URL` | Railway | Organização | Todos os builds de frontend + backend | URL do emissor. |
| `KEYCLOAK_HB_CATALOG_SERVICE_CLIENT_SECRET` | Keycloak | Repositório (`hb-catalog-service`) | `hb-catalog-service` | Um segredo de cliente por serviço. |
| `KEYCLOAK_HB_SUPPORT_SERVICE_CLIENT_SECRET` | Keycloak | Repositório (`hb-support-service`) | `hb-support-service` | |
| `KEYCLOAK_SC_ORDER_SERVICE_CLIENT_SECRET` | Keycloak | Repositório (`sc-order-service`) | `sc-order-service` | |
| `KEYCLOAK_HB_CASHIER_SERVICE_CLIENT_SECRET` | Keycloak | Repositório (`hb-cashier-service`) | `hb-cashier-service` | |
| `KEYCLOAK_BOOTSTRAP_ADMIN_PASSWORD` | Keycloak | Repositório (`platform-iam`) | Primeira inicialização do `keycloak` | Troque imediatamente após o primeiro login. |

### 10.1 Preencher os segredos via `gh`

Para os segredos no escopo da organização, repita para cada nome:

```bash
gh secret set RAILWAY_TOKEN --org hubinity --visibility all
# stdin prompt → paste the value
```

Para segredos no escopo de repositório:

```bash
gh secret set INFINITEPAY_WEBHOOK_SECRET \
  --repo hubinity/sc-order-service
```

- [ ] Execute o comando correspondente para todas as linhas da tabela.
- [ ] Verifique com:
  ```bash
  gh secret list --org hubinity
  gh secret list --repo hubinity/sc-order-service
  ```

---

## Seção 11 — Checklist de validação inicial

Faça um teste rápido do pipeline de ponta a ponta antes de prosseguir. Execute
cada etapa na ordem indicada; não avance se alguma etapa falhar.

- [ ] **Teste de envio ao registro de contêineres.**
  Clone qualquer repositório de backend (por exemplo, `hb-catalog-service`),
  faça o build de uma imagem descartável e envie-a ao GHCR:
  ```bash
  git clone https://github.com/hubinity/hb-catalog-service.git
  cd hb-catalog-service
  echo "${GH_PACKAGES_TOKEN}" | docker login ghcr.io -u ${GITHUB_USER} --password-stdin
  docker build -t ghcr.io/hubinity/hb-catalog-service:smoke .
  docker push ghcr.io/hubinity/hb-catalog-service:smoke
  ```
  Confirme que a tag aparece em https://github.com/orgs/hubinity/packages.

- [ ] **Teste de deploy manual no Railway.**
  No painel do Railway, acione um deploy manual do `hb-catalog-service`. Após
  aproximadamente três minutos, acesse:
  ```bash
  curl -fsS https://${RAILWAY_HB_CATALOG_SERVICE_PUBLIC_URL}/actuator/health
  ```
  O resultado esperado é `{"status":"UP"}`.

- [ ] **Teste de conectividade JDBC com o Supabase.**
  No Railway, examine os logs do serviço em execução e confirme que não há
  mensagens `PSQLException: SSL error` nem
  `prepared statement … already exists`.

- [ ] **Teste de ida e volta no CloudAMQP.**
  Na interface de gerenciamento do CloudAMQP:
  1. Publique uma mensagem de teste em `catalog.events` com a chave de
     roteamento (`routing key`) `test.smoke`.
  2. Vincule uma fila temporária `smoke-test` a esse exchange com a mesma
     chave de roteamento.
  3. Confirme que a mensagem chega à fila.
  4. Exclua a fila temporária.

- [ ] **Teste de preview do frontend.**
  Envie um commit simples para uma branch do `hb-catalog-web`; a Vercel deve
  gerar automaticamente uma URL de preview. Confirme que o preview é
  carregado.

- [ ] **Teste de acesso ao webhook da InfinitePay.**
  No painel do desenvolvedor da InfinitePay, dispare um webhook de teste do
  sandbox. Confirme nos logs do `sc-order-service` que ele foi recebido e
  rejeitado (ou aceito), conforme o resultado da validação HMAC com o
  `INFINITEPAY_WEBHOOK_SECRET`.

- [ ] **Teste de ingestão no Better Stack.**
  Acompanhe a visualização ao vivo de qualquer fonte do Logtail; gere uma linha
  de log no serviço implantado (por exemplo, acesse `/actuator/info`). Confirme
  que a linha foi recebida.

- [ ] **Teste de métrica no Grafana Cloud.**
  Depois de habilitar o agente do OpenTelemetry (em uma funcionalidade
  posterior), confirme que `http_server_requests_seconds_count` chega ao
  Prometheus da stack `hubinity`.

---

## Seção 12 — Resumo de custos

Custo mensal básico do MVP, considerando os planos gratuitos/Hobby em todos os
provedores.

| Serviço | Plano | Custo mensal | Observações |
|---|---|---|---|
| Supabase × 4 | Gratuito | US$ 0 | 500 MB/projeto, backup de 7 dias, pausa após uma semana de inatividade |
| Railway (Keycloak + sc-order + hb-cashier) | Hobby × 3 | US$ 15 | Sem hibernação; US$ 5/serviço |
| Railway (hb-catalog + hb-support) | Gratuito | US$ 0 | Mantidos ativos pelo UptimeRobot |
| Vercel × 3 | Gratuito (Hobby) | US$ 0 | 100 GB de transferência/mês, deploys de preview ilimitados |
| Netlify × 1 | Gratuito | US$ 0 | 100 GB de largura de banda/mês |
| CloudAMQP | Little Lemur | US$ 0 | 1 milhão de mensagens/mês, 20 conexões |
| Sandbox da InfinitePay | Gratuito | US$ 0 | Plano de produção a definir após o KYC |
| Better Stack (Logtail) | Gratuito | US$ 0 | 1 GB/mês de retenção, pesquisa por três dias |
| Grafana Cloud | Gratuito | US$ 0 | 10 mil séries de métricas, 50 GB de logs, 50 GB de traces |
| UptimeRobot | Gratuito | US$ 0 | 50 monitores, intervalo de cinco minutos |
| GitHub (Team / Free) | Gratuito | US$ 0 | Repositórios públicos e privados, 2.000 minutos/mês de Actions |
| GitHub Container Registry | Gratuito (com GitHub) | US$ 0 | 500 MB de armazenamento/1 GB de transferência por repositório privado |
| **TOTAL** | | **US$ 15/mês** | Custo básico do MVP |

Observações:

- Projetos gratuitos do Supabase são pausados após uma semana de inatividade;
  o UptimeRobot é a mitigação mais barata (um ping a cada cinco minutos na
  verificação de integridade do Spring é suficiente para manter o pool de
  conexões ativo).
- O plano gratuito do GitHub Actions (2.000 minutos/mês) é limitado para 12
  repositórios × CI. Planeje o upgrade para o GitHub Team (US$ 4/usuário/mês)
  assim que aumentar o número de colaboradores.
- Quando qualquer plano gratuito atingir seu limite, o caminho de upgrade é
  linear: Supabase Pro (US$ 25/projeto), Vercel Pro (US$ 20/usuário), Netlify
  Pro (US$ 19) e CloudAMQP Tough Tiger (US$ 19).

---

## Próximos passos

Quando todas as caixas acima estiverem marcadas e os testes da Seção 11 forem
aprovados:

1. Inicie a funcionalidade da **stack local com docker-compose** (item separado
   da Fase 0) — ela produzirá `platform-infra/docker-compose/` para o
   desenvolvimento offline com equivalentes desses provedores (Postgres,
   RabbitMQ, Keycloak e simulação do Logtail).
2. Configure o `.github/workflows/ci.yml` de cada repositório para usar a tabela
   de segredos acima.
3. Agende uma revisão trimestral de **troca de segredos** no calendário da
   equipe (`RAILWAY_TOKEN`, `VERCEL_TOKEN`, `GH_PACKAGES_TOKEN` e todas as
   senhas de banco de dados).
4. Substitua a URL de webhook provisória e as credenciais da InfinitePay
   pendentes de KYC quando a aprovação para produção for concedida.

— fim do checklist —

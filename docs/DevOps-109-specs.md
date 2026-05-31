# DevOps-109: AWS Cloud Deployment Infrastructure Plan

## 1. Goal

Extend the CI/CD infrastructure to support a live product in AWS with:

- Per-branch **preview deployments** for every pull request
- Automatic **production deployment** on merge to `main`
- **Build cache optimisation** to reduce pipeline duration

### Deliverables

| Deliverable | Description |
|---|---|
| Preview API URL | Per-PR AppRunner service (`t3-api-pr-{N}`) with unique HTTPS URL posted as a PR comment |
| Preview UI URL | AWS Amplify auto-generated branch URL per PR (`https://pr-{N}.{amplify_id}.amplifyapp.com`) |
| Production API URL | Stable AppRunner service (`t3-api-prod`) HTTPS endpoint |
| Production UI URL | Amplify `main` branch HTTPS URL; custom domain will be attached once purchased |
| Updated CI/CD pipeline | GitHub Actions workflows for preview, production, and cleanup |

---

## 2. Scope and Constraints

| Parameter | Value |
|---|---|
| AWS Account | `867633231218` |
| AWS Region | `eu-north-1` |
| Team identifier | `t3` |
| GitHub Monorepo | `larchanka-training/dmc-1-t3-notebook-mono` |
| IaC tool | Terraform |
| Deploy IAM user | `deploy-user` (GitHub Actions only) |
| GitHub credentials | `secrets.AWS_ACCESS_KEY_ID`, `secrets.AWS_SECRET_ACCESS_KEY` |

**Multi-team isolation rule:** Three teams share account `867633231218`. Every AWS resource created by this team **must** use the `t3-` prefix. The word "team" must not appear in resource names. This ensures no naming conflict with other teams regardless of the deployment paths they choose.

---

## 3. Architecture Overview

```
┌──────────────────────────────────────────────────────────────────────┐
│  GitHub (PR opened / synchronize)                                    │
│                                                                      │
│  PR branch ──► GitHub Actions: preview.yml                          │
│               ├─ Build API image → ECR tag: pr-{N}-{SHA}           │
│               ├─ Terraform apply → t3-api-pr-{N} (AppRunner)        │
│               ├─ Run DB migrations                                   │
│               └─ Post preview URLs as PR comment                     │
│                                                                      │
│  AWS Amplify webhook ──► Amplify builds UI for PR branch            │
│               └─ Preview URL: pr-{N}.{amplify_id}.amplifyapp.com    │
└──────────────────────────────────────────────────────────────────────┘

┌──────────────────────────────────────────────────────────────────────┐
│  GitHub (push to main)                                               │
│                                                                      │
│  main branch ──► GitHub Actions: deploy-prod.yml                    │
│               ├─ Build API image → ECR tags: prod-{SHA}, latest     │
│               ├─ Terraform apply → t3-api-prod (AppRunner update)   │
│               ├─ Run DB migrations                                   │
│               └─ Wait for RUNNING status                             │
│                                                                      │
│  AWS Amplify webhook ──► Amplify builds UI for main branch          │
│               └─ Production URL: main.{amplify_id}.amplifyapp.com   │
└──────────────────────────────────────────────────────────────────────┘

┌──────────────────────────────────────────────────────────────────────┐
│  GitHub (PR closed)                                                  │
│                                                                      │
│  ──► GitHub Actions: cleanup.yml                                     │
│       ├─ Terraform destroy → t3-api-pr-{N}                          │
│       └─ Delete ECR images tagged pr-{N}-*                          │
└──────────────────────────────────────────────────────────────────────┘
```

---

## 4. AWS Service Selection

| Service | Component | Rationale |
|---|---|---|
| AWS App Runner | API (FastAPI/Python) | Fully managed container runtime; no cluster management; native HTTPS; auto-scaling; supports per-PR service creation |
| AWS Amplify | UI (React/Vite) | Native PR branch preview URLs; static SPA hosting; built-in CI/CD with pnpm support; zero-config HTTPS |
| AWS RDS PostgreSQL 16 | Database | Managed PostgreSQL; shared between prod and preview environments |
| AWS ECR | Container registry | Private Docker registry co-located in `eu-north-1`; lifecycle policies to control image retention |
| AWS Secrets Manager | Secrets | DB credentials and app secrets; referenced by AppRunner at runtime |
| S3 + DynamoDB | Terraform remote state | Shared locking backend for Terraform workspaces |

---

## 5. Resource Naming Convention

All names use `t3-` prefix. The word "team" is excluded from all names.

| Resource | Name Pattern | Example |
|---|---|---|
| ECR repository | `t3-api` | `t3-api` |
| AppRunner service (prod) | `t3-api-prod` | `t3-api-prod` |
| AppRunner service (preview) | `t3-api-pr-{N}` | `t3-api-pr-42` |
| RDS instance identifier | `t3-postgres` | `t3-postgres` |
| RDS prod database | `t3_notebook_prod` | `t3_notebook_prod` |
| RDS preview database | `t3_notebook_preview` | `t3_notebook_preview` |
| Amplify app | `t3-ui` | `t3-ui` |
| VPC | `t3-vpc` | `t3-vpc` |
| Security groups | `t3-{purpose}-sg` | `t3-api-sg` |
| IAM roles | `t3-{service}-role` | `t3-apprunner-role` |
| S3 Terraform state bucket | `t3-tfstate-867633231218` | — |
| DynamoDB lock table | `t3-tfstate-lock` | — |
| Secrets Manager paths | `t3/{env}/{name}` | `t3/prod/database-url` |

---

## 6. Terraform Project Structure

```
infra/
  terraform/
    bootstrap/                  # One-time setup (local state, run once by hand)
      main.tf                   # Creates S3 bucket + DynamoDB lock table
      outputs.tf

    modules/
      ecr/                      # ECR repository + lifecycle policy
        main.tf
        variables.tf
        outputs.tf
      network/                  # VPC, subnets (private + public), IGW, NAT GW, route tables
        main.tf
        variables.tf
        outputs.tf
      rds/                      # RDS PostgreSQL 16, subnet group, SG
        main.tf
        variables.tf
        outputs.tf
      apprunner/                # Reusable AppRunner service module
        main.tf                 # aws_apprunner_service + VPC connector
        variables.tf            # image_uri, service_name, env_vars, cpu, memory
        outputs.tf              # service_url

    environments/
      prod/                     # Production: t3-api-prod
        main.tf
        variables.tf
        outputs.tf
        backend.tf              # S3 key: prod/terraform.tfstate
        terraform.tfvars

      preview/                  # Per-PR: t3-api-pr-{N}
        main.tf
        variables.tf            # var.pr_number
        outputs.tf              # preview_api_url
        backend.tf              # S3 key: preview/pr-${pr_number}/terraform.tfstate
```

### 6.1 Key Terraform Variables

**`environments/preview/variables.tf`:**
```hcl
variable "pr_number" {
  type        = string
  description = "Pull request number; used as resource name suffix"
}

variable "api_image_uri" {
  type        = string
  description = "Fully qualified ECR image URI for this PR"
}
```

**`environments/preview/backend.tf`:**
```hcl
terraform {
  backend "s3" {
    bucket         = "t3-tfstate-867633231218"
    key            = "preview/pr-${var.pr_number}/terraform.tfstate"
    region         = "eu-north-1"
    dynamodb_table = "t3-tfstate-lock"
    encrypt        = true
  }
}
```

> **Note:** Because Terraform does not allow variable interpolation in `backend` blocks at parse time, the S3 key must be passed as a `-backend-config` flag during `terraform init` in GitHub Actions. See the workflow section below.

---

## 7. Dockerfile Fixes

### 7.1 `api/Dockerfile` — Current Issues

| Issue | Problem |
|---|---|
| No `CMD` instruction | Container exits immediately; AppRunner cannot start the service |
| Runs as `root` | OWASP A05 (Security Misconfiguration): containers must not run as root |
| Dev server not used in production | The `docker-compose.yaml` overrides CMD with `fastapi dev`, but there is no fallback `CMD` for production |

**Fixed `api/Dockerfile`:**

```dockerfile
FROM python:3.12-slim

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1

WORKDIR /app

RUN apt-get update \
    && apt-get install -y --no-install-recommends bash procps \
    && rm -rf /var/lib/apt/lists/* \
    && groupadd --gid 1001 appuser \
    && useradd --uid 1001 --gid appuser --shell /bin/bash --create-home appuser

COPY requirements.txt ./requirements.txt
RUN pip install --no-cache-dir --upgrade pip \
    && pip install --no-cache-dir -r requirements.txt

COPY . .

RUN chown -R appuser:appuser /app

USER appuser

EXPOSE 8000

CMD ["sh", "-c", "alembic upgrade head && uvicorn app.main:app --host 0.0.0.0 --port 8000"]
```

**Key changes:**
- Added non-root `appuser` (uid/gid `1001`)
- Added `CMD` that runs Alembic migrations then starts `uvicorn` (production ASGI server)
- Alembic is idempotent and safe to run at startup; PostgreSQL advisory locking prevents race conditions when multiple replicas start simultaneously

### 7.2 `ui/Dockerfile` — Current Issues

| Issue | Problem |
|---|---|
| Uses `npm install` | Project uses `pnpm` (`pnpm-lock.yaml`); `npm install` ignores the lockfile and may install different versions |
| Dev server only | Exposes port `5173` (Vite dev server); not suitable for production serving |
| No build stage | Static assets are never built; container only works when `docker-compose.yaml` mounts source and runs `npm run dev` |

**Fixed `ui/Dockerfile` (multi-stage production build):**

```dockerfile
# === Build stage ===
FROM node:22-alpine AS builder

WORKDIR /home/app

RUN apk add --no-cache bash \
    && npm install -g pnpm@9

COPY package.json pnpm-lock.yaml ./
RUN pnpm install --frozen-lockfile

COPY . .

# Injected at build time by GitHub Actions
ARG VITE_API_URL
ENV VITE_API_URL=$VITE_API_URL

RUN pnpm build

# === Production stage ===
FROM nginx:alpine AS production

COPY --from=builder /home/app/dist /usr/share/nginx/html

# SPA routing: redirect all 404s to index.html
RUN printf 'server {\n  listen 80;\n  root /usr/share/nginx/html;\n  index index.html;\n  location / {\n    try_files $uri $uri/ /index.html;\n  }\n}\n' \
    > /etc/nginx/conf.d/default.conf

EXPOSE 80

CMD ["nginx", "-g", "daemon off;"]
```

**Key changes:**
- Multi-stage build; final image is `nginx:alpine` (~25 MB) instead of Node.js (~200 MB)
- Uses `pnpm install --frozen-lockfile` matching the repository lockfile
- `VITE_API_URL` injected at build time so the compiled JS bundle contains the correct API endpoint
- Nginx serves static files with proper SPA fallback routing

> **AWS Amplify does not use this Dockerfile.** Amplify builds directly from source using its own build environment configured via `ui/amplify.yml` (see Section 8). The fixed Dockerfile is used for local Docker builds and any future containerised hosting scenario.

---

## 8. AWS Amplify Configuration for UI

### 8.1 Amplify App Setup (via Terraform)

Amplify is provisioned by Terraform in `environments/prod/main.tf`:

```hcl
resource "aws_amplify_app" "ui" {
  name       = "t3-ui"
  repository = "https://github.com/larchanka-training/dmc-1-t3-notebook-mono"

  # OAuth token for GitHub access stored in Secrets Manager
  access_token = data.aws_secretsmanager_secret_version.github_token.secret_string

  build_spec = file("${path.module}/amplify_build_spec.yml")

  environment_variables = {
    VITE_API_URL = "https://${aws_apprunner_service.api_prod.service_url}"
  }

  enable_branch_auto_build    = true
  enable_branch_auto_deletion = true
}

resource "aws_amplify_branch" "main" {
  app_id      = aws_amplify_app.ui.id
  branch_name = "main"
  stage       = "PRODUCTION"
  framework   = "React"

  environment_variables = {
    VITE_API_URL = "https://${aws_apprunner_service.api_prod.service_url}"
  }
}
```

### 8.2 Amplify Build Specification

Create `ui/amplify.yml` in the repository:

```yaml
version: 1
applications:
  - frontend:
      phases:
        preBuild:
          commands:
            - npm install -g pnpm@9
            - pnpm install --frozen-lockfile
        build:
          commands:
            - pnpm build
      artifacts:
        baseDirectory: dist
        files:
          - '**/*'
      cache:
        paths:
          - node_modules/**/*
          - ~/.pnpm-store/**/*
    appRoot: ui
```

> The `appRoot: ui` key tells Amplify to resolve all paths relative to the `ui/` subdirectory within the monorepo.

### 8.3 PR Preview Configuration

Amplify PR previews are enabled via Terraform:

```hcl
resource "aws_amplify_app" "ui" {
  # ...
  enable_branch_auto_build = true

  # Amplify creates a preview for every PR branch automatically
  # Preview URL pattern: pr-{N}.{amplify_id}.amplifyapp.com
}
```

For PR previews, the `VITE_API_URL` must point to the preview AppRunner service. This is achieved by passing a branch-level environment variable through the Amplify webhook payload or by configuring a branch environment variable pattern. In the GitHub Actions `preview.yml` workflow, after provisioning the AppRunner preview service, the workflow updates the Amplify branch's `VITE_API_URL` using the AWS CLI:

```bash
aws amplify update-branch \
  --app-id "$AMPLIFY_APP_ID" \
  --branch-name "pr-${{ github.event.pull_request.number }}" \
  --environment-variables "VITE_API_URL=https://$APPRUNNER_PREVIEW_URL" \
  --region eu-north-1
```

---

## 9. GitHub Actions Workflows

### 9.1 Workflow Map

```
.github/
  workflows/
    ci.yml           # Lint, typecheck, test — runs on every PR
    preview.yml      # Deploy preview — triggered by PR open/sync
    deploy-prod.yml  # Deploy production — triggered by push to main
    cleanup.yml      # Destroy preview resources — triggered by PR close
```

### 9.2 `ci.yml` — Continuous Integration

**Trigger:** `pull_request` targeting `main` or `develop`; can also be triggered manually with `workflow_dispatch`.

```yaml
name: CI

on:
  pull_request:
    branches: [main, develop]
  workflow_dispatch:   # allows manual/forced run from GitHub Actions UI or gh CLI

jobs:
  ui-checks:
    runs-on: ubuntu-latest
    defaults:
      run:
        working-directory: ui
    steps:
      - uses: actions/checkout@v4

      - uses: pnpm/action-setup@v4
        with:
          version: 9

      - uses: actions/setup-node@v4
        with:
          node-version: 22
          cache: pnpm
          cache-dependency-path: ui/pnpm-lock.yaml

      - run: pnpm install --frozen-lockfile
      - run: pnpm typecheck
      - run: pnpm lint
      - run: pnpm test

  api-checks:
    runs-on: ubuntu-latest
    defaults:
      run:
        working-directory: api
    steps:
      - uses: actions/checkout@v4

      - uses: actions/setup-python@v5
        with:
          python-version: '3.12'
          cache: pip
          cache-dependency-path: api/requirements*.txt

      - run: pip install -r requirements.txt -r requirements-dev.txt
      - run: pytest tests/
```

### 9.3 `preview.yml` — Preview Deployment

**Trigger:** `pull_request` (opened, synchronize, reopened); can also be triggered manually via `workflow_dispatch` by supplying a PR number — useful for redeploying a preview after infrastructure changes without pushing a new commit.

```yaml
name: Preview Deploy

on:
  pull_request:
    types: [opened, synchronize, reopened]
  workflow_dispatch:   # forced / manual run
    inputs:
      pr_number:
        description: 'PR number to (re)deploy preview for'
        required: true
        type: string

env:
  AWS_REGION: eu-north-1
  ECR_REGISTRY: ${{ vars.AWS_ACCOUNT_ID }}.dkr.ecr.eu-north-1.amazonaws.com
  ECR_REPOSITORY: t3-api
  # Prefer event PR number; fall back to manual input when dispatched manually
  PR_NUMBER: ${{ github.event.pull_request.number || inputs.pr_number }}

jobs:
  deploy-preview:
    runs-on: ubuntu-latest
    permissions:
      contents: read
      pull-requests: write    # for posting PR comment

    steps:
      - uses: actions/checkout@v4

      - name: Configure AWS credentials
        uses: aws-actions/configure-aws-credentials@v4
        with:
          aws-access-key-id: ${{ secrets.AWS_ACCESS_KEY_ID }}
          aws-secret-access-key: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
          aws-region: ${{ env.AWS_REGION }}

      - name: Log in to ECR
        uses: aws-actions/amazon-ecr-login@v2

      - name: Set up Docker Buildx
        uses: docker/setup-buildx-action@v3

      - name: Build and push API image
        uses: docker/build-push-action@v6
        with:
          context: ./api
          push: true
          tags: ${{ env.ECR_REGISTRY }}/${{ env.ECR_REPOSITORY }}:pr-${{ env.PR_NUMBER }}-${{ github.sha }}
          cache-from: type=gha,scope=api-pr-${{ env.PR_NUMBER }}
          cache-to: type=gha,mode=max,scope=api-pr-${{ env.PR_NUMBER }}

      - name: Setup Terraform
        uses: hashicorp/setup-terraform@v3
        with:
          terraform_version: "~> 1.9"

      - name: Terraform init (preview workspace)
        working-directory: infra/terraform/environments/preview
        run: |
          terraform init \
            -backend-config="bucket=t3-tfstate-867633231218" \
            -backend-config="key=preview/pr-${{ env.PR_NUMBER }}/terraform.tfstate" \
            -backend-config="region=eu-north-1" \
            -backend-config="dynamodb_table=t3-tfstate-lock"

      - name: Terraform apply
        id: tf_apply
        working-directory: infra/terraform/environments/preview
        run: |
          terraform apply -auto-approve \
            -var="pr_number=${{ env.PR_NUMBER }}" \
            -var="api_image_uri=${{ env.ECR_REGISTRY }}/${{ env.ECR_REPOSITORY }}:pr-${{ env.PR_NUMBER }}-${{ github.sha }}"
          echo "api_url=$(terraform output -raw preview_api_url)" >> $GITHUB_OUTPUT

      - name: Update Amplify branch VITE_API_URL
        run: |
          aws amplify update-branch \
            --app-id "${{ vars.AMPLIFY_APP_ID }}" \
            --branch-name "${{ github.head_ref }}" \
            --environment-variables "VITE_API_URL=https://${{ steps.tf_apply.outputs.api_url }}" \
            --region ${{ env.AWS_REGION }} || true

      - name: Post preview URLs as PR comment
        uses: actions/github-script@v7
        with:
          script: |
            const apiUrl = `https://${{ steps.tf_apply.outputs.api_url }}`;
            const uiUrl = `https://pr-${{ env.PR_NUMBER }}.${{ vars.AMPLIFY_APP_ID }}.amplifyapp.com`;
            await github.rest.issues.createComment({
              owner: context.repo.owner,
              repo: context.repo.repo,
              issue_number: context.issue.number,
              body: `## Preview Deployment\n\n| Service | URL |\n|---|---|\n| UI | ${uiUrl} |\n| API | ${apiUrl} |`
            });
```

### 9.4 `deploy-prod.yml` — Production Deployment

**Trigger:** `push` to `main`; can also be triggered manually via `workflow_dispatch` — useful for forced redeployment of the current `main` HEAD without a new commit (e.g. after secrets rotation or AppRunner service reset).

```yaml
name: Production Deploy

on:
  push:
    branches: [main]
  workflow_dispatch:   # forced / manual production deploy
    inputs:
      reason:
        description: 'Reason for forced deploy (for audit log)'
        required: false
        default: 'Manual forced deploy'
        type: string

env:
  AWS_REGION: eu-north-1
  ECR_REGISTRY: ${{ vars.AWS_ACCOUNT_ID }}.dkr.ecr.eu-north-1.amazonaws.com
  ECR_REPOSITORY: t3-api

jobs:
  deploy-production:
    runs-on: ubuntu-latest

    steps:
      - uses: actions/checkout@v4

      - name: Configure AWS credentials
        uses: aws-actions/configure-aws-credentials@v4
        with:
          aws-access-key-id: ${{ secrets.AWS_ACCESS_KEY_ID }}
          aws-secret-access-key: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
          aws-region: ${{ env.AWS_REGION }}

      - name: Log in to ECR
        uses: aws-actions/amazon-ecr-login@v2

      - name: Set up Docker Buildx
        uses: docker/setup-buildx-action@v3

      - name: Build and push API image
        uses: docker/build-push-action@v6
        with:
          context: ./api
          push: true
          tags: |
            ${{ env.ECR_REGISTRY }}/${{ env.ECR_REPOSITORY }}:prod-${{ github.sha }}
            ${{ env.ECR_REGISTRY }}/${{ env.ECR_REPOSITORY }}:latest
          cache-from: type=gha,scope=api-prod
          cache-to: type=gha,mode=max,scope=api-prod

      - name: Setup Terraform
        uses: hashicorp/setup-terraform@v3
        with:
          terraform_version: "~> 1.9"

      - name: Terraform init (prod)
        working-directory: infra/terraform/environments/prod
        run: terraform init

      - name: Terraform apply
        working-directory: infra/terraform/environments/prod
        run: |
          terraform apply -auto-approve \
            -var="api_image_uri=${{ env.ECR_REGISTRY }}/${{ env.ECR_REPOSITORY }}:prod-${{ github.sha }}"

      - name: Wait for AppRunner service RUNNING
        run: |
          aws apprunner wait service-running \
            --service-arn $(aws apprunner list-services \
              --query "ServiceSummaryList[?ServiceName=='t3-api-prod'].ServiceArn" \
              --output text) \
            --region ${{ env.AWS_REGION }}
```

### 9.5 `cleanup.yml` — Preview Teardown

**Trigger:** `pull_request` (closed)

> `cleanup.yml` does not expose `workflow_dispatch` intentionally. Teardown must only happen when a PR is truly closed to prevent accidental resource deletion. If a manual cleanup is needed, run `terraform destroy` directly from a local machine using the instructions in Section 14, Phase 1.

```yaml
name: Preview Cleanup

on:
  pull_request:
    types: [closed]

env:
  AWS_REGION: eu-north-1
  PR_NUMBER: ${{ github.event.pull_request.number }}

jobs:
  cleanup-preview:
    runs-on: ubuntu-latest

    steps:
      - uses: actions/checkout@v4

      - name: Configure AWS credentials
        uses: aws-actions/configure-aws-credentials@v4
        with:
          aws-access-key-id: ${{ secrets.AWS_ACCESS_KEY_ID }}
          aws-secret-access-key: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
          aws-region: ${{ env.AWS_REGION }}

      - name: Setup Terraform
        uses: hashicorp/setup-terraform@v3
        with:
          terraform_version: "~> 1.9"

      - name: Terraform init (preview workspace)
        working-directory: infra/terraform/environments/preview
        run: |
          terraform init \
            -backend-config="bucket=t3-tfstate-867633231218" \
            -backend-config="key=preview/pr-${{ env.PR_NUMBER }}/terraform.tfstate" \
            -backend-config="region=eu-north-1" \
            -backend-config="dynamodb_table=t3-tfstate-lock"

      - name: Terraform destroy
        working-directory: infra/terraform/environments/preview
        run: |
          terraform destroy -auto-approve \
            -var="pr_number=${{ env.PR_NUMBER }}" \
            -var="api_image_uri=unused"

      - name: Delete ECR images for this PR
        run: |
          IMAGES=$(aws ecr list-images \
            --repository-name t3-api \
            --filter "tagStatus=TAGGED" \
            --query "imageIds[?starts_with(imageTag, 'pr-${{ env.PR_NUMBER }}-')]" \
            --output json)
          if [ "$IMAGES" != "[]" ]; then
            aws ecr batch-delete-image \
              --repository-name t3-api \
              --image-ids "$IMAGES"
          fi
```

### 9.6 Forced Run Reference

The table below summarises how to trigger each workflow manually without a new commit or PR event:

| Workflow | How to trigger manually | Required input |
|---|---|---|
| `ci.yml` | GitHub UI → Actions → CI → Run workflow | none |
| `preview.yml` | GitHub UI → Actions → Preview Deploy → Run workflow | `pr_number` (e.g. `42`) |
| `deploy-prod.yml` | GitHub UI → Actions → Production Deploy → Run workflow | `reason` (optional, audit note) |
| Any | `gh workflow run <filename> --ref main` | per workflow |

**GitHub CLI examples:**

```bash
# Re-run CI on main
gh workflow run ci.yml --ref main

# Force-redeploy preview for PR #42
gh workflow run preview.yml --ref main -f pr_number=42

# Force production deploy with audit reason
gh workflow run deploy-prod.yml --ref main -f reason="Post-secrets-rotation redeploy"
```

---

## 10. Build Caching Strategy

### 10.1 Docker Layer Cache (GitHub Actions Cache)

Docker BuildKit layer cache is stored in the GitHub Actions cache via `type=gha`. Cache scopes are separated by context to prevent cross-contamination:

| Scope name | Used for | Cache invalidation |
|---|---|---|
| `api-prod` | Production API builds | Requirements change or base image changes |
| `api-pr-{N}` | Per-PR API builds | Requirements change within the PR |

**Layer ordering in `api/Dockerfile` (from stable to volatile):**
1. `FROM python:3.12-slim` — changes only on base image update
2. `apt-get install` — changes only when system deps change
3. `COPY requirements.txt` + `pip install` — changes only when `requirements.txt` changes
4. `COPY . .` — changes on every commit (intentionally last)

This ordering ensures that the expensive `pip install` layer is retrieved from cache on every push that does not modify `requirements.txt`.

### 10.2 Python pip Cache (CI only)

Used in `ci.yml` for running tests, not inside Docker:

```yaml
- uses: actions/setup-python@v5
  with:
    python-version: '3.12'
    cache: pip
    cache-dependency-path: api/requirements*.txt
```

Cache key is derived from `requirements.txt` + `requirements-dev.txt` hash.

### 10.3 pnpm Store Cache (CI and Amplify)

**GitHub Actions (`ci.yml`):**

```yaml
- uses: pnpm/action-setup@v4
  with:
    version: 9
- uses: actions/setup-node@v4
  with:
    node-version: 22
    cache: pnpm
    cache-dependency-path: ui/pnpm-lock.yaml
```

**AWS Amplify (`ui/amplify.yml`):**

```yaml
cache:
  paths:
    - node_modules/**/*
    - ~/.pnpm-store/**/*
```

Amplify's built-in cache persists `node_modules` and the pnpm content store between builds. Cache is invalidated when `pnpm-lock.yaml` changes.

### 10.4 Terraform Provider Cache

```yaml
- name: Cache Terraform providers
  uses: actions/cache@v4
  with:
    path: ~/.terraform.d/plugin-cache
    key: terraform-providers-${{ hashFiles('**/.terraform.lock.hcl') }}
```

---

## 11. Environment Variables and Secrets

### 11.1 GitHub Repository Variables (non-secret, to be added)

| Variable | Value |
|---|---|
| `AWS_ACCOUNT_ID` | `867633231218` |
| `AWS_REGION` | `eu-north-1` |
| `AMPLIFY_APP_ID` | Terraform output after first apply |

### 11.2 GitHub Repository Secrets (already exist)

| Secret | Usage |
|---|---|
| `AWS_ACCESS_KEY_ID` | deploy-user access key |
| `AWS_SECRET_ACCESS_KEY` | deploy-user secret key |

### 11.3 AWS Secrets Manager

| Secret path | Content | Used by |
|---|---|---|
| `t3/prod/database-url` | Full PostgreSQL connection string for prod DB | AppRunner prod |
| `t3/preview/database-url` | Full PostgreSQL connection string for preview DB | AppRunner PR services |
| `t3/github-token` | GitHub personal access token for Amplify repo connection | Terraform (Amplify setup) |

AppRunner services reference secrets by ARN in Terraform:

```hcl
environment_variables = {
  DATABASE_URL = data.aws_secretsmanager_secret_version.db_url.secret_string
  ENVIRONMENT  = "production"
}
```

---

## 12. IAM Permissions for `deploy-user`

All permissions are scoped to `t3-*` resource ARNs to prevent interfering with other teams.

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "ECRTokenGlobal",
      "Effect": "Allow",
      "Action": ["ecr:GetAuthorizationToken"],
      "Resource": "*"
    },
    {
      "Sid": "ECRRepository",
      "Effect": "Allow",
      "Action": [
        "ecr:BatchCheckLayerAvailability",
        "ecr:GetDownloadUrlForLayer",
        "ecr:BatchGetImage",
        "ecr:InitiateLayerUpload",
        "ecr:UploadLayerPart",
        "ecr:CompleteLayerUpload",
        "ecr:PutImage",
        "ecr:DescribeRepositories",
        "ecr:ListImages",
        "ecr:BatchDeleteImage"
      ],
      "Resource": "arn:aws:ecr:eu-north-1:867633231218:repository/t3-*"
    },
    {
      "Sid": "AppRunner",
      "Effect": "Allow",
      "Action": [
        "apprunner:CreateService",
        "apprunner:UpdateService",
        "apprunner:DeleteService",
        "apprunner:DescribeService",
        "apprunner:ListServices",
        "apprunner:StartDeployment"
      ],
      "Resource": "arn:aws:apprunner:eu-north-1:867633231218:service/t3-*"
    },
    {
      "Sid": "IAMPassRole",
      "Effect": "Allow",
      "Action": ["iam:PassRole"],
      "Resource": "arn:aws:iam::867633231218:role/t3-*"
    },
    {
      "Sid": "TerraformStateS3",
      "Effect": "Allow",
      "Action": ["s3:GetObject", "s3:PutObject", "s3:DeleteObject", "s3:ListBucket"],
      "Resource": [
        "arn:aws:s3:::t3-tfstate-867633231218",
        "arn:aws:s3:::t3-tfstate-867633231218/*"
      ]
    },
    {
      "Sid": "TerraformStateLock",
      "Effect": "Allow",
      "Action": ["dynamodb:GetItem", "dynamodb:PutItem", "dynamodb:DeleteItem"],
      "Resource": "arn:aws:dynamodb:eu-north-1:867633231218:table/t3-tfstate-lock"
    },
    {
      "Sid": "SecretsManager",
      "Effect": "Allow",
      "Action": ["secretsmanager:GetSecretValue", "secretsmanager:DescribeSecret"],
      "Resource": "arn:aws:secretsmanager:eu-north-1:867633231218:secret:t3/*"
    },
    {
      "Sid": "Amplify",
      "Effect": "Allow",
      "Action": [
        "amplify:GetApp",
        "amplify:GetBranch",
        "amplify:UpdateBranch",
        "amplify:StartDeployment",
        "amplify:ListApps"
      ],
      "Resource": "arn:aws:amplify:eu-north-1:867633231218:apps/*"
    }
  ]
}
```

---

## 13. Database Migration Strategy

AppRunner does not support one-off pre-deploy tasks. The selected approach runs Alembic migrations at container startup before the server process begins:

```dockerfile
CMD ["sh", "-c", "alembic upgrade head && uvicorn app.main:app --host 0.0.0.0 --port 8000"]
```

**Why this is safe:**
- Alembic stores applied migration versions in the `alembic_version` table and skips already-applied migrations
- PostgreSQL advisory locks prevent two instances from running the same migration simultaneously
- AppRunner's health check (`GET /api/v1/health`) keeps the old instance active until the new instance passes; the new instance only passes after migrations complete and `uvicorn` starts

**Prod vs preview databases:**
- Production: `t3_notebook_prod` — dedicated RDS database; migrations apply only to production schema
- Preview: `t3_notebook_preview` — single shared database for all PR previews; all PR services connect to the same preview schema; Alembic ensures forward-compatibility

---

## 14. Implementation Phases

### Phase 1: Bootstrap (one-time, manual, ~2 hours)

| Step | Action |
|---|---|
| 1.1 | Write and apply `infra/terraform/bootstrap/` with local state to create S3 bucket `t3-tfstate-867633231218` (versioning enabled, AES-256 encryption) and DynamoDB table `t3-tfstate-lock` |
| 1.2 | Create ECR repository `t3-api` manually or via bootstrap Terraform |
| 1.3 | Store DB master password in Secrets Manager: `t3/prod/database-url`, `t3/preview/database-url` |
| 1.4 | Store GitHub personal access token in Secrets Manager: `t3/github-token` |
| 1.5 | Verify `deploy-user` has the IAM policy from Section 12 attached |

### Phase 2: Fix Dockerfiles (~1 hour)

| Step | Action |
|---|---|
| 2.1 | Update `api/Dockerfile` — add non-root user, add `CMD` with alembic + uvicorn |
| 2.2 | Update `ui/Dockerfile` — multi-stage build with pnpm, nginx production stage |
| 2.3 | Create `ui/amplify.yml` with build spec and pnpm cache config |
| 2.4 | Test locally: `docker compose up --build` must still work (compose overrides CMD for dev) |

### Phase 3: Terraform Modules (~4 hours)

| Step | Action |
|---|---|
| 3.1 | Write `modules/network/` — VPC, 2 private subnets, 2 public subnets, IGW, NAT GW |
| 3.2 | Write `modules/rds/` — RDS PostgreSQL 16, subnet group, security group |
| 3.3 | Write `modules/ecr/` — ECR repository, lifecycle policy (keep 20 prod images, 10 PR images, expire PR images after 14 days) |
| 3.4 | Write `modules/apprunner/` — reusable AppRunner service with VPC connector |
| 3.5 | Write `environments/prod/` — provisions `t3-api-prod`, RDS prod database, Amplify `t3-ui` |
| 3.6 | Write `environments/preview/` — provisions `t3-api-pr-{N}`, connects to preview RDS database |
| 3.7 | Run `terraform plan` against prod environment; verify no conflicts with other teams |

### Phase 4: GitHub Actions Workflows (~3 hours)

| Step | Action |
|---|---|
| 4.1 | Create `.github/workflows/ci.yml` |
| 4.2 | Create `.github/workflows/preview.yml` |
| 4.3 | Create `.github/workflows/deploy-prod.yml` |
| 4.4 | Create `.github/workflows/cleanup.yml` |
| 4.5 | Add GitHub Variables: `AWS_ACCOUNT_ID`, `AWS_REGION`, `AMPLIFY_APP_ID` |
| 4.6 | Open a test PR against a feature branch; verify preview pipeline runs end-to-end |

### Phase 5: Amplify Setup (~1 hour)

| Step | Action |
|---|---|
| 5.1 | Apply `environments/prod/` Terraform — this provisions the Amplify app |
| 5.2 | Verify Amplify connects to GitHub and reads `ui/amplify.yml` |
| 5.3 | Trigger first build manually from Amplify console; verify `main` branch deploys |
| 5.4 | Confirm PR preview URLs are generated for the next opened PR |
| 5.5 | Record `AMPLIFY_APP_ID` output and set it as GitHub Variable |

### Phase 6: End-to-End Validation (~1 hour)

| Test | Expected result |
|---|---|
| Open PR against `main` | `preview.yml` runs; PR comment contains UI and API preview URLs; both URLs respond |
| Push commit to open PR | `preview.yml` re-runs; same PR comment is updated; URLs reflect new build |
| Close PR | `cleanup.yml` runs; AppRunner service `t3-api-pr-{N}` is deleted; ECR PR images removed |
| Merge PR to `main` | `deploy-prod.yml` runs; production AppRunner service updated; Amplify production URL reflects changes |

---

## 15. Preview URL Summary

After full implementation, each PR produces:

| Service | URL pattern |
|---|---|
| UI preview | `https://pr-{N}.{AMPLIFY_APP_ID}.amplifyapp.com` |
| API preview | `https://{random_id}.eu-north-1.awsapprunner.com` (posted as PR comment) |

Production:

| Service | URL pattern |
|---|---|
| UI production | `https://main.{AMPLIFY_APP_ID}.amplifyapp.com` → replaced by custom domain once purchased |
| API production | `https://{prod_id}.eu-north-1.awsapprunner.com` → optionally aliased via Route 53 (`api.{domain}`) |

---

## 16. Custom Domain Migration (deferred)

> **Status: deferred.** The infrastructure is intentionally deployed without a custom domain on day one.
> Once a domain is purchased, apply the steps below with no changes to existing Terraform modules.

### 16.1 Prerequisites

| Item | Action |
|---|---|
| Domain purchased | Register via any registrar (Route 53 is simplest for AWS integration) |
| Hosted zone | Create or import Route 53 hosted zone `{domain}` — this is the only new Terraform resource needed |

### 16.2 Amplify custom domain (UI)

Add to `environments/prod/main.tf`:

```hcl
resource "aws_amplify_domain_association" "ui" {
  app_id      = aws_amplify_app.ui.id
  domain_name = var.custom_domain   # e.g. "notebook.example.com"

  sub_domain {
    branch_name = aws_amplify_branch.main.branch_name
    prefix      = ""        # apex: notebook.example.com
  }

  sub_domain {
    branch_name = aws_amplify_branch.main.branch_name
    prefix      = "www"     # www.notebook.example.com
  }
}
```

Amplify provisions an ACM certificate automatically and verifies DNS ownership.
After `terraform apply`, Amplify outputs CNAME records to add to Route 53.

### 16.3 AppRunner custom domain (API)

AppRunner supports a custom domain via `aws_apprunner_custom_domain_association`.
Add to `environments/prod/main.tf`:

```hcl
resource "aws_apprunner_custom_domain_association" "api" {
  service_arn  = module.apprunner_prod.service_arn
  domain_name  = "api.${var.custom_domain}"
  enable_www_subdomain = false
}
```

After applying, AppRunner returns DNS validation records; add them to Route 53.

### 16.4 CORS update

Once the custom domain is live, update `BACKEND_CORS_ORIGINS` in the API environment variables (via Secrets Manager or Terraform variable) to include the new UI origin:

```
https://{domain}, https://www.{domain}
```

The preview deployments continue using `.amplifyapp.com` and `.awsapprunner.com` — no change to preview infrastructure.

### 16.5 Terraform variable to add

```hcl
# environments/prod/variables.tf
variable "custom_domain" {
  type        = string
  default     = ""   # empty = no custom domain; fill in once domain is purchased
  description = "Custom domain name (e.g. notebook.example.com). Leave empty to use default AWS URLs."
}
```

When `custom_domain` is empty, the `aws_amplify_domain_association` and `aws_apprunner_custom_domain_association` resources are skipped via `count = var.custom_domain != "" ? 1 : 0`.

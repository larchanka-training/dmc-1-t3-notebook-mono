# DevOps-109: AWS Preview Deployments and CI/CD Plan

## 1. Goal

Extend the infrastructure so the project supports a live AWS-hosted product with:

- per-branch preview deployments for pull requests
- automatic deployment after merge to the main branch
- optimized build caching for faster CI/CD execution
- manual build and deploy triggers from GitHub Actions

This plan must preserve the current local development flow based on `docker-compose.yaml`, `api/Dockerfile`, and `ui/Dockerfile`.

## 2. Scope

This document defines:

- the recommended AWS target architecture
- the Terraform state and environment isolation model
- the GitHub Actions deployment workflow design
- the preview URL strategy before the final public domain is purchased
- the naming and tagging rules that avoid collisions with other teams in the same AWS account

This document does not implement the infrastructure. It is the approved delivery plan for the future Terraform and CI/CD work.

## 3. Fixed Constraints

- AWS account: `867633231218`
- AWS region: `eu-north-1`
- Terraform state bucket: `dmc-1-t3-notebook-terraform-state`
- Terraform lock table: `dmc-1-t3-notebook-terraform-lock`
- GitHub repository: `larchanka-training/dmc-1-t3-notebook-mono`
- GitHub Actions secrets already available:
  - `AWS_ACCESS_KEY_ID`
  - `AWS_SECRET_ACCESS_KEY`
- AWS deploy user: `deploy-user`
- `AWS App Runner` cannot be used because it is not available in `eu-north-1`
- local Docker-based development must remain fully functional
- the final public domain is not selected yet
- all team-owned AWS resource names must use the `t3` prefix and must not use the word `team`
- the AWS account is shared by three teams, so our setup must not create naming, networking, routing, or Terraform-state conflicts

## 4. Recommended AWS Architecture

### 4.1 Decision

Use `ECS on Fargate` as the runtime platform, `ECR` as the container registry, `Application Load Balancer` for HTTP routing, and `RDS PostgreSQL` for the application database. Manage all cloud resources with `Terraform`.

### 4.2 Why this is the most practical option

- It is fully supported in `eu-north-1`.
- It works well for containerized frontend and backend services that already exist in the repository.
- It does not require changing the current local Docker workflow.
- It supports isolated preview environments without introducing a new platform-specific build model.
- It allows gradual hardening from preview to production without replacing the deployment stack later.

### 4.3 Target runtime layout

Use one AWS network foundation and two application service types:

- `t3-notebook-ui`: UI container based on `ui/Dockerfile` production stage
- `t3-notebook-api`: API container based on `api/Dockerfile`

Core AWS services:

- `Amazon ECR` for Docker image storage
- `Amazon ECS Fargate` for running UI and API tasks
- `Application Load Balancer` for ingress and routing
- `Amazon RDS PostgreSQL` for durable backend storage
- `CloudWatch Logs` for logs
- `Secrets Manager` or `SSM Parameter Store` for runtime configuration and secrets
- `S3 + DynamoDB` as Terraform backend

### 4.4 Networking approach

Create a dedicated VPC for `t3` resources instead of sharing application networking with other teams.

Recommended baseline:

- `t3-notebook-vpc`
- 2 public subnets for ALB
- 2 private application subnets for ECS tasks
- 2 private database subnets for RDS
- NAT gateway strategy decided by budget:
  - one NAT gateway for lower cost in early stages
  - one per AZ later if higher availability is required

This keeps our deployment path independent from other teams and avoids service discovery or routing collisions.

## 5. Environment Strategy

Define three environment classes:

### 5.1 Shared environments

- `dev`: integration environment for the branch currently selected by the team
- `prod`: main branch deployment

### 5.2 Ephemeral preview environments

- one preview environment per pull request
- environment identifier format: `pr-<number>`
- all preview resources must include the `t3` prefix and the PR number

Example names:

- `t3-notebook-pr-42-ui`
- `t3-notebook-pr-42-api`
- `t3-notebook-pr-42-alb-rule`
- `t3-notebook-pr-42-target-ui`
- `t3-notebook-pr-42-target-api`

### 5.3 Lifecycle rules

- create or update preview on pull request open, synchronize, reopen, and manual dispatch
- destroy preview on pull request close or merge
- deploy `prod` automatically on push to `main`
- allow forced re-deploy through manual GitHub Actions dispatch

## 6. Preview URL Strategy

### 6.1 Constraint-driven decision

Because the final public domain is not purchased yet, the preview solution must work before DNS is finalized.

### 6.2 Recommended first phase

Use one shared preview ALB for `t3` and route each PR by path prefix on the ALB DNS name.

Architecture guardrails for this phase:

- the backend public API contract must remain under `/api/v1`
- authenticated preview flows must preserve the secure `HTTP-only` session-cookie model
- Google OAuth preview support requires a stable HTTPS callback host that can be registered with the provider

Preview URL pattern:

- UI: `http://<t3-preview-alb-dns>/pr-<number>/`
- API: `http://<t3-preview-alb-dns>/pr-<number>/api/`

Why this is the best temporary option:

- it does not require owning a domain
- it avoids creating a separate ALB for every PR
- it reduces cost compared with fully isolated load balancers
- it keeps all preview entry points predictable

Important limitation:

- plain ALB DNS + path-prefix routing is acceptable for temporary infrastructure validation
- it is not sufficient by itself for full authenticated product validation because the project uses secure session cookies and supports Google OAuth
- any preview that must exercise real authenticated browser flows must be exposed through HTTPS on a host model that supports cookie and callback isolation

### 6.3 Required application adjustments for path-based previews

The UI build must support a configurable base path for previews, for example:

- `VITE_APP_BASE_PATH=/pr-42/`
- `VITE_API_URL` must still resolve to backend routes exposed under `/api/v1`

The ALB and reverse proxy rules in AWS must route:

- `/pr-<number>/` to the preview UI target group
- `/pr-<number>/api/*` to the preview API target group

Additional routing rules required for architecture compatibility:

- do not change FastAPI route groups away from `/api/v1`
- if path-based previews are kept, add an HTTP proxy layer that strips the `/pr-<number>` prefix before the request reaches the API service
- ALB listener rules alone are not enough to preserve the backend contract because they can match paths but do not become the backend public API design
- if that proxy layer is not introduced, switch preview API routing to a host-based model before implementation

Additional UI rules required for architecture compatibility:

- the React router must support a configurable basename for preview builds
- existing canonical routes remain `/login`, `/notebooks`, and `/notebooks/:notebookId` inside that basename
- preview-specific routing must not change local Docker defaults or the root-path behavior used by shared environments

Additional auth rules required for architecture compatibility:

- preview auth must continue to use a backend-managed secure `HTTP-only` session cookie
- when multiple previews share one parent host, cookie scope must be isolated explicitly by host or cookie path so one PR preview cannot reuse another preview session implicitly
- Google OAuth should be enabled only for preview hosts whose HTTPS callback URL can be registered and validated; otherwise keep Google OAuth validation in shared `dev` or `prod` environments until host-based preview URLs are available

This does not change local Docker behavior. It only adds preview-specific runtime variables for AWS deployments.

### 6.4 Recommended second phase after domain purchase

Move to host-based preview URLs:

- `pr-42.<chosen-domain>` for UI
- `api-pr-42.<chosen-domain>` or `pr-42-api.<chosen-domain>` for API

Terraform should be written so this later migration only changes routing and DNS modules, not the full deployment model.

## 7. Production URL Strategy

Before the final domain is available, production can use:

- ALB DNS name for internal infrastructure validation only

Production URL guardrails:

- any environment used for real authenticated browser validation must be reachable over HTTPS
- the production-like entrypoint must preserve the secure `HTTP-only` session-cookie contract
- Google OAuth requires a stable HTTPS callback URL and must not rely on a raw ALB DNS placeholder as the long-term user-facing entrypoint
- if the final public domain is not purchased yet, use a temporary team-controlled HTTPS hostname for user-facing validation rather than treating the ALB DNS name as the real production URL

After domain purchase:

- UI: `https://<chosen-domain>`
- API: `https://api.<chosen-domain>`
- API routes on that host remain exposed under `/api/v1`

TLS should be handled with `ACM` certificates attached to the ALB.

## 8. Database Strategy

Use one dedicated PostgreSQL instance or cluster for `t3` workloads only.

Recommended approach:

- `RDS PostgreSQL`
- separate databases per shared environment:
  - `t3_notebook_dev`
  - `t3_notebook_prod`
- preview environments should not create a full RDS instance per PR

Preview database approach (implemented):

Each preview PR receives its own dedicated RDS PostgreSQL instance (`db.t4g.micro`, Graviton2 ARM). The instance is provisioned automatically by the `modules/rds` Terraform module:

- identifier: `t3-notebook-pr-<number>`
- database: `notebook`
- password: auto-generated via `random_password` and stored in Secrets Manager
- Secrets Manager secret name: `t3-notebook-pr-<number>-connection`
- ECS task receives `DATABASE_URL` directly from the secret ARN — no manual configuration required
- instance is destroyed with `terraform destroy` when the PR is closed

No GitHub Actions secret `PREVIEW_DATABASE_URL_SECRET_ARN` is required.

Reasoning for dedicated instance per PR:

- database isolation is clearer than schema-only isolation
- teardown logic is simpler: `terraform destroy` removes the instance
- it avoids accidental data overlap between previews

## 9. Container Build Strategy

### 9.1 Image repositories

Create separate ECR repositories:

- `t3-notebook-ui`
- `t3-notebook-api`

Image tags:

- immutable tag by commit SHA
- convenience tag by branch or environment where useful

Recommended tags:

- `sha-<git-sha>`
- `main-latest`
- `pr-42-latest`

### 9.2 Build source of truth

Reuse the existing Dockerfiles:

- `ui/Dockerfile` remains the source of truth for UI image builds
- `api/Dockerfile` remains the source of truth for API image builds

This preserves local development compatibility while also supporting CI/CD builds.

## 10. Build Caching Strategy

Use layered caching at both the GitHub Actions and Docker build levels.

### 10.1 UI caching

- cache `pnpm` store in GitHub Actions
- use `docker/buildx` with registry-backed cache in ECR or GitHub Actions cache backend
- reuse `package.json` and `pnpm-lock.yaml` as the stable dependency cache boundary

### 10.2 API caching

- cache `pip` downloads in GitHub Actions
- use `docker/buildx` layer caching
- keep `requirements.txt` as the dependency cache boundary

### 10.3 Recommended buildx configuration

Use Docker BuildKit and `buildx` with cache import/export.

Preferred order:

1. registry-backed cache image in ECR for persistence across runners
2. GitHub Actions cache backend as an additional accelerator if needed

Example cache references:

- `867633231218.dkr.ecr.eu-north-1.amazonaws.com/t3-notebook-ui:buildcache`
- `867633231218.dkr.ecr.eu-north-1.amazonaws.com/t3-notebook-api:buildcache`

This gives better reuse than local runner caching alone because GitHub-hosted runners are ephemeral.

## 11. Terraform State and Isolation Rules

### 11.1 Remote backend

Use the provided remote backend:

- bucket: `dmc-1-t3-notebook-terraform-state`
- lock table: `dmc-1-t3-notebook-terraform-lock`
- region: `eu-north-1`

The remote backend resources are bootstrap infrastructure and must be managed separately from the main application infrastructure.

### 11.2 State key naming

To avoid conflicts with other teams, all state keys must include both the repository identity and the `t3` scope.

Recommended state keys:

- `t3/dmc-1-t3-notebook-mono/shared/terraform.tfstate`
- `t3/dmc-1-t3-notebook-mono/dev/terraform.tfstate`
- `t3/dmc-1-t3-notebook-mono/prod/terraform.tfstate`
- `t3/dmc-1-t3-notebook-mono/previews/pr-<number>/terraform.tfstate`

### 11.3 Terraform module layout

Recommended layout:

```text
infra/
  modules/
    network/
    ecr/
    ecs-service/
    alb/
    rds/
    iam/
    observability/
  env/
    shared/
    dev/
    prod/
    preview/
```

### 11.4 Workspace policy

Do not rely on Terraform workspaces as the primary isolation mechanism for this project.

Use separate root modules and separate remote state keys instead.

Reason:

- clearer review boundaries
- lower risk of applying into the wrong environment
- simpler GitHub Actions logic for preview destruction

### 11.5 Bootstrap layer

Create a dedicated Terraform bootstrap layer for infrastructure that Terraform itself depends on before the main AWS environments can be initialized.

For this project, the bootstrap layer is responsible for:

- the shared S3 backend bucket `dmc-1-t3-notebook-terraform-state`
- the shared DynamoDB lock table `dmc-1-t3-notebook-terraform-lock`
- optional future backend support resources such as KMS encryption for Terraform state

Bootstrap layer rules:

- the bootstrap layer must be implemented as a separate Terraform root, for example `infra/bootstrap/`
- the bootstrap layer must use local state, not the shared S3 backend it is creating
- the bootstrap layer must not run as part of normal preview or production deployment workflows
- the bootstrap layer must be applied only manually and only when backend infrastructure must be created or changed

Why this separation is required:

- the main Terraform configuration cannot initialize an S3 backend that does not exist yet
- backend lifecycle is different from product infrastructure lifecycle
- accidental deletion or recreation of the backend is a high-impact operational risk

### 11.6 Terraform plan-time determinism rules

The Terraform implementation must be written so resource instance addressing is fully computable during `plan`.

Mandatory rules:

- `for_each` and `count` instance keys must be static and plan-time determinable
- never derive `for_each` map keys from values created in the same apply, such as security group IDs, subnet IDs, target group ARNs, listener rule ARNs, or similar provider-generated identifiers
- if a dynamic value is required, keep it in `each.value` and use a stable synthetic key such as an index-based or config-based key
- avoid two-phase apply as the default strategy; `-target` is only an emergency recovery tool and must not be a normal deployment path

Recommended pattern:

- build `for_each` maps from static inputs, list indexes, or explicit user-defined keys
- pass unknown-at-plan values as attributes inside the map value object

Example pattern:

```hcl
# Good: stable key, dynamic values in object fields.
for_each = {
  for idx, rule in var.ingress_rules : "${idx}-${rule.port}" => {
    port              = rule.port
    security_group_id = rule.security_group_id
  }
}
```

CI validation requirement:

- CI must run `terraform validate` and environment-scoped `terraform plan` for changed Terraform roots so plan-time key issues are detected before deployment

## 12. Naming, Tagging, and Collision Avoidance

All AWS resources must use the `t3` prefix.

Required tags:

- `Project = dmc-1-t3-notebook`
- `Repository = larchanka-training/dmc-1-t3-notebook-mono`
- `ManagedBy = terraform`
- `Owner = t3`
- `Environment = dev | prod | pr-<number>`

Naming rules:

- never use generic names such as `frontend`, `backend`, `preview`, or `prod` without the `t3` prefix
- never use the word `team`
- avoid creating shared AWS resources without the repository tag

This is required because three teams deploy different solutions in the same AWS account.

## 13. IAM and Secrets Model

### 13.1 GitHub Actions access

Use the existing access model based on:

- `secrets.AWS_ACCESS_KEY_ID`
- `secrets.AWS_SECRET_ACCESS_KEY`

These credentials must belong to `deploy-user`.

### 13.2 Permission scope

`deploy-user` must only have permissions for:

- Terraform backend access to the `t3` state prefixes in S3 and the shared lock table
- ECR push and pull for `t3-notebook-ui` and `t3-notebook-api`
- ECS, ALB, CloudWatch, IAM pass-role, RDS, Secrets Manager or SSM, and networking resources limited to `t3` infrastructure

### 13.3 ECS Exec access

ECS Exec (`aws ecs execute-command`) is enabled on all ECS services via `enable_execute_command = true` in the `ecs-service` module.

For ECS Exec to work, each task role must have the following permissions:

- `ssmmessages:CreateControlChannel`
- `ssmmessages:CreateDataChannel`
- `ssmmessages:OpenControlChannel`
- `ssmmessages:OpenDataChannel`

These permissions are attached to the `api`, `ui`, and `proxy` task roles via the `ecs-exec` inline policy in `modules/iam`.

To connect interactively to a running container:

```bash
# Find the task ID
aws ecs list-tasks \
  --cluster t3-notebook-cluster \
  --service-name t3-notebook-prod-api \
  --query 'taskArns[0]' \
  --output text

# Open a shell
aws ecs execute-command \
  --cluster t3-notebook-cluster \
  --task <task-arn> \
  --container api \
  --interactive \
  --command "/bin/sh"
```

Requirements for the operator's own IAM identity:

- `ecs:ExecuteCommand` on the target task resource
- AWS CLI v2 with the `session-manager-plugin` installed locally

Terraform apply is managed through GitHub Actions (`deploy-main.yml`). Do not run `terraform apply` locally because all Terraform state is stored in the remote S3 backend.

### 13.4 Follow-up improvement

After the first working delivery, migrate GitHub Actions authentication to `GitHub OIDC` if the AWS access model can be updated. This is recommended, but it is not required for the initial rollout because the current constraint already defines static secrets.

## 14. CI/CD Workflow Design

### 14.1 Required GitHub Actions workflows

Create these workflows:

1. `bootstrap.yml`
2. `ci.yml`
3. `deploy-preview.yml`
4. `destroy-preview.yml`
5. `deploy-main.yml`

### 14.1.1 Bootstrap workflow

The bootstrap workflow must be fully separated from the application deployment workflows.

Trigger on:

- `workflow_dispatch` only

Responsibilities:

- run Terraform only for `infra/bootstrap`
- create or update the Terraform backend bucket and lock table
- never deploy application resources such as VPC, ECS, ALB, RDS, UI, or API services

Workflow rules:

- do not run automatically on push or pull request events
- require explicit manual confirmation through workflow inputs
- restrict execution to authorized maintainers when repository settings allow it
- keep bootstrap changes independent from preview and production deployment paths

Recommended manual inputs:

- `action_reason`
- `confirm_bootstrap` with a required explicit value such as `true`
- `ref` when a non-default branch must be tested intentionally

Recommended execution model:

- `terraform init`
- `terraform plan`
- `terraform apply`

The bootstrap workflow is allowed to be created in GitHub Actions, but it must be treated as a rare administrative operation, not as a normal CI/CD stage.

### 14.2 CI workflow

Trigger on:

- pull request
- push to `main`
- manual dispatch

Responsibilities:

- lint and test UI and API
- build Docker images without deployment when needed
- validate Terraform formatting and plan for changed environments
- validate that preview-specific configuration preserves the frontend route model and the backend `/api/v1` contract
- fail fast when preview configuration would require weakening the secure-cookie auth model outside an explicitly documented non-auth validation mode

### 14.3 Preview deploy workflow

Trigger on:

- pull request opened
- pull request synchronize
- pull request reopened
- `workflow_dispatch`

Manual dispatch inputs:

- `pr_number`
- `ref`
- `force_rebuild` (`true|false`)
- `force_apply` (`true|false`)

Responsibilities:

- derive preview environment name `pr-<number>`
- build and push UI and API images
- run Terraform apply for preview infrastructure
- register or update preview routing rules
- publish preview URLs in the workflow summary and optionally in a PR comment
- inject preview-specific UI routing variables such as the router basename when path-based previews are used
- preserve the backend public API under `/api/v1`; if path-based routing is used, provision the required prefix-stripping proxy layer or stop the rollout
- declare in the workflow summary whether the resulting preview supports full authenticated validation or infrastructure-only validation
- enable Google OAuth in preview only when the preview host has a valid registered HTTPS callback URL; otherwise keep OAuth validation in shared environments

### 14.4 Preview destroy workflow

Trigger on:

- pull request closed
- `workflow_dispatch`

Manual dispatch inputs:

- `pr_number`
- `force_destroy` (`true|false`)

Responsibilities:

- run Terraform destroy for the preview state key
- remove preview routing
- destroy the per-PR RDS instance and its Secrets Manager secret

### 14.5 Main deploy workflow

Trigger on:

- push to `main`
- `workflow_dispatch`

Manual dispatch inputs:

- `ref`
- `environment` default `prod`
- `force_rebuild` (`true|false`)
- `force_apply` (`true|false`)

Responsibilities:

- build and push immutable images
- run Terraform apply for production
- deploy ECS task definition updates
- publish the resulting application URLs in the workflow summary
- publish the HTTPS user-facing URL separately from any raw ALB validation URL
- verify that the deployed entrypoint matches the secure-cookie and callback requirements for authenticated flows

### 14.6 Concurrency control

Use GitHub Actions concurrency groups:

- preview: one concurrency group per PR
- main: one concurrency group for production

This avoids overlapping deploys to the same target.

### 14.7 Manual force-deploy requirement

The workflows must support manual forced deployment because this is an explicit task requirement.

Recommended implementation:

- `workflow_dispatch` inputs for ref and force flags
- optional `terraform apply -refresh-only` or full apply depending on the selected flags
- optional image rebuild even when cache is warm

## 15. Preview Provisioning Model

### 15.1 Recommended balance of cost and isolation

Use a hybrid model:

- shared base infrastructure created once
- per-PR application resources created dynamically

Shared preview base:

- VPC
- ECS cluster
- shared preview ALB
- security groups
- CloudWatch log groups pattern
- optional shared preview RDS instance

Per-PR resources:

- ECS service for UI
- ECS service for API
- target groups
- listener rules
- task definitions
- dedicated RDS PostgreSQL instance (`db.t4g.micro`) for the PR
- Secrets Manager secret with generated `DATABASE_URL`
- runtime secrets/parameters scoped to the PR

This is more cost-efficient than creating a full isolated network stack per PR, while still giving each preview its own running application containers.

## 16. Repository and Branch Mapping Rules

This monorepo is the only source for deployment orchestration.

Mapping rules:

- `main` branch -> `prod`
- pull request branch -> `pr-<number>` preview environment
- optional protected integration branch -> `dev` if the team decides to use one later

Because the repository name is fixed, repository metadata should be embedded in tags, workflow summaries, and Terraform variables.

## 17. Rollout Plan

### Phase 1

- add Terraform backend configuration
- create shared AWS foundation for `t3`
- create ECR repositories
- create ECS cluster and shared preview ALB
- create production ALB and production ECS services

### Phase 2

- add GitHub Actions CI workflow
- add Docker buildx caching
- add `deploy-main` workflow for automatic main deployment

### Phase 3

- add per-PR preview provisioning
- expose preview URLs using ALB path-based routing
- add preview destroy workflow

### Phase 4

- migrate to purchased custom domain
- switch previews from path-based URLs to host-based URLs if desired
- add ACM and Route 53 records

## 18. Risks and Mitigations

### 18.1 Preview path routing complexity

Risk:

- path-based preview routing requires the UI to support a non-root base path

Mitigation:

- add `VITE_APP_BASE_PATH` support in the UI build without changing local docker defaults

### 18.2 Preview database sprawl

Risk:

- many open pull requests can leave unused preview databases

Mitigation:

- enforce destroy on PR close
- add scheduled cleanup for stale preview resources

### 18.3 Shared AWS account collisions

Risk:

- other teams create resources with similar names or overlapping Terraform state

Mitigation:

- strict `t3` prefixes
- repository tags
- isolated VPC
- isolated remote state key hierarchy

### 18.4 Build time growth

Risk:

- UI and API image builds become slow on GitHub-hosted runners

Mitigation:

- registry-backed build cache in ECR
- dependency caching for `pnpm` and `pip`
- immutable image tagging

### 18.5 Terraform graph evaluation failures

Risk:

- Terraform `plan` fails with `Invalid for_each argument` when resource instance keys depend on apply-time values

Mitigation:

- enforce the plan-time determinism rules in Section 11.6
- keep `for_each` keys static and move provider-generated values into `each.value`
- run `terraform plan` in CI for each changed environment root before any apply step

## 19. Acceptance Criteria

The implementation based on this plan is complete when all of the following are true:

- each pull request can produce a reachable preview URL
- preview deployment can be updated on new commits to the same PR
- preview deployment is destroyed automatically after PR close or merge
- merge to `main` deploys the latest application version automatically
- GitHub Actions supports manual forced build and deploy
- Terraform state is isolated under `t3`-scoped remote state keys
- AWS resource names and tags do not conflict with other teams
- local `docker-compose` workflow remains unchanged and operational
- `api/Dockerfile` and `ui/Dockerfile` remain valid for local development and CI/CD image builds
- preview and production routing preserve the canonical backend API contract under `/api/v1`
- path-based previews are either backed by a prefix-stripping proxy layer or explicitly replaced by host-based routing before rollout
- any environment used for authenticated browser validation keeps the secure `HTTP-only` cookie model over HTTPS
- preview auth isolation rules are explicit so one PR preview cannot accidentally share browser auth state with another
- Google OAuth validation runs only on environments with a valid registered HTTPS callback URL; when preview hosts cannot satisfy that requirement, the plan explicitly limits OAuth validation to shared environments instead of silently breaking it
- Terraform roots pass plan without instance-addressing failures caused by apply-time-derived `for_each` keys

## 20. Recommended Next Implementation Artifacts

The next delivery step should create:

- `infra/` Terraform root and module structure
- `.github/workflows/ci.yml`
- `.github/workflows/deploy-preview.yml`
- `.github/workflows/destroy-preview.yml`
- `.github/workflows/deploy-main.yml`
- AWS-specific runtime variable definitions for preview and production

## 21. Final Recommendation Summary

The most optimal delivery path for this project is:

- `Terraform` for all AWS infrastructure
- `ECR + ECS Fargate + ALB + RDS PostgreSQL` as the deployment platform
- one shared preview base with per-PR ECS services and routing rules
- automatic production deployment from `main`
- Docker BuildKit registry-backed caching in ECR
- strict `t3` naming, tagging, and Terraform state isolation to avoid cross-team conflicts

This approach is realistic in `eu-north-1`, compatible with the current monorepo and Docker setup, and gives a clean path from temporary AWS-generated preview URLs to the final custom-domain production architecture.
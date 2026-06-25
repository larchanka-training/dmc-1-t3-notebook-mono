# Disaster Recovery Runbook

**Project:** dmc-1-t3-notebook-mono  
**Platform:** AWS (ECS Fargate · RDS PostgreSQL 16 · CloudFront · S3 · ALB · Bedrock)  
**Last reviewed:** 2026-06-25  
**Owner:** DevOps / Platform team

---

## Table of Contents

1. [Runbook Conventions](#runbook-conventions)
2. [Scenario 1 — Database Loss](#scenario-1--database-loss)
3. [Scenario 2 — API Outage](#scenario-2--api-outage)
4. [Scenario 3 — AWS Region Failure](#scenario-3--aws-region-failure)
5. [Scenario 4 — Secrets / Key Leak](#scenario-4--secretskey-leak)
6. [Scenario 5 — Bedrock Budget Breach](#scenario-5--bedrock-budget-breach)
7. [Contacts and Escalation](#contacts-and-escalation)

---

## Runbook Conventions

| Term | Meaning |
|---|---|
| RTO | Recovery Time Objective — max acceptable downtime |
| RPO | Recovery Point Objective — max acceptable data loss window |
| INC | Active incident; log in the incident tracking system |
| ENV | `dev` / `prod`; substitute the actual environment throughout |
| `$VAR` | Shell variable; substitute actual value |

**Severity levels** used in this document:

| Sev | Impact |
|---|---|
| P0 | Full production outage or data loss |
| P1 | Partial production degradation |
| P2 | Non-critical / dev-only impact |

> All CLI commands assume AWS CLI v2, authenticated with a role that has the required permissions. The production stack runs in **`eu-north-1`**; export `AWS_REGION=eu-north-1` for all commands unless noted otherwise. CloudFront-scoped resources (its ACM certificate) live in **`us-east-1`** and must be managed there.

### Canonical Resource Reference (production)

| Resource | Identifier |
|---|---|
| Primary region | `eu-north-1` |
| CloudFront / ACM region | `us-east-1` |
| Root domain | `t3.jsnb.org` |
| API domain | `api.t3.jsnb.org` |
| Route 53 hosted zone | `t3.jsnb.org` |
| ECS cluster | `t3-notebook-cluster` (shared, no `-prod` suffix) |
| ECS service / task family | `t3-notebook-prod-api` |
| Container name / port | `api` / `8000` |
| CloudWatch log group | `/ecs/t3-notebook-prod-api` |
| RDS instance | `t3-notebook-prod-db` |
| DB connection secret | `t3-notebook-prod-db-connection` (JSON) |
| App config secret | `t3-notebook-prod/api-config` (ini, `AWS_APP_SECRET_ARN`) |
| ALB | `t3-notebook-prod-alb` |
| IAM ECS task role | `t3-notebook-api-task` (shared, no `-prod` suffix) |

> The ECS **cluster** is shared across environments and has **no `-prod` suffix** (`t3-notebook-cluster`); only the **service** and task family are environment-scoped (`t3-notebook-prod-api`). `notebook.com` / `api.notebook.com` are **local-development** domains only — production uses `t3.jsnb.org` / `api.t3.jsnb.org`.

> **Open issues:** gaps and fix recommendations identified during the 2026-06-25 live audit are tracked in [runbook_TOFIX_25_06_2026.md](./runbook_TOFIX_25_06_2026.md).

### Incident Session Setup

Run once at the start of any incident to make all CLI commands below copy-paste safe:

```bash
export AWS_REGION=eu-north-1
export ECS_CLUSTER=t3-notebook-cluster
export ECS_SERVICE=t3-notebook-prod-api
export RDS_ID=t3-notebook-prod-db
export ALB_NAME=t3-notebook-prod-alb
export APP_SECRET_ARN=t3-notebook-prod/api-config
export DB_SECRET_ARN=t3-notebook-prod-db-connection
export IAM_TASK_ROLE=t3-notebook-api-task
export LOG_GROUP=/ecs/t3-notebook-prod-api
export PROD_URL=https://t3.jsnb.org
export API_URL=https://api.t3.jsnb.org
```

---

## Scenario 1 — Database Loss

### Context

The system stores all durable server-side state (users, sessions, notebooks, sync metadata) in a single **AWS RDS PostgreSQL 16** instance provisioned by the `infra/modules/rds` Terraform module.

Production configuration:
- `multi_az = true`
- `backup_retention_period = 14` days
- `deletion_protection = true`
- `skip_final_snapshot = false` → final snapshot `<identifier>-final` is created on deletion
- Storage encrypted, Performance Insights enabled

The connection string is stored in **AWS Secrets Manager** as `<identifier>-connection`.

**RTO target:** < 2 h (restore from snapshot)  
**RPO target:** < 5 min (automated backup + Multi-AZ standby)

---

### 1.1 Classify the Loss

| Symptom | Category | Section |
|---|---|---|
| API returns 5xx, CloudWatch `DatabaseConnections` = 0 | Instance unavailable (Multi-AZ failover) | 1.2 |
| Instance missing from RDS console; no Multi-AZ standby | Accidental deletion | 1.3 |
| Data corruption or mass-delete of rows | Logical corruption | 1.4 |
| Snapshot/backup configuration missing | Backup misconfiguration | 1.5 |

---

### 1.2 Multi-AZ Automatic Failover (Instance Crash)

RDS Multi-AZ handles this automatically. The standby promotes in ~60–120 s.

**Verify recovery:**

```bash
# Check instance status
aws rds describe-db-instances \
  --db-instance-identifier t3-notebook-prod-db \
  --query 'DBInstances[0].{Status:DBInstanceStatus,AZ:AvailabilityZone,MultiAZ:MultiAZ}'

# Check recent events
aws rds describe-events \
  --source-identifier t3-notebook-prod-db \
  --source-type db-instance \
  --duration 60
```

**If API containers did not reconnect automatically:**

```bash
# Force a new ECS deployment to re-establish DB connections
aws ecs update-service \
  --cluster t3-notebook-cluster \
  --service t3-notebook-prod-api \
  --force-new-deployment

aws ecs wait services-stable \
  --cluster t3-notebook-cluster \
  --services t3-notebook-prod-api
```

Expected recovery: automatic, no data loss.

---

### 1.3 Accidental Instance Deletion

> ⚠ **Freeze CI/CD before restoring.** If the restore produces a new RDS identifier, an automated `terraform apply` triggered by the next push to `main` will see drift and attempt to destroy the restored instance. Freeze the infra pipeline before proceeding and re-enable only after Terraform state reconciliation (Step 7):
> ```bash
> gh workflow disable infra-cloud.yml --repo <ORG>/<MONO-REPO>
> ```

**Step 1 — Check for final snapshot:**

```bash
aws rds describe-db-snapshots \
  --db-instance-identifier t3-notebook-prod-db \
  --snapshot-type manual \
  --query 'DBSnapshots[*].{Id:DBSnapshotIdentifier,Status:Status,Time:SnapshotCreateTime}'
```

**Step 2 — Restore from snapshot:**

```bash
export SNAPSHOT_ID="t3-notebook-prod-db-final"   # or latest automated snapshot
export NEW_IDENTIFIER="t3-notebook-prod-db"

aws rds restore-db-instance-from-db-snapshot \
  --db-instance-identifier $NEW_IDENTIFIER \
  --db-snapshot-identifier $SNAPSHOT_ID \
  --db-instance-class db.t3.medium \
  --multi-az \
  --no-publicly-accessible \
  --deletion-protection \
  --tags Key=Environment,Value=production
```

**Step 3 — Wait for instance to be available:**

```bash
aws rds wait db-instance-available \
  --db-instance-identifier $NEW_IDENTIFIER
```

**Step 4 — Update Secrets Manager connection string** if the new instance has a different endpoint:

```bash
NEW_ENDPOINT=$(aws rds describe-db-instances \
  --db-instance-identifier $NEW_IDENTIFIER \
  --query 'DBInstances[0].Endpoint.Address' --output text)

# Update the secret value stored in Secrets Manager
aws secretsmanager update-secret \
  --secret-id t3-notebook-prod-db-connection \
  --secret-string "{\"host\":\"$NEW_ENDPOINT\", ...}"
```

**Step 5 — Force ECS redeployment:**

```bash
aws ecs update-service \
  --cluster t3-notebook-cluster \
  --service t3-notebook-prod-api \
  --force-new-deployment

aws ecs wait services-stable \
  --cluster t3-notebook-cluster \
  --services t3-notebook-prod-api
```

**Step 6 — Run smoke tests:**

```bash
curl -sf https://api.t3.jsnb.org/api/v1/system/health
```

**Step 7 — Re-apply Terraform to reconcile state:**

```bash
# The RDS resource lives inside module "database" in infra/env/prod
cd infra/env/prod
terraform import module.database.aws_db_instance.this $NEW_IDENTIFIER
terraform plan   # verify no drift
```

---

### 1.4 Logical Data Corruption (Point-in-Time Recovery)

RDS automated backups support Point-in-Time Recovery (PITR) within the 14-day retention window.

> ⚠ **Freeze CI/CD before restoring.** The PITR target uses a different identifier (`t3-notebook-prod-db-pitr`). Without freezing the infra pipeline, the next automated `terraform apply` will see drift and destroy the restored instance. Freeze the workflow before proceeding and re-enable only after Terraform state reconciliation.
> ```bash
> gh workflow disable infra-cloud.yml --repo <ORG>/<MONO-REPO>
> ```

```bash
# Restore to a point BEFORE corruption, to a NEW instance
aws rds restore-db-instance-to-point-in-time \
  --source-db-instance-identifier t3-notebook-prod-db \
  --target-db-instance-identifier t3-notebook-prod-db-pitr \
  --restore-time "2026-06-23T18:00:00Z" \
  --multi-az \
  --no-publicly-accessible
```

**Validate data on the restored instance before switching traffic.**  
This is a staging restore; only re-route once data integrity is confirmed.

---

### 1.5 Backup Misconfiguration Check

```bash
aws rds describe-db-instances \
  --db-instance-identifier t3-notebook-prod-db \
  --query 'DBInstances[0].{BackupRetention:BackupRetentionPeriod,MultiAZ:MultiAZ,Encrypted:StorageEncrypted,DeletionProtection:DeletionProtection}'
```

All values must match Terraform config. If not, run `terraform plan` and `terraform apply` to enforce the desired state.

---

## Scenario 2 — API Outage

### Context

The API runs as a containerized **FastAPI + Uvicorn** application on **ECS Fargate** behind an **AWS ALB**. CloudFront proxies `/api/*` requests to the ALB. The UI assets are served independently from **CloudFront + S3** and are not affected by API downtime.

**RTO target:** < 15 min for a code/config issue; < 30 min for an infra issue.

---

### 2.1 Classify the Outage

```bash
# Check ALB target health
aws elbv2 describe-target-health \
  --target-group-arn $ALB_TARGET_GROUP_ARN \
  --query 'TargetHealthDescriptions[*].{Target:Target.Id,State:TargetHealth.State,Reason:TargetHealth.Reason}'

# Check ECS service events
aws ecs describe-services \
  --cluster t3-notebook-cluster \
  --services t3-notebook-prod-api \
  --query 'services[0].events[:10]'

# Check running task count
aws ecs describe-services \
  --cluster t3-notebook-cluster \
  --services t3-notebook-prod-api \
  --query 'services[0].{Running:runningCount,Desired:desiredCount,Pending:pendingCount}'
```

| Symptom | Likely cause | Section |
|---|---|---|
| Running = 0, Pending = cycling | Container crash loop (bad config, missing secret) | 2.2 |
| Running = 0, Desired = 0 | Service scaled to zero or stopped | 2.3 |
| Running > 0, ALB unhealthy | Health check failure (DB down, misconfiguration) | 2.4 |
| Running > 0, ALB healthy, 5xx | Application-level error | 2.5 |

---

### 2.2 Container Crash Loop

**Get stopped task logs:**

```bash
# Find stopped task ARN
TASK_ARN=$(aws ecs list-tasks \
  --cluster t3-notebook-cluster \
  --desired-status STOPPED \
  --query 'taskArns[0]' --output text)

# Describe stop reason
aws ecs describe-tasks \
  --cluster t3-notebook-cluster \
  --tasks $TASK_ARN \
  --query 'tasks[0].{StopCode:stopCode,StopReason:stoppedReason,Containers:containers[*].{Name:name,Reason:reason,ExitCode:exitCode}}'

# Extract short task ID from ARN (last segment) and read CloudWatch logs.
# Log stream format: ecs/<container-name>/<short-task-id>
TASK_ID=$(echo $TASK_ARN | awk -F/ '{print $NF}')
aws logs get-log-events \
  --log-group-name /ecs/t3-notebook-prod-api \
  --log-stream-name ecs/api/$TASK_ID \
  --limit 100
```

**Common causes and fixes:**

| Cause | Fix |
|---|---|
| `AWS_APP_SECRET_ARN` missing or wrong | Update ECS task definition env vars; redeploy |
| Secrets Manager permission denied | Update IAM task role; redeploy |
| DB connection refused | Verify RDS security group allows ECS subnet CIDR |
| Image not found in ECR | Push correct image; update task definition |

**Redeploy after fixing root cause:**

```bash
aws ecs update-service \
  --cluster t3-notebook-cluster \
  --service t3-notebook-prod-api \
  --force-new-deployment

aws ecs wait services-stable \
  --cluster t3-notebook-cluster \
  --services t3-notebook-prod-api
```

---

### 2.3 Service Scaled to Zero

```bash
aws ecs update-service \
  --cluster t3-notebook-cluster \
  --service t3-notebook-prod-api \
  --desired-count 2

aws ecs wait services-stable \
  --cluster t3-notebook-cluster \
  --services t3-notebook-prod-api
```

Verify tasks reach `RUNNING` and ALB targets become healthy before closing the incident.

---

### 2.4 ALB Health Check Failure

The health check endpoint is `GET /api/v1/system/health`.

```bash
# Verify the endpoint responds from inside VPC (using a Fargate task with shell access if needed)
curl -sf http://localhost:8000/api/v1/system/health
```

Check:
- Database connectivity (Scenario 1 runbook if DB is down)
- Secrets Manager connectivity (IAM + VPC endpoint)
- Application startup logs for missing configuration values

---

### 2.5 Application-Level Errors (5xx from ALB healthy targets)

```bash
# Tail application logs
aws logs tail /ecs/t3-notebook-prod-api --follow --since 5m
```

If a recent deployment introduced the regression:

```bash
# Roll back to previous task definition revision
PREV_REVISION=$(aws ecs describe-task-definition \
  --task-definition t3-notebook-prod-api \
  --query 'taskDefinition.revision' --output text)
PREV_REVISION=$((PREV_REVISION - 1))

aws ecs update-service \
  --cluster t3-notebook-cluster \
  --service t3-notebook-prod-api \
  --task-definition t3-notebook-prod-api:$PREV_REVISION
```

---

## Scenario 3 — AWS Region Failure

### Context

The production environment is deployed in a **single AWS region (`eu-north-1`)**. A full regional outage makes RDS, ECS, ALB, and the CloudFront origin (the ALB) unavailable. CloudFront itself and its ACM certificate live in `us-east-1`; edge caches may serve stale static assets during a regional disruption.

**RTO target:** < 4 h manual failover to secondary region (no automated cross-region failover exists in Version 1).  
**RPO target:** < 24 h (last RDS automated backup exported to secondary region, see below).

> **Version 1 limitation:** There is no active standby in a second region. The steps below describe a manual cold-start in a secondary region using the most recent RDS snapshot and current Terraform configuration.

---

### 3.1 Confirm Regional Outage

```bash
# Check AWS Service Health Dashboard
open https://health.aws.amazon.com/health/status

# Verify no local network / DNS issue
curl -sf https://api.t3.jsnb.org/api/v1/system/health
nslookup api.t3.jsnb.org
```

Do not start failover until a regional outage is confirmed — failover is expensive and introduces complexity.

---

### 3.2 Pre-requisites (Must Be Done Before an Incident)

These steps must be completed in advance and verified regularly:

- [ ] **RDS automated snapshots copied to secondary region** — set up a CloudWatch Events rule or AWS Backup plan to copy snapshots to `$SECONDARY_REGION` nightly.
- [ ] **Terraform state accessible from secondary region** — ensure the S3 backend bucket is in a region that is not the same as the primary.
- [ ] **ECR images replicated** — enable ECR cross-region replication rules for `$SECONDARY_REGION`.
- [ ] **Secrets Manager secrets replicated** — enable Secrets Manager cross-region replication for the API secret ARN.
  > **Audit (2026-06-25):** `ReplicationStatus: null` for `t3-notebook-prod/api-config` — cross-region replication is **NOT configured**.
- [ ] **Route 53 health checks and failover routing** configured for `api.t3.jsnb.org` and the root domain `t3.jsnb.org` pointing to a secondary ALB/CloudFront distribution.

---

### 3.3 Manual Cold-Start in Secondary Region

**Step 1 — Identify the latest snapshot in secondary region:**

```bash
aws rds describe-db-snapshots \
  --region $SECONDARY_REGION \
  --snapshot-type automated \
  --query 'DBSnapshots[?DBInstanceIdentifier==`t3-notebook-prod-db`]|sort_by(@,&SnapshotCreateTime)[-1]'
```

**Step 2 — Restore RDS in secondary region:**

```bash
aws rds restore-db-instance-from-db-snapshot \
  --region $SECONDARY_REGION \
  --db-instance-identifier t3-notebook-prod-db \
  --db-snapshot-identifier $SNAPSHOT_ID \
  --db-instance-class db.t3.medium \
  --multi-az \
  --no-publicly-accessible
```

**Step 3 — Provision infrastructure in secondary region via Terraform:**

The repo uses **two independent Terraform root modules**: `infra/env/shared` (network VPC, IAM roles, ECR, ECS cluster) and `infra/env/prod` (ALB, ECS service, RDS, CloudFront). Both must be applied in order.

```bash
# 3a — Shared layer (VPC, IAM, ECR, ECS cluster)
cd infra/env/shared
terraform workspace new dr
terraform apply -var="aws_region=$SECONDARY_REGION"

# 3b — Prod layer (ALB, ECS service, CloudFront, Route53)
cd ../prod
terraform workspace new prod-dr
terraform apply -var="aws_region=$SECONDARY_REGION"
```

> `-target` flags are intentionally omitted: do a full apply so all resources are provisioned correctly. Per project conventions, `-target` is only an emergency recovery tool, not a standard deployment path (ref: `docs/DevOps-109-specs.md`).

**Step 4 — Update Route 53 to point to secondary ALB/CloudFront:**

```bash
# Update A/ALIAS records for api.t3.jsnb.org and t3.jsnb.org
# to the secondary region ALB DNS name and CloudFront distribution
```

**Step 5 — Verify smoke tests pass in secondary region:**

```bash
curl -sf https://api.t3.jsnb.org/api/v1/system/health
```

**Step 6 — Communicate status** to users (status page / email).

---

### 3.4 Post-Recovery — Return to Primary Region

Once the primary region recovers:

1. Take a final RDS snapshot in secondary region.
2. Export and restore to primary region RDS.
3. Verify data consistency (compare row counts, latest `updated_at` values).
4. Gradually shift Route 53 weights back to primary region.
5. Decommission secondary region resources to avoid double billing.
6. Conduct a post-mortem and update this runbook.

---

## Scenario 4 — Secrets / Key Leak

### Context

Sensitive credentials used by the system:

| Secret | Storage location | Used by |
|---|---|---|
| API application config (auth hash secrets — session / OTP / OAuth-state — and Google OAuth client id/secret) | AWS Secrets Manager — `t3-notebook-prod/api-config` (`AWS_APP_SECRET_ARN`, ini format) | ECS task at startup, injected into env via Pydantic Settings |
| RDS master password / connection URL | AWS Secrets Manager — `t3-notebook-prod-db-connection` (JSON) | ECS task (DB connection), Terraform, manual admin access |
| AWS IAM access keys | IAM (task roles) or GitHub Actions OIDC | CI/CD pipeline, Terraform |
| GitHub Actions secrets | GitHub repository secrets | CI/CD |
| Google OAuth client secret | Secrets Manager / env config | Backend auth flow |

**No secrets are stored in code, logs, or API responses.** This is a mandatory rule enforced at code review.

> **AI / Bedrock has no static API key.** The ECS task role grants `bedrock:InvokeModel` via IAM, so there is no Bedrock key to rotate. The DB password lives only in the `t3-notebook-prod-db-connection` secret — **not** in `api-config`.

---

### 4.1 Confirm and Scope the Leak

**Indicators of compromise:**

- GitHub secret scanning alert
- AWS GuardDuty finding
- Unexpected AWS API calls in CloudTrail
- Abnormal Bedrock or SES billing spike
- User-reported unexpected access

**Immediate actions (within 5 minutes):**

```bash
# 1. Identify the leaked credential type and source
#    Check GitHub secret scanning: Settings > Security > Secret scanning alerts

# 2. If an IAM access key was leaked, disable it immediately
aws iam update-access-key \
  --access-key-id $LEAKED_KEY_ID \
  --status Inactive

# 3. If a GitHub Actions secret was leaked, rotate it in
#    GitHub > Settings > Secrets and variables > Actions
```

---

### 4.2 Rotate Application Config Secret (Secrets Manager)

The API config is a single `ini`-format secret referenced by `AWS_APP_SECRET_ARN`.

**Fast-path — restore AWSPREVIOUS version (when a valid prior version exists):**

If the wrong value was just written and the previous version is known-good, restore it in under 60 seconds without re-entering any credentials:

```bash
PREV_VID=$(aws secretsmanager describe-secret \
  --secret-id t3-notebook-prod/api-config \
  --query 'VersionIdsToStages | to_entries | [?contains(value, `AWSPREVIOUS`)] | [0].key' \
  --output text)
CURR_VID=$(aws secretsmanager describe-secret \
  --secret-id t3-notebook-prod/api-config \
  --query 'VersionIdsToStages | to_entries | [?contains(value, `AWSCURRENT`)] | [0].key' \
  --output text)
# If PREV_VID is a non-empty UUID:
aws secretsmanager update-secret-version-stage \
  --secret-id t3-notebook-prod/api-config \
  --version-stage AWSCURRENT \
  --move-to-version-id "$PREV_VID" \
  --remove-from-version-id "$CURR_VID"
```

**Full rotation — when no valid previous version exists:**

```bash
# Generate a new session secret key
NEW_SESSION_KEY=$(openssl rand -hex 32)

# Update secret value — use AWS Console or CLI (do NOT log the value)
aws secretsmanager update-secret \
  --secret-id $AWS_APP_SECRET_ARN \
  --secret-string file://new-secret.ini   # file keeps secret off shell history
```

**Redeploy (required for both paths):**

```bash
# Force ECS redeployment to pick up the new secret
aws ecs update-service \
  --cluster t3-notebook-cluster \
  --service t3-notebook-prod-api \
  --force-new-deployment

aws ecs wait services-stable \
  --cluster t3-notebook-cluster \
  --services t3-notebook-prod-api

# All existing HTTP-only session cookies are immediately invalidated
# Users will be required to re-authenticate
```

---

### 4.3 Rotate RDS Master Password

```bash
NEW_DB_PASS=$(openssl rand -base64 24 | tr -d '/+=')

aws rds modify-db-instance \
  --db-instance-identifier t3-notebook-prod-db \
  --master-user-password "$NEW_DB_PASS" \
  --apply-immediately

# Update Secrets Manager connection secret with new password
aws secretsmanager update-secret \
  --secret-id t3-notebook-prod-db-connection \
  --secret-string "{\"password\":\"$NEW_DB_PASS\", ...}"

# The DB password lives in the connection secret only (api-config has no DB
# password); force an ECS redeploy so the API picks up the rotated connection
aws ecs update-service \
  --cluster t3-notebook-cluster \
  --service t3-notebook-prod-api \
  --force-new-deployment

aws ecs wait services-stable \
  --cluster t3-notebook-cluster \
  --services t3-notebook-prod-api
```

---

### 4.4 Rotate IAM Access Keys (CI/CD)

```bash
# Create replacement key first
aws iam create-access-key --user-name $CI_USER

# Update GitHub Actions secret with new key values
# GitHub > Settings > Secrets and variables > Actions > AWS_ACCESS_KEY_ID / AWS_SECRET_ACCESS_KEY

# Delete old key
aws iam delete-access-key \
  --user-name $CI_USER \
  --access-key-id $OLD_KEY_ID
```

If OIDC-based federation is used (recommended), no long-lived keys exist — rotate the trust policy instead.

---

### 4.5 Post-Rotation Checklist

- [ ] All old credentials confirmed inactive or deleted
- [ ] CloudTrail reviewed for unauthorized API calls during exposure window
- [ ] S3 access logs reviewed for unauthorized data access
- [ ] RDS logs reviewed for unauthorized queries
- [ ] GuardDuty findings reviewed and resolved
- [ ] Incident timeline documented
- [ ] GitHub secret scanning alerts resolved
- [ ] Users notified if session invalidation affected them
- [ ] Post-mortem scheduled within 48 h

---

## Scenario 5 — Bedrock Budget Breach

### Context

AI code generation uses **AWS Bedrock** as the canonical LLM provider (`AI_PROVIDER_NAME = "bedrock"`, `AI_PROVIDER_MODEL = "anthropic.claude-3-haiku"`). The backend mediates all requests through `POST /api/v1/ai/code-blocks/generate`. Bedrock is billed per-token (input + output). There is no hard Bedrock quota enforced by default — only AWS Budgets and CloudWatch metrics provide alerting.

> **Version 1 status:** the application-layer AI gateway is currently a placeholder (`UnavailableAiGenerationGateway` in `api/app/integrations/ai/provider.py`); live Bedrock invocation is not yet wired in code. However, the **IAM access is already provisioned** — the ECS task role `t3-notebook-api-task` has an inline policy `bedrock-deepseek-invoke` that grants `bedrock:InvokeModel` and `bedrock:InvokeModelWithResponseStream` on `Resource: "*"`. The cost controls below must be in place **before** the real gateway is enabled.

**Risk:** runaway AI requests (from a bug, abuse, or scraper) can generate unexpected costs before the alert fires.

---

### 5.1 Token Consumption Model

Per API call (approximate, varies by model):

| Component | Typical tokens |
|---|---|
| System prompt | ~200 tokens |
| Notebook context (N blocks) | ~100–500 tokens per block |
| User text block (task spec) | ~50–300 tokens |
| Generated code output | ~100–600 tokens |
| **Total per request** | **~500–2 000 tokens** |

At AWS Bedrock pricing (Anthropic Claude 3 Haiku, as of 2026):
- Input: ~$0.00025 / 1K tokens
- Output: ~$0.00125 / 1K tokens

**Monthly budget estimate:**

| Users | AI requests/user/day | Total requests/month | Estimated cost |
|---|---|---|---|
| 100 | 5 | 15 000 | ~$7–$30 |
| 1 000 | 5 | 150 000 | ~$70–$300 |
| Abuse / scraper | 10 000/day | 300 000 | ~$150–$600 |

---

### 5.2 Prevention — Configure Budgets and Quotas

These must be configured before going to production:

> **Audit (2026-06-25):** `bedrock-monthly` budget — **NOT created**. `bedrock-invocations-high` CloudWatch alarm — **NOT created**. Both are required before enabling the real Bedrock gateway. Run steps 1 and 2 below immediately.

**1 — AWS Budget alert:**

```bash
# Create a monthly cost budget scoped to Bedrock
aws budgets create-budget \
  --account-id $AWS_ACCOUNT_ID \
  --budget '{
    "BudgetName": "bedrock-monthly",
    "BudgetLimit": {"Amount": "200", "Unit": "USD"},
    "TimeUnit": "MONTHLY",
    "BudgetType": "COST",
    "CostFilters": {"Service": ["Amazon Bedrock"]}
  }' \
  --notifications-with-subscribers '[{
    "Notification": {
      "NotificationType": "ACTUAL",
      "ComparisonOperator": "GREATER_THAN",
      "Threshold": 80,
      "ThresholdType": "PERCENTAGE"
    },
    "Subscribers": [{"SubscriptionType": "EMAIL", "Address": "ops@t3.jsnb.org"}]
  }]'
```

**2 — CloudWatch alarm on Bedrock invocation count:**

```bash
aws cloudwatch put-metric-alarm \
  --alarm-name bedrock-invocations-high \
  --metric-name Invocations \
  --namespace AWS/Bedrock \
  --statistic Sum \
  --period 3600 \
  --threshold 1000 \
  --comparison-operator GreaterThanThreshold \
  --evaluation-periods 1 \
  --alarm-actions $SNS_TOPIC_ARN
```

**3 — Application-level rate limiting** (NOT yet implemented for AI — must be added):

- Per-user request limit: max N AI calls per hour (configurable via env).
- Per-request context truncation: limit total tokens sent to Bedrock.
- Request size validation at `POST /api/v1/ai/code-blocks/generate`.

> Reference: the auth feature already ships a rate limiter (`OTP_REQUEST_RATE_LIMIT` in `api/app/features/auth/rate_limit.py`) — reuse that pattern for the AI endpoint. No AI rate limiting or feature flag exists in the codebase today.

**Alternative near-real-time detection — CloudWatch Logs Metric Filter (no `budgets:*` required):**

A Logs Metric Filter on structured API logs fires before the 24-48h Cost Explorer lag and does not require `budgets:ModifyBudget`. Add to `infra/env/prod` once the AI gateway is wired:

```hcl
resource "aws_cloudwatch_log_metric_filter" "llm_total_tokens" {
  name           = "t3-notebook-llm-total-tokens"
  log_group_name = "/ecs/t3-notebook-prod-api"
  pattern        = "{ $.event = \"llm.requested\" }"
  metric_transformation {
    name      = "LlmTotalTokens"
    namespace = "T3Notebook/LLM"
    value     = "$.total_tokens"
    unit      = "Count"
  }
}

resource "aws_cloudwatch_metric_alarm" "llm_token_burst" {
  alarm_name          = "t3-notebook-llm-token-burst"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "LlmTotalTokens"
  namespace           = "T3Notebook/LLM"
  period              = 3600   # 1-hour window
  statistic           = "Sum"
  threshold           = 100000 # calibrate after baseline is established
  alarm_actions       = [aws_sns_topic.alerts.arn]
}
```

This closes the detection gap documented in TOFIX Issue 2 without requiring `budgets:*` IAM rights (tracked in TOFIX 2026-06-25).

---

### 5.3 Incident Response — Budget Threshold Breached

**Step 1 — Assess actual spend:**

```bash
aws ce get-cost-and-usage \
  --time-period Start=$(date +%Y-%m-01),End=$(date +%Y-%m-%d) \
  --granularity DAILY \
  --metrics BlendedCost \
  --filter '{"Dimensions":{"Key":"SERVICE","Values":["Amazon Bedrock"]}}'
```

**Step 2 — Identify the source (normal usage vs. abuse):**

```bash
# Check AI endpoint invocation count in application logs
aws logs filter-log-events \
  --log-group-name /ecs/t3-notebook-prod-api \
  --filter-pattern '"POST /api/v1/ai/code-blocks/generate"' \
  --start-time $(( $(date +%s) - 86400 ))000 \ # portable: Linux & macOS
  --query 'events[*].message' \
  | jq -r '.[]' | wc -l
```

**Step 3 — Emergency: disable AI endpoint:**

If abuse or runaway usage is confirmed, disable the AI route immediately without taking the whole API down:

```bash
# Option A (requires implementation): an `AI_FEATURE_ENABLED` flag does NOT yet
# exist in the API — add it (read in app/core/config.py) so the AI route can be
# disabled by setting AI_FEATURE_ENABLED=false in the task definition + redeploy.

# Option B (available today): Deny bedrock:InvokeModel on the ECS API task IAM role.
# NOTE: t3-notebook-api-task is shared across environments — this deny blocks
# Bedrock in dev/preview too. Acceptable for an emergency stop; remove promptly.
aws iam put-role-policy \
  --role-name t3-notebook-api-task \
  --policy-name deny-bedrock-emergency \
  --policy-document '{
    "Version": "2012-10-17",
    "Statement": [{
      "Effect": "Deny",
      "Action": "bedrock:InvokeModel",
      "Resource": "*"
    }]
  }'
```

The frontend handles AI endpoint failures gracefully — users will see an error in the AI action panel, but notebook editing and sync continue to work normally.

**Step 4 — Investigate and fix root cause:**

- Review application logs for repeated calls from the same user or IP.
- Check for scraper / bot traffic via CloudFront access logs.
- If a specific user account is abusing: disable the account in the database.
- If a code bug causes retries in a loop: identify commit, roll back, hot-fix.

**Step 5 — Re-enable AI endpoint:**

```bash
# Remove emergency deny policy
aws iam delete-role-policy \
  --role-name t3-notebook-api-task \
  --policy-name deny-bedrock-emergency

# Or, once the AI_FEATURE_ENABLED flag is implemented, re-enable via env var + redeploy
aws ecs update-service \
  --cluster t3-notebook-cluster \
  --service t3-notebook-prod-api \
  --force-new-deployment

aws ecs wait services-stable \
  --cluster t3-notebook-cluster \
  --services t3-notebook-prod-api
```

---

### 5.4 Bedrock Quota and Limit Reference

| Limit | Default | How to increase |
|---|---|---|
| Transactions per minute (TPM) per model | Model-dependent (e.g. 60 RPM for Claude 3 Haiku on-demand) | AWS Support quota request |
| Input tokens per minute | Model-dependent | AWS Support quota request |
| Concurrent model invocations | Service quota per account | AWS Support quota request |
| Monthly on-demand spend cap | None by default | AWS Budgets + manual disable |

To view current quotas:

```bash
aws service-quotas list-service-quotas \
  --service-code bedrock \
  --query 'Quotas[*].{Name:QuotaName,Value:Value,Adjustable:Adjustable}'
```

To request an increase:

```bash
aws service-quotas request-service-quota-increase \
  --service-code bedrock \
  --quota-code $QUOTA_CODE \
  --desired-value $NEW_VALUE
```

### 5.5 Operator IAM Permissions Required

The following actions must be granted to the on-call operator role for the full runbook to execute. Gaps found during the 2026-06-25 audit:

| Action | Status |
|---|---|
| `ecr:DescribeRegistry` | ❌ Not granted — cannot verify ECR cross-region replication |
| `route53:ListHealthChecks` | ❌ Not granted — cannot verify Route 53 failover health checks |
| `servicequotas:ListServiceQuotas` | ❌ Not granted — cannot inspect Bedrock quotas |

Add these read-only actions to the on-call IAM policy or the DevOps admin role before the next DR drill.

---

## Contacts and Escalation

| Role | Responsibility | Contact |
|---|---|---|
| On-call engineer | First responder for P0/P1 | PagerDuty / Slack `#on-call` |
| Platform / DevOps lead | Infrastructure and AWS decisions | Slack `#platform` |
| Backend lead | Application-level diagnosis | Slack `#backend` |
| AWS Support | Service-level issues, quota increases | AWS Support Console |

**Incident process:**
1. Open an INC ticket immediately on detection.
2. Post to `#incidents` Slack channel with severity, symptoms, and current status.
3. Update the INC ticket every 30 min until resolved.
4. Schedule a post-mortem within 48 h of P0 resolution.
5. Update this runbook with any gaps discovered during the incident.

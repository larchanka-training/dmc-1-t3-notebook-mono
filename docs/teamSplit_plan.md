# Implementation Plan: AWS Cost Allocation by Team

Reference: [docs/teamSplit.md](./teamSplit.md) — Recommended approach.

## Current State

All Terraform environments define `local.tags` with `Owner = "t3"` but **no `Team` tag**.
Only `infra/bootstrap/providers.tf` uses `default_tags`; the other four environments
(`shared`, `dev`, `prod`, `preview`) pass `local.tags` manually to each module.
No AWS Budget or Cost Category exists yet.

---

## Phase 0 — Request IAM permissions from management account (prerequisite)

**Goal:** `deploy-user` can tag SNS and Application Auto Scaling resources.
This is a **blocker for Phase 1 apply** on prod: adding `default_tags` to the
AWS provider makes Terraform attempt to tag every managed resource, including
SNS topics and autoscaling targets — actions `deploy-user` currently lacks.

### Task 0.1 — Submit IAM change request to management account admin

Request the following additions to the `deploy-user` IAM policy
(our account `867633231218`, region `eu-north-1`):

```json
{
  "Effect": "Allow",
  "Action": [
    "sns:TagResource",
    "sns:UntagResource",
    "application-autoscaling:TagResource",
    "application-autoscaling:UntagResource"
  ],
  "Resource": "*"
}
```

**Do not proceed with Phase 1 `terraform apply` on prod until this is confirmed.**
`shared`, `dev`, and `preview` environments may not use SNS/autoscaling and can be
applied earlier to validate the tag rollout — but prod apply will fail without it.

**Acceptance criterion:** management account admin confirms the policy update is live,
or a test `terraform plan && apply` on prod shows no tagging-permission errors.

---

## Phase 1 — Add `Team` tag across all Terraform environments

**Goal:** Every AWS resource owned by this team carries the tag `Team = "t3"`.

### Task 1.1 — Add `Team` key to `local.tags` in each environment root

Affected files (5 total):

| File | Current `Owner` value |
|---|---|
| `infra/bootstrap/main.tf` | `Owner = "t3"` |
| `infra/env/shared/main.tf` | `Owner = "t3"` |
| `infra/env/dev/main.tf` | `Owner = "t3"` |
| `infra/env/prod/main.tf` | `Owner = "t3"` |
| `infra/env/preview/main.tf` | `Owner = "t3"` (inline `tags = { ... }` block) |

Change for each `tags` block — add one line:

```hcl
tags = {
  Team        = "t3"        # ← add this
  Project     = "dmc-1-t3-notebook"
  Repository  = var.repository
  ManagedBy   = "terraform"
  Owner       = "t3"
  Environment = ...
}
```

> Keep `Owner` in place to avoid breaking any existing AWS resource policies or
> cross-team naming agreements that reference it.

### Task 1.2 — Add `default_tags` to AWS provider blocks

`bootstrap` already has `default_tags`. Add it to the remaining four environments.

**`infra/env/shared/providers.tf`** — before:
```hcl
provider "aws" {
  region = var.aws_region
}
```
After:
```hcl
provider "aws" {
  region = var.aws_region

  default_tags {
    tags = local.tags
  }
}
```

**`infra/env/dev/providers.tf`** — same change as `shared`.

**`infra/env/preview/providers.tf`** — same change as `shared`.

**`infra/env/prod/providers.tf`** — two provider blocks (main + `us_east_1` alias):
```hcl
provider "aws" {
  region = var.aws_region

  default_tags {
    tags = local.tags
  }
}

provider "aws" {
  alias  = "us_east_1"
  region = "us-east-1"

  default_tags {
    tags = local.tags
  }
}
```

> `default_tags` merges with any explicit `tags = { ... }` on individual resources
> (resource-level tags win on conflict). Existing `tags = local.tags` arguments on
> modules do not need to be removed — they are redundant but harmless and can be
> cleaned up separately.

### Task 1.3 — Apply Terraform and verify

For each environment in order:

```bash
# shared first (other envs read its remote state)
cd infra/env/shared  && terraform plan && terraform apply

cd infra/env/dev     && terraform plan && terraform apply
cd infra/env/prod    && terraform plan && terraform apply

# preview: apply for at least one active PR to validate
cd infra/env/preview && terraform plan -var pr_number=<active_pr> && terraform apply -var pr_number=<active_pr>
```

Verify in AWS Console → **Resource Groups & Tag Editor**:
- Filter by `Team = t3`
- Confirm all expected resources (ECS services, RDS, ALB, CloudFront, S3, ECR) appear.

**Acceptance criterion:** every `t3-notebook-*` resource in AWS carries the `Team = t3` tag.

---

## Phase 2 — Activate Cost Allocation Tag in AWS Billing

**Goal:** AWS Billing begins splitting line items by `Team`.

### Task 2.1 — Activate cost allocation tags (manual, one-time)

This step requires AWS Billing console access (root account or billing-admin IAM role).

Activate three tags — `Team`, `Environment`, and `Project` — all three already exist
in every `local.tags` block and will be present on all resources after Phase 1.

**Preferred: AWS CLI** (reproducible, can be added to a runbook):

```bash
aws ce update-cost-allocation-tags-status \
  --cost-allocation-tags-status \
    TagKey=Team,Status=Active \
    TagKey=Environment,Status=Active \
    TagKey=Project,Status=Active
```

**Alternative: AWS Console**:
1. Open **AWS Console → Billing → Cost Allocation Tags → User-Defined Tags**.
2. Find `Team`, `Environment`, `Project` in the list
   (they appear within 24 h of first use on any resource).
3. Select all three and click **Activate**.

> Tags activated after they first appear on resources are applied retroactively
> to the current month's cost data.

Activating all three tags unlocks the following Cost Explorer views:
- Spend by team (`Team = t3` vs other teams)
- Spend by environment within team (`prod` vs `dev` vs `preview`)
- Spend by project (useful if the account later hosts multiple projects)

### Task 2.2 — Verify in Cost Explorer

1. Open **AWS Console → Cost Explorer → Explore costs**.
2. Set **Group by → Tag → Team**.
3. Confirm a `t3` cost bucket appears and the values are plausible.
4. Repeat with **Group by → Tag → Environment** to verify prod/dev split.

**Acceptance criterion:** Cost Explorer shows a non-zero spend row for `Team = t3`.

---

## Phase 3 — Create AWS Budgets via Terraform

**Goal:** Proactive alerts when team spend approaches or exceeds a monthly threshold.

### Task 3.1 — Add `budgets.tf` to `infra/env/shared/`

Create `infra/env/shared/budgets.tf`:

```hcl
# Monthly budget for all t3 resources (all environments combined)
resource "aws_budgets_budget" "t3_team_monthly" {
  name         = "t3-notebook-team-monthly"
  budget_type  = "COST"
  limit_amount = "200"
  limit_unit   = "USD"
  time_unit    = "MONTHLY"

  cost_filter {
    name   = "TagKeyValue"
    values = ["user:Team$t3"]
  }

  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                  = 80
    threshold_type             = "PERCENTAGE"
    notification_type          = "ACTUAL"
    subscriber_email_addresses = [var.budget_alert_email]
  }

  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                  = 100
    threshold_type             = "PERCENTAGE"
    notification_type          = "FORECASTED"
    subscriber_email_addresses = [var.budget_alert_email]
  }
}

# Per-environment budget for prod only (higher sensitivity)
resource "aws_budgets_budget" "t3_prod_monthly" {
  name         = "t3-notebook-prod-monthly"
  budget_type  = "COST"
  limit_amount = "150"
  limit_unit   = "USD"
  time_unit    = "MONTHLY"

  cost_filter {
    name   = "TagKeyValue"
    values = ["user:Team$t3"]
  }

  cost_filter {
    name   = "TagKeyValue"
    values = ["user:Environment$production"]
  }

  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                  = 90
    threshold_type             = "PERCENTAGE"
    notification_type          = "ACTUAL"
    subscriber_email_addresses = [var.budget_alert_email]
  }
}
```

### Task 3.2 — Add `budget_alert_email` variable to `infra/env/shared/variables.tf`

```hcl
variable "budget_alert_email" {
  description = "Email address for AWS Budget alert notifications."
  type        = string
}
```

Set the value in `infra/env/shared/terraform.tfvars` (not committed) or via GitHub Actions secret `BUDGET_ALERT_EMAIL`.

### Task 3.3 — Apply and verify

```bash
cd infra/env/shared && terraform plan && terraform apply
```

**Acceptance criterion:** two new Budget entries visible in **AWS Console → Billing → Budgets**.

---

## Phase 4 — Add Cost Category for untagged resources (deferred)

**Goal:** Capture any resources that escape tag-based attribution (e.g. NAT Gateway
data transfer, certain CloudWatch metrics) by matching resource name patterns.

### Task 4.1 — Create Cost Category in AWS Billing console

1. Open **AWS Console → Billing → Cost Categories → Create cost category**.
2. Name: `TeamAllocation`.
3. Add rule for team T3:
   - Dimension: **Tag** → `Team` = `t3`
   - Add second condition (OR): **Resource** name contains `t3-notebook`
   - Category value: `Team-T3`
4. Add equivalent rules for other teams (optional, coordinated with them).
5. Save and wait up to 8 hours for the first cost data split.

> Cost Categories can also be managed via Terraform using `aws_ce_cost_category`.
> Defer Terraform management until the rules are stable.

### Task 4.2 — Verify

In Cost Explorer, add the **Cost Category → TeamAllocation** dimension.
Confirm that the previously-untagged line items now appear under `Team-T3`.

**Acceptance criterion:** total unattributed spend in Cost Explorer is < 5% of t3 total.

---

## Phase 5 — Evaluate per-account isolation (future)

**Trigger:** the shared account becomes operationally complex, or the team needs IAM
boundary isolation, independent service quotas, or billing fully separated from
the management account.

**Actions (not yet planned):**

1. Create AWS Organizations with a root management account.
2. Provision one member account per team via Terraform (`aws_organizations_account`).
3. Re-provision `t3` infrastructure in the new member account.
4. Use AWS Organizations Consolidated Billing for aggregate view.

This phase requires coordination with other teams and the account owner.
Do not start without an approved change request.

---

## Summary of Changes

| Phase | Artifact | Type |
|---|---|---|
| 0.1 | IAM policy for `deploy-user` | Request to management account admin — add SNS + autoscaling tag actions |
| 1.1 | `infra/bootstrap/main.tf` | Add `Team = "t3"` to `local.tags` |
| 1.1 | `infra/env/shared/main.tf` | Add `Team = "t3"` to `local.tags` |
| 1.1 | `infra/env/dev/main.tf` | Add `Team = "t3"` to `local.tags` |
| 1.1 | `infra/env/prod/main.tf` | Add `Team = "t3"` to `local.tags` |
| 1.1 | `infra/env/preview/main.tf` | Add `Team = "t3"` to inline `tags` block |
| 1.2 | `infra/env/shared/providers.tf` | Add `default_tags` |
| 1.2 | `infra/env/dev/providers.tf` | Add `default_tags` |
| 1.2 | `infra/env/prod/providers.tf` | Add `default_tags` to both provider blocks |
| 1.2 | `infra/env/preview/providers.tf` | Add `default_tags` |
| 2.1 | AWS CLI / Billing console | Activate `Team`, `Environment`, `Project` as Cost Allocation Tags |
| 3.1 | `infra/env/shared/budgets.tf` | New file — two `aws_budgets_budget` resources |
| 3.2 | `infra/env/shared/variables.tf` | Add `budget_alert_email` variable |
| 4.1 | AWS Billing console | Create Cost Category `TeamAllocation` (manual, deferred) |

## Execution Order

```
Phase 0 (IAM request to mgmt account admin) ← BLOCKER for prod apply
  ↓
Phase 1 (Terraform changes)
  → terraform apply shared
  → terraform apply dev
  → terraform apply preview (any active PR)
  → terraform apply prod   ← only after Phase 0 confirmed
Phase 2 (AWS CLI, 5 min)   ← after at least shared apply completes
Phase 3 (Terraform)        ← parallel with Phase 2, after Phase 1 shared apply
Phase 4 (deferred, AWS console)
Phase 5 (future, requires approval)
```

Phases 2 and 3 are independent of each other and can run in parallel once Phase 1
`shared` apply succeeds. Prod apply is gated on Phase 0 IAM confirmation.

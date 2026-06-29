# AWS Cost Allocation by Team

## Context

The project shares one AWS account (`867633231218`, region `eu-north-1`) across three teams.
All resources owned by this team use the `t3` name prefix (e.g. `t3-notebook-vpc`, `t3-notebook-api`).

Infrastructure is managed with Terraform.
Environments: `shared`, `dev`, `preview` (per-PR), `prod`.

---

## Option 1 — Cost Allocation Tags (recommended baseline)

**How it works**

Add a `Team` tag to every AWS resource provisioned by Terraform.
Activate the tag as a **Cost Allocation Tag** in AWS Billing.
Filter and group costs by `Team` in Cost Explorer and in budget alerts.

**Implementation steps**

1. Add a default tag in every Terraform root and module:

   ```hcl
   # infra/env/*/main.tf and all modules
   locals {
     common_tags = {
       Team        = "t3"
       Project     = "notebook"
       Environment = var.environment   # dev | prod | preview
     }
   }
   ```

2. Propagate `local.common_tags` to every resource block (or use the `default_tags` block of the AWS provider):

   ```hcl
   provider "aws" {
     region = "eu-north-1"
     default_tags {
       tags = local.common_tags
     }
   }
   ```

3. Activate the `Team` tag in **AWS Billing → Cost Allocation Tags → User-defined tags**.
   AWS starts splitting costs by tag within 24 hours.

4. In **Cost Explorer**: Group by tag `Team` to see per-team spend.

**Pros**

- No AWS account restructuring required.
- Works with the existing Terraform layout.
- Granular: can also split by `Environment` or `Project` in the same pass.
- Low operational overhead once tags are propagated.

**Cons**

- Some managed services (e.g. NAT Gateway data processing, certain CloudWatch metrics) may not attach custom tags — those costs fall into an untagged bucket.
- Requires a one-time Terraform pass to tag all existing resources.
- Cost data has up to 24-hour latency.

---

## Option 2 — AWS Cost Categories

**How it works**

AWS Cost Categories let you define rules that group line items into named categories
without requiring perfect tagging.
Rules can match on resource tags, account IDs, service names, or resource name patterns.

**Implementation steps**

1. Go to **AWS Billing → Cost Categories → Create cost category**.
2. Define one category per team, using rules like:
   - Tag `Team` = `t3` → category `Team-T3`
   - Resource name contains `t3-notebook` → category `Team-T3`
   - (repeat for other teams)
3. Use the Cost Category dimension in Cost Explorer, budgets, and reports.

**Pros**

- Can capture costs even from partially-tagged or legacy resources using name patterns.
- Works well as a complement to Option 1 to handle untagged items.
- Does not require Terraform changes (rules are defined in Billing console or via API).

**Cons**

- Up to 8-hour processing delay.
- Cost Categories themselves have a small additional charge ($0.01 per 1,000 line items covered by a rule, after the free tier).
- Rules require maintenance if resource naming conventions change.

---

## Option 3 — Separate AWS Accounts per Team (AWS Organizations)

**How it works**

Each team operates in its own AWS account.
Costs are naturally isolated per account.
An AWS Organizations management account consolidates billing across all team accounts.

**Implementation steps**

1. Create an AWS Organizations structure with one root management account.
2. Create one member account per team (e.g. `t3-notebook`, `t1-...`, `t2-...`).
3. Move existing `t3` resources to the `t3-notebook` account (or re-provision with Terraform using a new account target).
4. Use **AWS Organizations Consolidated Billing** to view aggregate and per-account costs.

**Pros**

- Strongest isolation: IAM boundaries, service quotas, and billing are fully separated.
- No tagging discipline required — account ID is the natural cost boundary.
- Simplifies permission management (no cross-team resource access by default).

**Cons**

- Requires significant restructuring of the existing AWS setup.
- Shared resources (e.g. a common preview ALB) must be split or moved to a dedicated shared account.
- Higher operational overhead: multiple accounts to manage, cross-account roles, etc.
- Not practical as a short-term fix; best planned as a future-state target.

---

## Option 4 — AWS Budgets with Tag-Based Alerts

**How it works**

Complementary to Options 1 and 2.
Create a budget scoped to tag `Team=t3` that sends alerts when spend exceeds a threshold.

**Implementation steps**

1. In **AWS Billing → Budgets → Create budget**:
   - Budget type: Cost budget
   - Filter by tag: `Team = t3`
   - Set monthly threshold (e.g. $200)
   - Configure SNS or email alert at 80% and 100% of threshold.

2. Optionally create separate budgets per environment:
   - Tag filter: `Team=t3` AND `Environment=prod`
   - Tag filter: `Team=t3` AND `Environment=preview`

**Pros**

- No infrastructure changes required beyond tagging (depends on Option 1).
- Proactive: alerts before costs exceed budget.
- Supports forecasted-spend alerts in addition to actual-spend alerts.

**Cons**

- Budgets are a monitoring tool, not a cost allocation mechanism on their own.
- Requires Option 1 or Option 2 tags to be present for accurate filtering.

---

## Recommended Approach for This Project

| Step | Action |
|---|---|
| **1 (now)** | Add `Team = t3` and `Environment` tags via `default_tags` in Terraform AWS provider for all environments (`shared`, `dev`, `prod`, `preview`). |
| **2 (now)** | Activate `Team` as a Cost Allocation Tag in AWS Billing. |
| **3 (now)** | Create an AWS Budget scoped to `Team=t3` with a monthly alert threshold. |
| **4 (later)** | Add a Cost Category rule to catch any untagged `t3` resources by name pattern. |
| **5 (future)** | Evaluate moving to separate AWS accounts per team if the shared account becomes operationally complex. |

This sequence minimizes implementation cost and risk while delivering immediate cost visibility.

---

## Terraform Reference: `default_tags` Pattern

```hcl
# infra/env/prod/main.tf  (same pattern for dev, shared, preview)
provider "aws" {
  region = "eu-north-1"

  default_tags {
    tags = {
      Team        = "t3"
      Project     = "notebook"
      Environment = "prod"
      ManagedBy   = "terraform"
      Repo        = "larchanka-training/dmc-1-t3-notebook-mono"
    }
  }
}
```

For preview environments, add the PR number:

```hcl
# infra/env/preview/main.tf
provider "aws" {
  region = "eu-north-1"

  default_tags {
    tags = {
      Team        = "t3"
      Project     = "notebook"
      Environment = "preview"
      PR          = var.pr_number
      ManagedBy   = "terraform"
      Repo        = "larchanka-training/dmc-1-t3-notebook-mono"
    }
  }
}
```

> **Note:** `default_tags` applies to all resources managed by this provider instance.
> Resources that inherit these tags do not need explicit `tags = {}` blocks.
> Tags set directly on a resource take precedence and are merged with `default_tags`.

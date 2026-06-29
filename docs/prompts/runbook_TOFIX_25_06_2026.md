# Runbook — Resolved Issues Log

**Audited:** 2026-06-25
**Resolved:** 2026-06-25
**Source:** live AWS CLI audit against `t3-notebook-prod` (account `$AWS_ACCOUNT_ID`, region `eu-north-1`)
**Runbook:** [runbook.md](./runbook.md)

All eleven gaps from the 2026-06-25 audit are resolved.

- Issues **1–7** are now codified as Terraform infrastructure-as-code under [infra/](../../infra). They take effect on the next `terraform apply` (the `shared` env applies before `prod`).
- Issues **8–11** were resolved procedurally in [runbook.md](./runbook.md) (see prior update).

---

## Summary

| # | Severity | Scenario | Issue | Status |
|---|---|---|---|---|
| 1 | 🔴 P0 | §5.2 | AWS Budget `bedrock-monthly` not created | ✅ Resolved (IaC) |
| 2 | 🔴 P0 | §5.2 | CloudWatch alarm `bedrock-invocations-high` not created | ✅ Resolved (IaC) |
| 3 | 🟠 P1 | §3.2 | Secrets Manager cross-region replication not configured | ✅ Resolved (IaC) |
| 4 | 🟠 P1 | §1.3 | No scheduled/retained RDS snapshots | ✅ Resolved (IaC) |
| 5 | 🟡 P2 | §3.2 | ECR cross-region replication not configured | ✅ Resolved (IaC) |
| 6 | 🟡 P2 | §3.2 | Route 53 health check / failover routing missing | ✅ Resolved (IaC) |
| 7 | 🟡 P2 | §5.5 | Operator role missing read-only IAM actions | ✅ Resolved (IaC) |
| 8 | 🔴 P0 | §1.3, §1.4 | CI/CD not frozen before RDS restore | ✅ Resolved (runbook) |
| 9 | 🟠 P1 | §4.2 | No fast `AWSPREVIOUS` secret rollback | ✅ Resolved (runbook) |
| 10 | 🟡 P2 | multiple | Missing `aws ecs wait services-stable` | ✅ Resolved (runbook) |
| 11 | 🟡 P2 | All | No incident session env var setup block | ✅ Resolved (runbook) |

---

## Resolution Log — Infrastructure (Issues 1–7)

Implemented as Terraform. Validated with `terraform fmt -recursive` and `terraform validate` (both `shared` and `prod` environments pass).

### Issue 1 — AWS Budget `bedrock-monthly`
- `aws_budgets_budget.bedrock_monthly` in [infra/env/prod/main.tf](../../infra/env/prod/main.tf) — $200/month limit, `Service = Amazon Bedrock` filter, 80% ACTUAL and 100% FORECASTED email notifications.
- Limit configurable via `bedrock_monthly_budget_usd`; recipient via `ops_alert_email` ([infra/env/prod/variables.tf](../../infra/env/prod/variables.tf)).

### Issue 2 — CloudWatch alarm `bedrock-invocations-high`
- `aws_sns_topic.alerts` + `aws_sns_topic_subscription.alerts_email` (notification channel).
- `aws_cloudwatch_metric_alarm.bedrock_invocations_high` — `AWS/Bedrock Invocations` Sum > 1000 / 1h.
- Plus the namespace-independent path from runbook §5.2: `aws_cloudwatch_log_metric_filter.llm_total_tokens` + `aws_cloudwatch_metric_alarm.llm_token_burst`, sourced from the API log group via `module.api_service.log_group_name`.
- All in [infra/env/prod/main.tf](../../infra/env/prod/main.tf).

### Issue 3 — Secrets Manager cross-region replication
- `aws_secretsmanager_secret.api_config` now has a `replica { region = var.dr_region }` block.
- The RDS connection secret replicates via the new `secret_replica_regions` input to the rds module ([infra/modules/rds/main.tf](../../infra/modules/rds/main.tf), [infra/modules/rds/variables.tf](../../infra/modules/rds/variables.tf)); wired in [infra/env/prod/main.tf](../../infra/env/prod/main.tf).
- DR region defaults to `eu-west-1` (`dr_region`).

### Issue 4 — Scheduled/retained RDS snapshots
- AWS Backup vault, IAM role, weekly plan (`cron(0 3 ? * SUN *)`, 35-day retention), and selection targeting the RDS instance in [infra/env/prod/main.tf](../../infra/env/prod/main.tf).
- New `db_instance_arn` output added to the rds module ([infra/modules/rds/outputs.tf](../../infra/modules/rds/outputs.tf)).
- Final-snapshot-on-destroy was already configured in the module.

### Issue 5 — ECR cross-region replication
- `aws_ecr_replication_configuration` added to [infra/modules/ecr/main.tf](../../infra/modules/ecr/main.tf), gated by a new `replication_regions` input ([infra/modules/ecr/variables.tf](../../infra/modules/ecr/variables.tf)).
- Wired to `[var.dr_region]` in [infra/env/shared/main.tf](../../infra/env/shared/main.tf). PREFIX_MATCH filter `t3-notebook`.

### Issue 6 — Route 53 health check + failover
- `aws_route53_health_check.api` (HTTPS, `/api/v1/health`, 30s interval, 3 failures) and PRIMARY/SECONDARY failover records for the `api` domain, in [infra/env/prod/main.tf](../../infra/env/prod/main.tf). Failover is enabled only when a DR-region secondary ALB is provided (`dr_secondary_alb_dns_name`); until then a plain primary alias is published to avoid a `SERVFAIL` DNS blackout on a false-positive health-check flip.
- Health-check path corrected to `/api/v1/health` to match the actual ALB target-group check (the audit draft used `/api/v1/system/health`).

### Issue 7 — Operator read-only IAM role
- `aws_iam_role.operator` (`t3-notebook-operator`) + inline `dr-runbook-readonly` policy granting `ecr:DescribeRegistry`, `route53:ListHealthChecks`, `route53:GetHealthCheck`, `servicequotas:ListServiceQuotas`, `servicequotas:GetServiceQuota`, in [infra/env/shared/main.tf](../../infra/env/shared/main.tf).
- Trust is scoped to explicit on-call/SSO principal ARNs (`operator_principal_arns`), never the account root; the role is created only when principals are supplied.

---

## Resolution Log — Procedural (Issues 8–11)

Already applied in [runbook.md](./runbook.md) during the 2026-06-25 update:

- **Issue 8** — CI/CD freeze warning added to §1.3 and §1.4.
- **Issue 9** — `AWSPREVIOUS` fast-path rollback added to §4.2.
- **Issue 10** — `aws ecs wait services-stable` added after every `--force-new-deployment`.
- **Issue 11** — Incident Session Setup env var block added to Runbook Conventions.

---

## Residual Manual Follow-up

These IaC changes are complete but require operational follow-up to be fully effective:

1. **Apply Terraform** — run `terraform apply` for `shared` then `prod`. Secret/ECR replication and the operator role are created on apply.
2. **Confirm SNS subscription** — the `ops@t3.jsnb.org` email subscription must be confirmed manually (one-time click) before budget/alarm notifications deliver.
3. **DR secondary region (§3.3)** — Issue 6 provisions only the PRIMARY failover record. Add the `SECONDARY` failover record pointing at the DR-region ALB once the secondary stack exists.
4. **Token-burst threshold** — `llm_token_burst` is set to 100000 tokens/h as a placeholder; recalibrate after a usage baseline is established.

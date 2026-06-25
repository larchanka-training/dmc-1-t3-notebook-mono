# Runbook — Open Issues & Fix Recommendations

**Audited:** 2026-06-25  
**Source:** live AWS CLI audit against `t3-notebook-prod` (account `867633231218`, region `eu-north-1`)  
**Runbook:** [runbook.md](./runbook.md)

All items below were identified by executing every runbook command against the real production AWS account. Nothing is theoretical — each gap was confirmed by an actual CLI response.

---

## Summary

| # | Severity | Scenario | Issue | Status |
|---|---|---|---|---|
| 1 | 🔴 P0 | §5.2 | AWS Budget `bedrock-monthly` not created | Open |
| 2 | 🔴 P0 | §5.2 | CloudWatch alarm `bedrock-invocations-high` not created | Open |
| 3 | 🟠 P1 | §3.2 | Secrets Manager cross-region replication not configured | Open |
| 4 | 🟠 P1 | §1.3 | No manual/final RDS snapshots exist (DR drill never run) | Open |
| 5 | 🟡 P2 | §3.2 | ECR cross-region replication unverifiable (IAM blocked) | Open |
| 6 | 🟡 P2 | §3.2 | Route 53 health checks unverifiable (IAM blocked) | Open |
| 7 | 🟡 P2 | §5.5 | Operator role missing 3 read-only IAM actions | Open |

---

## Issue 1 — AWS Budget `bedrock-monthly` not created

**Severity:** 🔴 P0  
**Scenario:** §5.2 Prevention — Configure Budgets and Quotas  
**Confirmed by:**
```
aws budgets describe-budgets --account-id 867633231218
→ query for BudgetName==bedrock-monthly returned: null
```

**Risk:** Bedrock IAM access is already live (`bedrock-deepseek-invoke` policy on `t3-notebook-api-task`). Once the application gateway is wired, runaway or abusive token usage will incur unbounded cost with no alert.

**Fix — run once (account `867633231218`):**
```bash
aws budgets create-budget \
  --account-id 867633231218 \
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

**Verify:**
```bash
aws budgets describe-budgets --account-id 867633231218 \
  --query 'Budgets[?BudgetName==`bedrock-monthly`].{Name:BudgetName,Limit:BudgetLimit.Amount}'
```

---

## Issue 2 — CloudWatch alarm `bedrock-invocations-high` not created

**Severity:** 🔴 P0  
**Scenario:** §5.2 Prevention — Configure Budgets and Quotas  
**Confirmed by:**
```
aws cloudwatch describe-alarms --alarm-names bedrock-invocations-high
→ MetricAlarms: []
```

**Risk:** No rate-based alerting on Bedrock invocations. A scraper or runaway retry loop can exhaust quota and generate cost before anyone is notified.

**Fix — requires an SNS topic ARN for notifications:**
```bash
# If no SNS topic exists yet, create one first:
SNS_TOPIC_ARN=$(aws sns create-topic --name devops-alerts \
  --query 'TopicArn' --output text)
aws sns subscribe --topic-arn $SNS_TOPIC_ARN \
  --protocol email --notification-endpoint ops@t3.jsnb.org

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

**Verify:**
```bash
aws cloudwatch describe-alarms --alarm-names bedrock-invocations-high \
  --query 'MetricAlarms[*].{Name:AlarmName,State:StateValue,Threshold:Threshold}'
```

---

## Issue 3 — Secrets Manager cross-region replication not configured

**Severity:** 🟠 P1  
**Scenario:** §3.2 Pre-requisites (Must Be Done Before an Incident)  
**Confirmed by:**
```
aws secretsmanager describe-secret --secret-id t3-notebook-prod/api-config
→ "ReplicationStatus": null
```

**Risk:** During a full `eu-north-1` regional failure, the API config secret (`t3-notebook-prod/api-config`) is unavailable in the secondary region. The cold-start ECS tasks in §3.3 will fail at startup because `_load_aws_secret()` cannot reach Secrets Manager.

**Fix:**
```bash
export SECONDARY_REGION=eu-west-1   # choose DR region

# Replicate app config secret
aws secretsmanager replicate-secret-to-regions \
  --secret-id t3-notebook-prod/api-config \
  --add-replica-regions '[{"Region":"'"$SECONDARY_REGION"'"}]'

# Verify
aws secretsmanager describe-secret \
  --secret-id t3-notebook-prod/api-config \
  --query 'ReplicationStatus'
```

> The `t3-notebook-prod-db-connection` secret should also be replicated (or recreated with the new DR endpoint) for the same reason.

---

## Issue 4 — No manual/final RDS snapshots exist

**Severity:** 🟠 P1  
**Scenario:** §1.3 Accidental Instance Deletion  
**Confirmed by:**
```
aws rds describe-db-snapshots \
  --db-instance-identifier t3-notebook-prod-db \
  --snapshot-type manual
→ DBSnapshots: []
```

**Risk:** If the RDS instance is accidentally deleted, §1.3 Step 1 instructs the responder to look for a `t3-notebook-prod-db-final` manual snapshot. It does not exist. Recovery would fall back to the latest automated snapshot (last taken 2026-06-24 02:32 UTC — up to ~24 h of RPO in the worst case).

**Fix — create an on-demand manual snapshot now and repeat after each major DB change:**
```bash
aws rds create-db-snapshot \
  --db-instance-identifier t3-notebook-prod-db \
  --db-snapshot-identifier t3-notebook-prod-db-manual-$(date +%Y%m%d)

# Wait for completion
aws rds wait db-snapshot-completed \
  --db-snapshot-identifier t3-notebook-prod-db-manual-$(date +%Y%m%d)
```

**Recommended:** add a nightly AWS Backup plan or EventBridge rule to automate weekly manual snapshots in addition to the 14-day automated retention.

---

## Issue 5 — ECR cross-region replication unverifiable

**Severity:** 🟡 P2  
**Scenario:** §3.2 Pre-requisites  
**Confirmed by:**
```
aws ecr describe-registry
→ AccessDeniedException: not authorized to perform ecr:DescribeRegistry
```

**Risk:** Unknown. ECR cross-region replication may or may not be configured — the operator cannot verify it. During a DR cold-start (§3.3), the secondary-region ECS tasks will fail to pull images if ECR is not replicated.

**Fix — two parts:**

1. Grant the operator/on-call role `ecr:DescribeRegistry` (see Issue 7).

2. Once the permission is in place, verify and enable replication:
```bash
aws ecr describe-registry --query 'replicationConfiguration'

# If empty, enable cross-region replication for t3-notebook-api:
aws ecr put-replication-configuration \
  --replication-configuration '{
    "rules": [{
      "destinations": [{"region": "'"$SECONDARY_REGION"'", "registryId": "867633231218"}],
      "repositoryFilters": [{"filter": "t3-notebook", "filterType": "PREFIX_MATCH"}]
    }]
  }'
```

---

## Issue 6 — Route 53 health checks / failover routing unverifiable

**Severity:** 🟡 P2  
**Scenario:** §3.2 Pre-requisites  
**Confirmed by:**
```
aws route53 list-health-checks
→ AccessDenied: not authorized to perform route53:ListHealthChecks
```

**Risk:** Unknown. No Route 53 health check or failover routing record is confirmed for `api.t3.jsnb.org`. During a regional outage, DNS would continue pointing to the unavailable `eu-north-1` ALB instead of automatically or manually failing over.

**Fix — two parts:**

1. Grant the operator role `route53:ListHealthChecks` (see Issue 7).

2. Create a health check and failover record set:
```bash
# Create health check on the ALB endpoint
aws route53 create-health-check \
  --caller-reference "$(date +%s)" \
  --health-check-config '{
    "FullyQualifiedDomainName": "api.t3.jsnb.org",
    "Port": 443,
    "Type": "HTTPS",
    "ResourcePath": "/api/v1/system/health",
    "RequestInterval": 30,
    "FailureThreshold": 3
  }'
```

Then update the `api.t3.jsnb.org` A/ALIAS record in the `t3.jsnb.org` hosted zone to use `Failover=PRIMARY` routing with the health check ID attached. Add a `Failover=SECONDARY` record pointing to the DR ALB once §3.3 is provisioned.

---

## Issue 7 — Operator role missing read-only IAM actions

**Severity:** 🟡 P2  
**Scenario:** §5.5 Operator IAM Permissions Required  
**Confirmed by:** `AccessDeniedException` on three separate commands during the audit.

| Missing action | Needed for |
|---|---|
| `ecr:DescribeRegistry` | Verify ECR cross-region replication (Issue 5) |
| `route53:ListHealthChecks` | Verify Route 53 failover health checks (Issue 6) |
| `servicequotas:ListServiceQuotas` | Inspect current Bedrock token/request quotas (§5.4) |

**Fix — add an inline policy to the on-call / DevOps operator IAM role:**
```bash
aws iam put-role-policy \
  --role-name <OPERATOR_ROLE_NAME> \
  --policy-name dr-runbook-readonly \
  --policy-document '{
    "Version": "2012-10-17",
    "Statement": [
      {
        "Sid": "DRRunbookReadOnly",
        "Effect": "Allow",
        "Action": [
          "ecr:DescribeRegistry",
          "route53:ListHealthChecks",
          "route53:GetHealthCheck",
          "servicequotas:ListServiceQuotas",
          "servicequotas:GetServiceQuota"
        ],
        "Resource": "*"
      }
    ]
  }'
```

---

## Remediation Priority Order

1. **Issue 1 + Issue 2** — Create Bedrock budget and alarm. 30-minute task. Do before enabling the Bedrock gateway.
2. **Issue 4** — Take a manual RDS snapshot now. 5-minute task. Repeat weekly.
3. **Issue 7** — Add 5 read-only actions to the operator IAM role. 10-minute task. Unblocks verification of Issues 5 and 6.
4. **Issue 3** — Enable Secrets Manager cross-region replication. 15-minute task.
5. **Issue 5** — Verify and enable ECR cross-region replication (requires Issue 7 first).
6. **Issue 6** — Configure Route 53 health check and failover records (requires secondary region infrastructure from §3.3 to be provisioned first).

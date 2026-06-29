# Bedrock Runtime Smoke Guide

## Purpose

This guide gives the team a screen-by-screen AWS Console checklist for enabling and verifying the canonical AI runtime path:

- `frontend -> backend -> AWS Bedrock`

Use it when you need to:

- confirm Bedrock model availability in the target region
- verify the backend runtime role and secret wiring
- distinguish config issues from live AWS access issues
- run the manual Bedrock-backed smoke flow on a synced notebook

For the backend operational contract and failure taxonomy, also see:

- [../../api/docs/ai_runtime_operations.md](../../api/docs/ai_runtime_operations.md)

## What You Need Before Starting

- access to the correct AWS account
- access to the target region in the AWS Console
- access to the ECS service that runs the backend API
- access to the IAM role attached to that ECS task
- access to the Secrets Manager secret referenced by `AWS_APP_SECRET_ARN`

This guide assumes the target region is:

- `eu-north-1`

## Quick Route

Open these screens in order:

1. `Amazon Bedrock -> Model catalog`
2. `ECS -> Clusters -> <target cluster> -> Services -> <api service>`
3. `ECS -> Task definition -> latest active revision`
4. `IAM -> Roles -> <task role>`
5. `Secrets Manager -> <secret from AWS_APP_SECRET_ARN>`
6. `GET /api/v1/system/health`
7. `CloudWatch -> Log groups -> <api service log group>`

## Step 1. Confirm the AWS Region

In the AWS Console top navigation, set the region to:

- `Europe (Stockholm) / eu-north-1`

Do not mix regions while checking Bedrock, ECS, and Secrets Manager.

If the backend config points to `eu-north-1` but you inspect a different region in the console, the smoke result is not trustworthy.

## Step 2. Confirm the Model in Bedrock

Open:

- `Amazon Bedrock -> Model catalog`

Check:

- the target model is visible in `eu-north-1`
- the exact model id matches `AI_PROVIDER_MODEL`
- the model does not still require onboarding steps such as:
  - `Request access`
  - `Complete setup`
  - `Subscribe`
  - `First-time use`

If the model card is not visible in `eu-north-1`, the backend will not be able to invoke it from that region.

## Step 3. Confirm Third-Party Model Prerequisites

Open the target model card in Bedrock and confirm whether it requires:

- first-time-use form completion
- AWS Marketplace subscription
- billing or payment method confirmation

If any of these are incomplete, the backend may look correctly configured but still fail at invoke time with an access error.

## Step 4. Confirm the Target Backend Service

Open:

- `ECS -> Clusters -> <target cluster> -> Services -> <api service>`

Check:

- this is the actual backend API service for the target environment
- the service is `Running`
- tasks are healthy and active
- the service uses the expected task definition revision

If you have several environments such as `dev`, `staging`, and `prod`, verify the exact service you plan to smoke.

## Step 5. Confirm the Task Definition

From the ECS service, open:

- `Task definition -> latest active revision`

Check:

- the `Task role ARN`
- the container environment variables or secrets
- that `AWS_APP_SECRET_ARN` is present if your runtime config comes from Secrets Manager

This is the point where the target environment wiring becomes concrete.

## Step 6. Confirm the IAM Role

Open:

- `IAM -> Roles -> <task role from the ECS task definition>`

Check that the role can:

- invoke the selected Bedrock model
- read the runtime secret from Secrets Manager
- decrypt the secret if a customer-managed KMS key is used

At minimum, the role must support the Bedrock invoke path and:

- `secretsmanager:GetSecretValue`

If the role is wrong or missing, Bedrock smoke cannot pass regardless of application code.

## Step 7. Confirm the Runtime Secret

Open:

- `Secrets Manager -> <secret referenced by AWS_APP_SECRET_ARN>`

Check that the secret contains the expected runtime settings, for example:

```ini
AI_PROVIDER_ENABLED=true
AI_PROVIDER_NAME=bedrock
AI_PROVIDER_MODEL=deepseek.v3.2
AI_BEDROCK_REGION=eu-north-1
AI_BEDROCK_TIMEOUT_SECONDS=20
AI_BEDROCK_MAX_RETRIES=1
```

Check carefully:

- `AI_PROVIDER_ENABLED=true`
- `AI_PROVIDER_NAME=bedrock`
- `AI_PROVIDER_MODEL` exactly matches the model id from Bedrock
- `AI_BEDROCK_REGION=eu-north-1`

If the secret and the Bedrock catalog disagree on region or model id, treat that as a hard blocker.

## Step 8. Confirm the Health Surface

Open:

- `GET /api/v1/system/health`

The backend should return a safe AI readiness block with:

- `provider`
- `configured`
- `ready`
- `reason`
- `missing_fields`

Expected happy-path values:

- `ai.provider = "bedrock"`
- `ai.configured = true`
- `ai.ready = true`

Meaning of common values:

| Health value | Meaning |
|---|---|
| `reason=disabled` | `AI_PROVIDER_ENABLED` is false |
| `reason=incomplete-config` | one or more required AI env vars are missing or invalid |
| `reason=sdk-unavailable` | the container runtime does not have Bedrock SDK support available |
| `reason=ready` | local runtime wiring is ready; live AWS invoke still needs valid role/model access |

## Step 9. Confirm CloudWatch Logs

Open:

- `CloudWatch -> Log groups -> <api service log group>`

After sending one AI request, check that logs contain:

- `request_id`
- provider class outcome such as timeout, unavailable, invalid response, or success

Logs must not contain:

- raw AWS credentials
- full prompt text
- full notebook context payload
- secret values from `AWS_APP_SECRET_ARN`

## Step 10. Run the Product Smoke

Once the AWS and health checks are clean:

1. Sign in to the product.
2. Open a synced notebook.
3. Choose a durable `text` block as the AI source.
4. Enter a simple prompt such as:

```text
Write JavaScript code that parses a CSV string into an array of objects.
```

5. Trigger AI generation.
6. Confirm the backend request succeeds.
7. Confirm the generated code is inserted into the next empty `code` block or a newly created `code` block below the source block.
8. Confirm the inserted code remains editable.
9. Run the code block in the notebook runtime.

## Fast Mismatch Checklist

These values must agree across screens:

| Screen | Value that must match |
|---|---|
| Bedrock Model catalog | exact model id |
| Runtime secret | `AI_PROVIDER_MODEL` |
| Console region | `eu-north-1` |
| Runtime secret | `AI_BEDROCK_REGION=eu-north-1` |
| ECS service | correct task definition |
| Task definition | correct task role and `AWS_APP_SECRET_ARN` |
| IAM role | Bedrock invoke + Secrets Manager read permissions |

## Typical Failure Mapping

| Symptom | Most likely problem |
|---|---|
| model not visible in Bedrock | wrong region or model unavailable in region |
| health says `incomplete-config` | wrong or missing secret/env values |
| health says `sdk-unavailable` | container packaging problem |
| AI request returns `503 AI_PROVIDER_UNAVAILABLE` | task role, model access, or outbound connectivity issue |
| AI request returns `504 AI_PROVIDER_TIMEOUT` | provider latency or timeout budget issue |
| frontend flow fails before backend call | auth, sync, or source-block prerequisite issue |

## Suggested Team Workflow

When the team enables AI in a new environment:

1. Verify Bedrock model availability in the target region.
2. Verify ECS service and task definition.
3. Verify the attached task role.
4. Verify the runtime secret.
5. Verify `GET /api/v1/system/health`.
6. Send one real AI request and capture `requestId`.
7. If the request fails, inspect CloudWatch logs using that `requestId`.

This order avoids mixing notebook-level issues with AWS runtime issues.

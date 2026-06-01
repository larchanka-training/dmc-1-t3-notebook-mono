# Terraform infrastructure

This directory contains the AWS infrastructure described in `docs/DevOps-109-specs.md`.

Layout:

- `bootstrap/`: one-time Terraform backend resources. Uses local state only.
- `env/shared/`: shared VPC, ECS cluster, ECR, IAM, Cloud Map, and preview ALB.
- `env/dev/`: optional shared integration environment.
- `env/prod/`: production environment for the `main` branch.
- `env/preview/`: per-PR preview environment (`pr-<number>` state isolation).
- `modules/`: reusable Terraform building blocks.
- `scripts/check_preview_readiness.sh`: verifies whether path-based previews are safe to roll out.

State keys:

- `t3/dmc-1-t3-notebook-mono/shared/terraform.tfstate`
- `t3/dmc-1-t3-notebook-mono/dev/terraform.tfstate`
- `t3/dmc-1-t3-notebook-mono/prod/terraform.tfstate`
- `t3/dmc-1-t3-notebook-mono/previews/pr-<number>/terraform.tfstate`

Preview note:

The preview Terraform root includes the prefix-stripping proxy required by the plan. The current UI still lacks configurable non-root base-path support, so the preview deployment workflow blocks rollout until the application side is ready.

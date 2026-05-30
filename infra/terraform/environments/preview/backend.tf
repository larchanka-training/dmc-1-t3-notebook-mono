# Backend config is passed via -backend-config flags in GitHub Actions.
# This file is intentionally empty — the backend block in main.tf uses "s3" {}
# with no inline config so that -backend-config arguments are accepted at init time.

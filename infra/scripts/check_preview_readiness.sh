#!/usr/bin/env bash

set -euo pipefail

repo_root="${1:-$PWD}"
errors=()

if ! grep -Eq 'VITE_APP_BASE_PATH|APP_BASE_PATH|basename' "$repo_root/ui/src/app/router/AppRouter.tsx" "$repo_root/ui/vite.config.ts" "$repo_root/ui/Dockerfile" 2>/dev/null; then
  errors+=("UI preview base-path support is missing: add configurable basename/build base support before path-based preview rollout.")
fi

if ! grep -Eq 'createBrowserRouter\(routes\)' "$repo_root/ui/src/app/router/AppRouter.tsx"; then
  errors+=("Unexpected router bootstrap shape. Re-check preview readiness guard.")
fi

if ! grep -Eq 'API_V1_STR: str = "/api/v1"' "$repo_root/api/app/core/config.py"; then
  errors+=("Backend /api/v1 contract is not declared as expected.")
fi

if ((${#errors[@]} > 0)); then
  printf 'Preview readiness check failed:\n' >&2
  for error in "${errors[@]}"; do
    printf ' - %s\n' "$error" >&2
  done
  exit 1
fi

printf 'Preview readiness check passed.\n'

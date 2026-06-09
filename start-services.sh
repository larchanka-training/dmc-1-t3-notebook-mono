#!/bin/bash
set -euo pipefail

required_paths=(
  "ui"
  "api"
  "ui/.env"
  "api/.env"
  "proxy/certs/notebook.com.pem"
  "proxy/certs/notebook.com-key.pem"
)

for path in "${required_paths[@]}"; do
  if [[ ! -e "$path" ]]; then
    echo "Missing required path: $path"
    echo "Initialize git submodules, generate local TLS certs, and provide the required .env files before starting."
    exit 1
  fi
done

if [[ -z "$(find ui -mindepth 1 -maxdepth 1 -print -quit 2>/dev/null)" ]]; then
  echo "Submodule directory 'ui' is empty."
  echo "Run: git submodule update --init --recursive"
  exit 1
fi

if [[ -z "$(find api -mindepth 1 -maxdepth 1 -print -quit 2>/dev/null)" ]]; then
  echo "Submodule directory 'api' is empty."
  echo "Run: git submodule update --init --recursive"
  exit 1
fi

echo "Starting project services with Docker Compose..."
docker compose up -d

echo "Services are starting."
echo "Frontend: https://notebook.com:8443"
echo "API: https://api.notebook.com:8443"
echo "pgAdmin: https://pgadmin.notebook.com:8443"

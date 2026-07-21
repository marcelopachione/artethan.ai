#!/usr/bin/env bash
# One-time setup: generates .env with strong secrets and fixes bind-mount
# ownership so the container users (non-root) can write to them.
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")"

# Shared with ../openclaw — safe to run from either stack's init.sh, second
# run is a no-op.
if ! docker network inspect artethan_net >/dev/null 2>&1; then
  docker network create artethan_net
  echo "Created network artethan_net."
else
  echo "Network artethan_net already exists, leaving it untouched."
fi

if [ -f .env ]; then
  echo ".env already exists, leaving it untouched."
else
  cp .env.example .env
  sed -i "s|^N8N_ENCRYPTION_KEY=.*|N8N_ENCRYPTION_KEY=$(openssl rand -base64 32)|" .env
  sed -i "s|^POSTGRES_PASSWORD=.*|POSTGRES_PASSWORD=$(openssl rand -base64 24)|" .env
  sed -i "s|^REDIS_PASSWORD=.*|REDIS_PASSWORD=$(openssl rand -base64 24)|" .env
  echo ".env created with generated secrets."
fi

mkdir -p data/n8n data/postgres data/redis data/files backups

# n8n official image runs as uid/gid 1000 (node)
sudo chown -R 1000:1000 data/n8n data/files

# postgres:16-alpine and redis:7-alpine both run as uid/gid 999
sudo chown -R 999:999 data/postgres
sudo chown -R 999:999 data/redis

echo "Done. Review .env, then run: docker compose up -d"

#!/usr/bin/env bash
# One-time setup: creates the cross-stack network shared with n8n, generates
# .env with a strong gateway token, and fixes bind-mount ownership so the
# container user (non-root) can write to it.
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")"

# Shared with ../n8n — safe to run from either stack's init.sh, second run
# is a no-op.
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
  sed -i "s|^OPENCLAW_GATEWAY_TOKEN=.*|OPENCLAW_GATEWAY_TOKEN=$(openssl rand -base64 32)|" .env
  echo ".env created with a generated gateway token."
  echo "Now edit .env and set OPENROUTER_API_KEY before starting the stack."
fi

mkdir -p data/openclaw backups

# The official image runs as uid/gid 1000 (user "node"), same as n8n's image.
sudo chown -R 1000:1000 data/openclaw

echo "Done. Review .env, then run: docker compose up -d"

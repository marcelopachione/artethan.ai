#!/usr/bin/env bash
# Writes the OpenClaw config (openclaw.json) non-interactively — required
# before the gateway service will start; it refuses to boot with only env
# vars set ("Missing config. Run `openclaw setup`..."). Safe to re-run: it
# just rewrites config/model, taking a .bak each time.
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")"

set -a
source .env
set +a

docker compose run --rm --no-deps openclaw openclaw setup \
  --non-interactive --accept-risk \
  --auth-choice openrouter-api-key \
  --gateway-auth token \
  --gateway-token-ref-env OPENCLAW_GATEWAY_TOKEN \
  --gateway-bind lan \
  --gateway-port 18789 \
  --skip-daemon --skip-ui --skip-channels --skip-search --skip-skills --skip-health

docker compose run --rm --no-deps openclaw openclaw models set "${OPENCLAW_PRIMARY_MODEL:-openrouter/auto}"

docker compose up -d openclaw

echo "Done. docker compose logs -f openclaw to watch it come up."

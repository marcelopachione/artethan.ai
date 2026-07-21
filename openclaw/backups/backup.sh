#!/usr/bin/env bash
# Archives the OpenClaw state dir (config, gateway token, session transcripts,
# cron job definitions, vector embeddings).
# Run manually or via cron, e.g.:
#   0 3 * * * /home/marcelo/workspace/artethan.ai/openclaw/backups/backup.sh >> /home/marcelo/workspace/artethan.ai/openclaw/backups/backup.log 2>&1
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."

TIMESTAMP=$(date +%Y%m%d_%H%M%S)
OUT_DIR="backups"
KEEP_DAYS=14

mkdir -p "$OUT_DIR"

tar -czf "$OUT_DIR/openclaw_data_${TIMESTAMP}.tar.gz" -C data openclaw

find "$OUT_DIR" -name '*.tar.gz' -mtime +"$KEEP_DAYS" -delete

echo "Backup complete: $OUT_DIR/openclaw_data_${TIMESTAMP}.tar.gz"

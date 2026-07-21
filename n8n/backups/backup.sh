#!/usr/bin/env bash
# Dumps Postgres and archives the n8n data dir (encryption key + binary data).
# Run manually or via cron, e.g.:
#   0 3 * * * /home/marcelo/workspace/artethan.ai/n8n/backups/backup.sh >> /home/marcelo/workspace/artethan.ai/n8n/backups/backup.log 2>&1
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."

set -a
source .env
set +a

TIMESTAMP=$(date +%Y%m%d_%H%M%S)
OUT_DIR="backups"
KEEP_DAYS=14

mkdir -p "$OUT_DIR"

docker compose exec -T postgres pg_dump -U "$POSTGRES_USER" "$POSTGRES_DB" \
  | gzip > "$OUT_DIR/postgres_${TIMESTAMP}.sql.gz"

tar -czf "$OUT_DIR/n8n_data_${TIMESTAMP}.tar.gz" -C data n8n

find "$OUT_DIR" -name '*.sql.gz' -mtime +"$KEEP_DAYS" -delete
find "$OUT_DIR" -name '*.tar.gz' -mtime +"$KEEP_DAYS" -delete

echo "Backup complete: $OUT_DIR/postgres_${TIMESTAMP}.sql.gz, $OUT_DIR/n8n_data_${TIMESTAMP}.tar.gz"

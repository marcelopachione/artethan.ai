#!/usr/bin/env bash
# Restores a Postgres dump produced by backup.sh.
# Usage: ./restore.sh backups/postgres_20260720_030000.sql.gz
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."

if [ $# -ne 1 ]; then
  echo "Usage: $0 <path-to-postgres-backup.sql.gz>"
  exit 1
fi

DUMP_FILE="$1"

set -a
source .env
set +a

echo "This will DROP and recreate the '$POSTGRES_DB' database. Ctrl+C to abort."
read -r -p "Type 'yes' to continue: " CONFIRM
[ "$CONFIRM" = "yes" ] || exit 1

docker compose stop n8n n8n-worker

gunzip -c "$DUMP_FILE" | docker compose exec -T postgres psql -U "$POSTGRES_USER" -c "DROP DATABASE IF EXISTS ${POSTGRES_DB}_restoring;"
docker compose exec -T postgres psql -U "$POSTGRES_USER" -c "CREATE DATABASE ${POSTGRES_DB}_restoring;"
gunzip -c "$DUMP_FILE" | docker compose exec -T postgres psql -U "$POSTGRES_USER" -d "${POSTGRES_DB}_restoring"

docker compose exec -T postgres psql -U "$POSTGRES_USER" -c "ALTER DATABASE ${POSTGRES_DB} RENAME TO ${POSTGRES_DB}_old_$(date +%s);"
docker compose exec -T postgres psql -U "$POSTGRES_USER" -c "ALTER DATABASE ${POSTGRES_DB}_restoring RENAME TO ${POSTGRES_DB};"

docker compose start n8n n8n-worker

echo "Restore complete. Old database kept as a safety net; drop it manually once verified."

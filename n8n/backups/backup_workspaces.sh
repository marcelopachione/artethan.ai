#!/usr/bin/env bash
# Exports all n8n workflows as JSON (one file per workflow) and pushes the
# changes to git. No retention/pruning: history lives in git.
# Run manually (pontual): ./backups/backup_workspaces.sh
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."

OUT_DIR="backups/workflows"
CONTAINER_TMP="/tmp/n8n_workflow_export"

mkdir -p "$OUT_DIR"

docker compose exec -T n8n rm -rf "$CONTAINER_TMP"
if ! docker compose exec -T n8n n8n export:workflow --backup --output="$CONTAINER_TMP"; then
  echo "No workflows to export yet."
  exit 0
fi

rm -rf "$OUT_DIR"
docker compose cp "n8n:$CONTAINER_TMP" "$OUT_DIR"
docker compose exec -T n8n rm -rf "$CONTAINER_TMP"

echo "Backup complete: $OUT_DIR/"

git add "$OUT_DIR"
if git diff --cached --quiet -- "$OUT_DIR"; then
  echo "No workflow changes to commit."
else
  git commit -m "chore(n8n): backup workflows $(date +%Y-%m-%d_%H:%M:%S)" -- "$OUT_DIR"
  git push origin master
  echo "Pushed workflow changes to master."
fi

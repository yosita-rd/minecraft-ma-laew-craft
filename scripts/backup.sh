#!/usr/bin/env bash
set -e

REAL_SCRIPT="$(realpath "${BASH_SOURCE[0]}")"
SCRIPT_DIR="$(dirname "$REAL_SCRIPT")"
BASE_DIR="$(dirname "$SCRIPT_DIR")"
BACKUP_DIR="$BASE_DIR/backups"
DATA_DIR="$BASE_DIR/server-data"
CONTAINER_NAME="mc-bedrock-server"

TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
BACKUP_FILE="$BACKUP_DIR/world_$TIMESTAMP.tar.gz"

mkdir -p "$BACKUP_DIR"

echo "=== Starting Minecraft World Backup: $TIMESTAMP ==="

# Check if container is running
IS_RUNNING=false
if docker ps --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
  IS_RUNNING=true
fi

if [ "$IS_RUNNING" = true ]; then
  echo "Flushing world chunks to disk via RCON..."
  docker exec -i "$CONTAINER_NAME" rcon-cli save-off || true
  docker exec -i "$CONTAINER_NAME" rcon-cli save-all flush || true
  sleep 3
else
  echo "Server container is not running. Performing offline archive..."
fi

# Ensure data directories exist
TARGETS=()
for dir in "world" "world_nether" "world_the_end"; do
  if [ -d "$DATA_DIR/$dir" ]; then
    TARGETS+=("$dir")
  fi
done

if [ ${#TARGETS[@]} -eq 0 ]; then
  echo "Warning: No world directories found in $DATA_DIR to back up."
  if [ "$IS_RUNNING" = true ]; then
    docker exec -i "$CONTAINER_NAME" rcon-cli save-on || true
  fi
  exit 0
fi

echo "Compressing world folders: ${TARGETS[*]}..."
tar -czf "$BACKUP_FILE" -C "$DATA_DIR" "${TARGETS[@]}"

if [ "$IS_RUNNING" = true ]; then
  echo "Re-enabling world auto-save..."
  docker exec -i "$CONTAINER_NAME" rcon-cli save-on || true
fi

# Retention policy: remove backups older than 7 days
echo "Applying retention policy (keeping last 7 days)..."
find "$BACKUP_DIR" -type f -name "world_*.tar.gz" -mtime +7 -delete

SIZE=$(du -h "$BACKUP_FILE" | cut -f1)
echo "=== Backup completed successfully! ==="
echo "File: $BACKUP_FILE"
echo "Size: $SIZE"

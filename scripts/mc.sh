#!/usr/bin/env bash
set -e

# Base directory determination
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASE_DIR="$(dirname "$SCRIPT_DIR")"
cd "$BASE_DIR"

CONTAINER_NAME="mc-bedrock-server"

function usage() {
  echo "============================================================"
  echo " Minecraft Hybrid Server Management CLI (mc)"
  echo "============================================================"
  echo "Usage: mc <command> [arguments]"
  echo ""
  echo "Commands:"
  echo "  start             Start the Minecraft server container"
  echo "  stop              Stop the Minecraft server safely"
  echo "  restart           Restart the server container"
  echo "  logs              Follow live server console logs (Ctrl+C to exit)"
  echo "  cmd <command>     Execute an in-game command via RCON"
  echo "                    Example: mc cmd op PlayerName"
  echo "                    Example: mc cmd say Hello World"
  echo "  status            Show container CPU/RAM resource usage"
  echo "  backup            Trigger an immediate zero-downtime world backup"
  echo "  restore <file>    Safely restore world from a backup tar.gz archive"
  echo "  update            Pull latest image updates and recreate container"
  echo "============================================================"
}

case "$1" in
  start)
    echo "Starting Minecraft server..."
    docker compose up -d
    ;;
  stop)
    echo "Stopping Minecraft server gracefully..."
    docker compose stop
    ;;
  restart)
    echo "Restarting Minecraft server..."
    docker compose restart
    ;;
  logs)
    docker compose logs -f minecraft
    ;;
  cmd)
    shift
    if [ -z "$1" ]; then
      echo "Error: No command provided to 'mc cmd'."
      echo "Example: mc cmd list"
      exit 1
    fi
    docker exec -i "$CONTAINER_NAME" rcon-cli "$@"
    ;;
  status)
    echo "--- Container Status ---"
    docker stats --no-stream "$CONTAINER_NAME"
    echo ""
    echo "--- Online Players ---"
    docker exec -i "$CONTAINER_NAME" rcon-cli list 2>/dev/null || echo "Server is offline or starting up."
    ;;
  backup)
    "$SCRIPT_DIR/backup.sh"
    ;;
  restore)
    shift
    if [ -z "$1" ]; then
      echo "Error: Please specify the backup file path to restore."
      echo "Example: mc restore backups/world_20261002_120000.tar.gz"
      exit 1
    fi
    RESTORE_FILE="$1"
    if [ ! -f "$RESTORE_FILE" ]; then
      echo "Error: File not found: $RESTORE_FILE"
      exit 1
    fi
    read -p "Are you sure you want to overwrite current world data with '$RESTORE_FILE'? (y/N): " CONFIRM
    if [[ "$CONFIRM" =~ ^[Yy]$ ]]; then
      echo "Stopping server before restore..."
      docker compose stop
      echo "Extracting backup..."
      tar -xzf "$RESTORE_FILE" -C "$BASE_DIR/server-data/"
      echo "Starting server..."
      docker compose up -d
      echo "World successfully restored."
    else
      echo "Restore aborted."
    fi
    ;;
  update)
    echo "Pulling updated Docker image..."
    docker compose pull
    echo "Recreating container..."
    docker compose up -d
    echo "Update complete."
    ;;
  *)
    usage
    exit 1
    ;;
esac

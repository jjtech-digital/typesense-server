#!/bin/sh
#
# Typesense Backup Script
#
# Usage:
#   backup.sh [label]          - Create a snapshot with optional label
#   backup.sh --cleanup [days] - Remove backups older than N days (default: 7)
#   backup.sh --list           - List existing backups
#
# Backups use Typesense's built-in /operations/snapshot API which creates
# a consistent point-in-time snapshot of all data.

set -e

TYPESENSE_HOST="http://127.0.0.1:8118"
TYPESENSE_DATA="${TYPESENSE_DATA_DIR:-/data}"
BACKUP_DIR="${TYPESENSE_DATA}/backups"
RETENTION_DAYS="${BACKUP_RETENTION_DAYS:-7}"
MAX_BACKUPS="${BACKUP_MAX_COUNT:-10}"

# Ensure backup directory exists
mkdir -p "$BACKUP_DIR"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

create_snapshot() {
    LABEL="${1:-manual}"
    TIMESTAMP=$(date '+%Y%m%d_%H%M%S')
    SNAPSHOT_NAME="${LABEL}_${TIMESTAMP}"
    SNAPSHOT_PATH="${BACKUP_DIR}/${SNAPSHOT_NAME}"

    log "Creating snapshot: $SNAPSHOT_NAME"

    # Use Typesense's snapshot API for consistent backup
    RESPONSE=$(curl -sf -X POST \
        "${TYPESENSE_HOST}/operations/snapshot?snapshot_path=${SNAPSHOT_PATH}" \
        -H "X-TYPESENSE-API-KEY: ${TYPESENSE_API_KEY}" \
        2>&1) || {
        log "ERROR: Snapshot API call failed. Is Typesense running?"
        log "Response: $RESPONSE"
        return 1
    }

    # Verify snapshot was created
    if [ -d "$SNAPSHOT_PATH" ]; then
        SNAPSHOT_SIZE=$(du -sh "$SNAPSHOT_PATH" 2>/dev/null | cut -f1)
        log "Snapshot created successfully: $SNAPSHOT_PATH ($SNAPSHOT_SIZE)"
    else
        log "WARNING: Snapshot API returned success but directory not found at $SNAPSHOT_PATH"
        return 1
    fi

    # Enforce max backup count
    enforce_max_backups

    log "Backup completed: $SNAPSHOT_NAME"
}

enforce_max_backups() {
    BACKUP_COUNT=$(ls -1d "$BACKUP_DIR"/*/ 2>/dev/null | wc -l)
    if [ "$BACKUP_COUNT" -gt "$MAX_BACKUPS" ]; then
        EXCESS=$((BACKUP_COUNT - MAX_BACKUPS))
        log "Removing $EXCESS old backup(s) to stay within limit of $MAX_BACKUPS..."
        ls -1dt "$BACKUP_DIR"/*/ 2>/dev/null | tail -n "$EXCESS" | while read -r OLD_BACKUP; do
            log "Removing: $OLD_BACKUP"
            rm -rf "$OLD_BACKUP"
        done
    fi
}

cleanup_old_backups() {
    DAYS="${1:-$RETENTION_DAYS}"
    log "Cleaning up backups older than $DAYS days..."

    REMOVED=0
    find "$BACKUP_DIR" -mindepth 1 -maxdepth 1 -type d -mtime "+${DAYS}" | while read -r OLD_BACKUP; do
        log "Removing: $OLD_BACKUP"
        rm -rf "$OLD_BACKUP"
        REMOVED=$((REMOVED + 1))
    done

    log "Cleanup complete."
}

list_backups() {
    log "Existing backups in $BACKUP_DIR:"
    if [ -z "$(ls -A "$BACKUP_DIR" 2>/dev/null)" ]; then
        log "  (none)"
        return
    fi
    ls -1dt "$BACKUP_DIR"/*/ 2>/dev/null | while read -r BACKUP; do
        SIZE=$(du -sh "$BACKUP" 2>/dev/null | cut -f1)
        NAME=$(basename "$BACKUP")
        echo "  $NAME  ($SIZE)"
    done
}

# --- Main ---
case "${1:-}" in
    --cleanup)
        cleanup_old_backups "${2:-}"
        ;;
    --list)
        list_backups
        ;;
    *)
        create_snapshot "${1:-manual}"
        ;;
esac

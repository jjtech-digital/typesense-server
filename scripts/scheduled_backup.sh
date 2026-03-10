#!/bin/sh
#
# Scheduled Backup Runner
#
# Runs periodic backups in the background. Started by start.sh if
# BACKUP_ENABLED=true is set in environment.
#
# Environment variables:
#   BACKUP_ENABLED          - Set to "true" to enable (default: false)
#   BACKUP_INTERVAL_HOURS   - Hours between backups (default: 6)
#   BACKUP_RETENTION_DAYS   - Days to keep old backups (default: 7)
#   BACKUP_MAX_COUNT        - Maximum number of backups to keep (default: 10)

set -e

INTERVAL_HOURS="${BACKUP_INTERVAL_HOURS:-6}"
INTERVAL_SECONDS=$((INTERVAL_HOURS * 3600))

log() {
    echo "[backup-scheduler] [$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

log "Scheduled backup enabled. Interval: every ${INTERVAL_HOURS}h, Retention: ${BACKUP_RETENTION_DAYS:-7} days, Max: ${BACKUP_MAX_COUNT:-10} backups"

# Wait for Typesense to be ready before first backup
log "Waiting for Typesense to become ready..."
RETRIES=0
MAX_RETRIES=30
while [ $RETRIES -lt $MAX_RETRIES ]; do
    if curl -sf http://127.0.0.1:8118/health >/dev/null 2>&1; then
        log "Typesense is ready."
        break
    fi
    RETRIES=$((RETRIES + 1))
    sleep 5
done

if [ $RETRIES -eq $MAX_RETRIES ]; then
    log "ERROR: Typesense did not become ready within $((MAX_RETRIES * 5)) seconds. Exiting backup scheduler."
    exit 1
fi

# Run backup loop
while true; do
    log "Sleeping ${INTERVAL_HOURS}h until next backup..."
    sleep "$INTERVAL_SECONDS"

    log "Starting scheduled backup..."
    /bin/sh backup.sh "scheduled" || log "WARNING: Scheduled backup failed."

    # Cleanup old backups
    /bin/sh backup.sh --cleanup || log "WARNING: Backup cleanup failed."
done

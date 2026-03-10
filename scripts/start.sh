#!/bin/sh
set -e

BACKUP_PID=""

# --- API Key Validation ---
if [ -z "$TYPESENSE_API_KEY" ] || [ "$TYPESENSE_API_KEY" = "CHANGE_ME_GENERATE_A_SECURE_KEY" ]; then
    echo "ERROR: TYPESENSE_API_KEY is not set or is using the placeholder value."
    echo "Please set a strong, unique API key before starting the server."
    exit 1
fi

if [ ${#TYPESENSE_API_KEY} -lt 32 ]; then
    echo "WARNING: TYPESENSE_API_KEY is shorter than 32 characters. Consider using a stronger key."
fi

# --- Fix ownership on the mounted volume (mounted as root at runtime) ---
chown -R typesense:typesense /data

# --- Ensure backup directory exists ---
mkdir -p /data/backups
chown typesense:typesense /data/backups

# --- Signal handling for graceful shutdown ---
cleanup() {
    echo "Received shutdown signal. Stopping services gracefully..."

    # Take a pre-shutdown snapshot if Typesense is running
    if kill -0 "$TYPESENSE_PID" 2>/dev/null; then
        echo "Taking pre-shutdown snapshot..."
        gosu typesense /bin/sh backup.sh pre-shutdown 2>/dev/null || true
    fi

    kill "$CADDY_PID" "$TYPESENSE_PID" ${BACKUP_PID:+"$BACKUP_PID"} 2>/dev/null || true
    wait "$CADDY_PID" "$TYPESENSE_PID" ${BACKUP_PID:+"$BACKUP_PID"} 2>/dev/null || true
    echo "All services stopped."
    exit 0
}

trap cleanup TERM INT QUIT

# --- Run both services as non-root user ---
gosu typesense ./start_caddy.sh &
CADDY_PID=$!

gosu typesense ./start_typesense.sh &
TYPESENSE_PID=$!

echo "Caddy started (PID: $CADDY_PID)"
echo "Typesense started (PID: $TYPESENSE_PID)"

# --- Optional: Start scheduled backup ---
if [ "${BACKUP_ENABLED:-false}" = "true" ]; then
    gosu typesense /bin/sh scheduled_backup.sh &
    BACKUP_PID=$!
    echo "Backup scheduler started (PID: $BACKUP_PID)"
fi

# Wait for either process to exit, then stop all
wait -n 2>/dev/null || wait
echo "A service exited unexpectedly. Shutting down..."
cleanup

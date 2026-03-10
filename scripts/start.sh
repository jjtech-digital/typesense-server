#!/bin/sh

# Fix ownership on the mounted volume (mounted as root at runtime)
chown -R typesense:typesense /data

# Run both services as non-root user
gosu typesense ./start_caddy.sh &
gosu typesense ./start_typesense.sh &

# Wait for either process to exit, then stop all
wait -n 2>/dev/null || wait
kill 0

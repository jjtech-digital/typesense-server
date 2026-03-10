#!/bin/sh

TYPESENSE_DATA="${TYPESENSE_DATA_DIR:-/data}"

# Ensure data directory exists and is writable
if [ ! -d "$TYPESENSE_DATA" ]; then
    echo "ERROR: Data directory $TYPESENSE_DATA does not exist."
    exit 1
fi

if [ ! -w "$TYPESENSE_DATA" ]; then
    echo "ERROR: Data directory $TYPESENSE_DATA is not writable."
    exit 1
fi

exec /opt/typesense-server \
    --data-dir="$TYPESENSE_DATA" \
    --api-key="${TYPESENSE_API_KEY}" \
    --api-address 127.0.0.1 \
    --api-port 8118 \
    --enable-cors \
    --enable-search-analytics=true \
    --analytics-flush-interval=60

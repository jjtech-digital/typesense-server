#!/bin/sh

exec /opt/typesense-server \
    --data-dir="${TYPESENSE_DATA_DIR:-/data}" \
    --api-key="${TYPESENSE_API_KEY}" \
    --api-address 127.0.0.1 \
    --api-port 8118 \
    --enable-cors \
    --enable-search-analytics=true \
    --analytics-flush-interval=60
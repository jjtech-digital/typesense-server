#!/bin/sh

./start_caddy.sh &
./start_typesense.sh &

# Wait for either process to exit, then stop all
wait -n 2>/dev/null || wait
kill 0

#!/bin/bash
set -e

# Run initial sync if INITIAL_SYNC is set to true
if [ "${INITIAL_SYNC:-false}" = "true" ]; then
  echo "Running initial sync..."
  /usr/local/bin/sync-script.sh
fi

# Start cron daemon
exec "$@"

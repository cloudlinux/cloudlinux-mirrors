#!/bin/bash
set -e

# Update repository configuration if REPOS environment variable is set
if [ -n "$REPOS" ]; then
  echo "Using repositories: $REPOS"
fi

# Run initial sync if INITIAL_SYNC is set to true
if [ "${INITIAL_SYNC:-false}" = "true" ]; then
  echo "Running initial sync..."
  if ! /usr/local/bin/sync-script.sh; then
    echo "Initial sync failed; continuing to cron for retries."
  fi
fi

# Start cron daemon
exec "$@"

#!/bin/bash
set -e

SYNC_MODE="${SYNC_MODE:-combined}"

# Update cron job based on SYNC_MODE
if [ "$SYNC_MODE" = "separate" ]; then
  echo "Setting up separate sync mode..."
  {
    echo "0 */4 * * * /usr/local/bin/sync-cloudlinux.sh >> /var/log/cloudlinux-mirror.log 2>&1"
    echo "0 2,6,10,14,18,22 * * * /usr/local/bin/sync-swng.sh >> /var/log/swng-mirror.log 2>&1"
  } | crontab -
else
  echo "Setting up combined sync mode..."
  echo "0 */4 * * * /usr/local/bin/sync-combined.sh >> /var/log/combined-mirror.log 2>&1" | crontab -
fi

# Run initial sync if INITIAL_SYNC is set to true
if [ "${INITIAL_SYNC:-false}" = "true" ]; then
  echo "Running initial sync..."
  if [ "$SYNC_MODE" = "separate" ]; then
    /usr/local/bin/sync-cloudlinux.sh &
    /usr/local/bin/sync-swng.sh &
    wait
  else
    /usr/local/bin/sync-combined.sh
  fi
fi

# Start cron daemon
exec "$@"

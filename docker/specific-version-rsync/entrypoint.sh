#!/bin/bash
set -e

# Validate CloudLinux version
if [ -z "$CLOUDLINUX_VERSION" ]; then
  echo "Error: CLOUDLINUX_VERSION environment variable is required"
  exit 1
fi

if [ "$CLOUDLINUX_VERSION" != "8" ] && [ "$CLOUDLINUX_VERSION" != "9" ]; then
  echo "Error: CLOUDLINUX_VERSION must be 8 or 9"
  exit 1
fi

# Update RSync source and paths based on version
export RSYNC_SOURCE="rsync://rsync.upstream.cloudlinux.com/SWNG/${CLOUDLINUX_VERSION}/"
export MIRROR_PATH="/var/www/mirrors/swng/${CLOUDLINUX_VERSION}"
export LOG_FILE="/var/log/swng-${CLOUDLINUX_VERSION}-mirror.log"

# Run initial sync if INITIAL_SYNC is set to true
if [ "${INITIAL_SYNC:-false}" = "true" ]; then
  echo "Running initial sync for CloudLinux ${CLOUDLINUX_VERSION}..."
  /usr/local/bin/sync-script.sh
fi

# Start cron daemon
exec "$@"

#!/bin/bash
# SWNG Version-Specific Mirror Sync Script

CLOUDLINUX_VERSION="${CLOUDLINUX_VERSION:-9}"
RSYNC_SOURCE="${RSYNC_SOURCE:-rsync://rsync.upstream.cloudlinux.com/SWNG/${CLOUDLINUX_VERSION}/}"
MIRROR_PATH="${MIRROR_PATH:-/var/www/mirrors/swng/${CLOUDLINUX_VERSION}}"
LOG_FILE="${LOG_FILE:-/var/log/swng-${CLOUDLINUX_VERSION}-mirror.log}"

# Create mirror directory if it doesn't exist
mkdir -p "$MIRROR_PATH"

echo "$(date): Starting SWNG CloudLinux ${CLOUDLINUX_VERSION} mirror sync" >> "$LOG_FILE"

rsync -av --delete \
  --progress \
  "$RSYNC_SOURCE" \
  "$MIRROR_PATH/" >> "$LOG_FILE" 2>&1

SYNC_EXIT_CODE=$?

if [ $SYNC_EXIT_CODE -eq 0 ]; then
  echo "$(date): SWNG CloudLinux ${CLOUDLINUX_VERSION} mirror sync completed successfully" >> "$LOG_FILE"
else
  echo "$(date): SWNG CloudLinux ${CLOUDLINUX_VERSION} mirror sync failed with exit code $SYNC_EXIT_CODE" >> "$LOG_FILE"
fi

exit $SYNC_EXIT_CODE

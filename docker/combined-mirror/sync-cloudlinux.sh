#!/bin/bash
# CloudLinux Mirror Sync Script

RSYNC_SOURCE="${CLOUDLINUX_RSYNC_SOURCE:-rsync://rsync.upstream.cloudlinux.com/CLOUDLINUX/}"
MIRROR_PATH="${CLOUDLINUX_MIRROR_PATH:-/var/www/mirrors/cloudlinux}"
LOG_FILE="${CLOUDLINUX_LOG_FILE:-/var/log/cloudlinux-mirror.log}"

echo "$(date): Starting CloudLinux mirror sync" >> "$LOG_FILE"

rsync -av --delete \
  --progress \
  "$RSYNC_SOURCE" \
  "$MIRROR_PATH/" >> "$LOG_FILE" 2>&1

SYNC_EXIT_CODE=$?

if [ $SYNC_EXIT_CODE -eq 0 ]; then
  echo "$(date): CloudLinux mirror sync completed successfully" >> "$LOG_FILE"
else
  echo "$(date): CloudLinux mirror sync failed with exit code $SYNC_EXIT_CODE" >> "$LOG_FILE"
fi

exit $SYNC_EXIT_CODE

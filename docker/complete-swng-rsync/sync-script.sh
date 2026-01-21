#!/bin/bash
# SWNG Mirror Sync Script

RSYNC_SOURCE="${RSYNC_SOURCE:-rsync://rsync.upstream.cloudlinux.com/SWNG/}"
MIRROR_PATH="${MIRROR_PATH:-/var/www/mirrors/swng}"
LOG_FILE="${LOG_FILE:-/var/log/swng-mirror.log}"

echo "$(date): Starting SWNG mirror sync" >> "$LOG_FILE"

rsync -av --delete \
  --progress \
  "$RSYNC_SOURCE" \
  "$MIRROR_PATH/" >> "$LOG_FILE" 2>&1

SYNC_EXIT_CODE=$?

if [ $SYNC_EXIT_CODE -eq 0 ]; then
  echo "$(date): SWNG mirror sync completed successfully" >> "$LOG_FILE"
else
  echo "$(date): SWNG mirror sync failed with exit code $SYNC_EXIT_CODE" >> "$LOG_FILE"
fi

exit $SYNC_EXIT_CODE

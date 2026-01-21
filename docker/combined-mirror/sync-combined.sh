#!/bin/bash
# Combined CloudLinux and SWNG Mirror Sync Script

CLOUDLINUX_RSYNC_SOURCE="${CLOUDLINUX_RSYNC_SOURCE:-rsync://rsync.upstream.cloudlinux.com/CLOUDLINUX/}"
SWNG_RSYNC_SOURCE="${SWNG_RSYNC_SOURCE:-rsync://rsync.upstream.cloudlinux.com/SWNG/}"
CLOUDLINUX_MIRROR_PATH="${CLOUDLINUX_MIRROR_PATH:-/var/www/mirrors/cloudlinux}"
SWNG_MIRROR_PATH="${SWNG_MIRROR_PATH:-/var/www/mirrors/swng}"
LOG_FILE="${COMBINED_LOG_FILE:-/var/log/combined-mirror.log}"

echo "$(date): Starting combined CloudLinux and SWNG mirror sync" >> "$LOG_FILE"

# Sync CloudLinux first
echo "$(date): Syncing CloudLinux repository..." >> "$LOG_FILE"
rsync -av --delete \
  --progress \
  "$CLOUDLINUX_RSYNC_SOURCE" \
  "$CLOUDLINUX_MIRROR_PATH/" >> "$LOG_FILE" 2>&1

CLOUDLINUX_EXIT_CODE=$?

if [ $CLOUDLINUX_EXIT_CODE -eq 0 ]; then
  echo "$(date): CloudLinux mirror sync completed successfully" >> "$LOG_FILE"
else
  echo "$(date): CloudLinux mirror sync failed with exit code $CLOUDLINUX_EXIT_CODE" >> "$LOG_FILE"
fi

# Sync SWNG
echo "$(date): Syncing SWNG repository..." >> "$LOG_FILE"
rsync -av --delete \
  --progress \
  "$SWNG_RSYNC_SOURCE" \
  "$SWNG_MIRROR_PATH/" >> "$LOG_FILE" 2>&1

SWNG_EXIT_CODE=$?

if [ $SWNG_EXIT_CODE -eq 0 ]; then
  echo "$(date): SWNG mirror sync completed successfully" >> "$LOG_FILE"
else
  echo "$(date): SWNG mirror sync failed with exit code $SWNG_EXIT_CODE" >> "$LOG_FILE"
fi

# Overall status
if [ $CLOUDLINUX_EXIT_CODE -eq 0 ] && [ $SWNG_EXIT_CODE -eq 0 ]; then
  echo "$(date): Combined mirror sync completed successfully" >> "$LOG_FILE"
  exit 0
else
  echo "$(date): Combined mirror sync completed with errors" >> "$LOG_FILE"
  exit 1
fi

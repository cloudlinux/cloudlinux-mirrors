#!/bin/bash
# SWNG Mirror Sync Script using reposync

MIRROR_PATH="${MIRROR_PATH:-/var/www/mirrors/swng}"
LOG_FILE="${LOG_FILE:-/var/log/swng-reposync.log}"
REPOS="${REPOS:-SWNG-9-x86_64 SWNG-8-x86_64}"

echo "$(date): Starting SWNG mirror sync with reposync" >> "$LOG_FILE"

# Build reposync command
REPOSYNC_CMD="reposync -p $MIRROR_PATH/"
for repo in $REPOS; do
  REPOSYNC_CMD="$REPOSYNC_CMD -r $repo"
done

# Run reposync
$REPOSYNC_CMD >> "$LOG_FILE" 2>&1
REPOSYNC_EXIT_CODE=$?

if [ $REPOSYNC_EXIT_CODE -eq 0 ]; then
  echo "$(date): Repository sync completed successfully" >> "$LOG_FILE"
  
  # Update repository metadata
  echo "$(date): Updating repository metadata..." >> "$LOG_FILE"
  for repo in $REPOS; do
    if [ -d "$MIRROR_PATH/$repo" ]; then
      createrepo "$MIRROR_PATH/$repo/" >> "$LOG_FILE" 2>&1
    fi
  done
  
  echo "$(date): SWNG mirror sync completed successfully" >> "$LOG_FILE"
else
  echo "$(date): SWNG mirror sync failed with exit code $REPOSYNC_EXIT_CODE" >> "$LOG_FILE"
fi

exit $REPOSYNC_EXIT_CODE

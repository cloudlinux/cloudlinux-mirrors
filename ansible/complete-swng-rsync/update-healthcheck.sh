#!/bin/bash
# Updates the /healthcheck endpoint timestamp so the CloudLinux cl-mirrors
# mirrorservice can verify this mirror is fresh.
# Called by the sync service unit's ExecStartPost after a successful run.
#
# Required by: https://repo.cloudlinux.com/cloudlinux/mirrorlists/cl-mirrors
# Format: line "<name> | Status: OK | YYYY/MM/DD HH:MM:SS" with timestamp <= 12h old.

set -eu

SOURCE_NAME="${1:-swng.cloudlinux.com}"
STATUS="${2:-OK}"
HEALTHCHECK_FILE="${HEALTHCHECK_FILE:-/var/www/healthcheck.html}"
NOW=$(date -u '+%Y/%m/%d %H:%M:%S')

mkdir -p "$(dirname "$HEALTHCHECK_FILE")"
cat > "$HEALTHCHECK_FILE" <<HTML
<html><body>
<strong>Last healthcheck update:</strong> $NOW UTC<br />
<h3>Sync status</h3>
$SOURCE_NAME | Status: $STATUS | $NOW <br />
</body></html>
HTML

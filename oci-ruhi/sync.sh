#!/bin/bash

set -e

# =====================
# Configurable Host Name
DOCKER_HOST_NAME="oci-ruhi"
# =====================

# Derived Paths
SRC_DIR="/opt/stacks/"
GIT_ROOT="/opt/homelab2.0"
DEST_DIR="$GIT_ROOT/$DOCKER_HOST_NAME/stacks/"
INCLUDE_FILE="$GIT_ROOT/$DOCKER_HOST_NAME/rsync-include-file.txt"
LOKI_URL="http://oci-nj.dragnet.in:3100/loki/api/v1/push"
LABELS="{ \"job\": \"homelab2.0-sync\", \"host\": \"$DOCKER_HOST_NAME\" }"

# Capture current IST timestamp
IST_TIME=$(TZ=Asia/Kolkata date "+%Y-%m-%d %H:%M:%S IST")
LOG_BUFFER=""

log() {
    echo "$1"
    LOG_BUFFER+="$1"$'\n'
}

log "[+] [$IST_TIME] [$DOCKER_HOST_NAME] Starting sync..."

# Rsync operation
RSYNC_OUTPUT=$(/usr/bin/rsync -av --delete --include-from="$INCLUDE_FILE" "$SRC_DIR" "$DEST_DIR" 2>&1)
log "[+] Rsync complete."
log "$RSYNC_OUTPUT"

# Git operations
cd "$GIT_ROOT"

log "[+] Pulling latest changes from origin..."
git pull --rebase || log "[!] Warning: git pull failed or conflicted"

if [[ -n $(git status --porcelain "$DOCKER_HOST_NAME/") ]]; then
    log "[+] Changes detected in $DOCKER_HOST_NAME/. Committing to Git..."
    git add "$DOCKER_HOST_NAME/"
    COMMIT_MSG="[$DOCKER_HOST_NAME] Auto-sync: Rsynced changes at $IST_TIME"
    git commit -m "$COMMIT_MSG"
    git push
    log "[✓] Git commit and push done: $COMMIT_MSG"
else
    log "[✓] No Git changes to commit in $DOCKER_HOST_NAME/."
fi

# Push logs to Loki
TIMESTAMP_NS=$(($(date +%s) * 1000000000))  # Convert to nanoseconds
ESCAPED_LOG=$(echo "$LOG_BUFFER" | sed ':a;N;$!ba;s/\n/\\n/g' | sed 's/"/\\"/g')

JSON_PAYLOAD=$(cat <<EOF
{
  "streams": [
    {
      "stream": $LABELS,
      "values": [
        ["$TIMESTAMP_NS", "$ESCAPED_LOG"]
      ]
    }
  ]
}
EOF
)

curl -s -X POST -H "Content-Type: application/json" -d "$JSON_PAYLOAD" "$LOKI_URL" || log "[!] Failed to push logs to Loki."

log "[✓] [$DOCKER_HOST_NAME] Script completed."

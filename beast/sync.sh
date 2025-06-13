#!/bin/bash

set -e

# Constants
SRC_DIR="/opt/stacks/"
DEST_DIR="/opt/homelab2.0/beast/stacks/"
INCLUDE_FILE="/opt/homelab2.0/beast/rsync-include-file.txt"
GIT_ROOT="/opt/homelab2.0"
LOKI_URL="http://10.0.0.25:3100/loki/api/v1/push"
LABELS='{job="homelab2.0-sync-beast"}'

# Capture start time and prepare log buffer
IST_TIME=$(TZ=Asia/Kolkata date "+%Y-%m-%d %H:%M:%S IST")
LOG_BUFFER=""

log() {
    echo "$1"
    LOG_BUFFER+="$1"$'\n'
}

# Begin sync
log "[+] [$IST_TIME] Starting sync..."

RSYNC_OUTPUT=$(/usr/bin/rsync -av --delete --include-from="$INCLUDE_FILE" "$SRC_DIR" "$DEST_DIR" 2>&1)
log "[+] Rsync complete."
log "$RSYNC_OUTPUT"

# Git operations
cd "$GIT_ROOT"
if [[ -n $(git status --porcelain) ]]; then
    log "[+] Changes detected. Committing to Git..."
    git add .
    COMMIT_MSG="Auto-sync: Rsynced changes at $IST_TIME"
    git commit -m "$COMMIT_MSG"
    git push
    log "[✓] Git commit and push done: $COMMIT_MSG"
else
    log "[✓] No Git changes to commit."
fi

# Push log to Loki
TIMESTAMP_NS=$(($(date +%s%N)))  # current timestamp in nanoseconds

LokiPayload=$(cat <<EOF
{
  "streams": [
    {
      "stream": $LABELS,
      "values": [
        ["$TIMESTAMP_NS", "$(echo "$LOG_BUFFER" | sed ':a;N;$!ba;s/\n/\\n/g')"]
      ]
    }
  ]
}
EOF
)

curl -s -X POST -H "Content-Type: application/json" -d "$LokiPayload" "$LOKI_URL" >/dev/null || log "[!] Failed to push logs to Loki."

log "[✓] Script completed."

#!/bin/bash

set -e

# Paths
SRC_DIR="/opt/stacks/"
DEST_DIR="/opt/homelab2.0/beast/stacks/"
INCLUDE_FILE="/opt/homelab2.0/beast/rsync-include-file.txt"
GIT_ROOT="/opt/homelab2.0"

# Rsync with delete and include filter
echo "[+] Syncing files..."
rsync -av --delete --include-from="$INCLUDE_FILE" "$SRC_DIR" "$DEST_DIR"

# Change to git repo root
cd "$GIT_ROOT"

# Check for git changes
if [[ -n $(git status --porcelain) ]]; then
    echo "[+] Changes detected. Committing..."

    # Timestamp in IST (Asia/Kolkata)
    IST_TIME=$(TZ=Asia/Kolkata date "+%Y-%m-%d %H:%M:%S IST")

    # Git operations
    git add .
    git commit -m "Auto-sync: Rsynced changes at $IST_TIME"
    git push

    echo "[✓] Changes committed and pushed."
else
    echo "[✓] No changes to commit."
fi

#!/bin/bash
# Restore claude-squad tmux sessions after a system reboot.
#
# After a reboot, tmux sessions are gone but claude-squad's state.json
# and git worktrees remain on disk. This script recreates the tmux
# sessions so claude-squad can reconnect to them.
#
# Run this BEFORE launching cs (claude-squad).

set -euo pipefail

STATE_FILE="$HOME/.claude-squad/state.json"

if [[ ! -f "$STATE_FILE" ]]; then
    echo "ERROR: $STATE_FILE not found"; exit 1
fi

COUNT=$(jq '.instances | length' "$STATE_FILE")
[[ "$COUNT" -eq 0 ]] && echo "No instances to restore." && exit 0

echo "Found ${COUNT} instance(s)."
echo ""

for i in $(seq 0 $((COUNT - 1))); do
    TITLE=$(jq -r ".instances[$i].title" "$STATE_FILE")
    STATUS=$(jq -r ".instances[$i].status" "$STATE_FILE")
    PROGRAM=$(jq -r ".instances[$i].program" "$STATE_FILE")
    SESSION_NAME=$(jq -r ".instances[$i].worktree.session_name" "$STATE_FILE")
    WORKTREE_PATH=$(jq -r ".instances[$i].worktree.worktree_path" "$STATE_FILE")
    TMUX_SESSION="claudesquad_$(echo "$SESSION_NAME" | tr '.' '_')"

    # Paused instances have their worktree removed; nothing to restore
    if [[ "$STATUS" -eq 3 ]]; then
        echo "[$TITLE] SKIP (paused)"; continue
    fi

    # Worktree directory must exist on disk
    if [[ ! -d "$WORKTREE_PATH" ]]; then
        echo "[$TITLE] SKIP (worktree missing: $WORKTREE_PATH)"; continue
    fi

    # Session already running (e.g. cs crashed but tmux survived)
    if tmux has-session -t "$TMUX_SESSION" 2>/dev/null; then
        echo "[$TITLE] SKIP (tmux session already exists)"; continue
    fi

    eval "tmux new-session -d -s \"$TMUX_SESSION\" -c \"$WORKTREE_PATH\" \"${PROGRAM} --continue\""
    tmux set-option -t "$TMUX_SESSION" history-limit 10000 2>/dev/null || true
    tmux set-option -t "$TMUX_SESSION" mouse on 2>/dev/null || true
    echo "[$TITLE] OK → $TMUX_SESSION"
done

echo ""
echo "Done. Run cs to reconnect."

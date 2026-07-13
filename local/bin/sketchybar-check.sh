#!/bin/bash
# SketchyBar Health Check
# Starts sketchybar directly with nohup (avoid launchd — macOS 26.x breaks process naming).
# Waits for external disk to be available before proceeding.

export PATH="/opt/homebrew/bin:$PATH"
LOG_FILE="/tmp/sketchybar_check.log"
LOCK_DIR="/tmp/sketchybar_check.lock"
SB_APP="$HOME/Applications/sketchybar-protected.app"
SB_BIN="$SB_APP/Contents/MacOS/sketchybar"
SB_CONFIG="$HOME/.config/sketchybar/sketchybarrc"
ERR_LOG="/tmp/sketchybar_start_err.log"
DISK_PATH="/Volumes/m2/Usuarios"
LOCK_TIMEOUT=30
RUN_DIR="$HOME/.local/run"
mkdir -p "$RUN_DIR" && chmod 700 "$RUN_DIR"

# --- Wait for external disk ---
/usr/local/bin/disk-ready.sh "$DISK_PATH" 30 || {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] External disk not ready, skipping" >> "$LOG_FILE"
    exit 1
}

# --- Lock: mkdir is atomic — only one process gets the lock ---
if ! mkdir "$LOCK_DIR" 2>/dev/null; then
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] SKIP: lock owned by another process" >> "$LOG_FILE"
    exit 0
fi
trap 'rm -rf "$LOCK_DIR" "$ERR_LOG"' EXIT

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$LOG_FILE"
}

# --- Main ---

# Check if already running and healthy
SB_PID="$(pgrep -x sketchybar | head -1)"
if [ -n "$SB_PID" ]; then
    # Verify it has items loaded (not a launchd zombie without config)
    if sketchybar --query bar >/dev/null 2>&1; then
        log "SketchyBar already running and healthy (PID: $SB_PID)"
        exit 0
    fi
    # Running but no items — must be a launchd zombie, kill it
    log "SketchyBar PID $SB_PID running but no items loaded, killing..."
    kill "$SB_PID" 2>/dev/null
    sleep 1
    rm -f "$RUN_DIR/sketchybar_*.lock" "$RUN_DIR/sketchybar_*.pid" /tmp/.sketchybar* 2>/dev/null
fi

# Clean any stale lock files from dead instances
rm -f "$RUN_DIR/sketchybar_*.lock" "$RUN_DIR/sketchybar_*.pid" 2>/dev/null

# Start sketchybar via open (so macOS attributes TCC permission to the .app, not the raw binary)
log "Starting SketchyBar via $SB_APP..."
open "$SB_APP" --args --config "$SB_CONFIG"

# Verify with progressive backoff (up to ~55s total — plugins can be slow)
for i in 1 2 3 4 5 6 7 8 9 10; do
    sleep "$i"
    SB_PID="$(pgrep -x sketchybar | head -1)"
    if [ -n "$SB_PID" ]; then
        # Process alive — check if items are loaded
        if sketchybar --query bar >/dev/null 2>&1; then
            log "SketchyBar started successfully (PID: $SB_PID)"
            printf '%s' "$SB_PID" > "$RUN_DIR/sketchybar_${USER}.pid"
            exit 0
        fi
        # Alive but not ready yet — keep waiting
    else
        # Check if it died
        if [ -f "$ERR_LOG" ] && [ -s "$ERR_LOG" ]; then
            ERR_MSG="$(cat "$ERR_LOG")"
            log "SketchyBar may have died (attempt $i/10): $ERR_MSG"
        fi
    fi
done

# Failed after all retries
log "SketchyBar failed to start after 5 attempts"
osascript -e 'display notification "SketchyBar: no se pudo iniciar" with title "SketchyBar Error" sound name "Glass"'
exit 1

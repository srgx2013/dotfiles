#!/bin/bash
# SKHD Health Check
# Starts skhd directly with nohup (avoid launchd — macOS 26.x breaks process naming).
# Waits for external disk to be available before proceeding.

LOG_FILE="/tmp/skhd_check.log"
LOCK_DIR="/tmp/skhd_check.lock"
SKHD_APP="$HOME/Applications/skhd-protected.app"
SKHD_BIN="$SKHD_APP/Contents/MacOS/skhd"
SKHD_CONFIG="$HOME/.config/skhd/skhdrc"
ERR_LOG="/tmp/skhd_start_err.log"
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

# Check if already running
SKHD_PID="$(pgrep -x skhd | head -1)"
if [ -n "$SKHD_PID" ]; then
    log "SKHD already running (PID: $SKHD_PID)"
    exit 0
fi

# Kill any leftover zombie from launchctl submit (shows as "-c ...")
# C5 fix: validate PID actually belongs to skhd before killing
ZOMBIE_PID="$(ps aux | grep "[s]khd.*skhdrc" | awk '{print $2}' | head -1)"
if [ -n "$ZOMBIE_PID" ]; then
    ZOMBIE_COMM="$(ps -p "$ZOMBIE_PID" -o comm= 2>/dev/null)"
    if [ "$ZOMBIE_COMM" = "skhd" ]; then
        log "Killing stale skhd zombie (PID: $ZOMBIE_PID)"
        kill "$ZOMBIE_PID" 2>/dev/null
        sleep 1
    else
        log "Skipping PID $ZOMBIE_PID: comm='$ZOMBIE_COMM' (not skhd)"
    fi
fi

# Start skhd via open (so macOS attributes TCC permission to the .app, not the raw binary)
log "Starting skhd via $SKHD_APP..."
open "$SKHD_APP" --args -c "$SKHD_CONFIG"

# Verify with progressive backoff — pgrep instead of PID capture
for i in 1 2 3 4 5 6 7 8 9 10; do
    sleep "$i"
    SKHD_PID="$(pgrep -x skhd | head -1)"
    if [ -n "$SKHD_PID" ]; then
        log "SKHD started successfully (PID: $SKHD_PID)"
        printf '%s' "$SKHD_PID" > "$RUN_DIR/skhd_${USER}.pid"
        exit 0
    fi
    # Check if it tried and died
    if [ -f "$ERR_LOG" ] && [ -s "$ERR_LOG" ]; then
        ERR_MSG="$(cat "$ERR_LOG")"
        log "skhd may have died (attempt $i/10): $ERR_MSG"
    fi
done

# Failed after all retries
log "SKHD failed to start after 10 attempts"
osascript -e 'display notification "SKHD: no se pudo iniciar" with title "SKHD Error" sound name "Glass"'
exit 1

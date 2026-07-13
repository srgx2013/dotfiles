#!/bin/bash
# Yabai Health Check
# Starts yabai directly (launchd doesn't work with yabai on macOS 26.x).
# Waits for external disk, retries with backoff, and acts as watchdog.
# Uses mkdir for atomic locking (portable on macOS).

export PATH="/opt/homebrew/bin:$PATH"
LOG_FILE="/tmp/yabai_check.log"
LOCK_DIR="/tmp/yabai_check.lock"
YABAI_BIN="/opt/homebrew/bin/yabai"
ERR_LOG="/tmp/yabai_start_err.log"
DISK_PATH="/Volumes/m2/Usuarios"
LOCK_TIMEOUT=30
RUN_DIR="$HOME/.local/run"
mkdir -p "$RUN_DIR" && chmod 700 "$RUN_DIR"
MAX_RETRIES=10
RETRY_INTERVAL=30  # seconds between retries when accessibility is missing

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

# Check if yabai is already running
EXISTING_PID="$(pgrep -x yabai | head -1)"
if [ -n "$EXISTING_PID" ]; then
    # Check 1: socket alive?
    if yabai -m query --spaces >/dev/null 2>&1; then
        # Check 2: not stuck in "mission-control is active" state?
        CURRENT=$(yabai -m query --spaces 2>/dev/null | python3 -c "
import sys,json
spaces=json.load(sys.stdin)
for s in spaces:
    if s.get('has-focus') or s.get('focused'):
        print(s['index'])
        break
" 2>/dev/null)
        if [ -n "$CURRENT" ]; then
            # Try to focus — succeeds means functional
            STUCK_MSG=$(yabai -m space --focus "$CURRENT" 2>&1)
            if [ $? -eq 0 ]; then
                log "Yabai already running and functional (PID: $EXISTING_PID)"
                exit 0
            fi
            # Only kill if specifically stuck in mission-control
            if echo "$STUCK_MSG" | grep -qi "mission-control"; then
                log "Yabai stuck in mission-control. Killing..."
            else
                # Already-focused or other benign exit 1 — treat as healthy
                log "Yabai running, benign: $STUCK_MSG"
                exit 0
            fi
        else
            log "Yabai alive (PID: $EXISTING_PID), no focused space found"
            exit 0
        fi
    else
        log "Yabai PID $EXISTING_PID exists but not responding, killing..."
    fi
    kill "$EXISTING_PID" 2>/dev/null
    sleep 1
    if kill -0 "$EXISTING_PID" 2>/dev/null; then
        log "SIGTERM didn't stop yabai, using SIGKILL..."
        kill -9 "$EXISTING_PID" 2>/dev/null
        sleep 1
    fi
    rm -f /tmp/yabai_*.{lock,socket} 2>/dev/null
fi

# Start yabai with retry + backoff
# Accessibility permissions may not be granted yet at boot — retry every 30s for ~5 min
log "Starting yabai..."
for attempt in $(seq 1 "$MAX_RETRIES"); do
    log "Attempt $attempt of $MAX_RETRIES..."

    PATH="/opt/homebrew/bin:$PATH" nohup "$YABAI_BIN" > /dev/null 2>"$ERR_LOG" &
    YABAI_PID=$!

    # Quick check: did it die immediately? (missing accessibility)
    sleep 2
    if ! kill -0 "$YABAI_PID" 2>/dev/null; then
        ERR_MSG="$(cat "$ERR_LOG" 2>/dev/null || echo 'unknown')"
        log "Yabai died on start: $ERR_MSG"
        if [ "$attempt" -lt "$MAX_RETRIES" ]; then
            log "Waiting ${RETRY_INTERVAL}s before retry $((attempt + 1))..."
            sleep "$RETRY_INTERVAL"
        fi
        continue
    fi

    # Process is alive — wait for socket with progressive backoff
    for wait_sec in 1 2 3 5 10; do
        sleep "$wait_sec"
        if yabai -m query --spaces >/dev/null 2>&1; then
            log "Yabai started successfully (PID: $YABAI_PID)"
            printf '%s' "$YABAI_PID" > "$RUN_DIR/yabai_${USER}.pid"
            # Inline watchdog removed — rely on launchd plist (StartInterval=120) only.
            # Dual-watching caused race conditions where the two watchdogs kill each other's yabai.
            exit 0
        fi
        # Still alive?
        if ! kill -0 "$YABAI_PID" 2>/dev/null; then
            ERR_MSG="$(cat "$ERR_LOG" 2>/dev/null || echo 'unknown')"
            log "Yabai died while waiting for socket: $ERR_MSG"
            continue  # C2 fix: go back to outer retry loop, not break out of it
        fi
    done

    # Kill if still alive but stuck (will retry on next loop)
    if kill -0 "$YABAI_PID" 2>/dev/null; then
        log "Yabai process alive but socket not responding, killing..."
        kill "$YABAI_PID" 2>/dev/null
    fi

    if [ "$attempt" -lt "$MAX_RETRIES" ]; then
        log "Waiting ${RETRY_INTERVAL}s before retry $((attempt + 1))..."
        sleep "$RETRY_INTERVAL"
    fi
done

# All attempts exhausted
log "Yabai failed to start after $MAX_RETRIES attempts (gave up)"
osascript -e 'display notification "Yabai: no se pudo iniciar después de varios intentos — revisá Accessibility" with title "Yabai Error" sound name "Glass"'
exit 1

#!/bin/bash
# Waits for a path to be available (disk mounted, filesystem ready)
# Usage: disk-ready.sh <path> [timeout_seconds]

TARGET="${1:-/Volumes/m2}"
TIMEOUT="${2:-30}"
ELAPSED=0

while [ ! -d "$TARGET" ]; do
    if [ "$ELAPSED" -ge "$TIMEOUT" ]; then
        echo "TIMEOUT: $TARGET not available after ${TIMEOUT}s"
        exit 1
    fi
    sleep 1
    ELAPSED=$((ELAPSED + 1))
done

# Extra check: the target is actually readable (not a dead mount)
# Use full timeout path when available, fall back to shell-native timeout
TIMEOUT_CMD=""
for _p in /opt/homebrew/bin/timeout /opt/homebrew/opt/coreutils/libexec/gnubin/timeout; do
    [ -x "$_p" ] && TIMEOUT_CMD="$_p" && break
done

TIMED_OUT=1
if [ -n "$TIMEOUT_CMD" ]; then
    "$TIMEOUT_CMD" 5 ls "$TARGET" >/dev/null 2>&1 && TIMED_OUT=0
else
    # C7 fix: shell-native timeout fallback — prevents hanging on dead mount
    # ( sleep 5; kill -ALRM $$ ) & wait $! returns 138 (128+10 SIGALRM) on timeout
    bash -c '
        child=$!
        ( sleep 5; kill -ALRM $$ ) 2>/dev/null &
        wait $child 2>/dev/null
        ret=$?
        [ $ret -eq 138 ] && exit 1
        exit 0
    ' 2>/dev/null
    if [ $? -eq 0 ]; then
        ls "$TARGET" >/dev/null 2>&1 && TIMED_OUT=0
    fi
fi
if [ "$TIMED_OUT" -eq 1 ]; then
    echo "DEAD_MOUNT: $TARGET exists but is not readable"
    exit 1
fi

exit 0

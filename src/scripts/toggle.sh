#!/bin/sh
# Name: Toggle Custom Screensaver
# DontUseFBInk

BASE="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
DAEMON="$BASE/custom_ss_daemon.sh"

PIDFILE="/tmp/custom_ss_daemon.pid"
SHIELD_PIDFILE="/tmp/custom_ss_shield.pid"
STATEFILE="/tmp/custom_ss_restore_renderers"
INDEXFILE="/tmp/custom_ss_last"
FIFO="/tmp/custom_ss_events.fifo"

LOG="$BASE/launcher.log"
LOG_MAX_BYTES=131072
LOG_KEEP_LINES=400

. "$BASE/blanket_renderers.sh"


log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') $1" >> "$LOG"
}


#
# Keep a log file from growing without bound: once it passes
# LOG_MAX_BYTES, keep only its last LOG_KEEP_LINES lines.
#
trim_log() {
    if [ -f "$1" ] && [ "$(wc -c < "$1")" -gt "$LOG_MAX_BYTES" ]; then
        tail -n "$LOG_KEEP_LINES" "$1" > "$1.tmp" && mv "$1.tmp" "$1"
    fi
}


#
# Show a one-line status message near the bottom of the screen.
#
notify() {
    for NOTIFY_FBINK in "$BASE/bin/fbink_hf" "$BASE/bin/fbink"; do
        if [ -x "$NOTIFY_FBINK" ]; then
            "$NOTIFY_FBINK" -q -m -y -6 "$1" >/dev/null 2>&1
            return
        fi
    done
}


daemon_is_running() {
    if [ ! -f "$PIDFILE" ]; then
        return 1
    fi

    PID="$(cat "$PIDFILE" 2>/dev/null)"

    if [ -z "$PID" ]; then
        return 1
    fi

    if ! kill -0 "$PID" 2>/dev/null; then
        return 1
    fi

    # Make sure the PID actually belongs to our daemon,
    # rather than some unrelated process that reused the PID.
    if [ -r "/proc/$PID/cmdline" ]; then
        tr '\0' ' ' < "/proc/$PID/cmdline" 2>/dev/null |
            grep -F "$DAEMON" >/dev/null 2>&1 ||
            return 1
    fi

    return 0
}


emergency_cleanup() {
    EMERGENCY_RESULT=0

    #
    # Kill a leftover shield, if there is one.
    #
    if [ -f "$SHIELD_PIDFILE" ]; then
        SPID="$(cat "$SHIELD_PIDFILE" 2>/dev/null)"

        if [ -n "$SPID" ]; then
            kill "$SPID" 2>/dev/null
        fi

        rm -f "$SHIELD_PIDFILE"
    fi

    #
    # If the daemon left behind its original-state record, restore the exact
    # renderer set that was active before startup.
    #
    if restore_original_renderers; then
        if [ -f "$STATEFILE" ]; then
            log "Emergency renderer restore complete"
        fi
    else
        log "ERROR: emergency renderer restore incomplete"
        EMERGENCY_RESULT=1
    fi

    rm -f \
        "$PIDFILE" \
        "$INDEXFILE" \
        "$FIFO"

    if [ "$EMERGENCY_RESULT" -eq 0 ]; then
        rm -f "$STATEFILE"
    fi

    DISPLAY=:0 "$BASE/bin/screensaver_shield" --refresh >>"$LOG" 2>&1

    return "$EMERGENCY_RESULT"
}


disable_custom_ss() {
    PID="$(cat "$PIDFILE" 2>/dev/null)"

    log "Disabling custom screensaver (PID $PID)"

    #
    # TERM triggers the daemon's cleanup trap.
    #
    kill "$PID" 2>/dev/null

    #
    # Give it up to 5 seconds to cleanly exit and restore Blanket.
    #
    COUNT=0

    while kill -0 "$PID" 2>/dev/null; do
        sleep 1
        COUNT=$((COUNT + 1))

        if [ "$COUNT" -ge 5 ]; then
            log "ERROR: daemon did not exit within 5 seconds"
            return 1
        fi
    done

    #
    # Normally the daemon has already cleaned everything.
    # This catches anything left behind.
    #
    if ! emergency_cleanup; then
        log "ERROR: custom screensaver disabled, but renderer restoration failed"
        return 1
    fi

    log "Custom screensaver DISABLED"
    notify "Custom screensaver OFF"
}


enable_custom_ss() {
    if [ ! -f "$DAEMON" ]; then
        log "ERROR: daemon missing: $DAEMON"
        exit 1
    fi

    #
    # Clean any stale files from an abnormal previous exit.
    #
    if ! emergency_cleanup; then
        log "ERROR: cannot enable while renderer restoration is incomplete"
        exit 1
    fi

    if ! ls /mnt/us/screensavers/*.png >/dev/null 2>&1; then
        log "No images in /mnt/us/screensavers - not enabling"
        notify "No images in /screensavers - stock screensaver kept"
        exit 1
    fi

    chmod +x "$DAEMON"

    log "Enabling custom screensaver"

    sh "$DAEMON" >/dev/null 2>&1 &

    NEWPID=$!

    #
    # Give the daemon a moment to initialize.
    #
    sleep 1

    if [ -f "$PIDFILE" ]; then
        PID="$(cat "$PIDFILE" 2>/dev/null)"

        if [ -n "$PID" ] && kill -0 "$PID" 2>/dev/null; then
            log "Custom screensaver ENABLED (PID $PID)"
            notify "Custom screensaver ON"
            exit 0
        fi
    fi

    log "ERROR: daemon failed to start"
    notify "Custom screensaver failed to start - stock kept"

    kill "$NEWPID" 2>/dev/null
    emergency_cleanup

    exit 1
}


#
# -------------------------
# Command
# -------------------------
#

trim_log "$LOG"
trim_log "$BASE/custom_ss.log"

case "${1:-toggle}" in
    disable)
        if daemon_is_running; then
            disable_custom_ss
        else
            rm -f "$PIDFILE"

            if [ -f "$SHIELD_PIDFILE" ] || \
                [ -f "$STATEFILE" ] || \
                [ -f "$INDEXFILE" ] || \
                [ -p "$FIFO" ]
            then
                emergency_cleanup
            fi
        fi
        ;;

    toggle)
        if daemon_is_running; then
            disable_custom_ss
        else
            #
            # Remove a stale PID file if the recorded process
            # no longer exists.
            #
            rm -f "$PIDFILE"

            enable_custom_ss
        fi
        ;;

    *)
        echo "Usage: $0 [disable]" >&2
        exit 1
        ;;
esac

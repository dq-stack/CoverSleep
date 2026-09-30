#!/bin/sh

# Book cover lookup used by the daemon when the Kindle sleeps inside a book.
# Callers provide BIN, LOG, and log().

COVER_EXTRACT="$BIN/cover_extract"
COVER_CACHE_PREFIX="/tmp/custom_ss_cover_"
COVER_MODE_FILE="/mnt/us/screensavers/.cover_mode"
CC_DB="/var/local/cc.db"


cover_mode_enabled() {
    [ "$(cat "$COVER_MODE_FILE" 2>/dev/null)" != "off" ]
}


in_book() {
    CL_APP="$(lipc-get-prop com.lab126.appmgrd activeApp 2>>"$LOG")"

    [ "$CL_APP" = "com.lab126.booklet.reader" ]
}


#
# The KF8 renderer (webreader) runs only while a book is open and holds
# exactly that book's file, so it answers both "in a book?" and "which
# book?" the moment the book opens.
#
webreader_book() {
    #
    # One grep over every process name keeps this fast at sleep time;
    # a per-process loop costs seconds on the Kindle's CPU.
    #
    for CL_COMM in $(grep -l -x webreader /proc/[0-9]*/comm 2>/dev/null); do
        ls -l "${CL_COMM%/comm}/fd" 2>/dev/null |
            sed -n 's/.*-> //p' |
            grep -E '^/mnt/(us|base-us)/documents/.*\.(azw3|azw|mobi|AZW3|AZW|MOBI)$'
    done | head -n 1
}


#
# Books rendered without webreader (e.g. older MOBI) fall back to appmgrd
# plus the most recently accessed library item. cc.db can lag a few
# seconds behind opening a book, which is an accepted edge case.
#
current_book_path() {
    CL_WEBREADER_BOOK="$(webreader_book)"

    if [ -n "$CL_WEBREADER_BOOK" ]; then
        echo "$CL_WEBREADER_BOOK"
        return 0
    fi

    if ! in_book; then
        return 1
    fi

    sqlite3 "$CC_DB" \
        "SELECT p_location FROM Entries
         WHERE p_type='Entry:Item' AND p_location IS NOT NULL
         ORDER BY p_lastAccess DESC LIMIT 1;" 2>>"$LOG"
}


#
# Echoes a path to the open book's cover image, extracting and caching it
# on first use. Returns 1 when the book has no usable cover.
#
current_cover_path() {
    CL_BOOK="$(current_book_path)"

    if [ -z "$CL_BOOK" ]; then
        return 1
    fi

    if [ ! -f "$CL_BOOK" ]; then
        log "Cover: book file missing: $CL_BOOK"
        return 1
    fi

    case "$CL_BOOK" in
        *.azw3|*.azw|*.mobi|*.AZW3|*.AZW|*.MOBI) ;;
        *)
            log "Cover: unsupported format: $CL_BOOK"
            return 1
            ;;
    esac

    CL_KEY="$(printf '%s %s' "$CL_BOOK" "$(stat -c %Y "$CL_BOOK" 2>/dev/null)" |
        cksum | cut -d ' ' -f 1)"
    CL_COVER="$COVER_CACHE_PREFIX$CL_KEY"

    if [ -f "$CL_COVER" ]; then
        log "Cover: cache hit for $CL_BOOK"
        echo "$CL_COVER"
        return 0
    fi

    if "$COVER_EXTRACT" "$CL_BOOK" "$CL_COVER" 2>>"$LOG"; then
        log "Cover: extracted from $CL_BOOK"
        echo "$CL_COVER"
        return 0
    fi

    rm -f "$CL_COVER"
    log "Cover: none in $CL_BOOK"
    return 1
}

#!/bin/sh
# msgbox.sh FBINK MESSAGE
# msgbox.sh FBINK --check     exit 0 if the box works here, without drawing
#
# Show MESSAGE in a bordered box in the middle of the screen, in the Kindle's
# own UI font (Amazon Ember), like the Kindle's own pop-ups. The box goes
# away after a few seconds, except for "in progress" messages (ending in
# "..." or "…"), which stay until the next message replaces them.
#
# Only on hard-float firmware (5.16.3 and later, e.g. the Kindle 11th gen),
# where the Library is an X window that can be asked to repaint over the box.
# Exits 1 without drawing anything elsewhere, so the caller can fall back to
# its old one-line message.
#
# Shared by CoverSleep and Calibre Wireless: keep the two copies identical.

FBINK="$1"
MSG="$2"
FONT=/usr/java/lib/fonts/Amazon-Ember-Regular.ttf
HOLD=4                       # seconds a finished message stays up
SEQ=/tmp/msgbox.seq          # newest message's number: older timers do nothing

[ -e /lib/ld-linux-armhf.so.3 ] && [ -f "$FONT" ] && [ -x "$FBINK" ] &&
    [ -x /usr/bin/xrefresh ] || exit 1

# Screen size, from the framebuffer's mode ("U:1072x1448p-0"). (FBInk's own
# report, fbink -e, crashes on some builds.)
MODE="$(sed -n '1s/^[^:]*:\([0-9]*x[0-9]*\).*/\1/p' /sys/class/graphics/fb0/modes 2>/dev/null)"
W="${MODE%x*}"
H="${MODE#*x}"
case "$W$H" in ''|*[!0-9]*) exit 1 ;; esac
[ "$W" -gt 0 ] && [ "$H" -gt 0 ] || exit 1
[ "$MSG" = --check ] && exit 0

BW=$((W * 80 / 100))         # box: 80% of the width, room for two lines
BH=$((H * 15 / 100))
L=$(((W - BW) / 2))
T=$(((H - BH) / 2))
B=$((W / 360))               # border, 3 px on a 1072 px screen
[ "$B" -lt 2 ] && B=2
P=$((W / 27))                # text padding inside the box

"$FBINK" -q -b -B BLACK -k top=$T,left=$L,width=$BW,height=$BH </dev/null || exit 1
"$FBINK" -q -b -B WHITE -k top=$((T + B)),left=$((L + B)),width=$((BW - 2 * B)),height=$((BH - 2 * B)) </dev/null
"$FBINK" -q -b -m -M -t regular=$FONT,size=11,top=$((T + B)),bottom=$((H - T - BH + B)),left=$((L + P)),right=$((W - L - BW + P)) \
    "$MSG" </dev/null
"$FBINK" -q -W GC16 -s top=$T,left=$L,width=$BW,height=$BH </dev/null

N=$(($(cat "$SEQ" 2>/dev/null || echo 0) + 1))
echo "$N" > "$SEQ"
case "$MSG" in
    *...|*…) exit 0 ;;
esac
# Remove the box by having X repaint just that part of the screen. Skipped if
# a newer message has replaced this one in the meantime.
(
    sleep "$HOLD"
    [ "$(cat "$SEQ" 2>/dev/null)" = "$N" ] &&
        DISPLAY=:0 xrefresh -geometry ${BW}x${BH}+${L}+${T} >/dev/null 2>&1
) </dev/null >/dev/null 2>&1 &
exit 0

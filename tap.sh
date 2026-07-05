#!/system/bin/sh
# ============================================================
# tap.sh — taps via sendevent (raw kernel input, no `input`).
# Sources the tap engine shipped in the Magisk module.
# ============================================================

LIB="${MODTAP:-/data/adb/modules/autotapper/tapper}"
. "$LIB/taplib.sh"

INTERVAL=2   # seconds between taps

while true; do
  tap_px 1000 500
  sleep "$INTERVAL"
done

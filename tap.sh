#!/system/bin/sh
# ============================================================
# tap.sh — the actual autotapper. Edit this, push to GitHub,
# and the phone picks it up automatically within ~2 minutes.
#
# Pure shell: uses Android's built-in `input tap X Y`.
# Find coordinates with Developer options > "Pointer location".
# ============================================================

INTERVAL=2   # seconds between taps

while true; do
  input tap 540 1200
  sleep "$INTERVAL"
  input tap 540 1600
  sleep "$INTERVAL"
done

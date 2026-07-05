#!/system/bin/sh
# ============================================================
# tap.sh — force Settings to its main screen, dump ONCE, verify
# Notifications is present, then tap it reusing that same dump.
# (Single dump avoids the race where a second dump disagrees.)
# ============================================================

LIB="${MODTAP:-/data/adb/modules/autotapper/tapper}"
. "$LIB/taplib.sh"

log(){ echo "$(date '+%H:%M:%S') $*"; }

DUMP=/data/local/tmp/ui.xml

log "opening Settings (forced to main)"
am start -a android.settings.SETTINGS \
   --activity-clear-top --activity-clear-task -f 0x10000000 >/dev/null 2>&1

# Dump repeatedly until Notifications shows up (settles after load).
i=0; FOUND=0
while [ $i -lt 12 ]; do
  uiautomator dump "$DUMP" >/dev/null 2>&1
  if grep -q 'text="Notifications"' "$DUMP" 2>/dev/null; then
    log "Settings main screen is up (dump $i)"
    FOUND=1
    break
  fi
  i=$((i+1))
  sleep 1
done

if [ $FOUND -eq 0 ]; then
  log "gave up: Notifications never appeared"
  exit 1
fi

# Tap reusing THIS dump — no second dump, no race.
log "tapping Notifications from verified dump"
REUSE_DUMP=1 FINDTAP_DUMP="$DUMP" sh "$LIB/findtap.sh" "Notifications"
log "done"
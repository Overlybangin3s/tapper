#!/system/bin/sh
# ============================================================
# tap.sh — force Settings to its MAIN screen, wait until it's
# actually there, then tap the "Notifications" row by name.
# ============================================================

LIB="${MODTAP:-/data/adb/modules/autotapper/tapper}"
. "$LIB/taplib.sh"

log(){ echo "$(date '+%H:%M:%S') $*"; }

# Force Settings to the front AND reset to its main screen even if
# it's already open on a subpage:
#   --activity-clear-top + NEW_TASK pops back to the root Settings activity.
log "opening Settings (forced to main)"
am start -a android.settings.SETTINGS \
   --activity-clear-top --activity-clear-task -f 0x10000000 >/dev/null 2>&1
# (0x10000000 = FLAG_ACTIVITY_NEW_TASK)

# Wait until "Notifications" is visible before acting.
i=0
while [ $i -lt 10 ]; do
  uiautomator dump /data/local/tmp/ui.xml >/dev/null 2>&1
  if grep -q 'text="Notifications"' /data/local/tmp/ui.xml 2>/dev/null; then
    log "Settings main screen is up"
    break
  fi
  i=$((i+1))
  sleep 1
done

if [ $i -ge 10 ]; then
  log "gave up: Notifications never appeared"
  exit 1
fi

log "finding + tapping Notifications"
sh "$LIB/findtap.sh" "Notifications"
log "done"
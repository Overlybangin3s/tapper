#!/system/bin/sh
# ============================================================
# tap.sh — open Settings, wait until the main list is actually
# on screen, then tap the "Notifications" row by name.
# Robust against slow loads / wrong screen: verifies before tapping.
# ============================================================

LIB="${MODTAP:-/data/adb/modules/autotapper/tapper}"
. "$LIB/taplib.sh"

log(){ echo "$(date '+%H:%M:%S') $*"; }

# Bring Settings to the front, main screen.
log "opening Settings"
am start -a android.settings.SETTINGS >/dev/null 2>&1

# Wait until "Notifications" is actually visible before acting.
# Try up to ~10s so a slow foreground doesn't cause a wrong-screen tap.
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
  log "gave up: Notifications never appeared on screen"
  exit 1
fi

log "finding + tapping Notifications"
sh "$LIB/findtap.sh" "Notifications"
log "done"
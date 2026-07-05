#!/system/bin/sh
# ============================================================
# tap.sh — open Settings and tap the "Notifications" row by name.
# Repo only needs this file; taplib.sh + findtap.sh live in the module.
# ============================================================

LIB="${MODTAP:-/data/adb/modules/autotapper/tapper}"
. "$LIB/taplib.sh"

log(){ echo "$(date '+%H:%M:%S') $*"; }

log "opening Settings"
am start -a android.settings.SETTINGS >/dev/null 2>&1
sleep 3

log "finding + tapping Notifications"
sh "$LIB/findtap.sh" "Notifications"

log "done"
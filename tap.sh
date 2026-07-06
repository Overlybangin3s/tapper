#!/system/bin/sh
# ============================================================
# tap.sh — list the bucket, grab the NEWEST object by upload
# time, drop it in the gallery, open the app(s). You post.
# No fixed filename, no marker file. Uses the Supabase ANON key.
# ============================================================

LIB="${MODTAP:-/data/adb/modules/autotapper/tapper}"
. "$LIB/taplib.sh"

# ---- CONFIG (push to edit) ----
API="https://vtyhbjckopwimxtlobpv.supabase.co"
BUCKET="AnitaMaxWinAB39291"
ANON="eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InZ0eWhiamNrb3B3aW14dGxvYnB2Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzYzNzExOTgsImV4cCI6MjA5MTk0NzE5OH0.D_pb3Mhr-dGMDqUh-0eQzvMNHnK311iDrngiRd6fUE8"          # the PUBLIC anon key — NOT service_role
PUBLIC="$API/storage/v1/object/public/$BUCKET"
STATE="/data/local/tmp/postvideo.last"
DEST="/sdcard/DCIM/Camera"
CHECK_INTERVAL=1800                    # poll every 30 min
APPS="com.snapchat.android"            # add tiktok/insta if you want them opened too
GAP=90
# --------------------------------

for bb in /data/adb/magisk/busybox /data/adb/ksu/bin/busybox /data/adb/ap/bin/busybox; do
  [ -x "$bb" ] && BB="$bb" && break
done
: "${BB:=busybox}"

log(){ echo "$(date '+%F %T') postvideo: $*"; }

# ask Supabase for the single newest object name in the bucket
newest_name(){
  "$BB" wget -q -O - \
    --header="apikey: $ANON" \
    --header="Authorization: Bearer $ANON" \
    --header="Content-Type: application/json" \
    --post-data='{"limit":1,"sortBy":{"column":"created_at","order":"desc"}}' \
    "$API/storage/v1/object/list/$BUCKET" 2>/dev/null \
  | grep -oE '"name":"[^"]*"' | head -1 | cut -d'"' -f4
}

deliver(){
  NAME="$1"
  OUT="$DEST/daily_$(date +%Y%m%d_%H%M%S).mp4"
  log "new video '$NAME' -> $OUT"
  "$BB" wget -q -O "$OUT" "$PUBLIC/$NAME" || { log "download failed"; return 1; }
  chmod 664 "$OUT"
  am broadcast -a android.intent.action.MEDIA_SCANNER_SCAN_FILE -d "file://$OUT" >/dev/null 2>&1
  sleep 2
  for PKG in $APPS; do
    log "opening $PKG"
    monkey -p "$PKG" -c android.intent.category.LAUNCHER 1 >/dev/null 2>&1
    sleep "$GAP"
  done
  echo "$NAME" > "$STATE"
}

log "watching bucket $BUCKET for newest upload"
while true; do
  NEW="$(newest_name)"
  OLD="$(cat "$STATE" 2>/dev/null)"
  [ -n "$NEW" ] && [ "$NEW" != "$OLD" ] && deliver "$NEW"
  sleep "$CHECK_INTERVAL"
done
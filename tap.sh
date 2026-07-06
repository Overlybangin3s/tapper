#!/system/bin/sh
# ============================================================
# tap.sh — VIDEO POSTER (lives in the GitHub repo, push to edit)
#
# manager.sh pulls this file and runs it, restarting it on every
# push. It polls your Supabase bucket for the NEWEST uploaded
# video, downloads it, drops it in the gallery so it's top of the
# picker, then opens the app(s). YOU do the actual posting.
#
# The bundled static curl (in $MODTAP/bin/curl) can't do DNS on
# Android, so we resolve the host with `ping` and pin it via
# --resolve. -k is needed because the static build has no CA store.
# ============================================================

MODTAP="${MODTAP:-/data/adb/modules/autotapper/tapper}"
CURL="$MODTAP/bin/curl"
chmod 755 "$CURL" 2>/dev/null

# ---- CONFIG (edit here, commit, push — phone picks it up in ~2 min) ----
API="https://vtyhbjckopwimxtlobpv.supabase.co"
HOST="vtyhbjckopwimxtlobpv.supabase.co"     # must match API's hostname
BUCKET="AnitaMaxWinAB39291"
# public anon key (safe on-device); rotate in Supabase > Settings > API
ANON="eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InZ0eWhiamNrb3B3aW14dGxvYnB2Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzYzNzExOTgsImV4cCI6MjA5MTk0NzE5OH0.D_pb3Mhr-dGMDqUh-0eQzvMNHnK311iDrngiRd6fUE8"
STATE="/data/local/tmp/vidpost.last"
DEST="/sdcard/DCIM/Camera"          # scans reliably into all three pickers
CHECK_INTERVAL=1800                 # poll every 30 min; acts only on a new file
APPS="com.snapchat.android"         # add: com.zhiliaoapp.musically com.instagram.android
GAP=90                              # seconds between opening each app
# ----------------------------------------------------------------------

PUBLIC="$API/storage/v1/object/public/$BUCKET"
LIST="$API/storage/v1/object/list/$BUCKET"

log(){ echo "$(date '+%F %T') vidpost: $*"; }

# resolve HOST to an IP using the system resolver (static curl can't do DNS)
resolve_ip(){
  ping -c1 "$HOST" 2>/dev/null \
    | grep -oE '[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+' | head -1
}

# curl wrapper: pins the resolved IP + skips cert check. Args passed through.
cf(){
  IP="$(resolve_ip)"
  [ -z "$IP" ] && { log "DNS: could not resolve $HOST"; return 1; }
  "$CURL" -s -k --resolve "$HOST:443:$IP" "$@"
}

# echo the newest object's name, or nothing
newest_name(){
  cf "$LIST" \
    -H "apikey: $ANON" \
    -H "Authorization: Bearer $ANON" \
    -H "Content-Type: application/json" \
    -d '{"prefix":"","limit":1,"sortBy":{"column":"created_at","order":"desc"}}' \
    2>/dev/null \
  | grep -oE '"name":"[^"]*"' | head -1 | cut -d'"' -f4
}

deliver(){
  NAME="$1"
  EXT="${NAME##*.}"
  case "$EXT" in *[!A-Za-z0-9]*|"") EXT="mp4" ;; esac
  OUT="$DEST/daily_$(date +%Y%m%d_%H%M%S).$EXT"

  log "new video '$NAME' -> $OUT"
  cf -o "$OUT" "$PUBLIC/$NAME" || { log "download failed"; return 1; }
  chmod 664 "$OUT"

  am broadcast -a android.intent.action.MEDIA_SCANNER_SCAN_FILE \
     -d "file://$OUT" >/dev/null 2>&1
  sleep 2

  for PKG in $APPS; do
    log "opening $PKG"
    monkey -p "$PKG" -c android.intent.category.LAUNCHER 1 >/dev/null 2>&1
    sleep "$GAP"
  done
  echo "$NAME" > "$STATE"
}

if [ ! -x "$CURL" ]; then
  log "ERROR: bundled curl missing/not executable at $CURL"
  exit 1
fi

log "watching bucket $BUCKET for newest upload"
while true; do
  NEW="$(newest_name)"
  OLD="$(cat "$STATE" 2>/dev/null)"
  [ -n "$NEW" ] && [ "$NEW" != "$OLD" ] && deliver "$NEW"
  sleep "$CHECK_INTERVAL"
done
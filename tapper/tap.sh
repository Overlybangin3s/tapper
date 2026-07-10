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
# --resolve. -k is needed because the static bauild has no CA store.
# ============================================================
LIB="${MODTAP:-/data/local/tmp/autotapper_repo/tapper}"   # <- match your real layout
. "$LIB/taplib.sh" || { echo "cannot source taplib.sh at $LIB"; exit 1; }
MODTAP="${MODTAP:-/data/adb/modules/autotapper/tapper}"
CURL="$MODTAP/bin/curl"
chmod 755 "$CURL" 2>/dev/null

# ---- CONFIG (edit here, commit, push — aphone picks it up in ~2 min) ----
API="https://vtyhbjckopwimxtlobpv.supabase.co"
HOST="vtyhbjckopwimxtlobpv.supabase.co"     # must match API's hostname
BUCKET="AnitaMaxWinAB39291"
# public anon key (safe on-device); rotate in Supabase > Settings > API
ANON="eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InZ0eWhiamNrb3B3aW14dGxvYnB2Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzYzNzExOTgsImV4cCI6MjA5MTk0NzE5OH0.D_pb3Mhr-dGMDqUh-0eQzvMNHnK311iDrngiRd6fUE8"
STATE="/data/local/tmp/vidpost.last"
DEST="/sdcard/DCIM/Camera"          # scans reliably into the gallery/share sheet
# CHECK_INTERVAL=1800                 # poll every 30 min; acts only on a new file
CHECK_INTERVAL=120                 # poll every 30 min; acts only on a new file
# On a new upload: download -> scan -> open the system SHARE SHEET with the
# video attached. You pick the app (Snap/TikTok/Insta) and post manually.
# ----------------------------------------------------------------------

PUBLIC="$API/storage/v1/object/public/$BUCKET"
LIST="$API/storage/v1/object/list/$BUCKET"
#function somewhere up here ? 
log(){ echo "$(date '+%F %T') vidpost: $*"; }

BOX=/data/adb/box/scripts/box.service

proxy_on(){
  log "enabling clash proxy"
  "$BOX" start >/dev/null 2>&1
}

proxy_off(){
  log "disabling clash proxy"
  "$BOX" stop >/dev/null 2>&1
}

kill_snap(){
  log "force-stopping Snapchat"
  am force-stop com.snapchat.android
  sleep 1
  am force-stop com.google.android.apps.photos
}

# rsleep MIN MAX — sleep a random decimal in [MIN, MAX] seconds
# usage: rsleep 1 6
rsleep(){
  LO=$(( $1 * 100 ))
  HI=$(( $2 * 100 ))
  SPAN=$(( HI - LO + 1 ))
  R=$(( $(od -An -N2 -tu2 /dev/urandom | tr -d ' ') % SPAN + LO ))
  S=$(( R / 100 ))
  F=$(( R % 100 ))
  sleep "$S.$(printf '%02d' "$F")"
}

random_caption(){
  CAPTIONS="its OVER #fyp #emoney #apple
yns at it again #fyp #apple
u cant be srs bro im crine #fyp #apple
always something with these yns #fyp #apple
if you have apple wallet its OVER #fyp #apple"
  N=$(printf '%s\n' "$CAPTIONS" | grep -c .)
  PICK=$(( $(od -An -N2 -tu2 /dev/urandom | tr -d ' ') % N + 1 ))
  printf '%s\n' "$CAPTIONS" | sed -n "${PICK}p"
}

# random delay between 0.10 and 0.40
rand_delay(){
  # random int 10-40, then format as 0.NN
  R=$(( $(od -An -N2 -tu2 /dev/urandom | tr -d ' ') % 31 + 10 ))
  printf '0.%02d' "$R"
}

tap_flow(){

    log "no MediaStore id yet; opening file directly"
    am start -a android.intent.action.VIEW -d "file://$OUT" -t "video/*" >/dev/null 2>&1
        log "tapping center of screen (540,1200)"
    sleep 1
    tap_px 540 1200
    sleep 1 
    sh "$LIB/findtap.sh" --desc "Share"
    sleep 1
    sh "$LIB/findtap.sh" --desc "Snapchat. Pinned"
    sleep 4

    # sh "$LIB/findtap.sh" --id "com.snapchat.android:id/sent_to_button_label_mode_view"
    tap_px 879 2280
    rsleep 4 7
    sh "$LIB/findtap.sh" "Spotlight"
    sleep 2
    sh "$LIB/findtap.sh" --offset "Spotlight" -300
 
    sleep 2
    sh "$LIB/findtap.sh" "Add a description..."
    sleep 2

    s="$(random_caption)"
    log "typing caption: $s"
    i=0
    while [ $i -lt ${#s} ]; do
      c=$(printf "%s" "$s" | cut -c $((i+1)))
      if [ "$c" = " " ]; then input text "%s"; else input text "$c"; fi
      sleep "$(rand_delay)"
      i=$((i+1))
    done
    sleep 2

    sh "$LIB/findtap.sh" --offset "Description" 330
    sleep 3
    # tap_px 541 2150
    sh "$LIB/findtap.sh" --desc "Next"
    sleep 1
    #sh "$LIB/findtap.sh" --desc "Send"
    kill_snap

}

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
 
  # scan into MediaStore so it has a content:// id (needed for the share sheet)
  am broadcast -a android.intent.action.MEDIA_SCANNER_SCAN_FILE \
     -d "file://$OUT" >/dev/null 2>&1
  sleep 3
 
  # look up the MediaStore id for the file we just wrote
  ID="$(content query --uri content://media/external/video/media \
         --where "_data='$OUT'" 2>/dev/null \
        | grep -oE '_id=[0-9]+' | grep -oE '[0-9]+' | head -1)"
 
  if [ -n "$ID" ]; then
    URI="content://media/external/video/media/$ID"
    log "opening in Google Photos (media id $ID)"
    # Open the clip in Google Photos' detail view (share/edit/add/trash bar).
    # From there YOU tap share -> Snapchat and post manually.
    am start -a android.intent.action.VIEW -t "video/*" -d "$URI" \
       -p com.google.android.apps.photos -f 0x1 >/dev/null 2>&1 || \
    am start -a android.intent.action.VIEW -t "video/*" -d "$URI" \
       -f 0x1 >/dev/null 2>&1

            log "tapping center of screen (540,1200)"
    sleep 1
    tap_px 540 1200

  else
  tap_flow
  fi
 
  echo "$NAME" > "$STATE"
}
# ---- CLI dispatch: run one function from Termux, then exit ----
if [ -n "$1" ]; then
  "$@"
  exit $?
fi

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

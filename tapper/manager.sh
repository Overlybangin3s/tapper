#!/system/bin/sh
# ============================================================
# Auto Tapper manager
# - polls your private GitHub repo for new commits
# - downloads + extracts the latest when it changes
# - runs the repo's tap.sh (restarting it on each update)
# Uses Magisk's bundled busybox (wget + tar). No git, no python.
# ============================================================

# ---- CONFIG ----
REPO="Overlybangin3s/tapper"          # owner/repo
BRANCH="master"
TOKENFILE="/data/adb/gh_token"        # you put your GitHub token here (once)
WORK="/data/local/tmp/autotapper_repo"
CHECK_INTERVAL=120                    # seconds between update checks
# ----------------

# busybox isn't on PATH at boot — call it by full path.
# Falls back through the common root-manager locations.
for bb in /data/adb/magisk/busybox /data/adb/ksu/bin/busybox /data/adb/ap/bin/busybox; do
  [ -x "$bb" ] && BB="$bb" && break
done
: "${BB:=busybox}"   # last resort: hope it's on PATH

log(){ echo "$(date '+%Y-%m-%d %H:%M:%S') $*"; }
token(){ tr -d ' \t\r\n' < "$TOKENFILE" 2>/dev/null; }

latest_sha(){
  T="$(token)"
  if [ -z "$T" ]; then log "ERROR: token empty"; return 1; fi
  "$BB" wget -q -O - \
    --header="Authorization: token $T" \
    --header="User-Agent: autotapper" \
    --header="Accept: application/vnd.github+json" \
    "https://api.github.com/repos/$REPO/commits/$BRANCH" \
    | grep -m1 '"sha"' | cut -d'"' -f4
}

download(){
  mkdir -p "$WORK"
  T="$(token)"
  "$BB" wget -q -O /data/local/tmp/repo.tar.gz \
    --header="Authorization: token $T" \
    --header="User-Agent: autotapper" \
    "https://api.github.com/repos/$REPO/tarball/$BRANCH" || return 1
  rm -rf "$WORK"/*
  "$BB" tar -xzf /data/local/tmp/repo.tar.gz -C "$WORK" --strip-components=1
}

MODTAP="${0%/*}"          # module's tapper dir (stable path)
export MODTAP

TAP_PID=""
start_tapper(){
  [ -n "$TAP_PID" ] && kill "$TAP_PID" 2>/dev/null
  if [ -f "$WORK/tap.sh" ]; then
    MODTAP="$MODTAP" sh "$WORK/tap.sh" &
    TAP_PID=$!
    log "tapper started (pid $TAP_PID)"
  else
    log "ERROR: tap.sh not found in repo"
  fi
}

if [ -z "$(token)" ]; then
  log "ERROR: no token at $TOKENFILE — put your GitHub token there and reboot"
  exit 1
fi

log "manager up, watching $REPO@$BRANCH"
CUR=""
while true; do
  NEW="$(latest_sha)"
  if [ -n "$NEW" ] && [ "$NEW" != "$CUR" ]; then
    log "new commit $CUR -> $NEW"
    if download; then
      CUR="$NEW"
      start_tapper
    else
      log "download failed, will retry"
    fi
  fi
  sleep "$CHECK_INTERVAL"
done

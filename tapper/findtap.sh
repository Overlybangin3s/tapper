#!/system/bin/sh
# ============================================================
# findtap.sh — find an on-screen element by name and tap it
#
# Uses `uiautomator dump` to get the current view hierarchy,
# finds the node whose text / content-desc / resource-id matches,
# computes the center of its bounds, and taps there via taplib.
#
# Usage:  findtap.sh "Notifications"
#         findtap.sh --id "com.android.settings:id/search"
#
# Zero extra setup: uiautomator + sendevent are on the device.
# ============================================================

HERE="${MODTAP:-${0%/*}}"
. "$HERE/taplib.sh"

DUMP="${FINDTAP_DUMP:-/data/local/tmp/ui.xml}"

# dump_ui(){
#   # Always take a fresh dump (reuse proved fragile). A short settle delay
#   # lets the screen finish rendering so the element is actually present.
#   sleep 1
#   uiautomator dump "$DUMP" >/dev/null 2>&1 || \
#   uiautomator dump --compressed "$DUMP" >/dev/null 2>&1
#   [ -s "$DUMP" ]
# }
dump_ui(){
  sleep 1
  uiautomator dump "$DUMP" >/dev/null 2>&1
  # uiautomator often returns non-zero even on success — trust the file,
  # and do NOT fall back to --compressed (it strips resource-ids).
  [ -s "$DUMP" ]
}
# extract bounds="[x1,y1][x2,y2]" for the first node matching a pattern,
# then echo the center pixel coords "cx cy"
find_center(){
  PATTERN="$1"
  # Split nodes onto their own lines into a temp file, then loop reading
  # from the FILE (not a pipe) so the loop runs in THIS shell and our
  # echo actually propagates out. (piping into `while` runs a subshell
  # on toybox sh and swallows the result -> empty coords.)
  SPLIT=/data/local/tmp/ui_split.txt
  sed 's|<node|\n<node|g' "$DUMP" > "$SPLIT"

  RESULT=""
  while IFS= read -r LINE; do
    printf '%s' "$LINE" | grep -qF "$PATTERN" || continue
    B=$(printf '%s' "$LINE" | grep -o 'bounds="\[[0-9]*,[0-9]*\]\[[0-9]*,[0-9]*\]"' | head -1)
    [ -z "$B" ] && continue
    # Pull the four numbers in order. grep -o one-per-line, then pick by
    # position with sed -n. Avoids greedy .* (which grabbed the 2nd pair
    # for all four) and avoids set--/IFS splitting (fragile under `read`).
    NL=$(printf '%s' "$B" | grep -oE '[0-9]+')
    X1=$(printf '%s\n' "$NL" | sed -n '1p')
    Y1=$(printf '%s\n' "$NL" | sed -n '2p')
    X2=$(printf '%s\n' "$NL" | sed -n '3p')
    Y2=$(printf '%s\n' "$NL" | sed -n '4p')
    [ -z "$X1" ] || [ -z "$Y1" ] || [ -z "$X2" ] || [ -z "$Y2" ] && continue
    CX=$(( (X1 + X2) / 2 )); CY=$(( (Y1 + Y2) / 2 ))
    if [ "$X2" -gt "$X1" ] && [ "$Y2" -gt "$Y1" ] && [ "$CX" -gt 0 ] && [ "$CY" -gt 0 ]; then
      RESULT="$CX $CY"
      break
    fi
  done < "$SPLIT"

  [ -z "$RESULT" ] && return 1
  echo "$RESULT"
}

tap_by(){
  WHAT="$1"
  dump_ui || { echo "dump failed"; return 1; }
  CENTER=$(find_center "$WHAT") || { echo "not found: $WHAT"; return 1; }
  set -- $CENTER
  CX=$1; CY=$2
  # never tap the corner: empty/zero bounds means we didn't really find it
  if [ -z "$CX" ] || [ -z "$CY" ] || { [ "$CX" = "0" ] && [ "$CY" = "0" ]; }; then
    echo "bad coords for '$WHAT' (got '$CX,$CY') — not tapping"
    return 1
  fi
  echo "found '$WHAT' at center $CX,$CY — tapping"
  # Let UiAutomation (from `uiautomator dump`) fully release the input path
  # before injecting, otherwise the accessibility layer swallows the tap
  # and the app never sees the click. Tune UP if taps still no-op.
  sleep "${TAP_SETTLE:-1.5}"
  tap_px "$CX" "$CY"
}

# ---- CLI ----
case "$1" in
  --id)   tap_by "resource-id=\"$2\"" ;;
  --desc) tap_by "content-desc=\"$2\"" ;;
  *)      tap_by "text=\"$1\"" ;;
esac

#!/system/bin/sh
# ============================================================
# taplib_human.sh — raw touch injection via sendevent (enhanced for realism)
#
# Based on original taplib.sh for Pixel 6 fts touchscreen.
# Now with human-like variance to simulate real finger/thumb "fingerprint"
# contact area + pressure dynamics instead of robotic fixed point tap.
#
# Key improvements for CS project / anti-detection / natural input:
#   - Small random position jitter around target center (not always pixel-perfect)
#   - Randomized TRACKING_ID (new "finger" each tap)
#   - Variable PRESSURE (real finger pressure fluctuates)
#   - Variable TOUCH_MAJOR / TOUCH_MINOR (contact ellipse size/shape — larger
#     = thumb/finger pad area, varies with angle/pressure/placement)
#   - Slight ORIENTATION variance
#   - TWO event reports per tap: initial contact + micro-settle update
#     (pressure ramp-ish, tiny position/size drift) to mimic how a real
#     finger press evolves over 50-100ms instead of instant on/off
#   - All tunable via environment variables for experiments
#
# Drop-in replacement: cp taplib_human.sh taplib.sh  or source this instead.
# Zero extra binaries needed (uses od + /dev/urandom already on device).
# ============================================================

DEV="/dev/input/event3"      # fts touchscreen (Pixel 6)
MAXX=1079                     # ABS_MT_POSITION_X max
MAXY=2399                     # ABS_MT_POSITION_Y max
SCRW=1080                     # screen width px
SCRH=2400                     # screen height px

# event type/code constants (from linux/input-event-codes.h)
EV_SYN=0; EV_KEY=1; EV_ABS=3
SYN_REPORT=0
BTN_TOUCH=330                 # 0x14a
ABS_MT_SLOT=47                # 0x2f
ABS_MT_TRACKING_ID=57         # 0x39
ABS_MT_POSITION_X=53          # 0x35
ABS_MT_POSITION_Y=54          # 0x36
ABS_MT_TOUCH_MAJOR=48         # 0x30
ABS_MT_TOUCH_MINOR=49         # 0x31
ABS_MT_ORIENTATION=52         # 0x34
ABS_MT_PRESSURE=58            # 0x3a

se(){ sendevent "$DEV" "$1" "$2" "$3"; }

# scale a pixel coord into the digitizer's coordinate space
scale_x(){ echo $(( $1 * MAXX / SCRW )); }
scale_y(){ echo $(( $1 * MAXY / SCRH )); }

# ------------------------------------------------------------
# Humanization tunables (override with export VAR=val before running)
# Good starting point for Pixel 6 fts — tweak while watching getevent -l
# ------------------------------------------------------------
JITTER_PX=${TAP_JITTER_PX:-3}           # +/- pixels random offset from center (0 = precise)
PRESS_MIN=${TAP_PRESS_MIN:-55}          # raised for better button registration reliability
PRESS_MAX=${TAP_PRESS_MAX:-125}
MAJOR_MIN=${TAP_MAJOR_MIN:-160}     # increased for more elongated thumb-like contact
MAJOR_MAX=${TAP_MAJOR_MAX:-220}
MINOR_MIN=${TAP_MINOR_MIN:-80}      # lowered to create clearer ellipse (better visible tilt)
MINOR_MAX=${TAP_MINOR_MAX:-130}
ORIENT_VAR=${TAP_ORIENT_VAR:-35}        # +/- raw orientation units — increase for more visible natural tilt (like real finger angle)
HOLD_BASE_MS=${TAP_HOLD_BASE_MS:-5}      # made even shorter for ultra fast taps

# Simple random int in [min, max] inclusive using /dev/urandom (no awk needed)
rand_int() {
  _min=$1; _max=$2
  _range=$((_max - _min + 1))
  _r=$(od -An -N2 -tu2 /dev/urandom 2>/dev/null | tr -d ' \n')
  [ -z "$_r" ] && _r=12345
  echo $((_min + (_r % _range)))
}

# tap_px X Y  — realistic but quick version (2 reports)
# Kept good elliptical contact + orientation, but removed extra reports/sleeps
# so it feels fast like the version you liked before.
tap_px(){
  X=$1; Y=$2

  # --- random human placement jitter ---
  JX=$(rand_int -$JITTER_PX $JITTER_PX)
  JY=$(rand_int -$JITTER_PX $JITTER_PX)
  TX=$((X + JX))
  TY=$((Y + JY))
  DX=$(scale_x "$TX"); DY=$(scale_y "$TY")

  # --- randomized contact parameters (thumb-like) ---
  TID=$(rand_int 30 220)
  PRESS=$(rand_int $PRESS_MIN $PRESS_MAX)
  MAJ=$(rand_int $MAJOR_MIN $MAJOR_MAX)
  MINO=$(rand_int $MINOR_MIN $MINOR_MAX)
  if [ "$MINO" -gt "$MAJ" ]; then _t=$MAJ; MAJ=$MINO; MINO=$_t; fi
  ORI=$(rand_int -$ORIENT_VAR $ORIENT_VAR)

  # short hold
  HOLD_MS=$(( HOLD_BASE_MS + $(rand_int -5 9) ))
  [ "$HOLD_MS" -lt 20 ] && HOLD_MS=20

  # ============================================================
  # REPORT 1 — Initial contact
  # ============================================================
  se $EV_ABS $ABS_MT_SLOT 0
  se $EV_KEY $BTN_TOUCH 1
  se $EV_ABS $ABS_MT_TRACKING_ID "$TID"
  se $EV_ABS $ABS_MT_POSITION_X "$DX"
  se $EV_ABS $ABS_MT_POSITION_Y "$DY"
  se $EV_ABS $ABS_MT_TOUCH_MAJOR "$MAJ"
  se $EV_ABS $ABS_MT_TOUCH_MINOR "$MINO"
  se $EV_ABS $ABS_MT_PRESSURE "$PRESS"
  se $EV_ABS $ABS_MT_ORIENTATION "$ORI"
  se $EV_SYN $SYN_REPORT 0

  sleep 0.003

  # ============================================================
  # REPORT 2 — Quick settle + release prep
  # ============================================================
  JX2=$(rand_int -1 2)
  JY2=$(rand_int -1 2)
  DX2=$(scale_x $((TX + JX2)))
  DY2=$(scale_y $((TY + JY2)))

  PRESS2=$((PRESS + $(rand_int 8 20)))
  [ "$PRESS2" -gt 200 ] && PRESS2=200

  MAJ2=$((MAJ + $(rand_int -6 12)))
  MINO2=$((MINO + $(rand_int -4 8)))
  [ "$MINO2" -gt "$MAJ2" ] && MINO2=$MAJ2

  ORI2=$(rand_int $((ORI - 15)) $((ORI + 15)))

  se $EV_ABS $ABS_MT_POSITION_X "$DX2"
  se $EV_ABS $ABS_MT_POSITION_Y "$DY2"
  se $EV_ABS $ABS_MT_TOUCH_MAJOR "$MAJ2"
  se $EV_ABS $ABS_MT_TOUCH_MINOR "$MINO2"
  se $EV_ABS $ABS_MT_PRESSURE "$PRESS2"
  se $EV_ABS $ABS_MT_ORIENTATION "$ORI2"
  se $EV_SYN $SYN_REPORT 0

  sleep "0.0$HOLD_MS" 2>/dev/null || sleep 0.04

  # ============================================================
  # UP
  # ============================================================
  se $EV_ABS $ABS_MT_PRESSURE 0
  se $EV_ABS $ABS_MT_TRACKING_ID -1
  se $EV_KEY $BTN_TOUCH 0
  se $EV_SYN $SYN_REPORT 0
}

# Optional: if you want a "precise mode" for debugging, you can temporarily
#   export TAP_JITTER_PX=0 TAP_PRESS_MIN=68 TAP_PRESS_MAX=68 etc.
# Then source taplib_human.sh and your findtap will use the realistic version.
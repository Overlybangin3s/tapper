#!/system/bin/sh
# ============================================================
# taplib.sh — raw touch injection via sendevent (no `input`)
#
# Works below the framework, so it's immune to the Android 14+
# `input` command lockdown (SIGABRT / Failed transaction).
#
# Protocol: Type B multitouch (ABS_MT_SLOT + TRACKING_ID),
# which is what the Pixel 6 digitizer uses.
#
# These values get filled in from getevent -pl:
#   DEV      = touchscreen event device (e.g. /dev/input/event2)
#   MAXX     = ABS_MT_POSITION_X max (digitizer range, not pixels)
#   MAXY     = ABS_MT_POSITION_Y max
#   SCRW     = screen width in pixels  (wm size)
#   SCRH     = screen height in pixels
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

se(){ sendevent "$DEV" "$1" "$2" "$3"; }

# scale a pixel coord into the digitizer's coordinate space
scale_x(){ echo $(( $1 * MAXX / SCRW )); }
scale_y(){ echo $(( $1 * MAXY / SCRH )); }

# extra axis codes seen in the real-finger capture
ABS_MT_TOUCH_MINOR=49    # 0x31
ABS_MT_ORIENTATION=52    # 0x34
ABS_MT_PRESSURE=58       # 0x3a

# tap_px X Y  — replays the exact axis set a real finger sends on this fts panel
tap_px(){
  DX=$(scale_x "$1"); DY=$(scale_y "$2")

  # DOWN — order and axes mirror a real finger:
  # BTN_TOUCH first, then tracking id, then full contact data.
  se $EV_KEY $BTN_TOUCH 1
  se $EV_ABS $ABS_MT_TRACKING_ID 88
  se $EV_ABS $ABS_MT_POSITION_X "$DX"
  se $EV_ABS $ABS_MT_POSITION_Y "$DY"
  se $EV_ABS $ABS_MT_TOUCH_MAJOR 154
  se $EV_ABS $ABS_MT_TOUCH_MINOR 132
  se $EV_ABS $ABS_MT_PRESSURE 68
  se $EV_ABS $ABS_MT_ORIENTATION 0
  se $EV_SYN $SYN_REPORT 0

  sleep 0.06

  # UP — zero pressure, release tracking id, lift, exactly like the capture
  se $EV_ABS $ABS_MT_PRESSURE 0
  se $EV_ABS $ABS_MT_TRACKING_ID -1
  se $EV_KEY $BTN_TOUCH 0
  se $EV_SYN $SYN_REPORT 0
}

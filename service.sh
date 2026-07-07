#!/system/bin/sh
# Magisk runs this on every boot, as root, in the background.
# Update path: Magisk Manager "Update" button (see updateJson in module.prop).
# No token, no self-poll loop, no bundled curl.
MODDIR=${0%/*}

# Wait for boot + network to settle.
sleep 45

# Launch the tapper, detached, with a log.
if [ -f "$MODDIR/tapper/tap.sh" ]; then
  MODTAP="$MODDIR/tapper" nohup sh "$MODDIR/tapper/tap.sh" \
    > /data/local/tmp/autotapper.log 2>&1 &
else
  echo "$(date) ERROR: tapper/tap.sh not found" > /data/local/tmp/autotapper.log
fi
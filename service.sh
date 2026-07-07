#!/system/bin/sh
# Magisk runs this on every boot, as root, in the background.
# Update path: Magisk Manager "Update" button (updateJson in module.prop).
MODDIR=${0%/*}

# Bundled static curl is used by tap.sh — restore the exec bit
# (zip installs / update-flashes can drop it).
chmod 755 "$MODDIR/tapper/bin/curl" 2>/dev/null

# Wait for boot + network to settle.
sleep 45

# Launch the tapper, detached, with a log.
if [ -f "$MODDIR/tapper/tap.sh" ]; then
  MODTAP="$MODDIR/tapper" nohup sh "$MODDIR/tapper/tap.sh" \
    > /data/local/tmp/autotapper.log 2>&1 &
else
  echo "$(date) ERROR: tapper/tap.sh not found" > /data/local/tmp/autotapper.log
fi
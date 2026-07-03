#!/usr/bin/env python3
"""
Simple screen autotapper for a Magisk-rooted Android phone.

Taps happen locally via `su -c "input tap X Y"`. No ADB, no network.

Find your coordinates with:
  Settings > Developer options > "Pointer location" (shows X/Y as you touch)
or run once:  su -c "getevent -l"   (advanced)
"""

import subprocess
import sys
import time

# ---- EDIT THESE ----
TAPS = [
    (540, 1200),   # (x, y) in pixels
    (540, 1600),
]
INTERVAL = 2.0      # seconds to wait between each tap
# --------------------


def tap(x: int, y: int) -> None:
    # `input tap` is provided by Android; root lets us call it directly.
    subprocess.run(
        ["su", "-c", f"input tap {x} {y}"],
        check=False,
    )


def main() -> None:
    print(f"autotap started — {len(TAPS)} point(s), {INTERVAL}s interval")
    print("stop with Ctrl-C")
    try:
        while True:
            for x, y in TAPS:
                tap(x, y)
                time.sleep(INTERVAL)
    except KeyboardInterrupt:
        print("\nstopped.")
        sys.exit(0)


if __name__ == "__main__":
    main()

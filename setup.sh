#!/data/data/com.termux/files/usr/bin/bash
# Idempotent bootstrap: safe to run every time.
# Installs what's missing, then launches the autotapper.

REPO=~/autotap
cd "$REPO" || exit 1

# Keep the CPU awake so the loop doesn't get frozen by Android.
command -v termux-wake-lock >/dev/null && termux-wake-lock

# Install deps only if absent.
command -v python >/dev/null || pkg install -y python
command -v git    >/dev/null || pkg install -y git

# Run it.
python main.py

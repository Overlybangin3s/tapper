#!/data/data/com.termux/files/usr/bin/bash
# Polls the repo; if a new commit landed, pulls it and re-runs setup.sh.
# Schedule with cron or termux-job-scheduler.

REPO=~/autotap
cd "$REPO" || exit 1

git fetch origin main --quiet
LOCAL=$(git rev-parse HEAD)
REMOTE=$(git rev-parse origin/main)

if [ "$LOCAL" != "$REMOTE" ]; then
    git merge origin/main --quiet
    echo "$(date): updated $LOCAL -> $REMOTE" >> ~/autotap-update.log
    bash "$REPO/setup.sh"
fi

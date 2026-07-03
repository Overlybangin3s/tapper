# autotap

Simple local screen autotapper for a Magisk-rooted Android phone, run from Termux.

Taps are done locally with `su -c "input tap X Y"`. **No ADB, no network, no open ports.** Root already gives you everything needed to inject taps.

## One-time setup on the phone

```bash
pkg install -y git
git clone https://github.com/YOU/autotap.git ~/autotap
bash ~/autotap/setup.sh
```

## Set your tap coordinates

Edit `main.py`, change the `TAPS` list. Find coordinates with:
Settings > Developer options > **Pointer location** — it shows X/Y as you touch the screen.

## Run it

```bash
bash ~/autotap/setup.sh
```

Stop with `Ctrl-C`.

## Optional: auto-update from GitHub

If you want the phone to pick up new commits automatically, schedule the poller:

```bash
pkg install cronie
crontab -e
# check every 2 minutes:
*/2 * * * * ~/autotap/check_update.sh
```

Android may freeze background jobs — disable battery optimization for Termux and keep `termux-wake-lock` running so the loop survives.

## Notes

- This taps **this** phone's own screen. That's the whole scope.
- If tapping ever fails, check that `su -c "input tap 500 500"` works by itself first — that isolates whether it's root/permissions vs. the script.

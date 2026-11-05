#!/bin/bash
# Activate and dismiss the selected screen saver N times (default 20) and count the legacy host
# processes after each step (MACOS.md §5: no processes piling up). Select «Binary Time» in
# System Settings first. Dismissal sends a Shift key press through System Events, so the app that
# runs this script needs Privacy & Security › Accessibility.
set -u

cycles=${1:-20}
run_seconds=${RUN_SECONDS:-4}
settle_seconds=${SETTLE_SECONDS:-3}
engine=/System/Library/CoreServices/ScreenSaverEngine.app

# Since Sonoma the choice lives in the wallpaper store, not in com.apple.screensaver.
store="$HOME/Library/Application Support/com.apple.wallpaper/Store/Index.plist"
if python3 -I -c '
import plistlib, sys
def walk(o):
    if isinstance(o, dict): return any(walk(v) for v in o.values())
    if isinstance(o, list): return any(walk(v) for v in o)
    if isinstance(o, bytes):
        try: return walk(plistlib.loads(o))
        except Exception: return False
    return isinstance(o, str) and "Binary%20Time.saver" in o
sys.exit(0 if walk(plistlib.load(open(sys.argv[1], "rb"))) else 1)' "$store" 2>/dev/null; then
    echo "selected screen saver: Binary Time"
else
    echo "warning: «Binary Time» does not look selected in System Settings › Wallpaper › Screen Saver"
fi

hosts() { pgrep -f 'legacyScreenSaver' | wc -l | tr -d ' '; }

baseline=$(hosts)
echo "host processes before: $baseline"
printf '%-6s %-8s %-8s\n' cycle running after
worst=$baseline
for ((i = 1; i <= cycles; i++)); do
    open -a "$engine"
    sleep "$run_seconds"
    running=$(hosts)
    if ! osascript -e 'tell application "System Events" to key code 56' >/dev/null 2>&1; then
        echo "cannot send a key press: allow Accessibility for this app and run again" >&2
        exit 2
    fi
    sleep "$settle_seconds"
    after=$(hosts)
    (( after > worst )) && worst=$after
    printf '%-6s %-8s %-8s\n' "$i" "$running" "$after"
done

echo "host processes after $cycles cycles: $(hosts) (before: $baseline, worst after dismiss: $worst)"
if (( worst > baseline + 1 )); then
    echo "FAIL: host processes pile up"
    exit 1
fi
echo "PASS: no piling up"

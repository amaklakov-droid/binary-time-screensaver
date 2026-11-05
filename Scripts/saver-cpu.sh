#!/bin/bash
# Runs the selected screen saver for a while and reports the CPU and memory of its legacy host
# process (MACOS.md §5: CPU < 5 % on an M1 at 60 Hz). Dismissal sends a Shift key press through
# System Events, so the app that runs this script needs Privacy & Security › Accessibility.
#   Scripts/saver-cpu.sh [seconds, default 30]
set -u

seconds=${1:-30}
engine=/System/Library/CoreServices/ScreenSaverEngine.app

open -a "$engine"
sleep 6
host=$(pgrep -f 'legacyScreenSaver' | tail -1)
if [ -z "$host" ]; then
    echo "no legacyScreenSaver process: the screen saver did not start" >&2
    exit 2
fi
samples=$(( (seconds - 6) / 3 ))
(( samples < 2 )) && samples=2
echo "host $host, $samples samples of 3 s"
# top's first sample has no CPU delta; skip it.
top -l $((samples + 1)) -s 3 -pid "$host" -stats cpu,mem 2>/dev/null | awk -v pid="$host" '
    $1 ~ /^[0-9.]+$/ { n++; if (n > 1) { cpu += $1; k++; if ($1 > max) max = $1; mem = $2 } }
    END { if (k) printf "CPU average %.1f %%, max %.1f %%, memory %s\n", cpu / k, max, mem }'
osascript -e 'tell application "System Events" to key code 56' >/dev/null 2>&1 \
    || echo "cannot send a key press: move the mouse to dismiss, and allow Accessibility for this app" >&2

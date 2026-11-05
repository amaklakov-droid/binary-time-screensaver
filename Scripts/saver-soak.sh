#!/bin/bash
# Long run of the selected screen saver (MACOS.md §5: memory stable over 8 h). Keeps the display
# awake, starts the saver, and logs the legacy host's CPU and memory every few minutes to
# build/soak-<date>.log. Stop with Ctrl-C or by moving the mouse; the log keeps what was measured.
# Run it from Terminal.app: a terminal inside another app dies when that app quits or updates.
#   Scripts/saver-soak.sh [hours, default 8] [minutes between samples, default 5]
set -u

hours=${1:-8}
interval=$(( ${2:-5} * 60 ))
root=$(cd "$(dirname "$0")/.." && pwd)
mkdir -p "$root/build"
log="$root/build/soak-$(date +%Y%m%d-%H%M).log"
end=$(( $(date +%s) + hours * 3600 ))
started=$(date '+%Y-%m-%d %H:%M:%S')

caffeinate -d -w $$ &
open -a /System/Library/CoreServices/ScreenSaverEngine.app
sleep 10
echo "time      pid    cpu%  rss_kb  hosts" | tee "$log"
last=""
changes=0
while (( $(date +%s) < end )); do
    host=$(pgrep -f 'legacyScreenSaver' | tail -1)
    if [ -z "$host" ] || ! pgrep -x ScreenSaverEngine >/dev/null; then
        echo "$(date +%H:%M:%S)  screen saver stopped" | tee -a "$log"
        break
    fi
    # A new pid means the host quit and macOS started another one; that must not happen during a run.
    if [ -n "$last" ] && [ "$host" != "$last" ]; then
        changes=$(( changes + 1 ))
        echo "$(date +%H:%M:%S)  host changed: $last -> $host" | tee -a "$log"
    fi
    last=$host
    printf '%s  %-6s %-5s %-7s %s\n' "$(date +%H:%M:%S)" "$host" \
        "$(ps -o %cpu= -p "$host" | tr -d ' ')" "$(ps -o rss= -p "$host" | tr -d ' ')" \
        "$(pgrep -f 'legacyScreenSaver' | wc -l | tr -d ' ')" | tee -a "$log"
    sleep "$interval"
done
echo "host changes: $changes" | tee -a "$log"
# Why the saver quit its host, if it did (BinaryTimeSaverView logs the reason, nothing else).
/usr/bin/log show --start "$started" --style compact \
    --predicate 'subsystem == "com.binarytime.saver" AND eventMessage BEGINSWITH "Exiting host"' 2>/dev/null \
    | tail -n +2 | tee -a "$log"
echo "log: $log"

#!/bin/zsh
# Renders the screen saver's list thumbnail (Saver/thumbnail.png 90×58 and thumbnail@2x.png 180×116,
# the size macOS uses for its own savers) with DebugHost: a 1440×928 screen in space mode, so the
# picture names no real place, scaled down.
#   Scripts/render-thumbnail.sh [path/to/DebugHost.app]
set -e
ROOT=$(cd "$(dirname "$0")/.." && pwd)
APP=${1:-$ROOT/build/DerivedData/Build/Products/Debug/DebugHost.app}
TMP=$(mktemp -d)
"$APP/Contents/MacOS/DebugHost" --reset --tz Etc/UTC --lang en --theme dark --hour 24 --calendar auto \
    --controls 0 --location vpn --space-index 0 --size 1440x928 --scale 1 \
    --freeze 2026-10-24T19:59:42Z --screenshot "$TMP/full.png" >/dev/null
sips -z 116 180 "$TMP/full.png" --out "$ROOT/Saver/thumbnail@2x.png" >/dev/null
sips -z 58 90 "$TMP/full.png" --out "$ROOT/Saver/thumbnail.png" >/dev/null
rm -rf "$TMP"
echo "written Saver/thumbnail.png and Saver/thumbnail@2x.png"

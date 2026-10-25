#!/bin/zsh
# Renders the 11 reference cases from reference/screenshots/ with DebugHost at the frozen reference
# instant (2026-10-24 19:59 Moscow) into build/compare/, next to the originals, for side-by-side review.
#   Scripts/render-references.sh [path/to/DebugHost.app]
set -e
ROOT=$(cd "$(dirname "$0")/.." && pwd)
APP=${1:-$ROOT/build/DerivedData/Build/Products/Debug/DebugHost.app}
BIN=$APP/Contents/MacOS/DebugHost
OUT=$ROOT/build/compare
mkdir -p "$OUT"
TZ_ID=Europe/Moscow
render() {  # name, then DebugHost arguments
  local name=$1; shift
  "$BIN" --reset --tz $TZ_ID --screenshot "$OUT/$name.png" "$@" >/dev/null
  echo "  $name"
}
render 01-dark-en-24h-1440x900          --lang en --theme dark  --hour 24 --calendar auto     --controls 0 --size 1440x900 --freeze 2026-10-24T19:59:17.800+03:00
render 02-dark-ru-24h-1440x900          --lang ru --theme dark  --hour 24 --calendar auto     --controls 0 --size 1440x900 --freeze 2026-10-24T19:59:29.330+03:00
render 03-light-ru-12h-square-1440x900  --lang ru --theme light --hour 12 --calendar auto     --controls 0 --size 1440x900 --freeze 2026-10-24T19:59:21.090+03:00 --shape square
render 04-dark-he-hebrew-rtl-1440x900   --lang he --theme dark  --hour 24 --calendar hebrew   --controls 0 --size 1440x900 --freeze 2026-10-24T19:59:22.790+03:00
render 05-light-ar-islamic-12h-rtl-1440x900 --lang ar --theme light --hour 12 --calendar islamic --controls 0 --size 1440x900 --freeze 2026-10-24T19:59:24.420+03:00
render 06-dark-bo-buddhist-1440x900     --lang bo --theme dark  --hour 24 --calendar buddhist --controls 0 --size 1440x900 --freeze 2026-10-24T19:59:26.090+03:00
render 07-dark-ja-vpn-space-1440x900    --lang ja --theme dark  --hour 24 --calendar auto     --controls 0 --size 1440x900 --freeze 2026-10-24T19:59:27.700+03:00 --location vpn --space-index 13
render 08-dark-ru-ultrawide-3440x1440   --lang ru --theme dark  --hour 24 --calendar auto     --controls 0 --size 3440x1440 --freeze 2026-10-24T19:59:29.330+03:00
render 09-dark-ru-portrait-900x1600     --lang ru --theme dark  --hour 24 --calendar auto     --controls 0 --size 900x1600 --freeze 2026-10-24T19:59:31.140+03:00
render 10-dark-ja-narrow-390x844        --lang ja --theme dark  --hour 24 --calendar auto     --controls 0 --size 390x844  --freeze 2026-10-24T19:59:32.920+03:00 --location vpn --space-index 10
render 11-debughost-controls-ru-1440x900 --lang ru --theme dark --hour 24 --calendar auto     --controls 1 --size 1440x900 --freeze 2026-10-24T19:59:34.690+03:00
echo "written to $OUT"

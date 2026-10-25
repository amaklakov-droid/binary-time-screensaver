#!/bin/zsh
# Downloads the OFL fonts named in design/tokens.json (font.stack) into Fonts/<Family>/ with their licenses.
# Sources: JetBrains Mono GitHub release; Noto families from the google/fonts repository (variable TTFs).
# Run only with the user's permission — it downloads ~10 MB. Downloads land in a fresh temp dir first.
set -euo pipefail
ROOT=$(cd "$(dirname "$0")/.." && pwd)
DEST=$ROOT/Fonts
TMP=$(mktemp -d "${TMPDIR:-/tmp}/binarytime-fonts.XXXXXX")
trap 'rm -rf "$TMP"' EXIT

JB_VERSION=${JB_VERSION:-2.304}
JB_URL="https://github.com/JetBrains/JetBrainsMono/releases/download/v${JB_VERSION}/JetBrainsMono-${JB_VERSION}.zip"
GF_RAW="https://raw.githubusercontent.com/google/fonts/main/ofl"

fetch() { # url dest
  echo "  ← $1"
  curl -fsSL --retry 3 --proto '=https' -o "$2" "$1"
}
is_ttf() { # file — TrueType/OpenType magic: 00 01 00 00, 'true', 'OTTO'
  local magic; magic=$(head -c 4 "$1" | xxd -p)
  [[ "$magic" == "00010000" || "$magic" == "74727565" || "$magic" == "4f54544f" ]]
}

echo "JetBrains Mono ${JB_VERSION}"
fetch "$JB_URL" "$TMP/jb.zip"
mkdir -p "$TMP/jb" && unzip -q "$TMP/jb.zip" -d "$TMP/jb"
mkdir -p "$DEST/JetBrainsMono"
for w in Light Regular SemiBold; do
  f=$(find "$TMP/jb" -path '*fonts/ttf/*' -name "JetBrainsMono-$w.ttf" | head -1)
  [[ -n "$f" ]] || { echo "missing JetBrainsMono-$w.ttf in archive"; exit 1; }
  is_ttf "$f" || { echo "not a TrueType file: $f"; exit 1; }
  cp "$f" "$DEST/JetBrainsMono/"
done
cp "$(find "$TMP/jb" -iname 'OFL.txt' | head -1)" "$DEST/JetBrainsMono/OFL.txt"

typeset -A NOTO=(
  [NotoSansHebrew]='notosanshebrew/NotoSansHebrew%5Bwdth%2Cwght%5D.ttf'
  [NotoSansArabic]='notosansarabic/NotoSansArabic%5Bwdth%2Cwght%5D.ttf'
  [NotoSerifTibetan]='notoseriftibetan/NotoSerifTibetan%5Bwght%5D.ttf'
  [NotoSansJP]='notosansjp/NotoSansJP%5Bwght%5D.ttf'
)
for family in ${(k)NOTO}; do
  echo "$family"
  relpath=${NOTO[$family]}
  dir=${relpath%%/*}
  file=$(printf "%b" "${${relpath#*/}//\%/\\x}")   # decode %5B %2C %5D
  mkdir -p "$DEST/$family"
  fetch "$GF_RAW/$relpath" "$TMP/$file"
  is_ttf "$TMP/$file" || { echo "not a TrueType file: $file"; exit 1; }
  cp "$TMP/$file" "$DEST/$family/$file"
  fetch "$GF_RAW/$dir/OFL.txt" "$DEST/$family/OFL.txt"
done
echo "done:"; du -sh "$DEST"; find "$DEST" -type f | sort

#!/bin/zsh
# Builds the release .dmg (TASK.md milestone 4) into dist/: universal Release build, bundle checks,
# Developer ID signature, notarization and stapling of the .saver and the .dmg.
#
#   DEVELOPER_ID="Developer ID Application: Name (TEAMID)" Scripts/release.sh
#   Scripts/release.sh --unsigned        # ad-hoc signature, no notarization: for local tests only
#
# Notarization reads credentials from a keychain profile that you create once yourself; they never
# appear in this script or in the repository:
#   xcrun notarytool store-credentials binarytime-notary --apple-id <id> --team-id <TEAMID>
# NOTARY_PROFILE overrides the profile name.
set -euo pipefail

ROOT=$(cd "$(dirname "$0")/.." && pwd)
UNSIGNED=0
[[ ${1:-} == --unsigned ]] && UNSIGNED=1
IDENTITY=${DEVELOPER_ID:-}
PROFILE=${NOTARY_PROFILE:-binarytime-notary}
if (( ! UNSIGNED )) && [[ -z $IDENTITY ]]; then
    echo "Set DEVELOPER_ID to your 'Developer ID Application: …' identity, or pass --unsigned." >&2
    exit 1
fi

DERIVED=$ROOT/build/release
SAVER=$DERIVED/Build/Products/Release/Binary\ Time.saver
DIST=$ROOT/dist
STAGE=$ROOT/build/dmg
step() { print -P "%B==> $1%b" }
fail() { echo "error: $1" >&2; exit 1 }

step "Build (Release, universal)"
rm -rf "$DERIVED"
xcodebuild -project "$ROOT/BinaryTime.xcodeproj" -scheme BinaryTimeSaver -configuration Release \
    -derivedDataPath "$DERIVED" clean build >"$ROOT/build/release.log" 2>&1 \
    || fail "build failed, see build/release.log"

step "Check the bundle"
PLIST=$SAVER/Contents/Info.plist
BUNDLE_ID=$(plutil -extract CFBundleIdentifier raw "$PLIST")
VERSION=$(plutil -extract CFBundleShortVersionString raw "$PLIST")
BINARY=$SAVER/Contents/MacOS/$(plutil -extract CFBundleExecutable raw "$PLIST")
ARCHS=$(lipo -archs "$BINARY")
[[ $ARCHS == *arm64* && $ARCHS == *x86_64* ]] || fail "not universal: $ARCHS"
for f in tokens.json i18n.json celestial-catalog.json zone.tab thumbnail.png thumbnail@2x.png; do
    [[ -f $SAVER/Contents/Resources/$f ]] || fail "missing resource $f"
done
# Every bundled font and its license (CLAUDE.md: never rely on system fonts).
want=$(cd "$ROOT/Fonts" && find . -type f \( -name '*.ttf' -o -name '*.otf' -o -name 'OFL.txt' \) | sort)
have=$(cd "$SAVER/Contents/Resources/Fonts" && find . -type f \( -name '*.ttf' -o -name '*.otf' -o -name 'OFL.txt' \) | sort)
[[ $want == "$have" ]] || fail "bundled fonts differ from Fonts/"
echo "  $BUNDLE_ID $VERSION ($ARCHS), $(echo $have | wc -l | tr -d ' ') font files"

step "Sign"
if (( UNSIGNED )); then
    codesign --force --options runtime --sign - "$SAVER"
else
    codesign --force --options runtime --timestamp --sign "$IDENTITY" "$SAVER"
fi
codesign --verify --strict --verbose=2 "$SAVER"
codesign -d --entitlements - "$SAVER" 2>/dev/null | grep -q get-task-allow && fail "get-task-allow entitlement present"

notarize() {  # file to submit
    xcrun notarytool submit "$1" --keychain-profile "$PROFILE" --wait | tee -a "$ROOT/build/release.log" \
        | grep -q 'status: Accepted' || fail "notarization rejected; run: xcrun notarytool log <id> --keychain-profile $PROFILE"
}

if (( ! UNSIGNED )); then
    step "Notarize the .saver"
    ZIP=$ROOT/build/BinaryTime-saver.zip
    rm -f "$ZIP"
    ditto -c -k --keepParent "$SAVER" "$ZIP"
    notarize "$ZIP"
    xcrun stapler staple "$SAVER"
fi

step "Make the .dmg"
NAME=BinaryTime-$VERSION
(( UNSIGNED )) && NAME=$NAME-unsigned
DMG=$DIST/$NAME.dmg
rm -rf "$STAGE" && mkdir -p "$STAGE" "$DIST"
ditto "$SAVER" "$STAGE/Binary Time.saver"
cp "$ROOT/README.md" "$ROOT/LICENSE" "$ROOT/THIRD-PARTY-NOTICES.md" "$STAGE/"
rm -f "$DMG"
hdiutil create -volname "Binary Time $VERSION" -srcfolder "$STAGE" -fs HFS+ -format UDZO -quiet "$DMG"

if (( ! UNSIGNED )); then
    step "Sign and notarize the .dmg"
    codesign --force --timestamp --sign "$IDENTITY" "$DMG"
    notarize "$DMG"
    xcrun stapler staple "$DMG"
    xcrun stapler validate "$DMG"
    spctl --assess --type open --context context:primary-signature --verbose=2 "$DMG"
fi

(cd "$DIST" && shasum -a 256 "$NAME.dmg" > "$NAME.dmg.sha256")
step "Done: dist/$NAME.dmg"
cat "$DIST/$NAME.dmg.sha256"

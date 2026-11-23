#!/bin/sh
# A build to hand out: Dighouse.app signed with the Developer ID and the hardened runtime, with uv inside so nothing
# needs installing first, packed as a disk image. Notarized and stapled when a notary profile is saved in the keychain
# (xcrun notarytool store-credentials NAME, once) and named in DIGHOUSE_NOTARY_PROFILE. Apple silicon only for now:
# the app and the uv inside it are built for arm64.
set -e
cd "$(dirname "$0")/.."
ID="${DIGHOUSE_SIGN:-$(security find-identity -v -p codesigning 2>/dev/null | awk -F'"' '/Developer ID Application/{print $2; exit}')}"
[ -n "$ID" ] || { echo "No Developer ID Application identity on this Mac; a build for others cannot be signed."; exit 1; }
DIGHOUSE_SIGN="$ID" ./scripts/bundle.sh
APP=build/Dighouse.app
UV="${DIGHOUSE_UV:-$(command -v uv)}"
[ -x "$UV" ] || { echo "uv was not found; set DIGHOUSE_UV to its path."; exit 1; }
mkdir -p "$APP/Contents/Resources/bin"
cp "$UV" "$APP/Contents/Resources/bin/uv"
codesign --force --options runtime --timestamp --sign "$ID" "$APP/Contents/Resources/bin/uv"
codesign --force --options runtime --timestamp --sign "$ID" "$APP"
codesign --verify --deep --strict --verbose=1 "$APP"
VERSION=$(/usr/libexec/PlistBuddy -c 'Print CFBundleShortVersionString' Info.plist)
DMG="build/Dighouse-$VERSION.dmg"
rm -f "$DMG"
hdiutil create -quiet -volname Dighouse -srcfolder "$APP" -ov -format UDZO "$DMG"
codesign --force --timestamp --sign "$ID" "$DMG"
if [ -n "$DIGHOUSE_NOTARY_PROFILE" ]; then
  xcrun notarytool submit "$DMG" --keychain-profile "$DIGHOUSE_NOTARY_PROFILE" --wait
  xcrun stapler staple "$DMG"
  spctl -a -t open --context context:primary-signature -v "$DMG"
  echo "Notarized: $DMG"
else
  echo "Signed, not notarized: $DMG. On another Mac, Gatekeeper asks before opening it. To notarize, save a profile once"
  echo "with xcrun notarytool store-credentials (an app-specific password from appleid.apple.com), then run"
  echo "DIGHOUSE_NOTARY_PROFILE=<name> app/scripts/release.sh"
fi

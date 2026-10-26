#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
APP="$ROOT/build/SiymoAI Mouse Mover.app"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources" dist
swift scripts/generate-icons.swift "$ROOT"
iconutil -c icns build/AppIcon.iconset -o "$APP/Contents/Resources/AppIcon.icns"
cp macos/Info.plist "$APP/Contents/Info.plist"
cp LICENSE "$APP/Contents/Resources/LICENSE"
swiftc -O -target arm64-apple-macos13.0 macos/MoverPolicy.swift macos/main.swift -o "$APP/Contents/MacOS/SiymoMouseMover" -framework AppKit -framework ApplicationServices -framework ServiceManagement
codesign --force --options runtime --sign "${MAC_SIGN_IDENTITY:--}" "$APP"
codesign --verify --deep --strict "$APP"
file "$APP/Contents/MacOS/SiymoMouseMover"
if [[ -n "${NOTARY_PROFILE:-}" ]]; then
    ditto -c -k --keepParent "$APP" build/notarization.zip
    xcrun notarytool submit build/notarization.zip --keychain-profile "$NOTARY_PROFILE" --wait
    xcrun stapler staple "$APP"
fi
STAGE="$(mktemp -d "$ROOT/build/dmg.XXXXXX")"
trap 'rm -rf "$STAGE"' EXIT
cp -R "$APP" "$STAGE/SiymoAI Mouse Mover.app"
ln -s /Applications "$STAGE/Applications"
cat > "$STAGE/Install.txt" <<'TXT'
Drag SiymoAI Mouse Mover to Applications, then open it.
The app lives in your menu bar, with no Dock icon or Terminal window.

This community build is not Apple-notarized. If macOS blocks the first launch,
use System Settings > Privacy & Security > Open Anyway after attempting to open.
Do not disable Gatekeeper.

From the mouse icon, choose Allow mouse movement… and enable the app under
Privacy & Security > Accessibility. This permission is required to move the pointer.
Click Start. The default inactivity interval is one minute.

Source, license, and help:
https://github.com/SiymoAI/siymo-mouse-mover
TXT
DMG="$ROOT/dist/SiymoAI-Mouse-Mover-1.0.1-macos-arm64.dmg"
rm -f "$DMG"
hdiutil create -volname 'SiymoAI Mouse Mover' -srcfolder "$STAGE" -format UDZO -ov "$DMG"
if [[ -n "${NOTARY_PROFILE:-}" ]]; then
    xcrun notarytool submit "$DMG" --keychain-profile "$NOTARY_PROFILE" --wait
    xcrun stapler staple "$DMG"
fi
ditto -c -k --keepParent "$APP" dist/SiymoAI-Mouse-Mover-1.0.1-macos-arm64.zip

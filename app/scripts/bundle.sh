#!/bin/sh
# Build Dighouse.app: the Swift app, its icon, and a copy of the archaeology tools.
set -e
cd "$(dirname "$0")/.."
swift build -c release
APP=build/Dighouse.app
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources/tools"
cp .build/release/Dighouse "$APP/Contents/MacOS/Dighouse"
cp Info.plist "$APP/Contents/Info.plist"
cp Resources/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"
rsync -a --delete Resources/starts Resources/tour "$APP/Contents/Resources/"
rsync -a --delete --exclude '__pycache__' ../src "$APP/Contents/Resources/tools/"
cp ../pyproject.toml ../uv.lock ../README.md ../skills/dighouse/SKILL.md "$APP/Contents/Resources/tools/"
codesign --force --deep --sign - "$APP" >/dev/null 2>&1
echo "Built $APP"

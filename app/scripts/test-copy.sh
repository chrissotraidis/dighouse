#!/bin/sh
# A copy of the built app with its own settings (bundle id com.chrissotraidis.dighouse.test), for checks while the
# real Dighouse is open. It starts from a copy of the real settings without the projects, and puts new projects in a
# scratch folder. Run scripts/bundle.sh first.
set -e
cd "$(dirname "$0")/.."
T=build/DighouseTest.app
[ -d "$T" ] && mv "$T" "/tmp/DighouseTest-old-$(date +%s).app"
ditto build/Dighouse.app "$T"
/usr/libexec/PlistBuddy -c 'Set :CFBundleIdentifier com.chrissotraidis.dighouse.test' "$T/Contents/Info.plist"
/usr/libexec/PlistBuddy -c 'Set :CFBundleName Dighouse Test' "$T/Contents/Info.plist" 2>/dev/null || true
codesign --force --deep --sign - "$T" >/dev/null 2>&1
if [ "$1" = "--fresh-settings" ] || ! defaults read com.chrissotraidis.dighouse.test model >/dev/null 2>&1; then
  defaults export com.chrissotraidis.dighouse /tmp/dighouse-settings-for-test.plist
  defaults import com.chrissotraidis.dighouse.test /tmp/dighouse-settings-for-test.plist
  for k in projects currentProject chatLists movedChats; do defaults delete com.chrissotraidis.dighouse.test $k 2>/dev/null || true; done
  defaults write com.chrissotraidis.dighouse.test projectsHome "$HOME/dighouse-ui-test"
fi
echo "Built $T. Open it with: open -n $T --args -ApplePersistenceIgnoreState YES"

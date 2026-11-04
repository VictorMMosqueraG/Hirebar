#!/bin/sh

set -eu
cd "$(dirname "$0")/.."

VERSION=$(tr -d '[:space:]' <VERSION)
APP=dist/Hirebar.app

echo "Building Hirebar ${VERSION}..."
swift build -c release --product Hirebar
BIN_DIR=$(swift build -c release --show-bin-path)

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN_DIR/Hirebar" "$APP/Contents/MacOS/Hirebar"
cp Resources/Info.plist "$APP/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $VERSION" "$APP/Contents/Info.plist"
cp -R Resources/inicial "$APP/Contents/Resources/"
codesign --force --deep --sign - "$APP"
echo "Built $APP"

case "${1:-}" in
	--install)
		pkill -x Hirebar 2>/dev/null || true
		sleep 1
		mkdir -p "$HOME/Applications"
		rm -rf "$HOME/Applications/Hirebar.app"
		cp -R "$APP" "$HOME/Applications/Hirebar.app"
		open "$HOME/Applications/Hirebar.app"
		echo "Installed in ~/Applications/Hirebar.app"
		;;
	--zip)
		(cd dist && ditto -c -k --keepParent Hirebar.app "Hirebar-$VERSION.zip")
		echo "Created dist/Hirebar-$VERSION.zip"
		;;
esac

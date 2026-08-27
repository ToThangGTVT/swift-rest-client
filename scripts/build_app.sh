#!/bin/bash
set -e

echo "==> Building CocoaRestClient standalone application..."
swift build -c release

BIN_PATH=$(swift build -c release --show-bin-path)
APP_NAME="CocoaRestClient.app"
APP_DIR="build/$APP_NAME"

rm -rf "$APP_DIR"
mkdir -p "$APP_DIR/Contents/MacOS"
mkdir -p "$APP_DIR/Contents/Resources"

cp "$BIN_PATH/CocoaRestClient" "$APP_DIR/Contents/MacOS/CocoaRestClient"

# Copy Icon
if [ -f "Resources/AppIcon.icns" ]; then
    cp "Resources/AppIcon.icns" "$APP_DIR/Contents/Resources/AppIcon.icns"
fi

# Copy Info.plist
if [ -f "Resources/Info.plist" ]; then
    cp "Resources/Info.plist" "$APP_DIR/Contents/Info.plist"
fi

echo "==> Successfully created standalone application bundle: $APP_DIR"

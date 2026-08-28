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

# Copy Info.plist. It is authored for Xcode, so the build-setting placeholders
# it contains have to be expanded by hand here.
BUNDLE_ID="${BUNDLE_ID:-com.utc.rest.client}"
if [ -f "Resources/Info.plist" ]; then
    cp "Resources/Info.plist" "$APP_DIR/Contents/Info.plist"
    /usr/libexec/PlistBuddy -c "Set :CFBundleIdentifier $BUNDLE_ID" \
        "$APP_DIR/Contents/Info.plist"
fi

# Sign with the Hardened Runtime enabled. Notarization rejects any bundle
# without it, so --options runtime is applied even for ad-hoc local builds.
if [ -z "$SIGN_IDENTITY" ]; then
    SIGN_IDENTITY=$(security find-identity -v -p codesigning \
        | grep "Developer ID Application" \
        | head -1 \
        | sed -E 's/.*"(.*)"/\1/')
fi

if [ -n "$SIGN_IDENTITY" ]; then
    echo "==> Signing with: $SIGN_IDENTITY"
    codesign --force --options runtime --timestamp \
        --sign "$SIGN_IDENTITY" "$APP_DIR"
else
    echo "==> WARNING: no 'Developer ID Application' identity found."
    echo "    Signing ad-hoc — the bundle runs locally but CANNOT be notarized."
    echo "    Set SIGN_IDENTITY=\"Developer ID Application: ...\" to sign for distribution."
    codesign --force --options runtime --sign - "$APP_DIR"
fi

codesign --display --verbose=2 "$APP_DIR" 2>&1 | grep -E "Identifier|flags|Authority" || true

echo "==> Successfully created standalone application bundle: $APP_DIR"

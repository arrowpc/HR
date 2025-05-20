#!/bin/bash
set -e

APP_NAME="HR"
BUILD_PATH=".build/release/$APP_NAME"
ASSETS_PATH="assets"
APP_BUNDLE="$APP_NAME.app"

swift build -c release

rm -rf "$APP_BUNDLE"
mkdir -p "$APP_BUNDLE/Contents/MacOS"
mkdir -p "$APP_BUNDLE/Contents/Resources"

cp "$BUILD_PATH" "$APP_BUNDLE/Contents/MacOS/"

cp Info.plist "$APP_BUNDLE/Contents/"

cp "$ASSETS_PATH/HR.icns" "$APP_BUNDLE/Contents/Resources/"

echo "App bundle created at $APP_BUNDLE"

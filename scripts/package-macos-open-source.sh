#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUILD_DIR="$ROOT_DIR/build"
DERIVED_DATA_DIR="$BUILD_DIR/DerivedData"
RELEASE_DIR="$ROOT_DIR/release"
APP_PATH="$DERIVED_DATA_DIR/Build/Products/Release/TextSnipper.app"
ZIP_PATH="$RELEASE_DIR/TextSnipper-macOS.zip"

rm -rf "$BUILD_DIR" "$RELEASE_DIR"
mkdir -p "$RELEASE_DIR"

xcodebuild \
  -project "$ROOT_DIR/TextSnipper.xcodeproj" \
  -scheme TextSnipper \
  -configuration Release \
  -derivedDataPath "$DERIVED_DATA_DIR" \
  CODE_SIGNING_ALLOWED=NO \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGN_IDENTITY="" \
  build

if [[ ! -d "$APP_PATH" ]]; then
  echo "Expected app bundle was not created at $APP_PATH" >&2
  exit 1
fi

ditto -c -k --sequesterRsrc --keepParent "$APP_PATH" "$ZIP_PATH"
shasum -a 256 "$ZIP_PATH" > "$ZIP_PATH.sha256"

echo "Created $ZIP_PATH"

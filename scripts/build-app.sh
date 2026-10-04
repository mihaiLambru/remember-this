#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."

if [ -z "${SDKROOT:-}" ] && [ -d /Library/Developer/CommandLineTools/SDKs/MacOSX15.4.sdk ]; then
  export SDKROOT=/Library/Developer/CommandLineTools/SDKs/MacOSX15.4.sdk
fi
export CLANG_MODULE_CACHE_PATH="${CLANG_MODULE_CACHE_PATH:-$PWD/.build/module-cache}"

swift build --product RememberThis
binary_directory="$(swift build --show-bin-path)"
app_directory="$PWD/build/Remember This.app"
app_version="${APP_VERSION:-0.1.0}"
build_number="${BUILD_NUMBER:-1}"
mkdir -p "$app_directory/Contents/MacOS" "$app_directory/Contents/Resources"
cp "$binary_directory/RememberThis" "$app_directory/Contents/MacOS/RememberThis"
cp Resources/Info.plist "$app_directory/Contents/Info.plist"
cp Resources/AppIcon.icns "$app_directory/Contents/Resources/AppIcon.icns"
/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $app_version" "$app_directory/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleVersion $build_number" "$app_directory/Contents/Info.plist"
codesign --force --sign - --entitlements Resources/RememberThis.entitlements "$app_directory"
printf 'Built %s\n' "$app_directory"

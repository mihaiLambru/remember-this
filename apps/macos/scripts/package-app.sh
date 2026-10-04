#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."

if [ "$#" -ne 1 ]; then
  printf 'Usage: %s VERSION\n' "$0" >&2
  exit 64
fi

version="$1"
app_directory="$PWD/build/Remember This.app"
output_directory="$PWD/dist"
archive="$output_directory/Remember-This-$version.zip"

APP_VERSION="$version" BUILD_NUMBER="${BUILD_NUMBER:-1}" bash scripts/build-app.sh
mkdir -p "$output_directory"
ditto -c -k --norsrc --keepParent "$app_directory" "$archive"
shasum -a 256 "$archive" > "$archive.sha256"
printf 'Packaged %s\n' "$archive"

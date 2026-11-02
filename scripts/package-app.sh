#!/bin/bash
set -euo pipefail

project_root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$project_root"
app_path="dist/Power Watcher.app"
if [[ ! -d "$app_path" ]]; then
  echo "Build the app first with ./scripts/build-app.sh --universal" >&2
  exit 66
fi
codesign --verify --strict "$app_path"
version=$(/usr/libexec/PlistBuddy -c 'Print CFBundleShortVersionString' "$app_path/Contents/Info.plist")
archive_name="PowerWatcher-$version-development.zip"
ditto -c -k --sequesterRsrc --keepParent "$app_path" "dist/$archive_name"
(cd dist && shasum -a 256 "$archive_name" > "$archive_name.sha256")
echo "Packaged local development build: $project_root/dist/$archive_name"
echo "This ad-hoc build is not notarized and is not an App Store submission."

#!/bin/bash
set -euo pipefail

project_root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$project_root"
configuration="${CONFIGURATION:-release}"
build_arguments=(-c "$configuration")
case "${1:-}" in
  "") ;;
  --universal) build_arguments+=(--arch arm64 --arch x86_64) ;;
  *) echo "Usage: $0 [--universal]" >&2; exit 64 ;;
esac
swift build "${build_arguments[@]}"
binary_directory="$(swift build "${build_arguments[@]}" --show-bin-path)"
app_path="$project_root/dist/Power Watcher.app"
mkdir -p "$app_path/Contents/MacOS" "$app_path/Contents/Resources"
cp "$binary_directory/PowerWatcher" "$app_path/Contents/MacOS/PowerWatcher"
cp Resources/Info.plist "$app_path/Contents/Info.plist"
cp Resources/PrivacyInfo.xcprivacy "$app_path/Contents/Resources/PrivacyInfo.xcprivacy"
iconset_path="$project_root/.build/AppIcon.iconset"
xcrun swift scripts/make-icon.swift "$iconset_path"
iconutil --convert icns "$iconset_path" --output "$app_path/Contents/Resources/AppIcon.icns"
codesign --force --sign - "$app_path"
codesign --verify --strict "$app_path"
echo "Built: $app_path"

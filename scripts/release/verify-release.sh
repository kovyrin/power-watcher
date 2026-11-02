#!/bin/bash
set -euo pipefail
fail() { echo "release verification: $*" >&2; exit 65; }
expect() { [[ "$1" == "$2" ]] || fail "$3"; }
development=0
if [[ "${1:-}" == --development ]]; then development=1; shift; fi
[[ $# == 1 ]] || { echo "Usage: $0 [--development] DIRECTORY" >&2; exit 64; }
directory="$(cd "$1" && pwd)"
suffix=""
[[ "$development" == 0 ]] || suffix="-development"
info="$directory/release-info$suffix.json"
version=$(/usr/bin/plutil -extract version raw -o - "$info")
[[ "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || { echo "Invalid release version" >&2; exit 65; }
image="$directory/PowerWatcher-v$version-macos-universal$suffix.dmg"
if [[ "$development" == 0 ]]; then
  [[ "$(/usr/bin/plutil -extract notarized raw -o - "$info")" == true ]] || {
    echo "release verification: notarized production artifacts required" >&2; exit 65;
  }
fi
(
  cd "$directory"
  /usr/bin/shasum -a 256 --check "checksums$suffix.txt"
)
/usr/bin/hdiutil verify "$image" >/dev/null
if [[ "$development" == 0 ]]; then
  /usr/bin/codesign --verify --strict "$image"
  /usr/bin/xcrun stapler validate "$image"
  /usr/sbin/spctl --assess --type open --context context:primary-signature --verbose "$image"
fi
mount_directory=$(/usr/bin/mktemp -d "${TMPDIR:-/tmp}/power-watcher-mount.XXXXXX")
mounted=0
cleanup() {
  if [[ "$mounted" == 1 ]]; then /usr/bin/hdiutil detach "$mount_directory" >/dev/null; fi
  /bin/rmdir "$mount_directory" 2>/dev/null || true
}
trap cleanup EXIT
/usr/bin/hdiutil attach -readonly -nobrowse -mountpoint "$mount_directory" "$image" >/dev/null
mounted=1
app="$mount_directory/Power Watcher.app"
binary="$app/Contents/MacOS/PowerWatcher"
expect "$(/usr/libexec/PlistBuddy -c 'Print CFBundleIdentifier' "$app/Contents/Info.plist")" \
  com.kovyrin.PowerWatcher 'wrong bundle identifier'
expect "$(/usr/libexec/PlistBuddy -c 'Print CFBundleShortVersionString' "$app/Contents/Info.plist")" \
  "$version" 'wrong bundle version'
expect "$(/usr/libexec/PlistBuddy -c 'Print LSMinimumSystemVersion' "$app/Contents/Info.plist")" \
  26.0 'wrong minimum macOS version'
expect "$(/usr/bin/readlink "$mount_directory/Applications")" /Applications 'wrong Applications shortcut'
/usr/bin/lipo "$binary" -verify_arch arm64 || fail 'arm64 slice missing'
/usr/bin/lipo "$binary" -verify_arch x86_64 || fail 'x86_64 slice missing'
/usr/bin/xcrun vtool -show-build "$binary" | /usr/bin/awk '
  $1 == "minos" { count++; if ($2 != "26.0") invalid = 1 }
  END { exit (invalid || count != 2) }
' || fail 'binary deployment targets must both be macOS 26.0'
/usr/bin/codesign --verify --deep --strict "$app" || fail 'invalid app signature'
if [[ "$development" == 0 ]]; then
  /usr/bin/codesign -dv --verbose=4 "$app" 2>&1 | /usr/bin/grep -q '^Authority=Developer ID Application:'
  /usr/bin/xcrun stapler validate "$app"
  /usr/sbin/spctl --assess --type execute --verbose "$app"
  /usr/bin/syspolicy_check distribution "$app"
fi
echo "Release verification passed (macOS 26+, arm64 + x86_64)."

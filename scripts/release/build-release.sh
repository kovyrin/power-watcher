#!/bin/bash
set +x
set -euo pipefail
umask 077
project_root="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$project_root"
development=0
case "${1:-}" in
  --development) development=1 ;;
  "") ;;
  -h|--help)
    echo "Usage: $0 [--development]"
    echo "Production: Developer ID identity plus a notary profile or API key are required."
    exit 0 ;;
  *) echo "Usage: $0 [--development]" >&2; exit 64 ;;
esac
version=$(/usr/libexec/PlistBuddy -c 'Print CFBundleShortVersionString' Resources/Info.plist)
[[ "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || { echo "Invalid app version" >&2; exit 65; }
commit=$(git rev-parse HEAD)
if [[ "$development" == 0 ]]; then
  [[ -z "$(git status --porcelain)" ]] || { echo "release build: commit source changes first" >&2; exit 65; }
  "$project_root/scripts/release/extract-notes.sh" "$version" >/dev/null
  if [[ -z "${POWER_WATCHER_SIGNING_KEYCHAIN:-}" &&
        -n "${POWER_WATCHER_CODESIGN_CERT_P12_BASE64:-}${POWER_WATCHER_CODESIGN_CERT_P12_PATH:-}" ]]; then
    exec "$project_root/scripts/release/with-signing-keychain.sh" "$0"
  fi
  "$project_root/scripts/release/check-signing-env.sh"
fi

temporary=$(/usr/bin/mktemp -d "${TMPDIR:-/tmp}/power-watcher-release.XXXXXX")
trap '/bin/rm -rf "$temporary"' EXIT
trap 'exit 130' INT
trap 'exit 143' TERM
output="$project_root/dist/releases/v$version"
mkdir -p "$output"
suffix=""
[[ "$development" == 0 ]] || suffix="-development"
artifact="PowerWatcher-v$version-macos-universal$suffix.dmg"
image="$output/$artifact"
app="$temporary/build/Power Watcher.app"

# Compilers and build scripts do not need signing passwords or notary keys.
(
  unset POWER_WATCHER_CODESIGN_CERT_P12_BASE64 POWER_WATCHER_CODESIGN_CERT_P12_PATH
  unset POWER_WATCHER_CODESIGN_CERT_PASSWORD POWER_WATCHER_NOTARY_KEY
  unset POWER_WATCHER_NOTARY_KEY_ID POWER_WATCHER_NOTARY_ISSUER_ID
  export POWER_WATCHER_BUILD_OUTPUT="$temporary/build"
  ./scripts/build-app.sh --universal
)
keychain_arguments=()
notary_arguments=()
if [[ "$development" == 0 ]]; then
  if [[ -n "${POWER_WATCHER_SIGNING_KEYCHAIN:-}" ]]; then
    keychain_arguments=(--keychain "$POWER_WATCHER_SIGNING_KEYCHAIN")
  fi
  if [[ -n "${POWER_WATCHER_NOTARY_PROFILE:-}" ]]; then
    notary_arguments=(--keychain-profile "$POWER_WATCHER_NOTARY_PROFILE")
  else
    notary_key_path="$POWER_WATCHER_NOTARY_KEY"
    if [[ ! -f "$notary_key_path" ]]; then
      notary_key_path="$temporary/notary-key.p8"
      printf '%s\n' "$POWER_WATCHER_NOTARY_KEY" > "$notary_key_path"
    fi
    notary_arguments=(--key "$notary_key_path" --key-id "$POWER_WATCHER_NOTARY_KEY_ID"
                      --issuer "$POWER_WATCHER_NOTARY_ISSUER_ID")
  fi
  (
    umask 022
    /usr/bin/codesign --force --sign "$POWER_WATCHER_CODESIGN_IDENTITY" \
      ${keychain_arguments[@]+"${keychain_arguments[@]}"} --options runtime --timestamp \
      --entitlements Resources/PowerWatcher.entitlements "$app"
  )
  /usr/bin/codesign --verify --deep --strict "$app"
  # Local preflight is advisory. Apple's notary verdict and the final stapled
  # app/DMG Gatekeeper assessments remain mandatory publication gates.
  if ! /usr/bin/syspolicy_check notary-submission "$app"; then
    echo "Local pre-notarization diagnostic failed; requesting Apple's authoritative verdict."
  fi
fi

notarize() {
  local file="$1" label="$2" result="$temporary/$2-notarization.json"
  local staple_target="${3:-$1}" status submission
  mkdir -p "$project_root/dist/notarization/v$version"
  /usr/bin/xcrun notarytool submit "$file" "${notary_arguments[@]}" \
    --no-wait --output-format json > "$result"
  submission=$(/usr/bin/plutil -extract id raw -o - "$result")
  /bin/cp "$result" "$project_root/dist/notarization/v$version/$label.json"
  echo "Waiting for Apple notarization: $label ($submission)"
  /usr/bin/xcrun notarytool wait "$submission" "${notary_arguments[@]}" \
    --timeout 30m --output-format json > "$result"
  /bin/cp "$result" "$project_root/dist/notarization/v$version/$label.json"
  status=$(/usr/bin/plutil -extract status raw -o - "$result")
  [[ "$status" == Accepted ]] || {
    /usr/bin/xcrun notarytool log "$submission" "${notary_arguments[@]}" \
      "$project_root/dist/notarization/v$version/$label-log.json" || true
    echo "Notarization $status: see dist/notarization/v$version" >&2
    exit 1
  }
  /usr/bin/xcrun stapler staple "$staple_target"
  /usr/bin/xcrun stapler validate "$staple_target"
}

if [[ "$development" == 0 ]]; then
  /usr/bin/ditto -c -k --keepParent "$app" "$temporary/app.zip"
  # Staple the app before packaging, so the installed copy also carries a ticket.
  notarize "$temporary/app.zip" app "$app"
fi
/bin/chmod -R u+rwX,go+rX "$app"
/usr/bin/codesign --verify --deep --strict "$app"
mkdir -p "$temporary/dmg"
/bin/chmod 755 "$temporary/dmg"
/usr/bin/ditto "$app" "$temporary/dmg/Power Watcher.app"
/bin/ln -s /Applications "$temporary/dmg/Applications"
/usr/bin/hdiutil create -volname "Power Watcher $version" -srcfolder "$temporary/dmg" \
  -format UDZO -ov "$image" >/dev/null
if [[ "$development" == 0 ]]; then
  /usr/bin/codesign --force --sign "$POWER_WATCHER_CODESIGN_IDENTITY" \
    ${keychain_arguments[@]+"${keychain_arguments[@]}"} --timestamp --identifier com.kovyrin.PowerWatcher.dmg "$image"
  notarize "$image" dmg
fi
notarized=true
[[ "$development" == 0 ]] || notarized=false
printf '{"version":"%s","commit":"%s","minimum_macos":"26.0","architectures":["arm64","x86_64"],"notarized":%s}\n' \
  "$version" "$commit" "$notarized" > "$output/release-info$suffix.json"
(
  cd "$output"
  /usr/bin/shasum -a 256 "$artifact" "release-info$suffix.json" > "checksums$suffix.txt"
)
if [[ "$development" == 1 ]]; then
  "$project_root/scripts/release/verify-release.sh" --development "$output"
else
  "$project_root/scripts/release/verify-release.sh" "$output"
fi
echo "Built release artifact: $image"

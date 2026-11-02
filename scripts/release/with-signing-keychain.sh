#!/bin/bash
set +x
set -euo pipefail
umask 077

[[ $# -gt 0 ]] || { echo "Usage: $0 COMMAND [ARG...]" >&2; exit 64; }
if [[ -z "${POWER_WATCHER_CODESIGN_CERT_P12_BASE64:-}${POWER_WATCHER_CODESIGN_CERT_P12_PATH:-}" ]]; then
  exec "$@"
fi
[[ -n "${POWER_WATCHER_CODESIGN_CERT_PASSWORD:-}" ]] || {
  echo "signing keychain: POWER_WATCHER_CODESIGN_CERT_PASSWORD is required" >&2
  exit 78
}

# Same ephemeral-keychain method as Agent Secret's release workflow. No changes
# to the default keychain or the persistent keychain search list are needed.
signing_directory=$(/usr/bin/mktemp -d "${TMPDIR:-/tmp}/power-watcher-signing.XXXXXX")
signing_keychain="$signing_directory/signing.keychain-db"
cleanup() {
  /usr/bin/security delete-keychain "$signing_keychain" >/dev/null 2>&1 || true
  /bin/rm -rf "$signing_directory"
}
trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM
keychain_password=$(/usr/bin/uuidgen)
certificate_path="${POWER_WATCHER_CODESIGN_CERT_P12_PATH:-}"
if [[ -n "${POWER_WATCHER_CODESIGN_CERT_P12_BASE64:-}" ]]; then
  certificate_path="$signing_directory/certificate.p12"
  printf '%s' "$POWER_WATCHER_CODESIGN_CERT_P12_BASE64" | /usr/bin/base64 --decode > "$certificate_path"
fi
[[ -f "$certificate_path" ]] || { echo "signing keychain: certificate file not found" >&2; exit 66; }
/usr/bin/security create-keychain -p "$keychain_password" "$signing_keychain"
/usr/bin/security set-keychain-settings -lut 21600 "$signing_keychain"
/usr/bin/security unlock-keychain -p "$keychain_password" "$signing_keychain"
/usr/bin/security import "$certificate_path" -k "$signing_keychain" \
  -P "$POWER_WATCHER_CODESIGN_CERT_PASSWORD" -T /usr/bin/codesign >/dev/null
/usr/bin/security set-key-partition-list -S apple-tool:,apple:,codesign: \
  -s -k "$keychain_password" "$signing_keychain" >/dev/null
export POWER_WATCHER_SIGNING_KEYCHAIN="$signing_keychain"
if [[ -z "${POWER_WATCHER_CODESIGN_IDENTITY:-}" ]]; then
  POWER_WATCHER_CODESIGN_IDENTITY=$(/usr/bin/security find-identity -v -p codesigning "$signing_keychain" |
    /usr/bin/awk -F '"' '/"Developer ID Application:/ { print $2 }')
  [[ -n "$POWER_WATCHER_CODESIGN_IDENTITY" && "$POWER_WATCHER_CODESIGN_IDENTITY" != *$'\n'* ]] || {
    echo "signing keychain: expected exactly one valid Developer ID Application identity" >&2; exit 78;
  }
  export POWER_WATCHER_CODESIGN_IDENTITY
fi
unset POWER_WATCHER_CODESIGN_CERT_P12_BASE64 POWER_WATCHER_CODESIGN_CERT_P12_PATH
unset POWER_WATCHER_CODESIGN_CERT_PASSWORD keychain_password
"$@"

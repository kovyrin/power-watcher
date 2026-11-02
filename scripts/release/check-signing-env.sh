#!/bin/bash
set +x
set -euo pipefail

fail() { echo "release signing: $*" >&2; exit 78; }

[[ "${POWER_WATCHER_CODESIGN_IDENTITY:-}" == "Developer ID Application: "* ]] ||
  fail "POWER_WATCHER_CODESIGN_IDENTITY must be a Developer ID Application identity"

if [[ -n "${POWER_WATCHER_CODESIGN_CERT_P12_BASE64:-}${POWER_WATCHER_CODESIGN_CERT_P12_PATH:-}" ]]; then
  [[ -n "${POWER_WATCHER_CODESIGN_CERT_PASSWORD:-}" ]] ||
    fail "POWER_WATCHER_CODESIGN_CERT_PASSWORD is required for certificate import"
elif [[ "${1:-}" == "--require-certificate" ]]; then
  fail "POWER_WATCHER_CODESIGN_CERT_P12_BASE64 or POWER_WATCHER_CODESIGN_CERT_P12_PATH is required"
fi

if [[ -n "${POWER_WATCHER_NOTARY_PROFILE:-}" ]]; then
  exit 0
fi
[[ -n "${POWER_WATCHER_NOTARY_KEY:-}" ]] ||
  fail "set POWER_WATCHER_NOTARY_PROFILE or POWER_WATCHER_NOTARY_KEY"
[[ -n "${POWER_WATCHER_NOTARY_KEY_ID:-}" ]] || fail "POWER_WATCHER_NOTARY_KEY_ID is required"
[[ -n "${POWER_WATCHER_NOTARY_ISSUER_ID:-}" ]] || fail "POWER_WATCHER_NOTARY_ISSUER_ID is required"

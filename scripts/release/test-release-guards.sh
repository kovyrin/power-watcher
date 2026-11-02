#!/bin/bash
set -euo pipefail
project_root="$(cd "$(dirname "$0")/../.." && pwd)"
temporary=$(mktemp -d "${TMPDIR:-/tmp}/power-watcher-guards.XXXXXX")
trap 'rm -rf "$temporary"' EXIT
checks=0
reject() {
  local expected="$1"; shift
  if "$@" > "$temporary/output" 2>&1; then
    echo "Expected refusal: $expected" >&2; exit 1
  fi
  if ! /usr/bin/grep -F "$expected" "$temporary/output" >/dev/null; then
    cat "$temporary/output" >&2; exit 1
  fi
  checks=$((checks + 1))
}
check="$project_root/scripts/release/check-signing-env.sh"
base=(/usr/bin/env -i PATH=/usr/bin:/bin:/usr/sbin:/sbin)
reject 'Developer ID Application identity' "${base[@]}" "$check"
reject 'Developer ID Application identity' "${base[@]}" \
  'POWER_WATCHER_CODESIGN_IDENTITY=Apple Development: Test' "$check"
reject 'set POWER_WATCHER_NOTARY_PROFILE' "${base[@]}" \
  'POWER_WATCHER_CODESIGN_IDENTITY=Developer ID Application: Test (EXAMPLE)' "$check"
reject 'CERT_PASSWORD is required' "${base[@]}" \
  'POWER_WATCHER_CODESIGN_IDENTITY=Developer ID Application: Test (EXAMPLE)' \
  POWER_WATCHER_CODESIGN_CERT_P12_BASE64=synthetic "$check"
reject 'P12_PATH is required' "${base[@]}" \
  'POWER_WATCHER_CODESIGN_IDENTITY=Developer ID Application: Test (EXAMPLE)' \
  POWER_WATCHER_NOTARY_PROFILE=synthetic "$check" --require-certificate
"${base[@]}" 'POWER_WATCHER_CODESIGN_IDENTITY=Developer ID Application: Test (EXAMPLE)' \
  POWER_WATCHER_NOTARY_PROFILE=synthetic "$check"
checks=$((checks + 1))
reject 'KEY_ID is required' "${base[@]}" \
  'POWER_WATCHER_CODESIGN_IDENTITY=Developer ID Application: Test (EXAMPLE)' \
  POWER_WATCHER_NOTARY_KEY=synthetic "$check"
"${base[@]}" 'POWER_WATCHER_CODESIGN_IDENTITY=Developer ID Application: Test (EXAMPLE)' \
  POWER_WATCHER_NOTARY_KEY=synthetic POWER_WATCHER_NOTARY_KEY_ID=synthetic \
  POWER_WATCHER_NOTARY_ISSUER_ID=synthetic "$check"
checks=$((checks + 1))
reject 'expected X.Y.Z' "$project_root/scripts/release/extract-notes.sh" '../invalid'
printf '# Changelog\n\n## [1.2.3] - Pending\n\n- Example\n' > "$temporary/notes"
if "$project_root/scripts/release/extract-notes.sh" 1.2.3 "$temporary/notes" >/dev/null 2>&1; then
  echo 'Pending notes must be rejected' >&2; exit 1
fi
checks=$((checks + 1))
printf '# Changelog\n\n## [1.2.3] - 2026-11-02\n\n- Example\n\n## [1.2.2] - 2026-11-01\n\n- Older\n' > "$temporary/notes"
"$project_root/scripts/release/extract-notes.sh" 1.2.3 "$temporary/notes" > "$temporary/extracted"
/usr/bin/grep -F Example "$temporary/extracted" >/dev/null
if /usr/bin/grep -F Older "$temporary/extracted" >/dev/null; then exit 1; fi
checks=$((checks + 1))
printf '{"version":"0.1.0","notarized":false}\n' > "$temporary/release-info.json"
reject 'notarized production artifacts required' "$project_root/scripts/release/verify-release.sh" "$temporary"
printf '{"version":"0.1.0","notarized":true}\n' > "$temporary/release-info.json"
printf 'synthetic damaged download\n' > "$temporary/PowerWatcher-v0.1.0-macos-universal.dmg"
printf '%064d  PowerWatcher-v0.1.0-macos-universal.dmg\n' 0 > "$temporary/checksums.txt"
reject 'FAILED' "$project_root/scripts/release/verify-release.sh" "$temporary"
echo "Release guard checks passed ($checks cases; synthetic credentials only)."

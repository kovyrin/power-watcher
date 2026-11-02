#!/bin/bash
set +x
set -euo pipefail
umask 077
project_root="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$project_root"
original_arguments=("$@")
certificate_ref="${POWER_WATCHER_CERTIFICATE_REF:-}"
credentials_ready=0
publish=0
while [[ $# -gt 0 ]]; do
  case "$1" in
    --certificate-ref)
      [[ $# -ge 2 ]] || { echo '--certificate-ref needs an exact op:// file reference' >&2; exit 64; }
      certificate_ref="$2"; shift 2 ;;
    --credentials-ready) credentials_ready=1; shift ;;
    --publish) publish=1; shift ;;
    -h|--help)
      echo "Usage: $0 [--certificate-ref op://VAULT/ITEM/FILE.p12] [--publish]"
      echo 'Uses an optional ignored .agent-secret.release.yml profile named release.'
      echo 'Otherwise provide the documented signing/notary environment variables.'
      exit 0 ;;
    *) echo "Unknown release option: $1" >&2; exit 64 ;;
  esac
done
if [[ "$credentials_ready" == 0 && -f .agent-secret.release.yml ]]; then
  exec agent-secret exec --force-refresh --config .agent-secret.release.yml --profile release -- \
    /bin/bash "$0" --credentials-ready ${original_arguments[@]+"${original_arguments[@]}"}
fi
temporary=$(/usr/bin/mktemp -d "${TMPDIR:-/tmp}/power-watcher-local-release.XXXXXX")
trap '/bin/rm -rf "$temporary"' EXIT
trap 'exit 130' INT
trap 'exit 143' TERM
if [[ -n "$certificate_ref" ]]; then
  [[ "$certificate_ref" == op://* ]] || { echo 'Certificate reference must start with op://' >&2; exit 64; }
  # Binary attachments cannot use Agent Secret's text-only env transport.
  # The operator supplies this exact file ref; no item/vault search is performed.
  (
    unset POWER_WATCHER_CODESIGN_CERT_PASSWORD POWER_WATCHER_NOTARY_KEY
    unset POWER_WATCHER_NOTARY_KEY_ID POWER_WATCHER_NOTARY_ISSUER_ID
    op read --out-file "$temporary/certificate.p12" --file-mode 0600 "$certificate_ref" >/dev/null
  )
  export POWER_WATCHER_CODESIGN_CERT_P12_PATH="$temporary/certificate.p12"
fi
"$project_root/scripts/release/build-release.sh"
if [[ "$publish" == 1 ]]; then
  "$project_root/scripts/release/publish-release.sh" --publish
else
  "$project_root/scripts/release/publish-release.sh"
fi

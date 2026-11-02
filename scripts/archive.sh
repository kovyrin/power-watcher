#!/bin/bash
set -euo pipefail

project_root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$project_root"
signing_arguments=()
archive_name="PowerWatcher"
case "${1:-}" in
  --unsigned)
    signing_arguments+=(CODE_SIGNING_ALLOWED=NO)
    archive_name="PowerWatcher-unsigned"
    ;;
  "")
    if [[ -z "${DEVELOPMENT_TEAM:-}" ]]; then
      echo "Set DEVELOPMENT_TEAM to your Apple Developer team ID, or use --unsigned for a local check." >&2
      exit 64
    fi
    signing_arguments+=("DEVELOPMENT_TEAM=$DEVELOPMENT_TEAM")
    ;;
  *) echo "Usage: DEVELOPMENT_TEAM=TEAMID $0 [--unsigned]" >&2; exit 64 ;;
esac

xcodebuild -project PowerWatcher.xcodeproj -scheme PowerWatcher \
  -configuration Release -destination 'generic/platform=macOS' \
  -derivedDataPath .build/xcode -archivePath "dist/$archive_name.xcarchive" \
  "${signing_arguments[@]}" archive
echo "Archive: $project_root/dist/$archive_name.xcarchive"

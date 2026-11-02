#!/bin/bash
set -euo pipefail
project_root="$(cd "$(dirname "$0")/../.." && pwd)"
version="${1:-}"
[[ "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || {
  echo "release notes: expected X.Y.Z" >&2; exit 64;
}
/usr/bin/awk -v version="$version" '
  $0 ~ /^## / && active { exit }
  index($0, "## [" version "] - ") == 1 {
    date = substr($0, length("## [" version "] - ") + 1)
    if (date !~ /^[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]$/) exit 1
    active = 1
    print
    next
  }
  active { print; if ($0 ~ /[^[:space:]]/) body = 1 }
  END { if (!active || !body) exit 1 }
' "${2:-$project_root/CHANGELOG.md}"

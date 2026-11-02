#!/bin/bash
set -euo pipefail
project_root="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$project_root"
publish=0
case "${1:-}" in
  --publish) publish=1 ;;
  "") ;;
  *) echo "Usage: $0 [--publish]" >&2; exit 64 ;;
esac
[[ -z "$(git status --porcelain)" ]] || { echo "release publish: commit source changes first" >&2; exit 65; }
version=$(/usr/libexec/PlistBuddy -c 'Print CFBundleShortVersionString' Resources/Info.plist)
[[ "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || exit 65
tag="v$version"
directory="$project_root/dist/releases/$tag"
head=$(git rev-parse HEAD)
repository="${POWER_WATCHER_GITHUB_REPOSITORY:-kovyrin/power-watcher}"
"$project_root/scripts/release/verify-release.sh" "$directory"
[[ "$(/usr/bin/plutil -extract commit raw -o - "$directory/release-info.json")" == "$head" ]] || {
  echo "release publish: artifacts were built from another commit" >&2; exit 65;
}
git fetch origin main --no-tags
[[ "$head" == "$(git rev-parse origin/main)" ]] || {
  echo "release publish: HEAD must equal origin/main" >&2; exit 65;
}
ci_success=$(gh run list --repo "$repository" --workflow ci.yml --branch main --commit "$head" \
  --json status,conclusion --jq '[.[] | select(.status == "completed" and .conclusion == "success")] | length')
[[ "$ci_success" -gt 0 ]] || { echo "release publish: CI must pass for this commit" >&2; exit 65; }
notes="$project_root/.build/release-notes.txt"
"$project_root/scripts/release/extract-notes.sh" "$version" > "$notes"
if [[ -n "$(git ls-remote origin "refs/tags/$tag")" ]]; then
  [[ "$(gh api "repos/$repository/commits/$tag" --jq .sha)" == "$head" ]] || {
    echo "release publish: tag already targets another commit" >&2; exit 65;
  }
else
  # API authentication works both with the local gh login and a repository-
  # scoped Actions token; checkout need not persist Git credentials.
  gh api --method POST "repos/$repository/git/refs" \
    -f "ref=refs/tags/$tag" -f "sha=$head" >/dev/null
fi
if gh release view "$tag" --repo "$repository" >/dev/null 2>&1; then
  [[ "$(gh release view "$tag" --repo "$repository" --json isDraft --jq .isDraft)" == true ]] || {
    echo "release publish: refusing to replace a published release" >&2; exit 65;
  }
  gh release edit "$tag" --repo "$repository" --title "Power Watcher $version" --notes-file "$notes"
  gh release upload "$tag" --repo "$repository" --clobber \
    "$directory/PowerWatcher-$tag-macos-universal.dmg" "$directory/checksums.txt" "$directory/release-info.json"
else
  gh release create "$tag" --repo "$repository" --draft --verify-tag \
    --title "Power Watcher $version" --notes-file "$notes" \
    "$directory/PowerWatcher-$tag-macos-universal.dmg" "$directory/checksums.txt" "$directory/release-info.json"
fi
if [[ "$publish" == 1 ]]; then
  gh release edit "$tag" --repo "$repository" --draft=false --latest
fi
gh release view "$tag" --repo "$repository" --json url,isDraft,assets

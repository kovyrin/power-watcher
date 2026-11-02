.PHONY: app universal test lint check smoke archive package icons release-test release-build release-push release-local

app:
	./scripts/build-app.sh

universal:
	./scripts/build-app.sh --universal

test:
	swift test
	./scripts/release/test-release-guards.sh

lint:
	npx --yes markdownlint-cli '**/*.md' --ignore node_modules --ignore .build --ignore dist
	@find scripts -name '*.sh' -print0 | xargs -0 -n 1 bash -n
	plutil -lint Resources/Info.plist Resources/PrivacyInfo.xcprivacy Resources/PowerWatcher.entitlements

check: test lint

smoke: app
	"dist/Power Watcher.app/Contents/MacOS/PowerWatcher" --self-check

archive:
	./scripts/archive.sh

package:
	./scripts/package-app.sh

icons:
	xcrun swift scripts/make-icon.swift Resources/Assets.xcassets/AppIcon.appiconset

release-build:
	./scripts/release/build-release.sh

release-test:
	./scripts/release/test-release-guards.sh

release-push:
	./scripts/release/publish-release.sh

release-local:
	./scripts/release/local-release.sh

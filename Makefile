.PHONY: app universal test lint check smoke archive package icons

app:
	./scripts/build-app.sh

universal:
	./scripts/build-app.sh --universal

test:
	swift test

lint:
	npx --yes markdownlint-cli '**/*.md' --ignore node_modules --ignore .build --ignore dist
	@for script in scripts/*.sh; do bash -n "$$script" || exit; done
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

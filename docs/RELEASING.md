# Releasing

The development ZIP is ad-hoc signed. It is not a Mac App Store submission or
a notarized public download.

## Local signed DMG and GitHub publication

Requires macOS 26+, Xcode 26+ with Swift 6.2, and the GitHub CLI authenticated for
the target repository. Commit and push source changes, then wait for CI to pass.

```sh
make check
./scripts/release/build-release.sh --development
```

The development flag tests DMG assembly, mounting, architecture, deployment
targets, checksums, and code-signature integrity without release credentials.
Its filenames include `-development`; it cannot be published by the production
publisher. It is not a public download.

Production signing accepts these environment variables, delivered by your
preferred secret manager or CI. Never put resolved values in repository files:

| Variable | Purpose |
| --- | --- |
| `POWER_WATCHER_CODESIGN_IDENTITY` | Developer ID Application identity |
| `POWER_WATCHER_CODESIGN_CERT_P12_PATH` | Optional local certificate file |
| `POWER_WATCHER_CODESIGN_CERT_P12_BASE64` | Base64 certificate |
| `POWER_WATCHER_CODESIGN_CERT_PASSWORD` | Password for certificate import |
| `POWER_WATCHER_NOTARY_PROFILE` | Existing notarytool Keychain profile |
| `POWER_WATCHER_NOTARY_KEY` | API private key contents or local `.p8` path |
| `POWER_WATCHER_NOTARY_KEY_ID` | App Store Connect team API key ID |
| `POWER_WATCHER_NOTARY_ISSUER_ID` | App Store Connect team API issuer ID |

Use either a notary profile or all three API key variables. A provided `.p12`
is imported into a temporary keychain, which is deleted on exit. The identity
can be detected from that certificate if omitted. Without a `.p12`, the named
Developer ID identity must already exist in a usable keychain. Apple Development
and ad-hoc identities are rejected.

For an optional Agent Secret integration, create an ignored
`.agent-secret.release.yml` with a `release` profile that maps the password and
notary aliases above to your exact refs. No private ref names are included in
the public repository. The local wrapper invokes that profile and reads only
the binary certificate ref explicitly supplied on the command line:

```sh
./scripts/release/local-release.sh \
  --certificate-ref 'op://Example/Release Certificate/certificate.p12'
```

This uses Agent Secret for text credentials and `op read --out-file` only for the
operator-selected binary attachment. It performs no vault search. The `.p12`,
API-key file, and imported keychain are private temporary files removed on exit.
Without the optional config file, the same wrapper uses credentials supplied by
another environment-based secret manager. Add `--publish` to make the verified
release public after building it; otherwise it uploads a draft.

```sh
./scripts/release/build-release.sh
./scripts/release/publish-release.sh
# After reviewing the verified draft, publish explicitly:
./scripts/release/publish-release.sh --publish
```

The builder creates `dist/releases/vVERSION/` containing a DMG, `checksums.txt`,
and `release-info.json`. The app is sandboxed, signed with Hardened Runtime and
a secure timestamp, notarized and stapled before DMG creation. The DMG is also
signed, notarized, stapled, mounted read-only, and checked with Gatekeeper.
Notarization receipts stay in ignored `dist/notarization/`.

Publication requires a clean checkout at current `origin/main`, passing CI for
that exact commit, artifact/source commit agreement, dated nonempty changelog
notes, and a matching version tag. It creates the tag through the GitHub API if
needed, uploads a draft, and refuses to replace a published release. Only
`--publish` makes it public. Download the published assets again and verify their
checksums before announcing the release.

## Optional GitHub signing workflow

The manual **Signed DMG** workflow follows the same temporary-keychain approach
used by [Agent Secret](https://github.com/kovyrin/agent-secret). It is independent
of that repository and uses only this repository's GitHub Secrets. Configure the
certificate base64/password/identity and three API-key variables from the table
above as repository secrets, retaining their `POWER_WATCHER_` names.

```sh
gh workflow run release.yml --ref main
```

This workflow checks source without secrets, validates signing inputs, then
builds and verifies production artifacts before creating a draft. It never
reads a password vault or automatically publishes. Existing secrets in another
repository are not implicitly available here and cannot be copied through the
GitHub secrets read API. Supply them through an authorized original source.

## Validate a candidate

```sh
npm ci
make check
make smoke
make universal
lipo "dist/Power Watcher.app/Contents/MacOS/PowerWatcher" -verify_arch arm64
lipo "dist/Power Watcher.app/Contents/MacOS/PowerWatcher" -verify_arch x86_64
make package
./scripts/archive.sh --unsigned
```

Use a clean checkout. Inspect the app, archive, manifest, entitlements, and icons.
Check the ZIP against its SHA-256 file. An unsigned archive cannot be uploaded.

Before release, verify on real Macs:

- Each preview, Stop, expiry, and keyboard navigation.
- Clicking and typing through edges while another app keeps focus.
- Full-screen apps, Spaces, Stage Manager, display changes, and sleep/wake.
- Connecting power, charging paused, monitoring disabled, and Reduce Motion.
- Actual 3%, 2%, and 1% battery transitions as practical; distinguish these from
  simulated checks.
- Battery reads and overlays in a sandboxed build.
- Login startup, approval, and unregistering from the final installed location.
- Apple silicon and Intel; a universal binary alone does not validate both Macs.

## Mac App Store

Apple requires sandboxing and Xcode-based packaging. See
[App Review Guidelines 2.4.5](https://developer.apple.com/app-store/review/guidelines/)
and [App Sandbox](https://developer.apple.com/documentation/xcode/configuring-the-macos-app-sandbox).

The project includes an Xcode target/shared scheme, sandbox entitlements, Utilities
category, original icon assets, and a privacy manifest. `UserDefaults` uses reason
`CA92.1` for the app's own preferences; see
[Apple's required-reason API documentation](https://developer.apple.com/documentation/bundleresources/app-privacy-configuration/nsprivacyaccessedapitypes/nsprivacyaccessedapitype).
No network or file-access entitlements are enabled.

Remaining account and release steps:

1. Confirm Apple Developer Program membership and App Store Connect access.
2. Select a signing team in Xcode. Confirm `com.kovyrin.PowerWatcher` is available
   and register it as an explicit App ID. If changed, update the Xcode project
   and plist before the first upload. Keep signing material and team IDs out of
   Git.
3. Create the App Store Connect record, confirm name availability, and choose
   pricing/availability. The repository does not reserve a store name.
4. Review version/build numbers in the plist and Xcode settings; increment the
   build number for each upload. Finalize the changelog.
5. Complete privacy and age-rating questionnaires against the actual binary.
   The current app does not collect data.
6. Set the public [privacy policy](../PRIVACY.md) and [support page](../SUPPORT.md)
   as metadata URLs, or host equivalents. Apple requires a privacy URL; see
   [App Privacy](https://developer.apple.com/help/app-store-connect/reference/app-information/app-privacy/).
7. Capture clean screenshots at App Store Connect's requested dimensions and
   finalize [listing copy](APP_STORE.md). The README screenshot is simulated and
   is not a finished store asset.
8. Test a properly signed sandboxed build, including IOKit, overlays, login
   registration, and supported macOS versions. Inspect entitlements with
   `codesign -d --entitlements -`.
9. Archive and use Xcode Organizer to validate, upload, and submit for review.
   Review approval and timing are not guaranteed.

```sh
DEVELOPMENT_TEAM=YOUR_TEAM_ID ./scripts/archive.sh
```

The script uses locally configured signing assets. It does not upload, register
identifiers automatically, accept agreements, or submit the app. Resolve
provisioning in Xcode first. See
[Preparing your app for distribution](https://developer.apple.com/documentation/xcode/preparing-your-app-for-distribution).

The original icon is generated by `scripts/make-icon.swift`. Do not substitute
SF Symbols for app icons; Apple's
[SF Symbols guidelines](https://developer.apple.com/design/human-interface-guidelines/sf-symbols)
prohibit that use. System symbols are used only within the interface.

## Direct downloads

Use Developer ID signing, Hardened Runtime, notarization, and stapling before
publishing a trusted direct download. `scripts/package-app.sh` only packages
the existing development app; it does not perform distribution signing.

Tag and publish only after the candidate and distribution path are ready. The
manual Signed DMG workflow submits to Apple's automated notary service and
creates a GitHub draft; it does not submit to App Review or publish automatically.

# Security

Power Watcher is pre-release. Fixes target `main` and the latest release once
one exists. There is no guaranteed response time or long-term support schedule.

## Reporting a vulnerability

Use [GitHub's private vulnerability reporting](https://github.com/kovyrin/power-watcher/security/advisories/new).
Include affected versions, impact, and a minimal reproduction. Do not disclose
credentials, signing material, or private user data, and do not open a public
issue for an unpatched vulnerability.

## Design and development

The app has no network client, server, accounts, or telemetry. The Xcode target
uses App Sandbox without network or file-access entitlements. Swift-package
development builds are ad-hoc signed and unsandboxed so opt-in diagnostics can
write artifacts in the workspace.

Never commit certificates, provisioning profiles, App Store Connect keys,
credentials, or environment files. Signing and uploading are maintainer
operations; pull-request CI has read-only repository permissions.

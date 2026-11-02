# Pre-release validation

Local checks performed November 1, 2026, on an Apple silicon Mac:

- Swift policy tests passed (eight test groups, including parameterized cases).
- Markdown, shell syntax, and plist checks passed.
- Documentation-tool dependency audit reported zero known vulnerabilities.
- Universal development app built; both arm64 and x86_64 slices were inspected
  and declare a minimum macOS version of 14.0.
- Xcode produced a universal unsigned application archive.
- An ad-hoc-signed copy with App Sandbox and Hardened Runtime passed GUI
  self-checks, including an actual internal battery read through IOKit.
- Integration checks covered simulated power transitions, preview priority,
  expiry/cancellation, window focus and click-through properties, gradient
  transparency/falloff, and control rendering.
- The owner observed a working on-screen preview. Keyboard navigation was also
  exercised after replacing the default blue focus ring with a subtle outline.

One self-check initially used a fixed 100 ms scheduling margin and failed under
load. It now waits for the expected state with a bounded deadline instead.

These checks do not establish actual 3%/2%/1% delivery, physical shutdown timing,
all display/Spaces/Stage Manager combinations, or Intel hardware operation.
App Store signing, provisioning, login-item behavior in the final signed app,
upload validation, and App Review remain release work. See [Releasing](RELEASING.md).

CI performs a fresh unit/lint run, universal build, and unsigned Xcode archive.
It does not submit an app or claim live-battery validation.

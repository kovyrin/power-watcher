# Contributing

Search [existing issues](https://github.com/kovyrin/power-watcher/issues) before
filing a bug. Discuss larger features in an issue before implementing them.

## Local setup

Use macOS 14+, Xcode 16+ with Swift 6, and a supported Node.js LTS release for
Markdown linting (22.22+, 24.15+, or 26+; CI uses 26).

```sh
npm ci
make check
make smoke
```

Use `PowerWatcher.xcodeproj` for the sandboxed app and Swift Package Manager for
fast policy tests. Keep generated builds, signing material, and personal Xcode
settings out of Git. Regenerate icon PNGs with `make icons` after editing
`scripts/make-icon.swift`.

The npm lockfile and targeted overrides pin patched documentation-tool
dependencies. Recheck `npm audit` and `make lint` when updating them. They are
development-only dependencies and are not included in the app.

## Expectations

- Keep UI state on the main actor and pure battery rules in `PowerWatcherCore`.
- Preserve click-through windows, clear centers, and other apps' keyboard focus.
- Keep previews temporary; never let them reduce a real warning's urgency.
- Respect Reduce Motion and avoid rapid flashing.
- Do not silently add networking, telemetry, permissions, or launch behavior.
- Keep UI labels concise; put explanations in documentation.
- Test changed behavior without simply duplicating implementation.
- Run Markdown lint on every Markdown file you create or change.

## Pull requests

Explain the problem, resulting behavior, and validation. Include privacy-safe
screenshots for UI changes, using simulated data. Identify simulated and actual
hardware results separately. Small, focused changes are easier to review.

Contributions use the project's [MIT license](LICENSE). By contributing, you
confirm you have the right to contribute the work. Follow the
[Code of Conduct](CODE_OF_CONDUCT.md).

# App Store metadata draft

Preparation copy only. Confirm name availability, screenshots, signing, privacy,
age rating, and pricing in App Store Connect before submission.

## Name and subtitle

- Name: **Power Watcher**
- Subtitle: **A clear nudge to plug in**
- Category: **Utilities**
- Language: **English**
- Keywords: `battery,charging,power,focus,reminder,menu bar,low battery`

## Description

Deep in work? Let your screen's edges remind you to plug in.

Power Watcher is a small menu-bar app that adds a gentle amber glow when your
Mac's battery reaches 3%. At 2% it grows stronger. At 1% it becomes a bright red
reminder to connect power.

The center stays clear, and the glow lets clicks and typing pass through.
Connect power and the warning disappears.

- Escalating warnings at 3%, 2%, and 1% battery.
- Edge glows across connected displays.
- Quick previews to try every level.
- Optional steady glow and support for Reduce Motion.
- Optional launch at login.
- No accounts, ads, tracking, or background networking.

Requires macOS 26 or later. Battery readings and shutdown timing depend on your
Mac. Power Watcher provides a reminder and does not prevent shutdown.

## URLs

- Support: <https://github.com/kovyrin/power-watcher/blob/main/SUPPORT.md>
- Privacy: <https://github.com/kovyrin/power-watcher/blob/main/PRIVACY.md>
- Source: <https://github.com/kovyrin/power-watcher>

## App Review notes

Power Watcher is an `LSUIElement` menu-bar utility with no Dock icon. Click the
shield-and-bolt status item for controls. No account or login is required.

Reviewers do not need to drain a battery. Click 3%, 2%, or 1% for a six-second
preview, or use the nine-second sequence. Stop preview removes it immediately.
The center stays transparent; overlay windows ignore mouse events and cannot
take keyboard focus.

Normal warnings require battery power and a reading at 3% or below. Connecting
power clears them. Open at login is off by default and uses `SMAppService` after
user consent. Reduce Motion makes the glow steady.

Supply the release build/version and review contact details privately in App
Store Connect. Do not put private account information in this repository.

# Halo

A free, open-source Dynamic Island for the Mac notch — a lightweight alternative to Alcove, NotchNook, and Atoll, built as a learning project.

Halo lives in and around the MacBook notch. Hover over it and it expands into a hub for media controls, a file shelf, custom volume/brightness HUDs, system stats, and calendar/timer widgets.

> **Status: v1 feature-complete.** Built incrementally as a learning project — the commit history reads as a build log.

<!-- Screenshots: collapsed notch, expanded media card, shelf with files,
     HUD wings mid-volume-change, calendar page, pomodoro ring.
     Drop images into docs/ and reference them here. -->

## Features (v1)

- [x] Notch overlay that expands on hover with Dynamic Island–style animations
- [x] Now Playing: album art, track info, play/pause/skip from the notch — works with any media source (Apple Music, Spotify, browser tabs)
- [x] File shelf: drag files onto the notch to hold them, drag out or AirDrop them; pin items to keep them across restarts
- [x] Custom volume & brightness HUDs replacing the system pop-ups, including monitor-speaker volume over DDC (DisplayPort/HDMI audio, which macOS itself can't control)
- [x] System stats: CPU / GPU / RAM / network, battery & charging flash, AirPods battery
- [x] Calendar page (month grid + per-day events), quick timers with completion ring, and a full Pomodoro timer — running timers stay glanceable in the collapsed notch as live activities

## Principles

- **Native & minimal** — Swift 6 + SwiftUI (AppKit where the overlay needs it). No Electron, no web views.
- **Zero third-party dependencies** — Apple frameworks only, with one audited, vendored exception for Now Playing data (see `Vendor/README.md`).
- **Lightweight** — idle CPU ≈ 0%, small memory footprint; event-driven, not polling.
- **Private by design** — no telemetry, no crash reporters, no network calls. Permissions are requested only when a feature needs them, and each one is documented.

## Privacy & permissions

Halo makes **zero network connections** — no telemetry, no crash reporting, no update checks. Nothing you play, hold, or schedule ever leaves the machine. The only data written to disk: pinned shelf file *paths* and Pomodoro durations, both in the app's own preferences.

Permissions it may ask for, and why:

| Permission | When asked | Why | Scope |
|---|---|---|---|
| **Accessibility** | At launch (for the HUD feature) | An event tap must intercept volume/brightness keys before macOS shows its own HUD | The tap is filtered to system-defined media-key events only — see `MediaKeyTap.swift`; ordinary keystrokes travel on a different event type and never reach Halo's code |
| **Calendar (full access)** | Only when you click "Connect Calendar" | To show your events in the notch | Read-only usage; declining just leaves the calendar page empty |

Private/undocumented API surfaces, in the open (each fails gracefully if a macOS update breaks it):

- **MediaRemote** via the vendored [mediaremote-adapter](Vendor/README.md) — system-wide Now Playing (Apple locked the direct route in macOS 15.4).
- **DisplayServices** — setting built-in display brightness; no public API exists.
- **IOAVService (DDC/CI)** — monitor speaker volume (and brightness, currently flagged off) for external displays; the same route MonitorControl uses.

The app is **not sandboxed**: spawning the media helper and the interfaces above require it. It requests no entitlements beyond that.

## Known limitations

- External-monitor **brightness** via DDC is implemented but currently disabled (`DisplayBrightnessManager.externalBrightnessEnabled`): the LG panel it was tested against accepts DDC audio commands but ignores DDC brightness writes. Monitor-speaker **volume** via DDC works.
- The HUD feature needs the **Accessibility** permission (event tap for media keys only — see `MediaKeyTap.swift` for the filter). Quit Halo and the keys instantly revert to stock macOS behavior.

## Requirements

- A Mac with a notch (MacBook Air 2022+ or MacBook Pro 14"/16" 2021+)
- macOS 14 Sonoma or later
- Xcode 16+ to build from source

## Install (no Xcode needed)

**Homebrew:**

```sh
brew install --cask --no-quarantine spador/halo/halo
```

**Manual:** download `Halo-<version>.zip` from [Releases](https://github.com/Spador/Halo/releases), unzip, drag `Halo.app` into Applications, then clear the download quarantine once (Halo is a personal open-source build, not notarized by Apple):

```sh
xattr -d com.apple.quarantine /Applications/Halo.app
```

On first launch, grant **Accessibility** when prompted — that powers the volume/brightness HUD. Calendar access is only requested if you use the calendar page.

## Build from source

1. Clone the repo and open `Halo.xcodeproj` in Xcode.
2. In **Signing & Capabilities**, select your own team (a free personal Apple ID team works — it keeps permission grants stable across rebuilds).
3. Press **⌘R** to build and run. Nothing but Xcode is required — the one vendored dependency compiles from source during the build.

For daily use, build a Release copy into /Applications:

```sh
xcodebuild -project Halo.xcodeproj -scheme Halo -configuration Release build
cp -R ~/Library/Developer/Xcode/DerivedData/Halo-*/Build/Products/Release/Halo.app /Applications/
```

## License

MIT for Halo's code (see `LICENSE`). The vendored `mediaremote-adapter` remains under its BSD 3-Clause license (see `Vendor/`).

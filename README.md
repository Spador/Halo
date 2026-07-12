# Halo

A free, open-source Dynamic Island for the Mac notch — a lightweight alternative to Alcove, NotchNook, and Atoll, built as a learning project.

Halo lives in and around the MacBook notch. Hover over it and it expands into a hub for media controls, a file shelf, custom volume/brightness HUDs, system stats, and calendar/timer widgets.

> **Status: early development.** Being built incrementally, phase by phase. Nothing below is functional yet unless checked.

## Planned features (v1)

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

## Known limitations

- External-monitor **brightness** via DDC is implemented but currently disabled (`DisplayBrightnessManager.externalBrightnessEnabled`): the LG panel it was tested against accepts DDC audio commands but ignores DDC brightness writes. Monitor-speaker **volume** via DDC works.
- The HUD feature needs the **Accessibility** permission (event tap for media keys only — see `MediaKeyTap.swift` for the filter). Quit Halo and the keys instantly revert to stock macOS behavior.

## Requirements

- A Mac with a notch (MacBook Air 2022+ or MacBook Pro 14"/16" 2021+)
- macOS 14 Sonoma or later
- Xcode 16+ to build from source

## Build from source

1. Clone the repo and open `Halo.xcodeproj` in Xcode.
2. Signing is set to **Sign to Run Locally** — no Apple ID or developer account needed.
3. Press **⌘R** to build and run.

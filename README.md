# Halo

A free, open-source Dynamic Island for the Mac notch — a lightweight alternative to Alcove, NotchNook, and Atoll, built as a learning project.

Halo lives in and around the MacBook notch. Hover over it and it expands into a hub for media controls, a file shelf, custom volume/brightness HUDs, system stats, and calendar/timer widgets.

> **Status: early development.** Being built incrementally, phase by phase. Nothing below is functional yet unless checked.

## Planned features (v1)

- [x] Notch overlay that expands on hover with Dynamic Island–style animations
- [x] Now Playing: album art, track info, play/pause/skip from the notch — works with any media source (Apple Music, Spotify, browser tabs)
- [x] File shelf: drag files onto the notch to hold them, drag out or AirDrop them; pin items to keep them across restarts
- [ ] Custom volume & brightness HUDs replacing the system pop-ups
- [ ] System stats: CPU / GPU / RAM / network, battery & charging, AirPods battery
- [ ] Calendar glance, quick timers, and a Pomodoro timer as notch live activities

## Principles

- **Native & minimal** — Swift 6 + SwiftUI (AppKit where the overlay needs it). No Electron, no web views.
- **Zero third-party dependencies** — Apple frameworks only, with one audited, vendored exception for Now Playing data (see `Vendor/README.md`).
- **Lightweight** — idle CPU ≈ 0%, small memory footprint; event-driven, not polling.
- **Private by design** — no telemetry, no crash reporters, no network calls. Permissions are requested only when a feature needs them, and each one is documented.

## Requirements

- A Mac with a notch (MacBook Air 2022+ or MacBook Pro 14"/16" 2021+)
- macOS 14 Sonoma or later
- Xcode 16+ to build from source

## Build from source

1. Clone the repo and open `Halo.xcodeproj` in Xcode.
2. Signing is set to **Sign to Run Locally** — no Apple ID or developer account needed.
3. Press **⌘R** to build and run.

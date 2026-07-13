<p align="center">
  <img src="docs/icon.png" width="140" alt="Halo icon">
</p>

<h1 align="center">Halo</h1>

<p align="center">A free, open source Dynamic Island for the MacBook notch.</p>

Halo lives around the notch. Hover over it and it expands into a hub for media controls, a file shelf, custom volume and brightness HUDs, system stats, a calendar, and timers.

<!-- Screenshots: collapsed notch, expanded media card, shelf with files,
     HUD wings mid-volume-change, calendar page, pomodoro ring.
     Drop images into docs/ and reference them here. -->

## Features

- Notch overlay that expands on hover with smooth spring animations
- Now Playing: album art, track info, play, pause and skip. Works with Apple Music, Spotify, and media playing in a browser tab. The card background is built from the current album art
- File shelf: drag files onto the notch to hold them, drag them back out into any app, send them via AirDrop, and pin the ones you want to keep across restarts
- Custom volume and brightness HUDs that replace the system pop ups, including monitor speaker volume over DDC for DisplayPort and HDMI audio, which macOS itself cannot control
- System stats: CPU, GPU, RAM and network readouts, battery with a charging flash in the notch, and AirPods battery
- Calendar page with a month grid and per day events, quick timers with a completion ring, and a full Pomodoro timer with configurable rounds. Running timers stay visible in the collapsed notch

## Install (no Xcode needed)

With Homebrew:

```sh
brew install --cask spador/halo/halo
xattr -dr com.apple.quarantine /Applications/Halo.app
```

The second line clears the download quarantine. It is needed because this is a personal build that is not notarized by Apple.

Manual: download the zip from [Releases](https://github.com/Spador/Halo/releases), unzip, drag Halo.app into Applications, and run the same xattr command.

On first launch, grant Accessibility when asked. That powers the volume and brightness HUD replacement. Calendar access is only requested if you open the calendar page and click Connect Calendar.

## Principles

- Native and minimal. Swift 6 and SwiftUI, with AppKit where the overlay needs it. No web views.
- Apple frameworks only, with one audited, vendored exception for Now Playing data (see `Vendor/README.md`).
- Lightweight. Idle CPU is 0.0 percent and memory stays around 25 MB in practice. Updates are event driven, not polled.
- Private by design. No telemetry, no crash reporters, no network calls. Permissions are requested only when a feature needs them.

## Privacy and permissions

Halo makes zero network connections. Nothing you play, hold, or schedule ever leaves the machine. The only data written to disk is the list of pinned shelf file paths and your Pomodoro durations, both in the app preferences.

| Permission | When asked | Why | Scope |
|---|---|---|---|
| Accessibility | At launch, for the HUD feature | An event tap must intercept volume and brightness keys before macOS shows its own HUD | The tap is filtered to system media key events only. See `MediaKeyTap.swift`. Ordinary keystrokes travel on a different event type and never reach Halo |
| Calendar (full access) | Only when you click Connect Calendar | To show your events in the notch | Read only usage. Declining just leaves the calendar page empty |

Halo uses three private or undocumented API surfaces, listed in the open. Each fails gracefully if a macOS update breaks it:

- MediaRemote, through the vendored [mediaremote-adapter](Vendor/README.md), for system wide Now Playing info. Apple locked the direct route in macOS 15.4
- DisplayServices, for setting the built in display brightness. No public API exists for this
- IOAVService (DDC/CI), a standard control channel to external monitors, used for speaker volume and, when enabled, brightness

The app is not sandboxed. Spawning the media helper and the interfaces above require that. It requests no unusual entitlements.

## Known limitations

- External monitor brightness over DDC is implemented but currently disabled (`DisplayBrightnessManager.externalBrightnessEnabled`). Some monitors accept DDC audio commands but ignore DDC brightness writes. Monitor speaker volume over DDC works
- The HUD feature needs the Accessibility permission. Quit Halo and your keys instantly revert to stock macOS behavior

## Requirements

- A Mac with a notch (MacBook Air 2022 or later, MacBook Pro 14 or 16 inch 2021 or later)
- macOS 14 Sonoma or later
- Xcode 16 or later, only if building from source

## Build from source

1. Clone the repo and open `Halo.xcodeproj` in Xcode.
2. In Signing & Capabilities, select your own team. A free personal Apple ID team works and keeps permission grants stable across rebuilds.
3. Press Cmd R to build and run. Nothing but Xcode is required. The one vendored dependency compiles from source during the build.

For daily use, build a Release copy into Applications:

```sh
xcodebuild -project Halo.xcodeproj -scheme Halo -configuration Release build
cp -R ~/Library/Developer/Xcode/DerivedData/Halo-*/Build/Products/Release/Halo.app /Applications/
```

## License

MIT for Halo code (see `LICENSE`). The vendored mediaremote-adapter remains under its BSD 3-Clause license (see `Vendor/`).

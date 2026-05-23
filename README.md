# StatusBar

A lightweight macOS menu bar app that keeps system metrics and Claude Code usage visible at a glance.

## Features

**Menu bar** — always-visible compact display:
- CPU usage %
- RAM in use
- Disk usage %
- Network download / upload speed
- Claude Code usage: session % / weekly % (e.g. `6%/2%`)

**Popover** (click the menu bar item to open):
- CPU, memory, and disk usage with color-coded progress bars (green / yellow / red)
- Network download and upload speeds
- Claude Code section: session utilization % with time until reset, weekly utilization % — both with progress bars
- Launch at login toggle
- Quit button

The popover dismisses automatically on any click outside it.

## Requirements

- macOS 14 (Sonoma) or later
- Claude Code CLI installed and signed in (required for usage data)

## Build & Install

```sh
# Release build
make build

# Build, bundle, and install to ~/Applications/
make install
```

Other targets:

| Target | Action |
|--------|--------|
| `make bundle` | Builds and creates `StatusBar.app` in the project directory |
| `make run`    | Bundles and launches immediately |
| `make clean`  | Removes build artifacts and the app bundle |

Built with Swift 6, SwiftUI + AppKit, and Swift Package Manager.

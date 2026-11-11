# Macenic

A lightweight, native macOS menu bar utility suite built with Swift and SwiftUI. Macenic brings system monitoring, clipboard history, window snapping, process management, audio switching, developer tools, and quick toggles together in one app — with no third-party dependencies.

## Features

### Menu Bar Dashboard
- Compact dashboard with System, Controls, Processes, Windows, and DevTools tabs
- Glassmorphism appearance controls
- Customizable global shortcuts
- Automatic update checks against GitHub Releases

### System Monitor
- Live CPU, memory, disk, and GPU usage gauges
- Network upload/download speed
- Battery level, health, cycle count, charging status, and last charged time

### Storage & Battery Health
- Storage usage overview, including purgeable space
- Category breakdown with a shortcut to macOS Storage settings
- Detailed battery information: maximum capacity, condition, cycle count, design capacity, remaining capacity, wattage, and charge time

### Clipboard Manager
- Persistent history for text and images (up to 50 unpinned items)
- Pin important items, delete entries, search, and filter by All / Text / Images
- Floating HUD with a global shortcut (default: `Cmd+Shift+V`)
- Keyboard navigation: arrow keys, `Enter` to paste, `1`–`9` for quick paste
- Hover previews for full text and images, positioned beside the clipboard panel
- Direct paste into the previously active app (requires Accessibility permission)
- Optional clipboard view in the menu bar

### Window Manager
- Snap windows to the left half, right half, or top half
- Maximize and restore window position
- Customizable global shortcuts (defaults use `Ctrl+Option` + arrow keys)
- Requires Accessibility permission

### Process Manager
- Live process list with CPU and memory usage
- Search by name or PID, filter by app/process, and sort by CPU, memory, or name
- Quit or force quit processes, bring apps to the front, and reveal apps in Finder
- Protected system processes are marked and cannot be terminated from the app

### Audio Switcher
- Quickly switch between audio output and input devices
- Adjust input volume when the device supports it

### Quick Toggles
- **Keep Awake** — prevent the display from sleeping
- **Keyboard Cleaner** — lock keyboard input for 30 seconds
- **Launch at Login** — start Macenic automatically when you log in

### Dev Toolkit
- **Data** — JSON formatting with 2-space, 4-space, or tab indentation; minify and validate JSON; Base64 encode/decode (standard and URL-safe); URL encode/decode and query parameter parsing; JWT decoding with issue/expiry details
- **Generators** — uppercase UUID v4, UUID v7, and ULID generation; configurable random strings; secure tokens in uppercase hex, Base64, or URL-safe format; live epoch clock and timestamp converter
- **Text** — regex testing and replacement, case conversion (including `UPPERCASE`), text cleanup transforms, character/word/line/byte counts, and JSON/HTML/URL escaping
- **Hashes** — SHA-256, SHA-512, SHA-1, MD5, and HMAC-SHA256 with an uppercase output option
- Available inside the dashboard and in a standalone resizable window

## Requirements

- macOS 14.6 (Sonoma) or later
- Xcode 26.0 or later

## Build

1. Clone the repository
```bash
git clone https://github.com/0xJihan/Macenic.git
cd Macenic
```

2. Open in Xcode
```bash
open Macenic.xcodeproj
```

3. Build and run (`Cmd+R`)

## Permissions

Macenic is a menu bar app (`LSUIElement`), so it runs without a Dock icon. Some features require Accessibility access:

- **Direct Auto-Paste** — pastes the selected clipboard item into the previously active app
- **Window Manager** — moves and resizes windows
- **Keyboard Cleaner** — intercepts keyboard input while cleaning

Enable Macenic in **System Settings → Privacy & Security → Accessibility** when prompted.

## Keyboard Shortcuts

| Action | Default shortcut |
| --- | --- |
| Clipboard HUD | `Cmd+Shift+V` |
| Snap left | `Ctrl+Option+←` |
| Snap right | `Ctrl+Option+→` |
| Maximize | `Ctrl+Option+↑` |
| Restore | `Ctrl+Option+⌫` |

All shortcuts can be changed from the app.

## Updates

Macenic checks the latest release from:

```text
https://github.com/0xJihan/Macenic/releases/latest
```

To publish an update:

1. Bump `MARKETING_VERSION` and `CURRENT_PROJECT_VERSION` in the Xcode project.
2. Build and export a disk image (`.dmg`).
3. Create a GitHub Release with a tag such as `v2.0.1` and attach the `.dmg` asset.

The app prefers a `.dmg` asset, falls back to a `.zip` asset, and otherwise opens the GitHub release page.

## Architecture

- **SwiftUI** with `MenuBarExtra` for the menu bar interface
- **@Observable** (Observation framework) for reactive state management
- **Native APIs only** — Mach, IOKit, CoreAudio, Carbon (global hotkeys), CoreGraphics, CryptoKit
- **No third-party dependencies**
- Modular feature-based structure:

```text
Macenic/
├── App/             # App entry point and AppState
├── Features/        # UI grouped by feature
│   ├── Clipboard/   # HUD, preview panel, history, menu bar view
│   ├── Dashboard/   # Dashboard, settings, about
│   ├── DevToolkit/  # Data, generator, text, and hash tools
│   └── ...
├── Models/          # Data models
├── Services/        # System and business-logic services
└── Utilities/       # Helpers (ByteFormatter)
```

## Support

If you find Macenic useful, consider supporting the project:

[Support Macenic](https://www.supportkori.com/0xjihan)

## Author

**Jihan Khan**
- Website: [jihankhan.netlify.app](https://jihankhan.netlify.app/)
- GitHub: [@0xJihan](https://github.com/0xJihan)
- Email: jihankhan966@gmail.com

## License

This project is licensed under the MIT License. See [LICENSE](LICENSE) for details.

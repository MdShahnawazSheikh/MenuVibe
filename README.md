<div align="center">

<img src="Resources/MenuBarIcon.svg" width="72" height="72" alt="MenuVibe icon">

# MenuVibe

**One small, native macOS menu bar app that replaces your clipboard manager, window snapper, and quick-notes utilities.**

Clipboard history · window snapping · a Markdown scratchpad — in a single notarizable binary that idles under 30 MB.

[![Build](https://github.com/OWNER/MenuVibe/actions/workflows/build.yml/badge.svg)](https://github.com/OWNER/MenuVibe/actions/workflows/build.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-black.svg)](LICENSE)
[![macOS 13+](https://img.shields.io/badge/macOS-13%2B-black.svg)](https://www.apple.com/macos/)
[![Swift 5.9](https://img.shields.io/badge/Swift-5.9-orange.svg)](https://swift.org)

</div>

> [!NOTE]
> **📸 Maintainer:** drop a real screen recording of the dropdown panel here before your first release.
> Record a ~10s GIF (clipboard search → window snap → quick note) and save it as `Design/demo.gif`, then replace this note with:
> `<div align="center"><img src="Design/demo.gif" width="420" alt="MenuVibe in action"></div>`

---

## What it does

MenuVibe lives in your menu bar as a single icon. Left-click (or press <kbd>⌘⇧Space</kbd> from anywhere) to drop down a compact, vibrant panel with three tabs:

### 📋 Clipboard history
Everything you copy — text, rich text, images, and files — captured automatically and kept searchable.
- Fuzzy filter as you type
- Click to paste and dismiss; <kbd>⌘1</kbd>–<kbd>⌘9</kbd> to paste the top nine without the mouse
- Pin items so they never expire; per-row delete on hover
- Image thumbnails, cached and downscaled
- **Privacy-first:** copies marked concealed/transient by password managers (1Password, etc.) are *never* stored

### ▦ Window snapping
Move and resize the frontmost window with the keyboard — Rectangle-style defaults, every shortcut remappable.
- Halves, thirds, fullscreen, fixed-size center, and move-to-next-display
- Multi-monitor aware (snaps against the display the window is actually on)
- Smoothly animated resize, not a jarring jump
- The Windows tab doubles as a live cheat sheet of every zone and its shortcut

### 📝 Quick notes
A single Markdown scratchpad that's always one keystroke away (<kbd>⌘⇧N</kbd>).
- Raw editing by default, one-tap rendered preview
- Autosaves on every keystroke — you never lose anything
- Stored as a plain `.md` file you can sync yourself

Plus an optional **Sensors** tab (off by default) with a lightweight CPU/memory readout.

---

## Why this stack

MenuVibe is written in **native Swift + SwiftUI, with AppKit where the platform demands it** (the `NSStatusItem`, the borderless panel, pasteboard monitoring, the Accessibility API, and Carbon global hotkeys). It has **zero third-party dependencies** — only the system SDK.

That choice is deliberate, not a default:

| Constraint | Native Swift | Electron | Tauri | Flutter desktop |
|---|:--:|:--:|:--:|:--:|
| Idle memory < 30 MB | ✅ ~26 MB | ❌ 150 MB+ | ⚠️ webview overhead | ⚠️ |
| Real `NSStatusItem` menu bar extra | ✅ | ⚠️ bolted on | ⚠️ | ❌ no first-class support |
| System-wide global hotkeys (app not frontmost) | ✅ Carbon | ⚠️ | ⚠️ | ⚠️ |
| Accessibility API window control | ✅ native | ⚠️ bridge | ⚠️ bridge | ❌ fights you |
| Cold launch < 500 ms | ✅ | ❌ | ⚠️ | ⚠️ |
| Small notarizable `.app` | ✅ | ❌ huge | ⚠️ | ⚠️ |

For a menu bar utility that is fundamentally a thin native UI over system APIs, anything with a bundled runtime pays an order-of-magnitude tax in memory and startup for no benefit. Native Swift is the honest choice — and the one the target audience (Mac power users) expects.

**Measured on an M-series Mac:** ~26 MB physical footprint idle, 0% idle CPU.

---

## Install

### Build from source (only supported method today)

Requires **Xcode 15+ / Swift 5.9+** on **macOS 13 Ventura or later**.

```bash
git clone https://github.com/OWNER/MenuVibe.git
cd MenuVibe

# Run straight from the terminal (Ctrl-C to quit):
make run

# …or build a real, ad-hoc-signed MenuVibe.app into ./dist:
make app
open dist/MenuVibe.app
```

On first launch MenuVibe walks you through a short setup and asks for **Accessibility** permission (needed only for window snapping — see [Permissions](#permissions)).

### Homebrew (planned)

A Homebrew cask (`brew install --cask menuvibe`) is on the roadmap once signed release builds are published. See [Distribution](#distribution).

---

## Keyboard shortcuts

Every shortcut is remappable in **Settings › Shortcuts** and **Settings › Window Snapping**. Defaults:

| Action | Default |
|---|---|
| Summon MenuVibe | <kbd>⌘⇧Space</kbd> |
| Open Quick Note | <kbd>⌘⇧N</kbd> |
| Left / Right half | <kbd>⌃⌥←</kbd> / <kbd>⌃⌥→</kbd> |
| Top / Bottom half | <kbd>⌃⌥↑</kbd> / <kbd>⌃⌥↓</kbd> |
| Fullscreen | <kbd>⌃⌥↩</kbd> |
| Center (900×600) | <kbd>⌃⌥C</kbd> |
| Left / Center / Right third | <kbd>⌃⌥D</kbd> / <kbd>⌃⌥F</kbd> / <kbd>⌃⌥G</kbd> |
| Move to next display | <kbd>⌃⌥N</kbd> |
| Paste clipboard item 1–9 | <kbd>⌘1</kbd>–<kbd>⌘9</kbd> (while the panel is open) |

---

## Permissions

MenuVibe requests exactly one system permission, and only when you enable the feature that needs it:

- **Accessibility** — required by the Window Snapper to move and resize *other apps'* windows via the macOS Accessibility API. It is used for nothing else. You grant it during onboarding, or later at any time from **Settings › Window Snapping**, which deep-links you to System Settings.

The clipboard and notes features are entirely local and need no permissions.

### A note on sandboxing

MenuVibe ships **outside the App Sandbox**, because the sandbox forbids the cross-process Accessibility control the Window Snapper depends on. This is why MenuVibe is distributed as a notarized, Hardened-Runtime app rather than through the Mac App Store. Everything MenuVibe stores stays under `~/Library/Application Support/MenuVibe/`, and nothing is ever sent off your Mac. See [`Resources/MenuVibe.entitlements`](Resources/MenuVibe.entitlements) for the exact, commented entitlement set.

---

## Where your data lives

```
~/Library/Application Support/MenuVibe/
├── clipboard.json        # clipboard history index (metadata only)
├── ClipboardImages/      # full-resolution copied images, one file each
└── quicknote.md          # your Quick Notes scratchpad — plain Markdown
```

`quicknote.md` is intentionally a plain, readable file so you can point Syncthing, iCloud Drive, or a dotfiles repo at it and sync it yourself. There is **no** built-in cloud sync (by design — see [Roadmap](#roadmap)).

---

## Distribution

For a signed, notarized build suitable for sharing:

```bash
export CODESIGN_IDENTITY="Developer ID Application: Your Name (TEAMID)"
make app                 # builds & signs dist/MenuVibe.app with your identity
make dmg                 # packages dist/MenuVibe.dmg (drag-to-Applications)

# then notarize:
xcrun notarytool submit dist/MenuVibe.dmg --keychain-profile "AC_PASSWORD" --wait
xcrun stapler staple dist/MenuVibe.app
```

---

## Project layout

```
MenuVibe/
├── Package.swift                 # SPM manifest (zero external dependencies)
├── Sources/MenuVibe/
│   ├── App/                      # entry point, NSStatusItem, dropdown panel
│   ├── Features/
│   │   ├── Clipboard/            # polling engine, store, list UI
│   │   ├── WindowSnapper/        # Accessibility API engine, cheat-sheet UI
│   │   ├── QuickNotes/           # autosaving store, editor, Markdown preview
│   │   └── SensorMonitor/        # optional CPU/memory readout
│   ├── Shared/                   # design system, hotkeys, preferences, paths
│   ├── Settings/                 # preferences window + panes
│   └── Onboarding/               # first-run flow
├── Resources/                    # Info.plist, entitlements, icon source
├── Scripts/                      # build-app.sh, make-dmg.sh
├── Tests/MenuVibeTests/          # unit tests for the pure logic
└── Design/                       # icon source, screenshots/GIFs
```

---

## Roadmap

Intentionally **not** in v1, tracked for later:

- [ ] Signed & notarized release builds + Homebrew cask
- [ ] Auto-update via [Sparkle](https://sparkle-project.org)
- [ ] Full SMC thermal/fan sensors (Intel today; Apple Silicon exposes few publicly)
- [ ] Opt-in iCloud sync for clipboard (privacy-gated)
- [ ] Custom window-snap zone editor
- [ ] Multiple named notes

---

## Contributing

Contributions are welcome — see [CONTRIBUTING.md](CONTRIBUTING.md). In short: the project builds with `swift build`, tests run with `swift test`, and the design language lives in [`Sources/MenuVibe/Shared/DesignSystem.swift`](Sources/MenuVibe/Shared/DesignSystem.swift) — please route new UI through it so the app stays coherent.

## License

[MIT](LICENSE) © MenuVibe contributors.

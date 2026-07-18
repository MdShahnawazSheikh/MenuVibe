# Changelog

All notable changes to MenuVibe are documented here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and the project aims to
follow [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Planned
- Signed & notarized release builds and a Homebrew cask
- Auto-update via Sparkle
- Full SMC thermal/fan sensors

## [1.0.0] — 2026-07-18

The first release. A tight, polished v1 of three tools in one menu bar app.

### Added
- **App shell** — single `NSStatusItem`, borderless vibrant dropdown panel with an
  icon-only tab strip, click-outside / Esc / focus-loss dismissal, persisted active
  tab, and a global summon hotkey (default ⌘⇧Space) that works from any app.
- **Clipboard manager** — 0.5s change-count polling, de-duplication, configurable
  history size (20/40/60/100), pinned items, fuzzy search, image thumbnails, source
  app icons, ⌘1–⌘9 quick-paste, and privacy skipping of concealed/transient copies.
- **Window snapper** — Accessibility-API driven halves/thirds/fullscreen/center/
  next-display, Rectangle-style remappable defaults, multi-monitor awareness,
  animated resize, and graceful handling of non-resizable, fullscreen, and
  permission-revoked states.
- **Quick notes** — a single autosaving Markdown scratchpad with a rendered-preview
  toggle, word/character count, copy-as-markdown/plain-text, and a dedicated hotkey
  (default ⌘⇧N). Stored as a plain `.md` file.
- **Sensors (optional, off by default)** — lightweight CPU & memory readout with a
  60-second sparkline.
- **Settings** — sidebar window with General, Clipboard, Window Snapping, Quick
  Notes, Shortcuts, and About panes; launch-at-login via `SMAppService`; a proper
  click-to-record shortcut recorder; and three menu bar icon styles.
- **Onboarding** — a 3-screen first-run flow that explains each feature and primes
  the Accessibility permission with context before triggering the system prompt.
- **Tooling** — `swift build`/`test`, an app-bundling script, a DMG script, a
  Makefile, and a GitHub Actions build/test workflow.

[Unreleased]: https://github.com/MdShahnawazSheikh/MenuVibe/compare/v1.0.0...HEAD
[1.0.0]: https://github.com/MdShahnawazSheikh/MenuVibe/releases/tag/v1.0.0

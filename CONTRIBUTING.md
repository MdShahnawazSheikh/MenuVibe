# Contributing to MenuVibe

Thanks for your interest in improving MenuVibe. This project aims for a "would pay for this" quality bar, so contributions are held to that standard — but the workflow is simple and the codebase is small and dependency-free.

## Getting set up

Requirements: **Xcode 15+ / Swift 5.9+** on **macOS 13+**.

```bash
git clone https://github.com/MdShahnawazSheikh/MenuVibe.git
cd MenuVibe
make run      # build + run from the terminal
make test     # run the unit tests
make app      # assemble dist/MenuVibe.app
```

There are no package dependencies to install — MenuVibe uses only the system SDK.

## How the project is organized

- **`Sources/MenuVibe/App/`** — the app shell: entry point, status item, dropdown panel.
- **`Sources/MenuVibe/Features/`** — one folder per feature, each self-contained (engine + view).
- **`Sources/MenuVibe/Shared/`** — the design system, hotkey center, preferences, and paths. **New UI must route through `DesignSystem.swift`** (`DS.Color`, `DS.Font`, `DS.Spacing`, `DS.Radius`, `DS.Motion`) so the app stays visually coherent.
- **`Sources/MenuVibe/Settings/`** and **`Onboarding/`** — auxiliary windows.

## Design principles (please read before UI work)

MenuVibe deliberately avoids the "AI-generated app" look. Before submitting UI changes, make sure they follow the house style:

- **One accent color**, taken from the user's macOS accent setting (`DS.Color.accent`). No gradients. No hardcoded blue.
- **Vary corner radius by hierarchy** — buttons 6pt, rows 8pt, panels 12pt. Don't round everything the same.
- **Real system materials** (`VisualEffectBackground`) for translucency, not flat fills.
- **SF Symbols only** for iconography, weight-matched to nearby text. No emoji in the UI.
- **Type scale 11/12/13/15**, with intentional weights (`DS.Font`).
- **Motion:** the house spring (`DS.Motion.spring`), nothing over 400ms.
- Both **Light and Dark Mode** must look intentional. Test both.
- **No placeholder / Lorem Ipsum copy** — every label should read like a real person wrote it.

The litmus test: *if you screenshotted your change and posted it to r/macapps with no caption, would people assume it's a polished paid app?*

## Making a change

1. **Open an issue first** for anything non-trivial, so we can agree on the approach.
2. Branch from `main`: `git checkout -b feature/short-description`.
3. Keep PRs focused — one concern per PR.
4. Add or update tests in `Tests/MenuVibeTests/` for any pure logic you touch.
5. Run `make test` and `make app`, and **manually verify the affected flow** (the CI can't click buttons).
6. Match the surrounding code's style — comment density, naming, and idiom.

## Commit messages

Use clear, imperative-mood messages (`Add pinned-item section to clipboard`). Reference the issue number where relevant.

## Reporting bugs

Open an issue with your macOS version, your Mac model (Intel or Apple Silicon), steps to reproduce, and what you expected. Console logs (`log show --predicate 'process == "MenuVibe"' --last 5m`) help a lot for permission or hotkey issues.

## Code of Conduct

Be respectful and constructive. We follow the spirit of the [Contributor Covenant](https://www.contributor-covenant.org/).

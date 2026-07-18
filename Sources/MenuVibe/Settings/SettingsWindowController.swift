import AppKit
import SwiftUI

/// Hosts the real Settings window (spec §8) — a standard titled macOS window, not a
/// menu bar dropdown. Kept as a single reusable controller the app delegate shows on
/// ⌘, or from the context menu.
final class SettingsWindowController: NSWindowController {
    convenience init(appDelegate: AppDelegate) {
        let root = SettingsView(
            preferences: appDelegate.preferences,
            hotKeys: appDelegate.hotKeys,
            clipboard: appDelegate.clipboard
        )
        let hosting = NSHostingController(rootView: root)
        let window = NSWindow(contentViewController: hosting)
        window.title = "MenuVibe Settings"
        window.styleMask = [.titled, .closable, .miniaturizable]
        window.setContentSize(NSSize(width: 640, height: 460))
        window.isReleasedWhenClosed = false
        window.center()
        self.init(window: window)
    }
}

import AppKit

/// Owns the single `NSStatusItem`. Distinguishes a left-click (open panel) from a
/// right-click or ⌘-click (context menu) by handling the mouse events on the button
/// directly, which `NSStatusItem.menu` cannot do without stealing the left-click.
final class StatusItemController: NSObject {
    private let item: NSStatusItem
    private let onPrimaryClick: () -> Void
    private let onSecondaryClick: () -> Void

    var button: NSStatusBarButton? { item.button }

    init(preferences: Preferences,
         onPrimaryClick: @escaping () -> Void,
         onSecondaryClick: @escaping () -> Void) {
        self.item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        self.onPrimaryClick = onPrimaryClick
        self.onSecondaryClick = onSecondaryClick
        super.init()

        if let button = item.button {
            button.image = MenuBarIcon.image(for: preferences.menuBarIconStyle)
            button.imageScaling = .scaleProportionallyDown
            button.target = self
            button.action = #selector(handleClick(_:))
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
            button.toolTip = "MenuVibe — clipboard, window snapping & quick notes"
            button.setAccessibilityLabel("MenuVibe")
        }
    }

    func updateIcon(style: MenuBarIconStyle) {
        item.button?.image = MenuBarIcon.image(for: style)
    }

    /// Temporarily attach a menu and pop it, then detach so left-click keeps working.
    func showMenu(_ menu: NSMenu) {
        item.menu = menu
        item.button?.performClick(nil)
        item.menu = nil
    }

    @objc private func handleClick(_ sender: NSStatusBarButton) {
        let event = NSApp.currentEvent
        let isSecondary = event?.type == .rightMouseUp
            || event?.modifierFlags.contains(.command) == true
        if isSecondary {
            onSecondaryClick()
        } else {
            onPrimaryClick()
        }
    }

    /// Keeps the status button visually "pressed" while the panel is open.
    func setHighlighted(_ highlighted: Bool) {
        item.button?.highlight(highlighted)
    }
}

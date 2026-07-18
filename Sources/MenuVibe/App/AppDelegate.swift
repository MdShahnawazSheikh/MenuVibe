import AppKit
import SwiftUI
import Combine

/// The composition root. Owns the long-lived services (clipboard, snapper, notes),
/// the status item, the dropdown panel, and the auxiliary windows, and wires the
/// global hotkeys to their actions.
final class AppDelegate: NSObject, NSApplicationDelegate {

    // Long-lived services
    let preferences = Preferences.shared
    let hotKeys = HotKeyCenter.shared
    private(set) lazy var clipboard = ClipboardManager(preferences: preferences)
    private(set) lazy var snapper = WindowSnapper()
    private(set) lazy var notes = QuickNotesStore()
    private(set) lazy var sensors = SensorMonitor()

    // UI controllers
    private var statusItem: StatusItemController!
    private var panel: PanelController!
    private var settingsController: SettingsWindowController?
    private var onboardingController: OnboardingWindowController?

    private var cancellables = Set<AnyCancellable>()

    func applicationDidFinishLaunching(_ notification: Notification) {
        panel = PanelController(appDelegate: self)
        statusItem = StatusItemController(
            preferences: preferences,
            onPrimaryClick: { [weak self] in self?.panel.toggle(relativeTo: self?.statusItem.button) },
            onSecondaryClick: { [weak self] in self?.showContextMenu() }
        )

        wireHotKeys()
        clipboard.start()

        // Re-render the status icon whenever the user picks a different variant.
        preferences.$menuBarIconStyle
            .sink { [weak self] style in self?.statusItem.updateIcon(style: style) }
            .store(in: &cancellables)

        if preferences.onboardingCompleted {
            hotKeys.activate()
        } else {
            presentOnboarding()
        }
    }

    // MARK: Hotkeys

    private func wireHotKeys() {
        hotKeys.setHandler(for: .summonPanel) { [weak self] in
            self?.panel.toggle(relativeTo: self?.statusItem.button)
        }
        hotKeys.setHandler(for: .quickNote) { [weak self] in
            self?.panel.open(tab: .notes, relativeTo: self?.statusItem.button)
        }
        for action in SnapAction.allCases {
            hotKeys.setHandler(for: action.shortcutID) { [weak self] in
                self?.snapper.perform(action)
            }
        }
    }

    /// Called by onboarding once the user finishes, so hotkeys don't fire mid-tour.
    func activateHotKeysAfterOnboarding() {
        preferences.onboardingCompleted = true
        hotKeys.activate()
    }

    // MARK: Context menu (right-click / ⌘-click — spec §3)

    private func showContextMenu() {
        let menu = NSMenu()
        menu.addItem(withTitle: "Preferences…", action: #selector(openSettings), keyEquivalent: ",").target = self
        menu.addItem(withTitle: "Check for Updates…", action: #selector(checkForUpdates), keyEquivalent: "").target = self
        menu.addItem(.separator())
        let quit = menu.addItem(withTitle: "Quit MenuVibe", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        quit.target = NSApp
        statusItem.showMenu(menu)
    }

    @objc func openSettings() {
        if settingsController == nil {
            settingsController = SettingsWindowController(appDelegate: self)
        }
        NSApp.activate(ignoringOtherApps: true)
        settingsController?.showWindow(nil)
    }

    @objc private func checkForUpdates() {
        // Sparkle auto-update is a documented roadmap item (spec §8, §12). Until it
        // ships, point the user at the releases page rather than faking a check.
        NSWorkspace.shared.open(AppLinks.releases)
    }

    func applicationWillTerminate(_ notification: Notification) {
        // Flush the notes debounce so the final keystrokes are never lost (spec §6).
        notes.flush()
        clipboard.stop()
        sensors.stop()
    }

    // MARK: Onboarding

    private func presentOnboarding() {
        onboardingController = OnboardingWindowController(appDelegate: self)
        NSApp.activate(ignoringOtherApps: true)
        onboardingController?.showWindow(nil)
    }
}

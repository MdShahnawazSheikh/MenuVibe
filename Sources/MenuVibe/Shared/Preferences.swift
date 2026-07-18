import Foundation
import Combine
import ServiceManagement

/// The single source of truth for user settings. Backed by `UserDefaults`, exposed
/// as an `ObservableObject` so SwiftUI views bind directly. Kept deliberately small:
/// anything that is genuinely bulk data (clipboard history, the note) lives in its
/// own store on disk, not here.
final class Preferences: ObservableObject {
    static let shared = Preferences()

    private let defaults = UserDefaults.standard

    private enum Key {
        static let onboardingCompleted = "onboardingCompleted"
        static let lastActiveTab = "lastActiveTab"
        static let clipboardHistoryLimit = "clipboardHistoryLimit"
        static let sensorMonitorEnabled = "sensorMonitorEnabled"
        static let menuBarIconStyle = "menuBarIconStyle"
        static let notesPreviewEnabled = "notesPreviewEnabled"
        static let launchAtLogin = "launchAtLogin"
    }

    // MARK: Onboarding

    @Published var onboardingCompleted: Bool {
        didSet { defaults.set(onboardingCompleted, forKey: Key.onboardingCompleted) }
    }

    // MARK: Panel state

    @Published var lastActiveTab: PanelTab {
        didSet { defaults.set(lastActiveTab.rawValue, forKey: Key.lastActiveTab) }
    }

    // MARK: Clipboard

    /// Allowed values: 20 / 40 / 60 / 100 (spec §4). 40 is the default.
    @Published var clipboardHistoryLimit: Int {
        didSet { defaults.set(clipboardHistoryLimit, forKey: Key.clipboardHistoryLimit) }
    }

    // MARK: Sensor monitor (opt-in, off by default — spec §7)

    @Published var sensorMonitorEnabled: Bool {
        didSet { defaults.set(sensorMonitorEnabled, forKey: Key.sensorMonitorEnabled) }
    }

    // MARK: Appearance

    @Published var menuBarIconStyle: MenuBarIconStyle {
        didSet { defaults.set(menuBarIconStyle.rawValue, forKey: Key.menuBarIconStyle) }
    }

    // MARK: Quick Notes

    @Published var notesPreviewEnabled: Bool {
        didSet { defaults.set(notesPreviewEnabled, forKey: Key.notesPreviewEnabled) }
    }

    // MARK: Launch at login (SMAppService — the modern API, spec §8)

    @Published var launchAtLogin: Bool {
        didSet {
            defaults.set(launchAtLogin, forKey: Key.launchAtLogin)
            applyLaunchAtLogin(launchAtLogin)
        }
    }

    private init() {
        defaults.register(defaults: [
            Key.clipboardHistoryLimit: 40,
            Key.menuBarIconStyle: MenuBarIconStyle.layers.rawValue,
            Key.notesPreviewEnabled: false,
            Key.lastActiveTab: PanelTab.clipboard.rawValue
        ])

        onboardingCompleted = defaults.bool(forKey: Key.onboardingCompleted)
        clipboardHistoryLimit = defaults.integer(forKey: Key.clipboardHistoryLimit)
        sensorMonitorEnabled = defaults.bool(forKey: Key.sensorMonitorEnabled)
        notesPreviewEnabled = defaults.bool(forKey: Key.notesPreviewEnabled)
        launchAtLogin = defaults.bool(forKey: Key.launchAtLogin)
        lastActiveTab = PanelTab(rawValue: defaults.string(forKey: Key.lastActiveTab) ?? "")
            ?? .clipboard
        menuBarIconStyle = MenuBarIconStyle(rawValue: defaults.string(forKey: Key.menuBarIconStyle) ?? "")
            ?? .layers
    }

    /// Reflects the login-item registration into the actual system state. Silently
    /// reverts the published flag if the OS rejects the change so the toggle never
    /// lies about what the system will do.
    private func applyLaunchAtLogin(_ enabled: Bool) {
        guard #available(macOS 13.0, *) else { return }
        do {
            if enabled {
                if SMAppService.mainApp.status != .enabled {
                    try SMAppService.mainApp.register()
                }
            } else {
                if SMAppService.mainApp.status == .enabled {
                    try SMAppService.mainApp.unregister()
                }
            }
        } catch {
            NSLog("MenuVibe: launch-at-login change failed: \(error.localizedDescription)")
            DispatchQueue.main.async { [weak self] in
                // Reconcile the toggle with reality without re-triggering the setter's side effect.
                let actual = SMAppService.mainApp.status == .enabled
                if self?.launchAtLogin != actual { self?.launchAtLogin = actual }
            }
        }
    }
}

/// The tabs shown in the dropdown panel. Raw values are stable identifiers persisted
/// across launches, so don't rename them casually.
enum PanelTab: String, CaseIterable, Identifiable {
    case clipboard
    case windows
    case notes
    case sensors

    var id: String { rawValue }

    /// SF Symbol for the icon-only tab strip (spec §3). Weight is matched at the call site.
    var symbol: String {
        switch self {
        case .clipboard: return "doc.on.clipboard"
        case .windows:   return "square.split.2x2"
        case .notes:     return "note.text"
        case .sensors:   return "gauge.medium"
        }
    }

    var title: String {
        switch self {
        case .clipboard: return "Clipboard"
        case .windows:   return "Windows"
        case .notes:     return "Notes"
        case .sensors:   return "Sensors"
        }
    }
}

/// Menu bar icon variants the user can pick between (spec §8). All render as
/// monochrome template images that respect menu bar auto-tinting.
enum MenuBarIconStyle: String, CaseIterable, Identifiable {
    case layers      // stacked offset squares — the default "multi-tool" mark
    case blade       // abstracted swiss-army-knife silhouette
    case dot         // minimal single-glyph fallback

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .layers: return "Layers"
        case .blade:  return "Blade"
        case .dot:    return "Minimal"
        }
    }
}

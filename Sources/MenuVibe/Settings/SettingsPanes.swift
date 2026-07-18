import SwiftUI
import AppKit

// MARK: - General

struct GeneralPane: View {
    @ObservedObject var preferences: Preferences

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.section) {
            SettingsGroup(title: "Startup") {
                SettingsRow(title: "Launch at login",
                            subtitle: "Start MenuVibe automatically when you log in.") {
                    Toggle("", isOn: $preferences.launchAtLogin).labelsHidden().toggleStyle(.switch)
                }
            }

            SettingsGroup(title: "Menu Bar Icon") {
                SettingsRow(title: "Icon style",
                            subtitle: "The mark shown in your menu bar. All variants tint automatically.") {
                    Picker("", selection: $preferences.menuBarIconStyle) {
                        ForEach(MenuBarIconStyle.allCases) { style in
                            Text(style.displayName).tag(style)
                        }
                    }
                    .labelsHidden()
                    .fixedSize()
                }
            }

            SettingsGroup(title: "Extras") {
                SettingsRow(title: "Show Sensors tab",
                            subtitle: "A lightweight CPU & memory readout. Off by default; sampling only runs while the tab is open.") {
                    Toggle("", isOn: $preferences.sensorMonitorEnabled).labelsHidden().toggleStyle(.switch)
                }
            }
        }
    }
}

// MARK: - Clipboard

struct ClipboardPane: View {
    @ObservedObject var preferences: Preferences
    let clipboard: ClipboardManager
    @State private var confirmClear = false

    private let limits = [20, 40, 60, 100]

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.section) {
            SettingsGroup(title: "History") {
                SettingsRow(title: "Items to keep",
                            subtitle: "Older unpinned items drop off once you pass this limit. Pinned items are always kept.") {
                    Picker("", selection: $preferences.clipboardHistoryLimit) {
                        ForEach(limits, id: \.self) { Text("\($0)").tag($0) }
                    }
                    .labelsHidden()
                    .fixedSize()
                }
                DSDivider().padding(.leading, DS.Spacing.comfy)
                SettingsRow(title: "Clear history",
                            subtitle: "Removes all unpinned clipboard items from disk. This can't be undone.") {
                    Button("Clear History…", role: .destructive) { confirmClear = true }
                }
            }

            SettingsGroup(title: "Privacy") {
                SettingsRow(title: "Skip password-manager copies",
                            subtitle: "MenuVibe never stores clipboard content marked concealed or transient by apps like 1Password. Always on.") {
                    Image(systemName: "checkmark.seal.fill")
                        .foregroundStyle(DS.Color.accent)
                }
            }
        }
        .confirmationDialog("Clear clipboard history?",
                            isPresented: $confirmClear, titleVisibility: .visible) {
            Button("Clear History", role: .destructive) { clipboard.clearHistory() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This removes every unpinned item. Pinned items are kept.")
        }
    }
}

// MARK: - Window Snapping

struct WindowsPane: View {
    @ObservedObject var hotKeys: HotKeyCenter

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.section) {
            SettingsGroup(title: "Snap Shortcuts") {
                ForEach(Array(SnapAction.allCases.enumerated()), id: \.element.id) { index, action in
                    SettingsRow(title: action.title) {
                        ShortcutRecorderField(id: action.shortcutID, hotKeys: hotKeys)
                    }
                    if index < SnapAction.allCases.count - 1 {
                        DSDivider().padding(.leading, DS.Spacing.comfy)
                    }
                }
            }
            Text("Snapping needs Accessibility access, granted during onboarding. You can change it anytime in System Settings › Privacy & Security › Accessibility.")
                .font(DS.Font.caption)
                .foregroundStyle(DS.Color.secondaryLabel)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

// MARK: - Quick Notes

struct NotesPane: View {
    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.section) {
            SettingsGroup(title: "Storage") {
                SettingsRow(title: "Note location",
                            subtitle: AppPaths.quickNote.path) {
                    Button("Reveal in Finder") {
                        NSWorkspace.shared.activateFileViewerSelecting([AppPaths.quickNote])
                    }
                }
            }
            Text("Your note is a plain Markdown file. Point Syncthing, iCloud Drive, or a dotfiles repo at it to sync it yourself — MenuVibe never uploads it anywhere.")
                .font(DS.Font.caption)
                .foregroundStyle(DS.Color.secondaryLabel)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

// MARK: - Shortcuts

struct ShortcutsPane: View {
    @ObservedObject var hotKeys: HotKeyCenter

    private let global: [ShortcutID] = [.summonPanel, .quickNote]

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.section) {
            SettingsGroup(title: "Global") {
                ForEach(Array(global.enumerated()), id: \.element) { index, id in
                    SettingsRow(title: id.title) {
                        ShortcutRecorderField(id: id, hotKeys: hotKeys)
                    }
                    if index < global.count - 1 {
                        DSDivider().padding(.leading, DS.Spacing.comfy)
                    }
                }
            }
            Text("Right-click any shortcut field to reset it to its default. Global shortcuts work from any app, even when MenuVibe has no window focused.")
                .font(DS.Font.caption)
                .foregroundStyle(DS.Color.secondaryLabel)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

// MARK: - About

struct AboutPane: View {
    private var version: String {
        let v = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
        let b = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "Version \(v) (\(b))"
    }

    /// The real app icon from the bundle, so About shows the product mark, not the
    /// monochrome menu bar glyph.
    private var appIcon: NSImage { NSApp.applicationIconImage ?? MenuBarIcon.image(for: .layers) }

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.comfy) {
            HStack(spacing: DS.Spacing.comfy) {
                Image(nsImage: appIcon)
                    .resizable()
                    .frame(width: 64, height: 64)
                VStack(alignment: .leading, spacing: 2) {
                    Text("MenuVibe")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(DS.Color.primaryLabel)
                    Text(version)
                        .font(DS.Font.caption)
                        .foregroundStyle(DS.Color.secondaryLabel)
                    Text("MIT · open source")
                        .font(DS.Font.caption)
                        .foregroundStyle(DS.Color.tertiaryLabel)
                }
            }

            Text("A native macOS menu bar suite: clipboard history, window snapping, and quick notes in one small binary.")
                .font(DS.Font.rowTitle)
                .foregroundStyle(DS.Color.secondaryLabel)
                .fixedSize(horizontal: false, vertical: true)

            // The star CTA — front and center, with a line that earns it.
            HStack(spacing: DS.Spacing.comfy) {
                StarOnGitHubButton()
                Text("If MenuVibe saved you a few clicks, a star helps others find it.")
                    .font(DS.Font.caption)
                    .foregroundStyle(DS.Color.secondaryLabel)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.vertical, DS.Spacing.tight)

            HStack(spacing: DS.Spacing.base) {
                Link("GitHub Repository", destination: AppLinks.repo)
                Text("·").foregroundStyle(DS.Color.tertiaryLabel)
                Link("Report an Issue", destination: AppLinks.issues)
                Text("·").foregroundStyle(DS.Color.tertiaryLabel)
                Link("MIT License", destination: AppLinks.license)
            }
            .font(DS.Font.interactive)

            Spacer(minLength: 0)
            Text("Made for people who live in the menu bar.")
                .font(DS.Font.caption)
                .foregroundStyle(DS.Color.tertiaryLabel)
        }
    }
}

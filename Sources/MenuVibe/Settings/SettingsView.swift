import SwiftUI
import AppKit

/// The Settings content: a sidebar of panes over a detail area, mirroring the native
/// macOS Settings layout (spec §8). Each pane is intentionally sparse and labelled in
/// plain language.
struct SettingsView: View {
    @ObservedObject var preferences: Preferences
    @ObservedObject var hotKeys: HotKeyCenter
    let clipboard: ClipboardManager

    @State private var selection: Pane = .general

    enum Pane: String, CaseIterable, Identifiable {
        case general, clipboard, windows, notes, shortcuts, about
        var id: String { rawValue }
        var title: String {
            switch self {
            case .general: return "General"
            case .clipboard: return "Clipboard"
            case .windows: return "Window Snapping"
            case .notes: return "Quick Notes"
            case .shortcuts: return "Shortcuts"
            case .about: return "About"
            }
        }
        var symbol: String {
            switch self {
            case .general: return "gearshape"
            case .clipboard: return "doc.on.clipboard"
            case .windows: return "square.split.2x2"
            case .notes: return "note.text"
            case .shortcuts: return "keyboard"
            case .about: return "info.circle"
            }
        }
    }

    var body: some View {
        HStack(spacing: 0) {
            sidebar
            Divider()
            ScrollView {
                detail
                    .padding(DS.Spacing.section)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .frame(minWidth: 640, minHeight: 460)
    }

    // MARK: Sidebar

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 2) {
            ForEach(Pane.allCases) { pane in
                Button {
                    withAnimation(DS.Motion.quick) { selection = pane }
                } label: {
                    HStack(spacing: DS.Spacing.base) {
                        Image(systemName: pane.symbol)
                            .font(.system(size: 13, weight: .medium))
                            .frame(width: 18)
                            .foregroundStyle(selection == pane ? DS.Color.accent : DS.Color.secondaryLabel)
                        Text(pane.title)
                            .font(DS.Font.rowTitle)
                            .foregroundStyle(DS.Color.primaryLabel)
                        Spacer()
                    }
                    .padding(.horizontal, DS.Spacing.base)
                    .frame(height: 30)
                    .background(
                        RoundedRectangle(cornerRadius: DS.Radius.row, style: .continuous)
                            .fill(selection == pane ? DS.Color.accent.opacity(0.14) : .clear)
                    )
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            Spacer()
        }
        .padding(DS.Spacing.base)
        .frame(width: 180)
        .background(VisualEffectBackground(material: .sidebar))
    }

    // MARK: Detail

    @ViewBuilder
    private var detail: some View {
        switch selection {
        case .general:   GeneralPane(preferences: preferences)
        case .clipboard: ClipboardPane(preferences: preferences, clipboard: clipboard)
        case .windows:   WindowsPane(hotKeys: hotKeys)
        case .notes:     NotesPane()
        case .shortcuts: ShortcutsPane(hotKeys: hotKeys)
        case .about:     AboutPane()
        }
    }
}

// MARK: - Shared settings primitives

/// A titled group of rows, matching the grouped look of System Settings.
struct SettingsGroup<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.base) {
            DSSectionHeader(title: title)
            VStack(spacing: 0) { content }
                .background(
                    RoundedRectangle(cornerRadius: DS.Radius.panel, style: .continuous)
                        .fill(DS.Color.primaryLabel.opacity(0.04))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: DS.Radius.panel, style: .continuous)
                        .strokeBorder(DS.Color.separator, lineWidth: 0.5)
                )
        }
    }
}

/// One labelled row inside a `SettingsGroup`, with a trailing control.
struct SettingsRow<Trailing: View>: View {
    let title: String
    var subtitle: String? = nil
    @ViewBuilder let trailing: Trailing

    var body: some View {
        HStack(spacing: DS.Spacing.comfy) {
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(DS.Font.rowTitle)
                    .foregroundStyle(DS.Color.primaryLabel)
                if let subtitle {
                    Text(subtitle)
                        .font(DS.Font.caption)
                        .foregroundStyle(DS.Color.secondaryLabel)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Spacer()
            trailing
        }
        .padding(.horizontal, DS.Spacing.comfy)
        .padding(.vertical, DS.Spacing.base)
    }
}

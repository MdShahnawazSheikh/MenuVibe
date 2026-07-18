import SwiftUI
import AppKit

/// The Clipboard tab: a pinned search field, an optional "Pinned" section, and the
/// reverse-chronological timeline. Click a row to paste it and dismiss; hover to pin
/// or delete; ⌘1–⌘9 paste the top nine without touching the mouse (spec §4).
struct ClipboardView: View {
    @ObservedObject var manager: ClipboardManager
    let onRequestClose: () -> Void

    @State private var query = ""
    @FocusState private var searchFocused: Bool

    private var filtered: [ClipboardItem] {
        guard !query.isEmpty else { return manager.items }
        return manager.items.filter { Fuzzy.matches(query, in: $0.preview) }
    }

    private var pinned: [ClipboardItem] { filtered.filter { $0.isPinned } }
    private var timeline: [ClipboardItem] { filtered.filter { !$0.isPinned } }

    var body: some View {
        VStack(spacing: 0) {
            searchField
            DSDivider()
            Group {
                if manager.items.isEmpty {
                    emptyState
                } else if filtered.isEmpty {
                    noMatchesState
                } else {
                    list
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(numberShortcuts)
    }

    // MARK: Search

    private var searchField: some View {
        HStack(spacing: DS.Spacing.snug) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(DS.Color.tertiaryLabel)
            TextField("Filter clipboard…", text: $query)
                .textFieldStyle(.plain)
                .font(DS.Font.rowTitle)
                .focused($searchFocused)
            if !query.isEmpty {
                Button {
                    query = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(DS.Color.tertiaryLabel)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, DS.Spacing.comfy)
        .frame(height: DS.Metrics.searchFieldHeight + 6)
    }

    // MARK: List

    private var list: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                if !pinned.isEmpty {
                    sectionHeader("Pinned")
                    ForEach(pinned) { row(for: $0, index: nil) }
                    if !timeline.isEmpty {
                        sectionHeader("Recent")
                    }
                }
                ForEach(Array(timeline.enumerated()), id: \.element.id) { pair in
                    row(for: pair.element, index: pair.offset < 9 ? pair.offset + 1 : nil)
                }
            }
            .padding(.vertical, DS.Spacing.tight)
        }
    }

    private func sectionHeader(_ title: String) -> some View {
        DSSectionHeader(title: title)
            .padding(.horizontal, DS.Spacing.comfy)
            .padding(.top, DS.Spacing.base)
            .padding(.bottom, DS.Spacing.tight)
    }

    private func row(for item: ClipboardItem, index: Int?) -> some View {
        ClipboardRow(
            item: item,
            thumbnail: item.kind == .image ? manager.thumbnail(for: item) : nil,
            shortcutIndex: index,
            onActivate: { activate(item) },
            onTogglePin: { manager.togglePin(item) },
            onDelete: { manager.delete(item) }
        )
    }

    private func activate(_ item: ClipboardItem) {
        manager.copyToPasteboard(item)
        onRequestClose()
    }

    // MARK: ⌘1–⌘9 (spec §4 power-user feature)

    private var numberShortcuts: some View {
        ForEach(0..<9, id: \.self) { i in
            Button("") {
                if i < timeline.count { activate(timeline[i]) }
            }
            .keyboardShortcut(KeyEquivalent(Character("\(i + 1)")), modifiers: .command)
            .opacity(0)
            .frame(width: 0, height: 0)
            .accessibilityHidden(true)
        }
    }

    // MARK: Empty states (real copy, not "No data" — spec §4)

    private var emptyState: some View {
        EmptyStateView(
            symbol: "doc.on.clipboard",
            title: "Nothing copied yet",
            message: "Copy something and it'll show up here — text, images, or files."
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity) // center in the fixed panel
    }

    private var noMatchesState: some View {
        EmptyStateView(
            symbol: "magnifyingglass",
            title: "No matches",
            message: "Nothing in your history matches “\(query)”."
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

/// One clipboard row: source-app icon, content preview (or thumbnail), relative time,
/// and hover-revealed pin + delete affordances.
private struct ClipboardRow: View {
    let item: ClipboardItem
    let thumbnail: NSImage?
    let shortcutIndex: Int?
    let onActivate: () -> Void
    let onTogglePin: () -> Void
    let onDelete: () -> Void

    @State private var hovering = false

    var body: some View {
        Button(action: onActivate) {
            HStack(spacing: DS.Spacing.base) {
                leading
                VStack(alignment: .leading, spacing: 1) {
                    Text(item.preview)
                        .font(DS.Font.rowTitle)
                        .foregroundStyle(DS.Color.primaryLabel)
                        .lineLimit(1)
                        .truncationMode(.middle)
                    HStack(spacing: DS.Spacing.tight) {
                        if let name = item.sourceAppName {
                            Text(name)
                                .font(DS.Font.caption)
                                .foregroundStyle(DS.Color.tertiaryLabel)
                                .lineLimit(1)
                        }
                    }
                }
                Spacer(minLength: DS.Spacing.snug)
                trailing
            }
            .padding(.horizontal, DS.Spacing.comfy)
            .frame(height: DS.Metrics.rowHeight)
            .contentShape(Rectangle())
            .background(
                RoundedRectangle(cornerRadius: DS.Radius.row, style: .continuous)
                    .fill(hovering ? DS.Color.rowHover : .clear)
                    .padding(.horizontal, DS.Spacing.snug)
            )
        }
        .buttonStyle(.plain)
        .onHover { hovering in withAnimation(DS.Motion.quick) { self.hovering = hovering } }
        .help("Click to copy back to the clipboard")
    }

    @ViewBuilder
    private var leading: some View {
        if let thumbnail {
            Image(nsImage: thumbnail)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: 28, height: 28)
                .clipShape(RoundedRectangle(cornerRadius: DS.Radius.thumbnail, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: DS.Radius.thumbnail, style: .continuous)
                        .strokeBorder(DS.Color.separator, lineWidth: 0.5)
                )
        } else if let icon = AppIconProvider.icon(forBundleID: item.sourceBundleID) {
            Image(nsImage: icon)
                .resizable()
                .frame(width: 18, height: 18)
        } else {
            Image(systemName: item.kindSymbol)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(DS.Color.secondaryLabel)
                .frame(width: 18)
        }
    }

    @ViewBuilder
    private var trailing: some View {
        if hovering {
            HStack(spacing: DS.Spacing.tight) {
                iconButton(item.isPinned ? "pin.fill" : "pin", help: item.isPinned ? "Unpin" : "Pin", action: onTogglePin)
                iconButton("xmark", help: "Delete", action: onDelete)
            }
            .transition(.opacity)
        } else {
            HStack(spacing: DS.Spacing.snug) {
                if item.isPinned {
                    Image(systemName: "pin.fill")
                        .font(.system(size: 10))
                        .foregroundStyle(DS.Color.accent)
                }
                if let index = shortcutIndex {
                    Text("⌘\(index)")
                        .font(.system(size: 10, weight: .medium, design: .rounded))
                        .foregroundStyle(DS.Color.tertiaryLabel)
                        .monospacedDigit()
                }
                Text(Format.relativeTime(item.createdAt))
                    .font(DS.Font.caption)
                    .foregroundStyle(DS.Color.tertiaryLabel)
                    .fixedSize()
            }
        }
    }

    private func iconButton(_ symbol: String, help: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(DS.Color.secondaryLabel)
                .frame(width: 20, height: 20)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(help)
    }
}

/// The reusable, deliberately-worded empty state used across tabs (spec §2, §4).
struct EmptyStateView: View {
    let symbol: String
    let title: String
    let message: String

    var body: some View {
        VStack(spacing: DS.Spacing.base) {
            Image(systemName: symbol)
                .font(.system(size: 26, weight: .light))
                .foregroundStyle(DS.Color.tertiaryLabel)
            Text(title)
                .font(DS.Font.rowTitleEmph)
                .foregroundStyle(DS.Color.secondaryLabel)
            Text(message)
                .font(DS.Font.caption)
                .foregroundStyle(DS.Color.tertiaryLabel)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, DS.Spacing.section)
        .padding(.vertical, 44)
    }
}

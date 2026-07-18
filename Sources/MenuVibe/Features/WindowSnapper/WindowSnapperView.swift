import SwiftUI

/// The Windows tab: a living cheat sheet. Each snap zone is a tappable tile showing
/// its glyph, name, and current shortcut, so the panel doubles as documentation and
/// as a mouse-driven fallback (spec §5). If Accessibility is off, an inline banner
/// explains why and offers to fix it — no silent dead feature.
struct WindowSnapperView: View {
    let snapper: WindowSnapper
    @ObservedObject var hotKeys: HotKeyCenter
    @ObservedObject private var snapperObserved: WindowSnapper

    init(snapper: WindowSnapper, hotKeys: HotKeyCenter) {
        self.snapper = snapper
        self.snapperObserved = snapper
        self.hotKeys = hotKeys
    }

    private let columns = [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)]

    private var halves: [SnapAction] { [.leftHalf, .rightHalf, .topHalf, .bottomHalf] }
    private var thirds: [SnapAction] { [.leftThird, .centerThird, .rightThird] }
    private var others: [SnapAction] { [.fullscreen, .center, .nextDisplay] }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DS.Spacing.comfy) {
                if !snapperObserved.hasAccessibilityPermission {
                    permissionBanner
                }
                group("Halves", halves)
                group("Thirds", thirds)
                group("More", others)
            }
            .padding(DS.Spacing.comfy)
            .animation(DS.Motion.spring, value: snapperObserved.hasAccessibilityPermission)
        }
        .frame(maxHeight: DS.Metrics.panelMaxHeight)
        .onAppear { snapper.refreshPermissionStatus() }
    }

    private func group(_ title: String, _ actions: [SnapAction]) -> some View {
        VStack(alignment: .leading, spacing: DS.Spacing.snug) {
            DSSectionHeader(title: title)
            LazyVGrid(columns: columns, spacing: DS.Spacing.base) {
                ForEach(actions) { action in
                    SnapTile(
                        action: action,
                        shortcut: hotKeys.combo(for: action.shortcutID).displayString,
                        enabled: snapperObserved.hasAccessibilityPermission,
                        onTap: { snapper.perform(action) }
                    )
                }
            }
        }
    }

    private var permissionBanner: some View {
        HStack(alignment: .top, spacing: DS.Spacing.base) {
            Image(systemName: "lock.trianglebadge.exclamationmark")
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(DS.Color.accent)
            VStack(alignment: .leading, spacing: 3) {
                Text("Accessibility access needed")
                    .font(DS.Font.rowTitleEmph)
                    .foregroundStyle(DS.Color.primaryLabel)
                if snapper.isTranslocated {
                    // The grant will never stick from a translocated path — tell the truth.
                    Text("MenuVibe is running from a temporary quarantine location, so macOS won't remember Accessibility access. Move MenuVibe into your Applications folder, then reopen it.")
                        .font(DS.Font.caption)
                        .foregroundStyle(DS.Color.secondaryLabel)
                        .fixedSize(horizontal: false, vertical: true)
                } else {
                    Text("Window snapping moves other apps' windows, which macOS gates behind Accessibility.")
                        .font(DS.Font.caption)
                        .foregroundStyle(DS.Color.secondaryLabel)
                        .fixedSize(horizontal: false, vertical: true)
                    Button("Open Accessibility Settings") {
                        snapper.openAccessibilitySettings()
                    }
                    .buttonStyle(.plain)
                    .font(DS.Font.interactive)
                    .foregroundStyle(DS.Color.accent)
                    .padding(.top, 2)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(DS.Spacing.comfy)
        .background(
            RoundedRectangle(cornerRadius: DS.Radius.panel, style: .continuous)
                .fill(DS.Color.accent.opacity(0.10))
        )
        .overlay(
            RoundedRectangle(cornerRadius: DS.Radius.panel, style: .continuous)
                .strokeBorder(DS.Color.accent.opacity(0.22), lineWidth: 0.5)
        )
        .transition(.opacity.combined(with: .move(edge: .top)))
    }
}

/// A single snap-zone tile. The glyph doubles as a tiny diagram of where the window
/// lands; the shortcut sits beneath so the panel is a usable cheat sheet.
private struct SnapTile: View {
    let action: SnapAction
    let shortcut: String
    let enabled: Bool
    let onTap: () -> Void
    @State private var hovering = false

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: DS.Spacing.base) {
                Image(systemName: action.symbol)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(enabled ? DS.Color.accent : DS.Color.tertiaryLabel)
                    .frame(width: 22)
                VStack(alignment: .leading, spacing: 1) {
                    Text(action.title)
                        .font(DS.Font.interactive)
                        .foregroundStyle(DS.Color.primaryLabel)
                    Text(shortcut)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(DS.Color.tertiaryLabel)
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, DS.Spacing.base)
            .frame(height: 42)
            .background(
                RoundedRectangle(cornerRadius: DS.Radius.row, style: .continuous)
                    .fill(hovering && enabled ? DS.Color.rowHover : DS.Color.primaryLabel.opacity(0.04))
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .onHover { inside in withAnimation(DS.Motion.quick) { hovering = inside } }
    }
}

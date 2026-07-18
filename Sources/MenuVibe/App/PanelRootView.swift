import SwiftUI
import AppKit

/// Bridges an `NSVisualEffectView` into SwiftUI so the panel gets *real* vibrancy
/// (the menu bar material that samples the desktop behind it), not a flat fill
/// pretending to be translucent (spec §2).
struct VisualEffectBackground: NSViewRepresentable {
    var material: NSVisualEffectView.Material = .menu
    var blending: NSVisualEffectView.BlendingMode = .behindWindow

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blending
        view.state = .active
        return view
    }

    func updateNSView(_ view: NSVisualEffectView, context: Context) {
        view.material = material
        view.blendingMode = blending
    }
}

/// The dropdown's top-level content: a tab strip over a crossfading content area,
/// all sitting on the vibrant material with a hairline border and rounded corners.
struct PanelRootView: View {
    @ObservedObject var model: PanelModel
    @ObservedObject var clipboard: ClipboardManager
    let snapper: WindowSnapper
    @ObservedObject var notes: QuickNotesStore
    @ObservedObject var sensors: SensorMonitor
    @ObservedObject var preferences: Preferences
    @ObservedObject var hotKeys: HotKeyCenter
    let onRequestClose: () -> Void
    let onOpenSettings: () -> Void

    private var tabs: [PanelTab] {
        PanelTab.allCases.filter { $0 != .sensors || preferences.sensorMonitorEnabled }
    }

    var body: some View {
        VStack(spacing: 0) {
            tabStrip
            DSDivider()
            content
                .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .frame(width: DS.Metrics.panelWidth)
        .background(VisualEffectBackground())
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.panel, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: DS.Radius.panel, style: .continuous)
                .strokeBorder(DS.Color.separator, lineWidth: 0.5)
        )
        .shadow(color: .black.opacity(0.18), radius: 16, y: 6)
        .padding(10) // room for the panel's own soft shadow
    }

    // MARK: Tab strip (icon-only, spec §3)

    private var tabStrip: some View {
        HStack(spacing: DS.Spacing.tight) {
            ForEach(tabs) { tab in
                TabButton(
                    tab: tab,
                    isActive: model.activeTab == tab,
                    action: { switchTo(tab) }
                )
            }
            Spacer(minLength: 0)
            Button(action: onOpenSettings) {
                Image(systemName: "gearshape")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(DS.Color.secondaryLabel)
                    .frame(width: 28, height: 26)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help("Preferences")
        }
        .padding(.horizontal, DS.Spacing.base)
        .frame(height: DS.Metrics.tabStripHeight)
    }

    private func switchTo(_ tab: PanelTab) {
        withAnimation(DS.Motion.crossfade) { model.activeTab = tab }
    }

    // MARK: Content

    @ViewBuilder
    private var content: some View {
        ZStack {
            switch model.activeTab {
            case .clipboard:
                ClipboardView(manager: clipboard, onRequestClose: onRequestClose)
                    .transition(.opacity)
            case .windows:
                WindowSnapperView(snapper: snapper, hotKeys: hotKeys)
                    .transition(.opacity)
            case .notes:
                QuickNotesView(store: notes, preferences: preferences,
                               focusRequest: $model.focusRequest)
                    .transition(.opacity)
            case .sensors:
                SensorMonitorView(monitor: sensors)
                    .transition(.opacity)
            }
        }
        .animation(DS.Motion.crossfade, value: model.activeTab)
    }
}

/// A single icon-only tab. Active state is a soft accent-tinted pill; the icon weight
/// matches the surrounding text per the iconography rule (spec §2).
private struct TabButton: View {
    let tab: PanelTab
    let isActive: Bool
    let action: () -> Void
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            Image(systemName: tab.symbol)
                .font(.system(size: 14, weight: isActive ? .semibold : .medium))
                .foregroundStyle(isActive ? DS.Color.accent : DS.Color.secondaryLabel)
                .frame(width: 34, height: 26)
                .background(
                    RoundedRectangle(cornerRadius: DS.Radius.button, style: .continuous)
                        .fill(isActive ? DS.Color.accent.opacity(0.15)
                              : (hovering ? DS.Color.primaryLabel.opacity(0.06) : .clear))
                )
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { inside in withAnimation(DS.Motion.quick) { hovering = inside } }
        .help(tab.title)
        .accessibilityLabel(tab.title)
    }
}

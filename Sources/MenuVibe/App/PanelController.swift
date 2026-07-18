import AppKit
import SwiftUI
import Combine

/// A borderless `NSPanel` that is still allowed to become the key window.
///
/// This is the fix for "I can't type in Quick Note / search": a plain borderless
/// window returns `false` from `canBecomeKey`, so no `TextField`/`TextEditor` inside
/// it ever becomes first responder and keystrokes go nowhere. Overriding these lets
/// the dropdown accept text like Spotlight does, while `.nonactivatingPanel` keeps it
/// from stealing the Dock/menu bar focus of whatever app you summoned it from.
final class KeyablePanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}

/// A borderless floating panel anchored under the status item. Hosts the SwiftUI
/// panel content and implements standard menu-bar-extra dismissal: click-outside,
/// Escape, or resignation of key status (spec §3).
final class PanelController: NSObject, NSWindowDelegate {
    private let panel: KeyablePanel
    private weak var appDelegate: AppDelegate?
    private let model: PanelModel
    private var localEscMonitor: Any?
    private var globalClickMonitor: Any?
    private var cancellables = Set<AnyCancellable>()

    var isOpen: Bool { panel.isVisible }

    init(appDelegate: AppDelegate) {
        self.appDelegate = appDelegate
        self.model = PanelModel(activeTab: appDelegate.preferences.lastActiveTab)

        panel = KeyablePanel(
            contentRect: NSRect(x: 0, y: 0, width: DS.Metrics.panelWidth, height: 400),
            styleMask: [.borderless, .nonactivatingPanel, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        panel.level = .statusBar
        panel.isFloatingPanel = true
        panel.hidesOnDeactivate = false
        panel.becomesKeyOnlyIfNeeded = false
        panel.isOpaque = false
        panel.backgroundColor = .clear
        // No native window shadow: AppKit traces it around the window's *rectangular*
        // frame, producing hard square corners that clash with the rounded glass surface.
        // The rounded SwiftUI `.shadow` in PanelRootView hugs the real shape instead.
        panel.hasShadow = false
        panel.animationBehavior = .utilityWindow
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]

        super.init()
        panel.delegate = self

        let root = PanelRootView(
            model: model,
            clipboard: appDelegate.clipboard,
            snapper: appDelegate.snapper,
            notes: appDelegate.notes,
            sensors: appDelegate.sensors,
            preferences: appDelegate.preferences,
            hotKeys: appDelegate.hotKeys,
            onRequestClose: { [weak self] in self?.close() },
            onOpenSettings: { [weak self] in self?.appDelegate?.openSettings() }
        )
        let hosting = NSHostingView(rootView: root)
        hosting.autoresizingMask = [.width, .height]
        panel.contentView = hosting

        // Persist the active tab as the user moves between tabs (spec §3).
        model.$activeTab
            .dropFirst()
            .sink { appDelegate.preferences.lastActiveTab = $0 }
            .store(in: &cancellables)
    }

    // MARK: Open / close

    func toggle(relativeTo anchor: NSStatusBarButton?) {
        isOpen ? close() : open(tab: model.activeTab, relativeTo: anchor)
    }

    func open(tab: PanelTab, relativeTo anchor: NSStatusBarButton?) {
        model.activeTab = tab
        guard !isOpen else {
            model.focusRequest = tab   // already open — just switch + refocus
            return
        }
        positionPanel(relativeTo: anchor)

        // Start a touch lower and transparent, then rise + fade in — a soft "settle"
        // that reads as liquid without a flash of unpositioned content.
        let target = panel.frame
        panel.setFrameOrigin(NSPoint(x: target.origin.x, y: target.origin.y - 10))
        panel.alphaValue = 0
        panel.makeKeyAndOrderFront(nil)
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.24
            ctx.timingFunction = CAMediaTimingFunction(controlPoints: 0.16, 1, 0.3, 1) // easeOutBack-ish
            panel.animator().alphaValue = 1
            panel.animator().setFrame(target, display: true)
        }
        model.focusRequest = tab
        installDismissMonitors()
    }

    func close() {
        guard isOpen else { return }
        removeDismissMonitors()
        NSAnimationContext.runAnimationGroup({ ctx in
            ctx.duration = 0.12
            ctx.timingFunction = CAMediaTimingFunction(name: .easeIn)
            panel.animator().alphaValue = 0
        }, completionHandler: { [weak self] in
            self?.panel.orderOut(nil)
        })
    }

    // MARK: Positioning

    private func positionPanel(relativeTo anchor: NSStatusBarButton?) {
        // The SwiftUI root is a fixed size (panel width/height plus its shadow padding),
        // so we size the window to that once and never let content drive the frame — the
        // window stays rock-steady across tabs and content states.
        let height = DS.Metrics.panelHeight + 20 // + shadow padding (10pt each side)
        let width = DS.Metrics.panelWidth + 20
        panel.setContentSize(NSSize(width: width, height: height))

        guard let anchor, let anchorWindow = anchor.window else {
            panel.center()
            return
        }
        let buttonRect = anchor.convert(anchor.bounds, to: nil)
        let screenRect = anchorWindow.convertToScreen(buttonRect)
        let gap: CGFloat = 6
        let pad: CGFloat = 10 // shadow padding baked into the window on every side

        // Center the *visible glass* under the status item and sit `gap` below the menu
        // bar; the window is `pad` larger all around than the glass, so we compensate.
        var originX = screenRect.midX - width / 2
        let originY = screenRect.minY - height - gap + pad

        // Keep the panel on-screen if the status item sits near a screen edge.
        if let screen = anchorWindow.screen ?? NSScreen.main {
            let visible = screen.visibleFrame
            originX = min(max(originX, visible.minX + 8 - pad), visible.maxX - width - 8 + pad)
        }
        panel.setFrameOrigin(NSPoint(x: originX, y: originY))
    }

    // MARK: Dismissal

    private func installDismissMonitors() {
        localEscMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if event.keyCode == 53 { self?.close(); return nil } // Escape
            return event
        }
        globalClickMonitor = NSEvent.addGlobalMonitorForEvents(
            matching: [.leftMouseDown, .rightMouseDown]
        ) { [weak self] _ in
            self?.close()
        }
    }

    private func removeDismissMonitors() {
        if let m = localEscMonitor { NSEvent.removeMonitor(m); localEscMonitor = nil }
        if let m = globalClickMonitor { NSEvent.removeMonitor(m); globalClickMonitor = nil }
    }

    // MARK: NSWindowDelegate

    func windowDidResignKey(_ notification: Notification) {
        // Losing key status (Spotlight, another app, Mission Control) dismisses us.
        close()
    }
}

/// Observable state shared between the panel controller and its SwiftUI content.
final class PanelModel: ObservableObject {
    @Published var activeTab: PanelTab
    /// Bumped when a feature is summoned directly (e.g. Quick Note hotkey) so the
    /// active tab can move focus to its primary input.
    @Published var focusRequest: PanelTab?

    init(activeTab: PanelTab) {
        self.activeTab = activeTab
    }
}

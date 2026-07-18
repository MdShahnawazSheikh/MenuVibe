import AppKit
import SwiftUI
import Combine

/// A borderless floating panel anchored under the status item. Hosts the SwiftUI
/// panel content and implements standard menu-bar-extra dismissal: click-outside,
/// Escape, or resignation of key status (spec §3).
final class PanelController: NSObject, NSWindowDelegate {
    private let panel: NSPanel
    private weak var appDelegate: AppDelegate?
    private let model: PanelModel
    private var localEscMonitor: Any?
    private var globalClickMonitor: Any?
    private var cancellables = Set<AnyCancellable>()

    var isOpen: Bool { panel.isVisible }

    init(appDelegate: AppDelegate) {
        self.appDelegate = appDelegate
        self.model = PanelModel(activeTab: appDelegate.preferences.lastActiveTab)

        panel = NSPanel(
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
        panel.hasShadow = true
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
        panel.alphaValue = 0
        panel.makeKeyAndOrderFront(nil)
        // Fade + settle in with the house spring feel, no flash of unpositioned content.
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.16
            ctx.timingFunction = CAMediaTimingFunction(name: .easeOut)
            panel.animator().alphaValue = 1
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
        panel.layoutIfNeeded()
        let contentHeight = panel.contentView?.fittingSize.height ?? 400
        let height = min(max(contentHeight, 200), DS.Metrics.panelMaxHeight)
        panel.setContentSize(NSSize(width: DS.Metrics.panelWidth, height: height))

        guard let anchor, let anchorWindow = anchor.window else {
            panel.center()
            return
        }
        let buttonRect = anchor.convert(anchor.bounds, to: nil)
        let screenRect = anchorWindow.convertToScreen(buttonRect)
        let gap: CGFloat = 6

        var originX = screenRect.midX - DS.Metrics.panelWidth / 2
        let originY = screenRect.minY - height - gap

        // Keep the panel on-screen if the status item sits near a screen edge.
        if let screen = anchorWindow.screen ?? NSScreen.main {
            let visible = screen.visibleFrame
            originX = min(max(originX, visible.minX + 8), visible.maxX - DS.Metrics.panelWidth - 8)
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

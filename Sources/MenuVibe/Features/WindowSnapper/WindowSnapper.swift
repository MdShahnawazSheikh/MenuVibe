import Foundation
import AppKit
import ApplicationServices
import Combine

/// Moves and resizes the frontmost window via the Accessibility API.
///
/// Coordinate note: AX uses a top-left origin measured from the primary display,
/// while Cocoa/`NSScreen` uses a bottom-left origin. Every public frame here is
/// computed in the AX (top-left) space, and screen geometry is flipped into that
/// space via `axVisibleFrame(of:)`. Getting this wrong is the classic window-snapper
/// bug where windows land on the wrong monitor or upside-down, so it lives in one place.
final class WindowSnapper: ObservableObject {

    /// Published so the Windows tab can surface an inline "grant permission" prompt
    /// the moment access is missing or revoked (spec §5).
    @Published private(set) var hasAccessibilityPermission: Bool = false

    init() {
        refreshPermissionStatus()
    }

    // MARK: Permission

    /// Whether the process is currently trusted for Accessibility, without prompting.
    @discardableResult
    func refreshPermissionStatus() -> Bool {
        let trusted = AXIsProcessTrusted()
        if trusted != hasAccessibilityPermission {
            DispatchQueue.main.async { self.hasAccessibilityPermission = trusted }
        }
        hasAccessibilityPermission = trusted
        return trusted
    }

    /// Trigger the system's Accessibility prompt (used from onboarding, spec §9).
    func requestAccessibilityPermission() {
        let key = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
        _ = AXIsProcessTrustedWithOptions([key: true] as CFDictionary)
    }

    func openAccessibilitySettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }

    // MARK: Public actions

    func perform(_ action: SnapAction) {
        guard refreshPermissionStatus() else {
            // Permission missing/revoked mid-session — nudge, don't silently no-op (spec §5).
            requestAccessibilityPermission()
            return
        }
        guard let window = focusedWindow() else { return }

        // Skip windows that are fullscreen / in their own Space, or that refuse resizing.
        guard !isFullScreen(window), isResizable(window) else { return }

        if action.isDisplayMove {
            moveToNextDisplay(window)
        } else {
            guard let screen = currentScreen(of: window) else { return }
            let target = action.frame(in: axVisibleFrame(of: screen))
            setFrame(target, for: window, animated: true)
        }
    }

    // MARK: AX element access

    private func focusedWindow() -> AXUIElement? {
        guard let app = NSWorkspace.shared.frontmostApplication else { return nil }
        let appElement = AXUIElementCreateApplication(app.processIdentifier)
        var window: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(appElement, kAXFocusedWindowAttribute as CFString, &window)
        guard result == .success, let window else { return nil }
        // Force-cast is safe: a successful AXFocusedWindow copy is always an AXUIElement.
        return (window as! AXUIElement)
    }

    private func isFullScreen(_ window: AXUIElement) -> Bool {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(window, "AXFullScreen" as CFString, &value) == .success,
              let number = value as? Bool else { return false }
        return number
    }

    private func isResizable(_ window: AXUIElement) -> Bool {
        var settable: DarwinBoolean = false
        guard AXUIElementIsAttributeSettable(window, kAXSizeAttribute as CFString, &settable) == .success
        else { return false }
        return settable.boolValue
    }

    // MARK: Geometry

    private func currentFrame(of window: AXUIElement) -> CGRect? {
        var posValue: CFTypeRef?
        var sizeValue: CFTypeRef?
        guard AXUIElementCopyAttributeValue(window, kAXPositionAttribute as CFString, &posValue) == .success,
              AXUIElementCopyAttributeValue(window, kAXSizeAttribute as CFString, &sizeValue) == .success
        else { return nil }
        var point = CGPoint.zero
        var size = CGSize.zero
        AXValueGetValue(posValue as! AXValue, .cgPoint, &point)
        AXValueGetValue(sizeValue as! AXValue, .cgSize, &size)
        return CGRect(origin: point, size: size)
    }

    /// The height of the primary display, used to flip between AX and Cocoa spaces.
    private var primaryHeight: CGFloat {
        (NSScreen.screens.first { $0.frame.origin == .zero } ?? NSScreen.main)?.frame.height ?? 0
    }

    /// A screen's `visibleFrame` (menu bar / Dock excluded) expressed in AX top-left
    /// coordinates so snap math can operate directly on it.
    private func axVisibleFrame(of screen: NSScreen) -> CGRect {
        let vf = screen.visibleFrame
        let axY = primaryHeight - vf.origin.y - vf.height
        return CGRect(x: vf.origin.x, y: axY, width: vf.width, height: vf.height)
    }

    /// Identify the screen a window currently lives on by its center point, so
    /// snapping targets the display the user is actually working on (spec §5 multi-monitor).
    private func currentScreen(of window: AXUIElement) -> NSScreen? {
        guard let frame = currentFrame(of: window) else { return NSScreen.main }
        let axCenter = CGPoint(x: frame.midX, y: frame.midY)
        // Flip the center back to Cocoa space to test against NSScreen frames.
        let cocoaCenter = CGPoint(x: axCenter.x, y: primaryHeight - axCenter.y)
        let containing = NSScreen.screens.first { $0.frame.contains(cocoaCenter) }
        if let containing { return containing }
        // Window straddles/leaves all screens: fall back to the largest overlap.
        return NSScreen.screens.max { a, b in
            overlapArea(frame, a) < overlapArea(frame, b)
        } ?? NSScreen.main
    }

    private func overlapArea(_ windowFrame: CGRect, _ screen: NSScreen) -> CGFloat {
        let axScreen = axFullFrame(of: screen)
        let intersection = windowFrame.intersection(axScreen)
        return intersection.isNull ? 0 : intersection.width * intersection.height
    }

    private func axFullFrame(of screen: NSScreen) -> CGRect {
        let f = screen.frame
        return CGRect(x: f.origin.x, y: primaryHeight - f.origin.y - f.height, width: f.width, height: f.height)
    }

    // MARK: Applying frames

    private func moveToNextDisplay(_ window: AXUIElement) {
        let screens = NSScreen.screens
        guard screens.count > 1,
              let current = currentScreen(of: window),
              let currentFrame = currentFrame(of: window),
              let currentIndex = screens.firstIndex(of: current)
        else { return }

        let next = screens[(currentIndex + 1) % screens.count]
        let from = axVisibleFrame(of: current)
        let to = axVisibleFrame(of: next)

        // Preserve the window's relative position and proportional size on the new display.
        let relX = (currentFrame.origin.x - from.origin.x) / max(from.width, 1)
        let relY = (currentFrame.origin.y - from.origin.y) / max(from.height, 1)
        let newSize = CGSize(width: min(currentFrame.width, to.width),
                             height: min(currentFrame.height, to.height))
        let newOrigin = CGPoint(x: to.origin.x + relX * to.width,
                                y: to.origin.y + relY * to.height)
        setFrame(CGRect(origin: newOrigin, size: newSize), for: window, animated: true)
    }

    private func setFrame(_ target: CGRect, for window: AXUIElement, animated: Bool) {
        guard animated, let start = currentFrame(of: window) else {
            applyFrame(target, to: window)
            return
        }
        // A short eased interpolation gives the "smooth resize" the spec asks for
        // (150–200ms), instead of a jarring instant snap. AX has no animation of its
        // own, so we step the frame over a handful of display-linked-ish ticks.
        let duration = 0.18
        let steps = 12
        var tick = 0
        let timer = Timer(timeInterval: duration / Double(steps), repeats: true) { t in
            tick += 1
            let progress = min(1, Double(tick) / Double(steps))
            let eased = 1 - pow(1 - progress, 3) // easeOutCubic
            let frame = CGRect(
                x: start.origin.x + (target.origin.x - start.origin.x) * eased,
                y: start.origin.y + (target.origin.y - start.origin.y) * eased,
                width: start.width + (target.width - start.width) * eased,
                height: start.height + (target.height - start.height) * eased
            )
            self.applyFrame(frame, to: window)
            if progress >= 1 {
                t.invalidate()
                self.applyFrame(target, to: window) // land exactly on target
            }
        }
        RunLoop.main.add(timer, forMode: .common)
    }

    /// Set size then position then size again — some apps clamp position based on
    /// their current size, so ordering matters to land the frame reliably.
    private func applyFrame(_ frame: CGRect, to window: AXUIElement) {
        var size = frame.size
        var origin = frame.origin
        if let sizeValue = AXValueCreate(.cgSize, &size) {
            AXUIElementSetAttributeValue(window, kAXSizeAttribute as CFString, sizeValue)
        }
        if let posValue = AXValueCreate(.cgPoint, &origin) {
            AXUIElementSetAttributeValue(window, kAXPositionAttribute as CFString, posValue)
        }
        if let sizeValue = AXValueCreate(.cgSize, &size) {
            AXUIElementSetAttributeValue(window, kAXSizeAttribute as CFString, sizeValue)
        }
    }
}

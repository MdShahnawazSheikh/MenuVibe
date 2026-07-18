import AppKit
import SwiftUI

/// Hosts the first-launch onboarding flow (spec §9). A borderless, centered window
/// that the user can't accidentally lose behind other apps mid-tour.
final class OnboardingWindowController: NSWindowController {
    convenience init(appDelegate: AppDelegate) {
        var controller: OnboardingWindowController?
        let root = OnboardingView(
            snapper: appDelegate.snapper,
            hotKeys: appDelegate.hotKeys,
            onFinish: {
                appDelegate.activateHotKeysAfterOnboarding()
                controller?.close()
            }
        )
        let hosting = NSHostingController(rootView: root)
        let window = NSWindow(contentViewController: hosting)
        window.styleMask = [.titled, .fullSizeContentView]
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.isMovableByWindowBackground = true
        window.setContentSize(NSSize(width: 460, height: 520))
        window.isReleasedWhenClosed = false
        window.center()
        window.standardWindowButton(.miniaturizeButton)?.isHidden = true
        window.standardWindowButton(.zoomButton)?.isHidden = true
        self.init(window: window)
        controller = self
    }
}

import Foundation
import CoreGraphics

/// The fixed set of window arrangements MenuVibe ships (spec §5 — no custom zone
/// editor in v1). Each action knows how to compute a target frame from the screen's
/// visible area, and which remappable shortcut slot drives it.
enum SnapAction: String, CaseIterable, Identifiable {
    case leftHalf, rightHalf, topHalf, bottomHalf
    case fullscreen, center
    case leftThird, centerThird, rightThird
    case nextDisplay

    var id: String { rawValue }

    var title: String {
        switch self {
        case .leftHalf:   return "Left Half"
        case .rightHalf:  return "Right Half"
        case .topHalf:    return "Top Half"
        case .bottomHalf: return "Bottom Half"
        case .fullscreen: return "Fullscreen"
        case .center:     return "Center"
        case .leftThird:  return "Left Third"
        case .centerThird:return "Center Third"
        case .rightThird: return "Right Third"
        case .nextDisplay:return "Next Display"
        }
    }

    /// SF Symbol shown on the visual cheat-sheet grid (spec §5).
    var symbol: String {
        switch self {
        case .leftHalf:   return "rectangle.lefthalf.inset.filled"
        case .rightHalf:  return "rectangle.righthalf.inset.filled"
        case .topHalf:    return "rectangle.tophalf.inset.filled"
        case .bottomHalf: return "rectangle.bottomhalf.inset.filled"
        case .fullscreen: return "rectangle.inset.filled"
        case .center:     return "rectangle.center.inset.filled"
        case .leftThird:  return "rectangle.lefthalf.inset.filled"
        case .centerThird:return "rectangle.center.inset.filled"
        case .rightThird: return "rectangle.righthalf.inset.filled"
        case .nextDisplay:return "display.2"
        }
    }

    var shortcutID: ShortcutID {
        switch self {
        case .leftHalf:   return .snapLeftHalf
        case .rightHalf:  return .snapRightHalf
        case .topHalf:    return .snapTopHalf
        case .bottomHalf: return .snapBottomHalf
        case .fullscreen: return .snapFullscreen
        case .center:     return .snapCenter
        case .leftThird:  return .snapLeftThird
        case .centerThird:return .snapCenterThird
        case .rightThird: return .snapRightThird
        case .nextDisplay:return .snapNextDisplay
        }
    }

    /// Actions that relocate across displays are handled specially by the snapper and
    /// don't have a within-screen target frame.
    var isDisplayMove: Bool { self == .nextDisplay }

    /// The target frame within a screen's visible area, in the AX/Cocoa top-left
    /// coordinate space the caller normalises to. `visible` is expected in a
    /// top-left-origin space already.
    func frame(in visible: CGRect) -> CGRect {
        let w = visible.width, h = visible.height
        let x = visible.minX, y = visible.minY
        switch self {
        case .leftHalf:   return CGRect(x: x, y: y, width: w / 2, height: h)
        case .rightHalf:  return CGRect(x: x + w / 2, y: y, width: w / 2, height: h)
        case .topHalf:    return CGRect(x: x, y: y, width: w, height: h / 2)
        case .bottomHalf: return CGRect(x: x, y: y + h / 2, width: w, height: h / 2)
        case .fullscreen: return visible
        case .center:
            // A fixed, comfortable centered size that never exceeds the screen (spec §5).
            let cw = min(900, w), ch = min(600, h)
            return CGRect(x: x + (w - cw) / 2, y: y + (h - ch) / 2, width: cw, height: ch)
        case .leftThird:   return CGRect(x: x, y: y, width: w / 3, height: h)
        case .centerThird: return CGRect(x: x + w / 3, y: y, width: w / 3, height: h)
        case .rightThird:  return CGRect(x: x + 2 * w / 3, y: y, width: w / 3, height: h)
        case .nextDisplay: return visible // unused; handled by the snapper
        }
    }
}

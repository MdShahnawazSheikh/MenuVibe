import SwiftUI
import AppKit

/// MenuVibe's design language. Everything visual routes through here so the app
/// reads as one deliberate product rather than a pile of default SwiftUI controls.
///
/// Principles enforced by this file:
///   • One accent color, taken from the *user's* macOS accent setting — never a
///     hardcoded blue, never a gradient.
///   • A tight type scale (11/12/13/15) with an intentional weight hierarchy.
///   • Corner radii that vary by element hierarchy instead of one radius everywhere.
///   • System materials for real vibrancy, system labels/grays for everything else.
enum DS {

    // MARK: Metrics

    /// Corner radii, deliberately different per element class (spec §2).
    enum Radius {
        static let button: CGFloat = 7
        static let row: CGFloat = 9
        static let panel: CGFloat = 12
        static let thumbnail: CGFloat = 5
        /// The outer glass surface (dropdown panel, settings cards) — larger, to match
        /// the softer corners of macOS's own Liquid Glass surfaces.
        static let surface: CGFloat = 18
    }

    /// A 4pt spacing grid. Density-first — this is a menu bar surface, not a page.
    enum Spacing {
        static let hairline: CGFloat = 2
        static let tight: CGFloat = 4
        static let snug: CGFloat = 6
        static let base: CGFloat = 8
        static let comfy: CGFloat = 12
        static let loose: CGFloat = 16
        static let section: CGFloat = 20
    }

    enum Metrics {
        static let panelWidth: CGFloat = 380
        /// The panel is a *fixed* height so it never jumps as content changes or as you
        /// move between tabs — the rock-solid feel of Spotlight/Raycast. Content scrolls
        /// or centers within it; it never drives the window size.
        static let panelHeight: CGFloat = 480
        static let panelMaxHeight: CGFloat = 520
        static let rowHeight: CGFloat = 44
        static let tabStripHeight: CGFloat = 38
        static let searchFieldHeight: CGFloat = 30
    }

    // MARK: Typography — SF Pro, one weight per role (spec §2).

    enum Font {
        static let sectionHeader = SwiftUI.Font.system(size: 11, weight: .semibold)
        static let rowTitle      = SwiftUI.Font.system(size: 13, weight: .regular)
        static let rowTitleEmph  = SwiftUI.Font.system(size: 13, weight: .medium)
        static let caption       = SwiftUI.Font.system(size: 11, weight: .regular)
        static let interactive   = SwiftUI.Font.system(size: 12, weight: .medium)
        static let title         = SwiftUI.Font.system(size: 15, weight: .semibold)
        static let mono          = SwiftUI.Font.system(size: 13, weight: .regular, design: .monospaced)
    }

    // MARK: Color — accent follows the system; everything else is a semantic label.

    enum Color {
        /// The user's chosen macOS accent color. Respects the System Settings value,
        /// including "multicolor" (which resolves to the current control tint).
        static var accent: SwiftUI.Color { SwiftUI.Color(nsColor: .controlAccentColor) }

        static let primaryLabel   = SwiftUI.Color(nsColor: .labelColor)
        static let secondaryLabel = SwiftUI.Color(nsColor: .secondaryLabelColor)
        static let tertiaryLabel  = SwiftUI.Color(nsColor: .tertiaryLabelColor)
        static let separator      = SwiftUI.Color(nsColor: .separatorColor)

        /// Hover fill for interactive rows — a whisper of the accent, not a slab.
        static var rowHover: SwiftUI.Color { accent.opacity(0.12) }
        static var rowSelected: SwiftUI.Color { accent.opacity(0.18) }
    }

    // MARK: Motion — snappy springs, never bouncy, never > 400ms (spec §2).

    enum Motion {
        /// The house spring. Used for panel open/close, tab switches, list reorders.
        static let spring = Animation.spring(response: 0.32, dampingFraction: 0.82)
        /// Slightly quicker spring for micro-interactions (hover, press).
        static let quick = Animation.spring(response: 0.24, dampingFraction: 0.85)
        /// Crossfade for tab content — a subtle dissolve, not a hard cut (spec §3).
        static let crossfade = Animation.easeInOut(duration: 0.18)
    }
}

// MARK: - View helpers

extension View {
    /// Suppresses the macOS keyboard focus ring on our menu-style surfaces. Inside a
    /// popover or the Settings sidebar, the outline that lands on the first control when
    /// the window becomes key reads as a stray "selected box" rather than a helpful
    /// affordance, so we opt out of it. No-op below macOS 14, where the API is absent.
    @ViewBuilder
    func noFocusRing() -> some View {
        if #available(macOS 14, *) {
            self.focusEffectDisabled()
        } else {
            self
        }
    }
}

// MARK: - Reusable primitives

/// A hairline divider that matches the system separator in both appearances.
struct DSDivider: View {
    var body: some View {
        Rectangle()
            .fill(DS.Color.separator)
            .frame(height: 1)
            .accessibilityHidden(true)
    }
}

/// A section header used inside panels and settings — 11pt semibold, tracked up,
/// secondary label color. The restrained, "real app" section label.
struct DSSectionHeader: View {
    let title: String
    var body: some View {
        Text(title.uppercased())
            .font(DS.Font.sectionHeader)
            .tracking(0.6)
            .foregroundStyle(DS.Color.secondaryLabel)
            .accessibilityAddTraits(.isHeader)
    }
}

/// A hover-tracking container. Publishes hover state so rows can reveal affordances
/// (delete button, pin) only on hover — the standard macOS list idiom.
struct HoverReader<Content: View>: View {
    @State private var hovering = false
    let content: (Bool) -> Content

    init(@ViewBuilder content: @escaping (Bool) -> Content) {
        self.content = content
    }

    var body: some View {
        content(hovering)
            .onHover { inside in
                withAnimation(DS.Motion.quick) { hovering = inside }
            }
    }
}

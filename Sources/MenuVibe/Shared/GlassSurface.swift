import SwiftUI
import AppKit

/// Bridges `NSVisualEffectView` into SwiftUI *with its corners actually clipped*.
///
/// The classic bug this fixes: SwiftUI's `.clipShape` does not clip the backing layer
/// of an `NSViewRepresentable`, so a rounded panel backed by a raw `NSVisualEffectView`
/// shows the material bleeding past the rounded corners ("the corner is overflowing
/// the glass"). Setting a rounded `maskImage` on the effect view itself clips the
/// vibrancy at its source, on every macOS version.
struct VisualEffectBackground: NSViewRepresentable {
    var material: NSVisualEffectView.Material = .menu
    var blending: NSVisualEffectView.BlendingMode = .behindWindow
    var cornerRadius: CGFloat = 0

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blending
        view.state = .active
        view.maskImage = cornerRadius > 0 ? Self.mask(radius: cornerRadius) : nil
        return view
    }

    func updateNSView(_ view: NSVisualEffectView, context: Context) {
        view.material = material
        view.blendingMode = blending
        view.maskImage = cornerRadius > 0 ? Self.mask(radius: cornerRadius) : nil
    }

    /// A resizable rounded-rect mask so the vibrancy is clipped to the corner radius.
    private static func mask(radius: CGFloat) -> NSImage {
        let edge = radius * 2 + 1
        let image = NSImage(size: NSSize(width: edge, height: edge), flipped: false) { rect in
            NSColor.black.setFill()
            NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius).fill()
            return true
        }
        image.capInsets = NSEdgeInsets(top: radius, left: radius, bottom: radius, right: radius)
        image.resizingMode = .stretch
        return image
    }
}

/// Wraps content in MenuVibe's glass surface: native Liquid Glass on macOS 26+, and a
/// correctly-clipped vibrant material with a hairline highlight everywhere else.
///
/// One modifier so every floating surface in the app looks identical and the corner
/// clipping is handled in exactly one place.
struct GlassSurface: ViewModifier {
    var radius: CGFloat = DS.Radius.surface
    var material: NSVisualEffectView.Material = .menu

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)
        if #available(macOS 26.0, *) {
            content
                .glassEffect(.regular, in: shape)
                .overlay(
                    shape.strokeBorder(.white.opacity(0.08), lineWidth: 0.5)
                        .blendMode(.plusLighter)
                )
        } else {
            content
                .background(VisualEffectBackground(material: material, cornerRadius: radius))
                .clipShape(shape)
                .overlay(
                    // A soft top highlight sells the "glass" edge in both appearances.
                    shape.strokeBorder(
                        LinearGradient(
                            colors: [.white.opacity(0.18), .white.opacity(0.02)],
                            startPoint: .top, endPoint: .bottom
                        ),
                        lineWidth: 0.75
                    )
                )
                .overlay(
                    shape.strokeBorder(DS.Color.separator.opacity(0.6), lineWidth: 0.5)
                )
        }
    }
}

extension View {
    /// Apply MenuVibe's glass surface (Liquid Glass on macOS 26+, clipped vibrancy below).
    func glassSurface(radius: CGFloat = DS.Radius.surface,
                      material: NSVisualEffectView.Material = .menu) -> some View {
        modifier(GlassSurface(radius: radius, material: material))
    }
}

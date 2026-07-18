import AppKit

/// Draws MenuVibe's menu bar mark as a vector template image.
///
/// Drawing in code (rather than shipping a raster asset) guarantees the mark stays
/// crisp at any point size and tints correctly with the menu bar's light/dark state,
/// because `isTemplate = true` hands the alpha shape to AppKit for tinting (spec §2).
///
/// The default `.layers` mark is three offset rounded squares — a compact hint at
/// "several tools stacked into one," legible down to 16pt.
enum MenuBarIcon {

    /// Point size the status item renders at. 18pt matches the menu bar's optical size.
    static let pointSize: CGFloat = 18

    static func image(for style: MenuBarIconStyle) -> NSImage {
        let size = NSSize(width: pointSize, height: pointSize)
        let image = NSImage(size: size, flipped: false) { rect in
            NSColor.black.setFill()   // color is irrelevant; template mode discards it
            NSColor.black.setStroke()
            switch style {
            case .layers: drawLayers(in: rect)
            case .blade:  drawBlade(in: rect)
            case .dot:    drawDot(in: rect)
            }
            return true
        }
        image.isTemplate = true
        image.accessibilityDescription = "MenuVibe"
        return image
    }

    // MARK: Styles

    /// Three offset rounded squares, back-to-front, with the frontmost knocked out
    /// so the stack reads as distinct layers even when solid-tinted.
    private static func drawLayers(in rect: NSRect) {
        let side = rect.width * 0.5
        let radius = side * 0.28
        let step = rect.width * 0.16

        func square(at offset: CGFloat) -> NSBezierPath {
            let origin = NSPoint(x: rect.midX - side / 2 - offset,
                                 y: rect.midY - side / 2 + offset)
            return NSBezierPath(roundedRect: NSRect(origin: origin, size: NSSize(width: side, height: side)),
                                xRadius: radius, yRadius: radius)
        }

        // Back and middle layers as outlines (they peek out behind the front one).
        for offset in [step, 0] {
            let path = square(at: offset)
            path.lineWidth = rect.width * 0.09
            path.stroke()
        }
        // Front layer filled, then a smaller cutout so the fill doesn't turn into a blob.
        let front = square(at: -step)
        front.fill()
        NSGraphicsContext.current?.compositingOperation = .destinationOut
        let cutSide = side * 0.42
        let cut = NSBezierPath(roundedRect: NSRect(x: rect.midX + step - cutSide / 2,
                                                   y: rect.midY - step - cutSide / 2,
                                                   width: cutSide, height: cutSide),
                               xRadius: radius * 0.5, yRadius: radius * 0.5)
        cut.fill()
        NSGraphicsContext.current?.compositingOperation = .sourceOver
    }

    /// An abstracted swiss-army-knife silhouette reduced to a rounded body plus a
    /// single folded blade line.
    private static func drawBlade(in rect: NSRect) {
        let bodyRect = rect.insetBy(dx: rect.width * 0.24, dy: rect.height * 0.12)
        let body = NSBezierPath(roundedRect: bodyRect,
                                xRadius: bodyRect.width * 0.45,
                                yRadius: bodyRect.width * 0.45)
        body.lineWidth = rect.width * 0.1
        body.stroke()

        let blade = NSBezierPath()
        blade.move(to: NSPoint(x: rect.midX, y: bodyRect.minY + bodyRect.height * 0.28))
        blade.line(to: NSPoint(x: rect.midX + rect.width * 0.2, y: rect.maxY - rect.height * 0.12))
        blade.lineWidth = rect.width * 0.1
        blade.lineCapStyle = .round
        blade.stroke()
    }

    /// Minimal fallback: a single rounded square with a centered dot.
    private static func drawDot(in rect: NSRect) {
        let r = rect.insetBy(dx: rect.width * 0.2, dy: rect.height * 0.2)
        let outer = NSBezierPath(roundedRect: r, xRadius: r.width * 0.3, yRadius: r.width * 0.3)
        outer.lineWidth = rect.width * 0.1
        outer.stroke()
        let dot = NSBezierPath(ovalIn: NSRect(x: rect.midX - rect.width * 0.09,
                                              y: rect.midY - rect.width * 0.09,
                                              width: rect.width * 0.18, height: rect.width * 0.18))
        dot.fill()
    }
}

#!/usr/bin/env swift
//
// Generates MenuVibe's app icon: a modern macOS squircle with a deep graphite glass
// body and the layered "multi-tool" mark rendered in a vibrant cyan→blue→indigo
// gradient. Draws each size natively for crispness, then leaves an .iconset for
// iconutil to compile into AppIcon.icns.
//
//   swift Scripts/generate-appicon.swift            # writes Design/AppIcon.iconset + Design/AppIcon-1024.png
//   iconutil -c icns Design/AppIcon.iconset -o Resources/AppIcon.icns
//
import AppKit

// MARK: - Geometry helpers

/// An Apple-style continuous superellipse ("squircle") path.
func squircle(in rect: CGRect, n: CGFloat = 4.2) -> NSBezierPath {
    let path = NSBezierPath()
    let a = rect.width / 2, b = rect.height / 2
    let cx = rect.midX, cy = rect.midY
    let steps = 720
    for i in 0...steps {
        let t = CGFloat(i) / CGFloat(steps) * 2 * .pi
        let ct = cos(t), st = sin(t)
        let x = cx + a * copysign(pow(abs(ct), 2 / n), ct)
        let y = cy + b * copysign(pow(abs(st), 2 / n), st)
        if i == 0 { path.move(to: NSPoint(x: x, y: y)) }
        else { path.line(to: NSPoint(x: x, y: y)) }
    }
    path.close()
    return path
}

/// A rounded square used for the layered mark.
func roundedSquare(_ rect: CGRect, radius: CGFloat) -> NSBezierPath {
    NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius)
}

func color(_ hex: UInt32) -> NSColor {
    NSColor(srgbRed: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255, alpha: 1)
}

// MARK: - Icon drawing

func drawIcon(size S: CGFloat) -> NSImage {
    let image = NSImage(size: NSSize(width: S, height: S))
    image.lockFocus()
    guard let ctx = NSGraphicsContext.current?.cgContext else { image.unlockFocus(); return image }
    ctx.setShouldAntialias(true)

    // macOS app-icon art occupies ~82% of the canvas, centered, with soft shadow.
    let inset = S * 0.09
    let bodyRect = CGRect(x: inset, y: inset, width: S - inset * 2, height: S - inset * 2)
    let body = squircle(in: bodyRect)

    // Drop shadow beneath the squircle.
    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -S * 0.012),
                  blur: S * 0.05, color: NSColor.black.withAlphaComponent(0.35).cgColor)
    color(0x16181D).setFill()
    body.fill()
    ctx.restoreGState()

    // Graphite glass body: top-lit vertical gradient.
    ctx.saveGState()
    body.addClip()
    let bodyGradient = NSGradient(colors: [color(0x33373F), color(0x1B1D23), color(0x101216)],
                                  atLocations: [0, 0.55, 1], colorSpace: .sRGB)!
    bodyGradient.draw(in: bodyRect, angle: -90)

    // Subtle top sheen for the glass feel.
    let sheen = NSGradient(colors: [NSColor.white.withAlphaComponent(0.14), NSColor.white.withAlphaComponent(0)],
                           atLocations: [0, 1], colorSpace: .sRGB)!
    let sheenRect = CGRect(x: bodyRect.minX, y: bodyRect.midY, width: bodyRect.width, height: bodyRect.height / 2)
    sheen.draw(in: sheenRect, angle: -90)
    ctx.restoreGState()

    // Inner hairline highlight along the top edge of the squircle.
    ctx.saveGState()
    body.lineWidth = S * 0.006
    NSColor.white.withAlphaComponent(0.10).setStroke()
    body.stroke()
    ctx.restoreGState()

    // MARK: The layered "multi-tool" mark.
    // Three offset rounded squares, back-to-front. The two back layers are drawn as
    // clean vibrant strokes; the front layer is filled with the cyan→blue→indigo
    // gradient and given a knock-out square so the stack always reads as layers.
    let markGradient = NSGradient(colors: [color(0x40E6D8), color(0x4A82FF), color(0x7A5CF7)],
                                  atLocations: [0, 0.5, 1], colorSpace: .sRGB)!
    let side = S * 0.30
    let radius = side * 0.32
    let step = S * 0.075
    let center = CGPoint(x: bodyRect.midX, y: bodyRect.midY)

    func layerRect(dx: CGFloat, dy: CGFloat) -> CGRect {
        CGRect(x: center.x - side / 2 + dx, y: center.y - side / 2 + dy, width: side, height: side)
    }

    // Back two layers: vibrant strokes, dimmer the further back they sit.
    for (dx, dy, alpha) in [(-step, -step, 0.45), (0.0, 0.0, 0.75)] {
        ctx.saveGState()
        let path = roundedSquare(layerRect(dx: dx, dy: dy), radius: radius)
        path.lineWidth = S * 0.024
        color(0x6AA0FF).withAlphaComponent(alpha).setStroke()
        path.stroke()
        ctx.restoreGState()
    }

    // Front layer: gradient fill clipped to the rounded square.
    let frontRect = layerRect(dx: step, dy: step)
    ctx.saveGState()
    roundedSquare(frontRect, radius: radius).addClip()
    markGradient.draw(in: frontRect, angle: 55)
    ctx.restoreGState()

    // Knock out a small rounded square from the front layer for legibility.
    ctx.saveGState()
    ctx.setBlendMode(.destinationOut)
    let cut = side * 0.40
    roundedSquare(CGRect(x: frontRect.midX - cut / 2, y: frontRect.midY - cut / 2, width: cut, height: cut),
                  radius: radius * 0.5).fill()
    ctx.restoreGState()

    // Soft outer glow so the mark feels lit against the graphite.
    ctx.saveGState()
    ctx.setBlendMode(.plusLighter)
    let glowRect = frontRect.insetBy(dx: -S * 0.05, dy: -S * 0.05)
    roundedSquare(glowRect, radius: radius * 1.4).addClip()
    NSGradient(colors: [color(0x4A82FF).withAlphaComponent(0.18), NSColor.clear],
               atLocations: [0, 1], colorSpace: .sRGB)!
        .draw(in: glowRect, relativeCenterPosition: NSPoint(x: 0.2, y: 0.2))
    ctx.restoreGState()

    image.unlockFocus()
    return image
}

func writePNG(_ image: NSImage, to url: URL, pixels: Int) {
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels,
                              bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                              colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    rep.size = NSSize(width: pixels, height: pixels)
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    image.draw(in: NSRect(x: 0, y: 0, width: pixels, height: pixels))
    NSGraphicsContext.restoreGraphicsState()
    try? rep.representation(using: .png, properties: [:])!.write(to: url)
}

// MARK: - Emit the iconset

let fm = FileManager.default
let root = URL(fileURLWithPath: fm.currentDirectoryPath)
let iconset = root.appendingPathComponent("Design/AppIcon.iconset")
try? fm.createDirectory(at: iconset, withIntermediateDirectories: true)

let variants: [(name: String, px: Int)] = [
    ("icon_16x16", 16), ("icon_16x16@2x", 32),
    ("icon_32x32", 32), ("icon_32x32@2x", 64),
    ("icon_128x128", 128), ("icon_128x128@2x", 256),
    ("icon_256x256", 256), ("icon_256x256@2x", 512),
    ("icon_512x512", 512), ("icon_512x512@2x", 1024),
]

for v in variants {
    let img = drawIcon(size: CGFloat(v.px))
    writePNG(img, to: iconset.appendingPathComponent("\(v.name).png"), pixels: v.px)
}

// A standalone 1024 master for the README / stores.
writePNG(drawIcon(size: 1024), to: root.appendingPathComponent("Design/AppIcon-1024.png"), pixels: 1024)

print("✓ Wrote \(iconset.path) and Design/AppIcon-1024.png")

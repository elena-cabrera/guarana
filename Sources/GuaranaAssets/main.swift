import AppKit
import CoreGraphics
import Foundation
import GuaranaArt
import ImageIO
import UniformTypeIdentifiers

// Renders every bitmap asset from the same vector drawing code the app uses.
// Usage: swift run GuaranaAssets <output-dir>

let outDir = URL(fileURLWithPath: CommandLine.arguments.dropFirst().first ?? "build/assets", isDirectory: true)
try FileManager.default.createDirectory(at: outDir, withIntermediateDirectories: true)

func render(_ w: Int, _ h: Int, _ draw: (CGContext) -> Void) -> CGImage {
    let ctx = CGContext(data: nil, width: w, height: h, bitsPerComponent: 8, bytesPerRow: 0,
                        space: CGColorSpace(name: CGColorSpace.sRGB)!,
                        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    ctx.setShouldAntialias(true)
    ctx.interpolationQuality = .high
    draw(ctx)
    return ctx.makeImage()!
}

func writePNG(_ image: CGImage, _ url: URL) {
    try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
    let dest = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil)!
    CGImageDestinationAddImage(dest, image, nil)
    CGImageDestinationFinalize(dest)
}

func roundedFont(_ size: CGFloat, _ weight: NSFont.Weight) -> NSFont {
    let base = NSFont.systemFont(ofSize: size, weight: weight)
    if let d = base.fontDescriptor.withDesign(.rounded) { return NSFont(descriptor: d, size: size) ?? base }
    return base
}

func drawText(_ ctx: CGContext, _ text: String, font: NSFont, color: CGColor, centerX: CGFloat, baselineY: CGFloat, kern: CGFloat = 0) {
    let attr = NSAttributedString(string: text, attributes: [
        .font: font, .foregroundColor: NSColor(cgColor: color)!, .kern: kern,
    ])
    let line = CTLineCreateWithAttributedString(attr)
    let width = CTLineGetTypographicBounds(line, nil, nil, nil)
    ctx.textPosition = CGPoint(x: centerX - width / 2, y: baselineY)
    CTLineDraw(line, ctx)
}

// MARK: App icon

func appIcon(_ px: Int) -> CGImage {
    render(px, px) { ctx in
        let s = CGFloat(px)
        ctx.scaleBy(x: s / 1024, y: s / 1024)
        // macOS icon grid: 824pt squircle centred in 1024.
        let tile = CGRect(x: 100, y: 100, width: 824, height: 824)
        let path = CGPath(roundedRect: tile, cornerWidth: 185, cornerHeight: 185, transform: nil)
        ctx.saveGState()
        ctx.setShadow(offset: CGSize(width: 0, height: -10), blur: 24, color: CGColor(gray: 0, alpha: 0.22))
        ctx.addPath(path); ctx.setFillColor(Palette.white); ctx.fillPath()
        ctx.restoreGState()

        ctx.saveGState()
        ctx.addPath(path); ctx.clip()
        let g = CGGradient(colorsSpace: CGColorSpace(name: CGColorSpace.sRGB)!,
                           colors: [Palette.white, CGColor(srgbRed: 1, green: 0.93, blue: 0.91, alpha: 1)] as CFArray,
                           locations: [0.35, 1])!
        ctx.drawLinearGradient(g, start: CGPoint(x: 512, y: 924), end: CGPoint(x: 512, y: 100), options: [])
        // playful confetti dots
        let dots: [(CGFloat, CGFloat, CGFloat, CGColor)] = [
            (230, 760, 22, Palette.sun), (800, 330, 16, Palette.sky), (205, 300, 13, Palette.leaf),
            (790, 780, 11, Palette.red), (850, 560, 9, Palette.sun),
        ]
        for (x, y, r, c) in dots { ctx.setFillColor(c); ctx.fillEllipse(in: CGRect(x: x - r, y: y - r, width: r * 2, height: r * 2)) }
        ctx.restoreGState()

        FruitArt.draw(in: ctx, rect: CGRect(x: 192, y: 170, width: 640, height: 640), openness: 1, style: .color)
    }
}

let iconset = outDir.appendingPathComponent("AppIcon.iconset", isDirectory: true)
for base in [16, 32, 128, 256, 512] {
    writePNG(appIcon(base), iconset.appendingPathComponent("icon_\(base)x\(base).png"))
    writePNG(appIcon(base * 2), iconset.appendingPathComponent("icon_\(base)x\(base)@2x.png"))
}

// MARK: Installer (DMG) background — 640 x 400 pt

func dmgBackground(scale: CGFloat) -> CGImage {
    let w: CGFloat = 640, h: CGFloat = 400
    return render(Int(w * scale), Int(h * scale)) { ctx in
        ctx.scaleBy(x: scale, y: scale)
        ctx.setFillColor(Palette.white); ctx.fill(CGRect(x: 0, y: 0, width: w, height: h))

        // Blush puddles under where Finder puts the two icons (app at x=160, Applications at x=480, y=210 from top).
        ctx.setFillColor(Palette.blush.copy(alpha: 0.55)!)
        ctx.fillEllipse(in: CGRect(x: 160 - 82, y: h - 210 - 82, width: 164, height: 164))
        ctx.setFillColor(CGColor(srgbRed: 0.88, green: 0.94, blue: 1, alpha: 1))
        ctx.fillEllipse(in: CGRect(x: 480 - 82, y: h - 210 - 82, width: 164, height: 164))

        // Dotted, bouncy arrow from the fruit to Applications.
        let arrow = CGMutablePath()
        arrow.move(to: CGPoint(x: 262, y: h - 196))
        arrow.addCurve(to: CGPoint(x: 372, y: h - 196),
                       control1: CGPoint(x: 290, y: h - 150), control2: CGPoint(x: 345, y: h - 150))
        ctx.saveGState()
        ctx.setLineWidth(5); ctx.setLineCap(.round)
        ctx.setLineDash(phase: 0, lengths: [0.1, 13])
        ctx.setStrokeColor(Palette.red)
        ctx.addPath(arrow); ctx.strokePath()
        ctx.restoreGState()
        // arrow head, aligned with the curve's final tangent
        let end = CGPoint(x: 372, y: h - 196)
        let dir = atan2(-46.0, 27.0)
        let head = CGMutablePath()
        for side in [-1.0, 1.0] {
            let a = dir + .pi + side * 0.55
            head.move(to: end)
            head.addLine(to: CGPoint(x: end.x + cos(a) * 16, y: end.y + sin(a) * 16))
        }
        ctx.addPath(head.copy(strokingWithWidth: 5, lineCap: .round, lineJoin: .round, miterLimit: 1))
        ctx.setFillColor(Palette.red); ctx.fillPath()

        // Confetti.
        let dots: [(CGFloat, CGFloat, CGFloat, CGColor)] = [
            (48, 60, 7, Palette.sun), (600, 52, 6, Palette.leaf), (585, 340, 8, Palette.sun),
            (40, 330, 5, Palette.sky), (320, 330, 5, Palette.red), (250, 340, 4, Palette.sky),
        ]
        for (x, y, r, c) in dots { ctx.setFillColor(c); ctx.fillEllipse(in: CGRect(x: x - r, y: h - y - r, width: r * 2, height: r * 2)) }

        // Copy.
        drawText(ctx, "Drag Guarana into Applications", font: roundedFont(22, .bold), color: Palette.ink,
                 centerX: w / 2, baselineY: h - 66)
        drawText(ctx, "then find the little red fruit in your menu bar", font: roundedFont(14, .medium),
                 color: CGColor(srgbRed: 0.45, green: 0.42, blue: 0.42, alpha: 1), centerX: w / 2, baselineY: h - 92)
        drawText(ctx, "wide awake, whenever you need it", font: roundedFont(12, .semibold),
                 color: Palette.red, centerX: w / 2, baselineY: 34, kern: 0.6)
    }
}

writePNG(dmgBackground(scale: 1), outDir.appendingPathComponent("dmg-background.png"))
writePNG(dmgBackground(scale: 2), outDir.appendingPathComponent("dmg-background@2x.png"))

// MARK: Web images

func fruit(_ px: Int, open: CGFloat, style: FruitArt.Style = .color) -> CGImage {
    render(px, px) { ctx in FruitArt.draw(in: ctx, rect: CGRect(x: 0, y: 0, width: px, height: px), openness: open, style: style) }
}
writePNG(fruit(64, open: 1), outDir.appendingPathComponent("web/favicon.png"))
writePNG(fruit(512, open: 1), outDir.appendingPathComponent("web/fruit-awake.png"))
writePNG(fruit(512, open: 0), outDir.appendingPathComponent("web/fruit-asleep.png"))
writePNG(appIcon(512), outDir.appendingPathComponent("web/app-icon.png"))
writePNG(fruit(64, open: 0, style: .template), outDir.appendingPathComponent("web/menubar-asleep.png"))

print("Assets written to \(outDir.path)")

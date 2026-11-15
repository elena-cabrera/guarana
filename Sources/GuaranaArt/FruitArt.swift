import CoreGraphics
import Foundation

/// Brand palette shared by the app, the icon and the installer.
public enum Palette {
    public static let red = CGColor(srgbRed: 0.949, green: 0.208, blue: 0.231, alpha: 1)       // #F2353B
    public static let redLight = CGColor(srgbRed: 1.0, green: 0.42, blue: 0.38, alpha: 1)      // #FF6B61
    public static let redDeep = CGColor(srgbRed: 0.78, green: 0.11, blue: 0.16, alpha: 1)      // #C71C29
    public static let leaf = CGColor(srgbRed: 0.204, green: 0.761, blue: 0.435, alpha: 1)      // #34C26F
    public static let stem = CGColor(srgbRed: 0.42, green: 0.23, blue: 0.16, alpha: 1)         // #6B3A29
    public static let aril = CGColor(srgbRed: 1.0, green: 0.98, blue: 0.95, alpha: 1)          // #FFFAF2
    public static let ink = CGColor(srgbRed: 0.118, green: 0.102, blue: 0.102, alpha: 1)       // #1E1A1A
    public static let sun = CGColor(srgbRed: 1.0, green: 0.788, blue: 0.29, alpha: 1)          // #FFC94A
    public static let blush = CGColor(srgbRed: 1.0, green: 0.84, blue: 0.82, alpha: 1)         // #FFD6D1
    public static let sky = CGColor(srgbRed: 0.46, green: 0.72, blue: 1.0, alpha: 1)           // #75B8FF
    public static let white = CGColor(srgbRed: 1, green: 1, blue: 1, alpha: 1)
}

/// The guarana fruit: a round red berry that splits open to reveal a white aril
/// and a black seed — it looks like an eye. Awake = eye open, asleep = eye closed.
public enum FruitArt {
    public enum Style {
        /// Full colour (app icon, popover, active menu bar icon).
        case color
        /// Single-colour silhouette with cut-outs, for menu bar template images.
        case template
    }

    /// Draws the fruit into `rect`.
    /// - Parameters:
    ///   - openness: 0 = eye closed (asleep), 1 = eye wide open (awake).
    ///   - yDown: pass true when the context's origin is top-left (SwiftUI Canvas, flipped NSImage).
    public static func draw(in ctx: CGContext, rect: CGRect, openness: CGFloat, style: Style, yDown: Bool = false) {
        ctx.saveGState()
        defer { ctx.restoreGState() }

        // Map the unit square (y up) onto `rect`.
        let s = min(rect.width, rect.height)
        let ox = rect.midX - s / 2
        let oy = rect.midY - s / 2
        if yDown {
            ctx.translateBy(x: ox, y: oy + s)
            ctx.scaleBy(x: s, y: -s)
        } else {
            ctx.translateBy(x: ox, y: oy)
            ctx.scaleBy(x: s, y: s)
        }

        let open = max(0, min(1, openness))
        switch style {
        case .color: drawColor(ctx, open: open)
        case .template: drawTemplate(ctx, open: open)
        }
    }

    // MARK: Geometry (unit square, y up)

    static let bodyRect = CGRect(x: 0.11, y: 0.05, width: 0.78, height: 0.76)
    static let eyeCenter = CGPoint(x: 0.5, y: 0.46)
    static let eyeWidth: CGFloat = 0.50
    static let eyeHeight: CGFloat = 0.40 // full height when open

    static func bodyPath() -> CGPath {
        // A plump round berry that tapers into a tiny tip at the bottom (guarana, not apple:
        // no dimple on top, the top is the widest part where the husk splits open).
        let p = CGMutablePath()
        let cx: CGFloat = 0.5
        let top = CGPoint(x: cx, y: 0.80)
        let tip = CGPoint(x: cx, y: 0.03)
        p.move(to: top)
        p.addCurve(to: CGPoint(x: 0.885, y: 0.47), control1: CGPoint(x: 0.73, y: 0.80), control2: CGPoint(x: 0.885, y: 0.68))
        p.addCurve(to: CGPoint(x: cx + 0.045, y: 0.055), control1: CGPoint(x: 0.885, y: 0.25), control2: CGPoint(x: 0.70, y: 0.09))
        p.addQuadCurve(to: tip, control: CGPoint(x: cx + 0.01, y: 0.04))
        p.addQuadCurve(to: CGPoint(x: cx - 0.045, y: 0.055), control: CGPoint(x: cx - 0.01, y: 0.04))
        p.addCurve(to: CGPoint(x: 0.115, y: 0.47), control1: CGPoint(x: 0.30, y: 0.09), control2: CGPoint(x: 0.115, y: 0.25))
        p.addCurve(to: top, control1: CGPoint(x: 0.115, y: 0.68), control2: CGPoint(x: 0.27, y: 0.80))
        p.closeSubpath()
        return p
    }

    static func leafPath() -> CGPath {
        let p = CGMutablePath()
        let base = CGPoint(x: 0.51, y: 0.84)
        let tip = CGPoint(x: 0.76, y: 0.96)
        p.move(to: base)
        p.addCurve(to: tip, control1: CGPoint(x: 0.55, y: 0.98), control2: CGPoint(x: 0.68, y: 1.0))
        p.addCurve(to: base, control1: CGPoint(x: 0.74, y: 0.85), control2: CGPoint(x: 0.60, y: 0.81))
        p.closeSubpath()
        return p
    }

    static func stemPath() -> CGPath {
        let p = CGMutablePath()
        p.move(to: CGPoint(x: 0.5, y: 0.78))
        p.addQuadCurve(to: CGPoint(x: 0.46, y: 0.90), control: CGPoint(x: 0.5, y: 0.86))
        return p.copy(strokingWithWidth: 0.045, lineCap: .round, lineJoin: .round, miterLimit: 1)
    }

    static func eyePath(open: CGFloat) -> CGPath {
        let c = eyeCenter
        let w = eyeWidth / 2
        let h = eyeHeight * open
        let p = CGMutablePath()
        p.move(to: CGPoint(x: c.x - w, y: c.y))
        p.addCurve(to: CGPoint(x: c.x + w, y: c.y),
                   control1: CGPoint(x: c.x - w * 0.55, y: c.y + h * 0.75),
                   control2: CGPoint(x: c.x + w * 0.55, y: c.y + h * 0.75))
        p.addCurve(to: CGPoint(x: c.x - w, y: c.y),
                   control1: CGPoint(x: c.x + w * 0.55, y: c.y - h * 0.75),
                   control2: CGPoint(x: c.x - w * 0.55, y: c.y - h * 0.75))
        p.closeSubpath()
        return p
    }

    /// A sleepy closed eye: a soft downward arc with two tiny lashes.
    static func closedEyePath(lineWidth: CGFloat) -> CGPath {
        let c = eyeCenter
        let w = eyeWidth / 2 * 0.86
        let p = CGMutablePath()
        p.move(to: CGPoint(x: c.x - w, y: c.y + 0.02))
        p.addQuadCurve(to: CGPoint(x: c.x + w, y: c.y + 0.02), control: CGPoint(x: c.x, y: c.y - 0.13))
        // lashes
        p.move(to: CGPoint(x: c.x - w * 0.45, y: c.y - 0.045))
        p.addLine(to: CGPoint(x: c.x - w * 0.62, y: c.y - 0.11))
        p.move(to: CGPoint(x: c.x + w * 0.45, y: c.y - 0.045))
        p.addLine(to: CGPoint(x: c.x + w * 0.62, y: c.y - 0.11))
        return p.copy(strokingWithWidth: lineWidth, lineCap: .round, lineJoin: .round, miterLimit: 1)
    }

    static var pupilRect: CGRect {
        let r: CGFloat = 0.135
        return CGRect(x: eyeCenter.x - r, y: eyeCenter.y - r, width: r * 2, height: r * 2)
    }

    // MARK: Colour

    static func drawColor(_ ctx: CGContext, open: CGFloat) {
        let space = CGColorSpace(name: CGColorSpace.sRGB)!

        // Soft ground shadow.
        ctx.setFillColor(CGColor(srgbRed: 0.6, green: 0.1, blue: 0.1, alpha: 0.10))
        ctx.fillEllipse(in: CGRect(x: 0.27, y: 0.0, width: 0.46, height: 0.06))

        // Stem + leaf behind the body.
        ctx.addPath(stemPath()); ctx.setFillColor(Palette.stem); ctx.fillPath()
        ctx.addPath(leafPath()); ctx.setFillColor(Palette.leaf); ctx.fillPath()
        // leaf vein
        let vein = CGMutablePath()
        vein.move(to: CGPoint(x: 0.54, y: 0.865))
        vein.addQuadCurve(to: CGPoint(x: 0.72, y: 0.945), control: CGPoint(x: 0.63, y: 0.93))
        ctx.addPath(vein.copy(strokingWithWidth: 0.012, lineCap: .round, lineJoin: .round, miterLimit: 1))
        ctx.setFillColor(CGColor(srgbRed: 1, green: 1, blue: 1, alpha: 0.45)); ctx.fillPath()

        // Body with a juicy radial gradient.
        ctx.saveGState()
        ctx.addPath(bodyPath()); ctx.clip()
        let grad = CGGradient(colorsSpace: space, colors: [Palette.redLight, Palette.red, Palette.redDeep] as CFArray,
                              locations: [0, 0.55, 1])!
        ctx.drawRadialGradient(grad, startCenter: CGPoint(x: 0.36, y: 0.62), startRadius: 0,
                               endCenter: CGPoint(x: 0.5, y: 0.42), endRadius: 0.55, options: [.drawsAfterEndLocation])
        // shine
        ctx.setFillColor(CGColor(srgbRed: 1, green: 1, blue: 1, alpha: 0.38))
        ctx.saveGState()
        ctx.translateBy(x: 0.27, y: 0.62); ctx.rotate(by: 0.6)
        ctx.fillEllipse(in: CGRect(x: -0.07, y: -0.035, width: 0.14, height: 0.07))
        ctx.restoreGState()
        ctx.fillEllipse(in: CGRect(x: 0.205, y: 0.505, width: 0.035, height: 0.035))
        ctx.restoreGState()

        if open > 0.06 {
            // Aril (white of the eye) with a darker husk rim.
            ctx.addPath(eyePath(open: open).copy(strokingWithWidth: 0.05, lineCap: .round, lineJoin: .round, miterLimit: 1))
            ctx.setFillColor(Palette.redDeep); ctx.fillPath()

            ctx.saveGState()
            ctx.addPath(eyePath(open: open)); ctx.clip()
            ctx.setFillColor(Palette.aril); ctx.fill(CGRect(x: 0, y: 0, width: 1, height: 1))
            // seed / pupil
            ctx.setFillColor(Palette.ink); ctx.fillEllipse(in: pupilRect)
            // sparkle
            ctx.setFillColor(Palette.white)
            ctx.fillEllipse(in: CGRect(x: eyeCenter.x + 0.025, y: eyeCenter.y + 0.035, width: 0.06, height: 0.06))
            ctx.fillEllipse(in: CGRect(x: eyeCenter.x - 0.07, y: eyeCenter.y - 0.075, width: 0.025, height: 0.025))
            ctx.restoreGState()
        } else {
            ctx.addPath(closedEyePath(lineWidth: 0.05))
            ctx.setFillColor(CGColor(srgbRed: 0.45, green: 0.05, blue: 0.09, alpha: 1)); ctx.fillPath()
        }

        // Rosy cheeks.
        ctx.setFillColor(CGColor(srgbRed: 1, green: 0.6, blue: 0.62, alpha: 0.55))
        ctx.fillEllipse(in: CGRect(x: 0.18, y: 0.29, width: 0.10, height: 0.055))
        ctx.fillEllipse(in: CGRect(x: 0.72, y: 0.29, width: 0.10, height: 0.055))
    }

    // MARK: Template (monochrome, menu bar)

    static func drawTemplate(_ ctx: CGContext, open: CGFloat) {
        ctx.setFillColor(CGColor(gray: 0, alpha: 1))
        ctx.addPath(stemPath()); ctx.fillPath()
        ctx.addPath(leafPath()); ctx.fillPath()
        ctx.addPath(bodyPath()); ctx.fillPath()

        ctx.setBlendMode(.clear)
        if open > 0.06 {
            ctx.addPath(eyePath(open: open)); ctx.fillPath()
            ctx.setBlendMode(.normal)
            ctx.saveGState()
            ctx.addPath(eyePath(open: open)); ctx.clip()
            ctx.fillEllipse(in: pupilRect.insetBy(dx: 0.01, dy: 0.01))
            ctx.restoreGState()
        } else {
            ctx.addPath(closedEyePath(lineWidth: 0.085)); ctx.fillPath()
            ctx.setBlendMode(.normal)
        }
    }
}

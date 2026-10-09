import AppKit

/// The logo's Sparkle for the menu bar (without the tile and bubble, which don't read at 18 pt),
/// drawn as vectors.
enum MenuBarIcon {
    static func image() -> NSImage {
        NSImage(size: NSSize(width: 18, height: 18), flipped: false) { _ in
            guard let ctx = NSGraphicsContext.current?.cgContext else { return false }
            let R: CGFloat = 8.6
            let ink = CGColor(srgbRed: 0.13, green: 0.08, blue: 0.23, alpha: 1)
            ctx.translateBy(x: 9, y: 9)

            ctx.saveGState()
            ctx.addPath(Shapes.sparkle(radius: R, pinch: 0.3))
            ctx.clip()
            let colors = [CGColor.hex(0xFFE45C), CGColor.hex(0xFFB72B), CGColor.hex(0xFF8650)]
            let gradient = CGGradient(colorsSpace: CGColorSpace(name: CGColorSpace.sRGB),
                                      colors: colors as CFArray, locations: [0, 0.5, 1])!
            ctx.drawLinearGradient(gradient, start: CGPoint(x: -R, y: R), end: CGPoint(x: R, y: -R), options: [])
            ctx.restoreGState()

            // Eyes and a little smile.
            for side in [-1.0, 1.0] as [CGFloat] {
                let x = side * 2.2
                ctx.setFillColor(.white)
                ctx.fillEllipse(in: CGRect(x: x - 1.5, y: 1.0 - 1.7, width: 3, height: 3.4))
                ctx.setFillColor(ink)
                ctx.fillEllipse(in: CGRect(x: x + 0.35 - 0.85, y: 1.3 - 0.85, width: 1.7, height: 1.7))
            }
            ctx.move(to: CGPoint(x: -1.1, y: -2.0))
            ctx.addQuadCurve(to: CGPoint(x: 1.1, y: -2.0), control: CGPoint(x: 0, y: -3.1))
            ctx.setStrokeColor(ink)
            ctx.setLineWidth(0.8)
            ctx.setLineCap(.round)
            ctx.strokePath()
            return true
        }
    }
}

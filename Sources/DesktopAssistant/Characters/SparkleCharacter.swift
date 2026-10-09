import AppKit

/// The ✨ every product slaps on its AI features, now with googly eyes. Drawn entirely in code.
final class SparklePack: CharacterPack {
    let id = "sparkle"
    let name = "Sparkle"
    // Extra height above the star so hats aren't clipped when it hops.
    let size = NSSize(width: 120, height: 150)
    let headTop: CGFloat = 100
    let footInset: CGFloat = 14
    let walkSpeed: CGFloat = 90
    let bounciness: CGFloat = 0.45
    let movement = MovementStyle.hop
    let quips = [
        "✨ I sprinkled some AI on it. ✨",
        "I'm not just a sparkle. I'm a *platform*.",
        "Every app has me now. I'm basically a celebrity. ✨",
        "Click the sparkle! Click the sparkle! Click the sparkle!",
        "My gradient was designed by a committee of 40 people.",
    ]

    func makeView() -> CharacterView {
        SparkleView(frame: NSRect(origin: .zero, size: size))
    }
}

final class SparkleView: GooglyCharacterView {
    // Gold like the ✨ emoji: lemon to amber to warm orange. Dusky when sleepy, tarnished when grumpy.
    private static let happy = palette([0xFFE45C, 0xFFB72B, 0xFF8650], glow: .hex(0xFFC83D, alpha: 0.7), lid: 0xE89A22)
    private static let sleepy = palette([0xEDD27A, 0xD9A84A, 0xC98460], glow: .hex(0xD9A84A, alpha: 0.45), lid: 0xC2913A)
    private static let grumpy = palette([0xB8B19F, 0x9B9482, 0x807A69], glow: .hex(0x807A69, alpha: 0.3), lid: 0x8E8775)

    override func palette(for state: CreatureState) -> Palette {
        switch state {
        case .sulk: return Self.grumpy
        case .sleep: return Self.sleepy
        default: return Self.happy
        }
    }

    override func drawBody(_ ctx: CGContext, R: CGFloat, palette: Palette, t: CGFloat) {
        let body = Shapes.sparkle(radius: R, pinch: 0.28)

        // Soft glow
        ctx.saveGState()
        ctx.setShadow(offset: .zero, blur: 12, color: palette.glow)
        ctx.addPath(body)
        ctx.setFillColor(palette.mid)
        ctx.fillPath()
        ctx.restoreGState()

        // Shimmering gradient fill, with a highlight on the top spike.
        ctx.saveGState()
        ctx.addPath(body)
        ctx.clip()
        let angle = t * 0.6
        let start = CGPoint(x: cos(angle) * R, y: sin(angle) * R)
        ctx.drawLinearGradient(palette.gradient, start: start, end: CGPoint(x: -start.x, y: -start.y), options: [])
        ctx.setFillColor(CGColor(gray: 1, alpha: 0.4))
        ctx.fillEllipse(in: CGRect(x: -R * 0.16, y: R * 0.42, width: R * 0.1, height: R * 0.36))
        ctx.restoreGState()

        ctx.addPath(body)
        ctx.setStrokeColor(CGColor(gray: 1, alpha: 0.55))
        ctx.setLineWidth(1.5)
        ctx.strokePath()
    }
}

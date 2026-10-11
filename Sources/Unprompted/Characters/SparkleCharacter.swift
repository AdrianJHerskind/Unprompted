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

    override func makeLayeredBody(R: CGFloat, scale: CGFloat) -> LayeredBody? {
        SparkleBody(R: R, scale: scale)
    }
}

/// The star as layers: a soft glow, a shimmering gradient that slowly turns inside the star's
/// outline, and a highlight with an outline on top. Only the gradient's direction changes from one
/// update to the next, and the window server draws gradients on the GPU, so nothing is redrawn.
private final class SparkleBody: LayeredBody {
    let layer = CALayer()
    private let glow = CALayer()
    private let fill = CAGradientLayer()
    private let shine = CALayer()
    private let shape: CGPath
    private let R: CGFloat
    private let scale: CGFloat
    private var shownGradient: CGGradient?

    init(R: CGFloat, scale: CGFloat) {
        self.R = R
        self.scale = scale
        let shape = Shapes.sparkle(radius: R, pinch: 0.28)
        self.shape = shape
        let square = CGRect(x: -R, y: -R, width: 2 * R, height: 2 * R)

        fill.bounds = square
        fill.position = .zero
        fill.locations = [0, 0.5, 1]
        let outline = CALayer()
        outline.showPicture(of: square, scale: scale) { ctx in
            ctx.addPath(shape)
            ctx.setFillColor(.black)
            ctx.fillPath()
        }
        fill.mask = outline

        shine.showPicture(of: square.insetBy(dx: -2, dy: -2), scale: scale) { ctx in
            ctx.saveGState()
            ctx.addPath(shape)
            ctx.clip()
            ctx.setFillColor(CGColor(gray: 1, alpha: 0.4))
            ctx.fillEllipse(in: CGRect(x: -R * 0.16, y: R * 0.42, width: R * 0.1, height: R * 0.36))
            ctx.restoreGState()
            ctx.addPath(shape)
            ctx.setStrokeColor(CGColor(gray: 1, alpha: 0.55))
            ctx.setLineWidth(1.5)
            ctx.strokePath()
        }

        layer.addSublayer(glow)
        layer.addSublayer(fill)
        layer.addSublayer(shine)
    }

    func update(state: CreatureState, palette: GooglyCharacterView.Palette, t: CGFloat) {
        if palette.gradient !== shownGradient {
            shownGradient = palette.gradient
            fill.colors = palette.colors
            // A soft glow doesn't need the extra pixels.
            let area = CGRect(x: -R - 16, y: -R - 16, width: 2 * R + 32, height: 2 * R + 32)
            glow.showPicture(of: area, scale: scale / 2) { [shape] ctx in
                ctx.setShadow(offset: .zero, blur: 12, color: palette.glow)
                ctx.addPath(shape)
                ctx.setFillColor(palette.mid)
                ctx.fillPath()
            }
        }
        // The gradient runs across the star, from one edge of its circle to the other, slowly turning.
        let angle = t * 0.6
        fill.startPoint = CGPoint(x: 0.5 + cos(angle) / 2, y: 0.5 + sin(angle) / 2)
        fill.endPoint = CGPoint(x: 0.5 - cos(angle) / 2, y: 0.5 - sin(angle) / 2)
    }
}

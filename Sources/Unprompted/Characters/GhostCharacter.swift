import AppKit

/// A friendly, slightly see-through ghost with a waving hem. Floats instead of walking.
final class GhostPack: CharacterPack {
    let id = "ghost"
    let name = "Ghost"
    let size = NSSize(width: 120, height: 150)
    let headTop: CGFloat = 96
    let footInset: CGFloat = 14
    let walkSpeed: CGFloat = 70
    let bounciness: CGFloat = 0.2
    let movement = MovementStyle.float
    let quips = [
        "Boo! 👻 Did I scare you? I'm an AI. I scare everyone.",
        "I'm the ghost of assistants past. Clippy says hi. 📎",
        "I haunt your unsaved documents. Ooooo…",
        "Ooooo… you have unread emails… ooooo…",
        "I'm not dead. I'm just deprecated.",
        "I float because walking is so 2010.",
    ]
    let chatReplies = [
        "Ooooo… the answer is… ooooo… unclear… 👻",
        "I asked the other side. They said: “have you tried restarting?”",
        "The spirits say maybe. The spirits are very indecisive.",
    ]

    func makeView() -> CharacterView {
        GhostView(frame: NSRect(origin: .zero, size: size))
    }
}

final class GhostView: GooglyCharacterView {
    private static let friendly = palette([0xFFFFFF, 0xF4F5FF, 0xDCE2FF], glow: .hex(0xB9A8FF, alpha: 0.7), lid: 0xE4E7F5)
    private static let drowsy = palette([0xF2F3FA, 0xE4E6F5, 0xCCD3F0], glow: .hex(0x8E9BD6, alpha: 0.45), lid: 0xD5D9EE)
    private static let gloomy = palette([0xD6D9E2, 0xC5C9D4, 0xAEB3C2], glow: .hex(0x8C93A8, alpha: 0.35), lid: 0xBFC3CE)

    override func palette(for state: CreatureState) -> Palette {
        switch state {
        case .sulk: return Self.gloomy
        case .sleep: return Self.drowsy
        default: return Self.friendly
        }
    }

    override var hatHeight: CGFloat { 0.8 }
    override var propAnchor: CGPoint { CGPoint(x: 0.92, y: -0.4) }

    override var twinkleColor: CGColor { CGColor(srgbRed: 0.75, green: 0.83, blue: 1, alpha: 0.8) }

    override func bodyGlow(for palette: Palette) -> Glow? {
        Glow(color: palette.glow, radius: 5.5)
    }

    override func drawBody(_ ctx: CGContext, R: CGFloat, palette: Palette, t: CGFloat) {
        let w = R * 0.82                // half width
        let domeCenter = R * 0.95 - w
        let hemY = -R * 0.8
        let notchY = hemY + R * 0.06    // where the hem's lobes meet
        let waveSpeed: CGFloat = state == .sleep ? 1.5 : (state == .walk || state == .fall ? 7 : 4)

        // Little arms, raised in alarm when falling or dragged, waving when talking or happy.
        let armLift: CGFloat
        switch state {
        case .fall, .drag: armLift = R * 0.35
        case .talk, .happy: armLift = R * 0.12 + sin(t * 9) * R * 0.1
        case .sulk, .sleep: armLift = -R * 0.12
        default: armLift = 0
        }

        let body = CGMutablePath()
        body.move(to: CGPoint(x: -w, y: notchY))
        body.addLine(to: CGPoint(x: -w, y: domeCenter))
        body.addArc(center: CGPoint(x: 0, y: domeCenter), radius: w, startAngle: .pi, endAngle: 0, clockwise: true)
        body.addLine(to: CGPoint(x: w, y: notchY))
        // Scalloped hem, right to left: rounded lobes with notches between them, gently waving.
        let scallops = 4
        for i in 0..<scallops {
            let x0 = w - 2 * w * CGFloat(i) / CGFloat(scallops)
            let x1 = w - 2 * w * CGFloat(i + 1) / CGFloat(scallops)
            let depth = R * 0.24 + sin(t * waveSpeed + CGFloat(i) * 1.4) * R * 0.07
            body.addCurve(to: CGPoint(x: x1, y: notchY),
                          control1: CGPoint(x: x0 - (x0 - x1) * 0.05, y: notchY - depth * 1.3),
                          control2: CGPoint(x: x1 + (x0 - x1) * 0.05, y: notchY - depth * 1.3))
        }
        body.closeSubpath()

        // Body and arms as one shape, so all of it is evenly see-through without a transparency
        // layer. The arms wind the same way as the body; otherwise where they overlap would be a hole.
        let shape = CGMutablePath()
        shape.addPath(body)
        for side in [-1.0, 1.0] as [CGFloat] {
            let arm = CGRect(x: side * w - R * 0.16, y: -R * 0.2 + armLift, width: R * 0.32, height: R * 0.2)
            let toArm = CGAffineTransform(translationX: arm.midX, y: arm.midY).scaledBy(x: arm.width / 2, y: arm.height / 2)
            shape.move(to: CGPoint(x: -1, y: 0), transform: toArm)
            shape.addArc(center: .zero, radius: 1, startAngle: .pi, endAngle: -.pi, clockwise: true, transform: toArm)
            shape.closeSubpath()
        }

        ctx.saveGState()
        // Just a little see-through, so a little of the glow behind it shows through too.
        ctx.setAlpha(0.9)
        ctx.addPath(shape)
        ctx.clip()
        // Extend past both ends so the hem's lobes (below `hemY`) get filled too.
        ctx.drawLinearGradient(palette.gradient, start: CGPoint(x: 0, y: R), end: CGPoint(x: 0, y: hemY),
                               options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])
        ctx.restoreGState()

        ctx.addPath(body)
        ctx.setStrokeColor(.hex(0xAEB4D6, alpha: 0.8))
        ctx.setLineWidth(1.2)
        ctx.strokePath()
    }
}

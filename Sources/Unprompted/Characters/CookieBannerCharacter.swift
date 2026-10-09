import AppKit

/// The web's most persistent assistant: a "We use cookies" banner on little legs.
final class CookieBannerPack: CharacterPack {
    let id = "cookiebanner"
    let name = "Cookie Banner"
    let size = NSSize(width: 120, height: 150)
    let headTop: CGFloat = 86
    let footInset: CGFloat = 14
    let walkSpeed: CGFloat = 115
    let bounciness: CGFloat = 0.3
    let movement = MovementStyle.walk
    let quips = [
        "We value your privacy! Accept all cookies? 🍪",
        "This assistant uses cookies to improve your experience. And as snacks.",
        "By ignoring me, you agree to our 1,742 partners.",
        "Reject all? Okay. I'll ask again in five minutes.",
        "Manage preferences → Legitimate interest → Are you sure? → Are you SURE?",
        "I'm GDPR compliant. Mostly. Somewhat. In spirit.",
        "Your choices have been saved. (They have not.)",
    ]
    let chatReplies = [
        "Before I answer, please accept 47 cookies. 🍪",
        "This answer is available after you click “Accept all”.",
        "Your question has been shared with 1,742 partners. The answer is yes.",
    ]

    func makeView() -> CharacterView {
        CookieBannerView(frame: NSRect(origin: .zero, size: size))
    }
}

final class CookieBannerView: GooglyCharacterView {
    // Only `lid` matters here (the sulky eyelids); the card draws its own colors.
    private static let normal = palette([0xFFFDF7, 0xFFFDF7, 0xFFFDF7], glow: .hex(0, alpha: 0.2), lid: 0xEDE6D6)
    private static let grey = palette([0xE6E6E6, 0xE6E6E6, 0xE6E6E6], glow: .hex(0, alpha: 0.2), lid: 0xD6D6D6)
    private static let legInk = CGColor.hex(0x2B2B2B)

    override func palette(for state: CreatureState) -> Palette {
        state == .sulk ? Self.grey : Self.normal
    }

    override var hatHeight: CGFloat { 0.7 }
    override var propAnchor: CGPoint { CGPoint(x: 1.22, y: -0.55) }

    override func twinkleColor(alpha: CGFloat) -> CGColor {
        CGColor(srgbRed: 0.79, green: 0.55, blue: 0.29, alpha: alpha * 0.7) // crumbs
    }

    override func drawBody(_ ctx: CGContext, R: CGFloat, palette: Palette, t: CGFloat) {
        let card = CGRect(x: -R * 1.15, y: -R * 0.72, width: R * 2.3, height: R * 1.44)
        let sulky = state == .sulk
        let paper = CGColor.hex(sulky ? 0xE6E6E6 : 0xFFFDF7)

        drawLegs(ctx, R: R, hipY: card.minY + 2, t: t)

        // The card itself.
        let cardPath = CGPath(roundedRect: card, cornerWidth: R * 0.14, cornerHeight: R * 0.14, transform: nil)
        ctx.saveGState()
        ctx.setShadow(offset: CGSize(width: 0, height: -2), blur: 6, color: .hex(0x000000, alpha: 0.25))
        ctx.addPath(cardPath)
        ctx.setFillColor(paper)
        ctx.fillPath()
        ctx.restoreGState()
        ctx.addPath(cardPath)
        ctx.setStrokeColor(.hex(0xCFC6B4))
        ctx.setLineWidth(1)
        ctx.strokePath()

        // A cookie, with a bite taken out.
        let c = CGPoint(x: card.minX + R * 0.3, y: card.maxY - R * 0.3)
        let cr = R * 0.2
        ctx.setFillColor(.hex(sulky ? 0xA89A8A : 0xC98B4A))
        ctx.fillEllipse(in: CGRect(x: c.x - cr, y: c.y - cr, width: cr * 2, height: cr * 2))
        ctx.setFillColor(.hex(0x4A2C17))
        for (dx, dy) in [(-0.35, 0.2), (0.25, 0.3), (0.0, -0.3), (-0.4, -0.35), (0.4, -0.15)] as [(CGFloat, CGFloat)] {
            ctx.fillEllipse(in: CGRect(x: c.x + dx * cr - cr * 0.13, y: c.y + dy * cr - cr * 0.13, width: cr * 0.26, height: cr * 0.26))
        }
        ctx.setFillColor(paper)
        ctx.fillEllipse(in: CGRect(x: c.x + cr * 0.45, y: c.y + cr * 0.35, width: cr * 0.8, height: cr * 0.8))

        // Title, and the two famous buttons.
        text(sulky ? "Rejected 😔" : "We use cookies", at: CGPoint(x: card.minX + R * 0.6, y: card.maxY - R * 0.4),
             size: R * 0.17, weight: .semibold, color: NSColor(white: 0.2, alpha: 1))

        let buttonY = card.minY + R * 0.08
        let buttonH = R * 0.26
        let reject = CGRect(x: card.minX + R * 0.1, y: buttonY, width: R * 0.95, height: buttonH)
        let accept = CGRect(x: card.midX + R * 0.05, y: buttonY, width: R * 1.0, height: buttonH)

        ctx.addPath(CGPath(roundedRect: reject, cornerWidth: buttonH / 2, cornerHeight: buttonH / 2, transform: nil))
        ctx.setStrokeColor(.hex(0x9AA0A6))
        ctx.setLineWidth(1)
        ctx.strokePath()
        text("Reject", centeredIn: reject, size: R * 0.15, weight: .medium, color: NSColor(white: 0.35, alpha: 1))

        let acceptColor: UInt32 = sulky ? 0xA0A4AA : (state == .happy ? 0x22B573 : 0x2F7BF6)
        ctx.addPath(CGPath(roundedRect: accept, cornerWidth: buttonH / 2, cornerHeight: buttonH / 2, transform: nil))
        ctx.setFillColor(.hex(acceptColor))
        ctx.fillPath()
        text(state == .happy ? "Accepted! ✓" : "Accept all", centeredIn: accept, size: R * 0.15, weight: .semibold, color: .white)
    }

    /// Two little legs behind the card, with a light outline so they show on dark backgrounds.
    private func drawLegs(_ ctx: CGContext, R: CGFloat, hipY: CGFloat, t: CGFloat) {
        for (i, legX) in ([-0.42, 0.42] as [CGFloat]).enumerated() {
            var swing: CGFloat = 0
            switch state {
            case .walk: swing = sin(t * 16 + CGFloat(i) * .pi) * R * 0.18
            case .fall, .drag: swing = (i == 0 ? -1 : 1) * R * 0.15 + sin(t * 20 + CGFloat(i)) * R * 0.08
            case .happy: swing = sin(t * 12 + CGFloat(i) * .pi) * R * 0.1
            default: break
            }
            let hip = CGPoint(x: legX * R, y: hipY)
            let foot = CGPoint(x: legX * R + swing, y: -R + R * 0.07)
            let shoe = CGRect(x: foot.x - R * 0.13, y: foot.y - R * 0.07, width: R * 0.26, height: R * 0.13)
            ctx.setLineCap(.round)
            ctx.setStrokeColor(.hex(0xFFFFFF, alpha: 0.85))
            ctx.setLineWidth(R * 0.07 + 2.5)
            ctx.move(to: hip)
            ctx.addLine(to: foot)
            ctx.strokePath()
            ctx.setFillColor(.hex(0xFFFFFF, alpha: 0.85))
            ctx.fillEllipse(in: shoe.insetBy(dx: -1.3, dy: -1.3))
            ctx.setStrokeColor(Self.legInk)
            ctx.setLineWidth(R * 0.07)
            ctx.move(to: hip)
            ctx.addLine(to: foot)
            ctx.strokePath()
            ctx.setFillColor(.hex(0x3A2A20))
            ctx.fillEllipse(in: shoe)
        }
    }

    private func text(_ s: String, at p: CGPoint, size: CGFloat, weight: NSFont.Weight, color: NSColor) {
        (s as NSString).draw(at: p, withAttributes: [.font: NSFont.systemFont(ofSize: size, weight: weight), .foregroundColor: color])
    }

    private func text(_ s: String, centeredIn rect: CGRect, size: CGFloat, weight: NSFont.Weight, color: NSColor) {
        let attrs: [NSAttributedString.Key: Any] = [.font: NSFont.systemFont(ofSize: size, weight: weight), .foregroundColor: color]
        let textSize = (s as NSString).size(withAttributes: attrs)
        (s as NSString).draw(at: CGPoint(x: rect.midX - textSize.width / 2, y: rect.midY - textSize.height / 2), withAttributes: attrs)
    }
}

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
        "This message will reappear every time you visit. Forever. 🍪",
        "Essential cookies only? Bold. I respect a rebel.",
        "Your consent is very important to us. Your opinion, slightly less.",
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

    override var twinkleColor: CGColor { CGColor(srgbRed: 0.79, green: 0.55, blue: 0.29, alpha: 0.7) } // crumbs

    override func makeLayeredBody(R: CGFloat, scale: CGFloat) -> LayeredBody? {
        CookieBody(view: self, R: R, scale: scale)
    }

    fileprivate static func cardRect(R: CGFloat) -> CGRect {
        CGRect(x: -R * 1.15, y: -R * 0.72, width: R * 2.3, height: R * 1.44)
    }

    fileprivate static func cardPath(R: CGFloat) -> CGPath {
        CGPath(roundedRect: cardRect(R: R), cornerWidth: R * 0.14, cornerHeight: R * 0.14, transform: nil)
    }

    /// The card as it looks while idle, sulking or happy (its shadow is a layer's).
    fileprivate func drawCard(_ ctx: CGContext, R: CGFloat, look: CreatureState) {
        let card = Self.cardRect(R: R)
        let sulky = look == .sulk
        let paper = CGColor.hex(sulky ? 0xE6E6E6 : 0xFFFDF7)

        // The card itself.
        let cardPath = Self.cardPath(R: R)
        ctx.addPath(cardPath)
        ctx.setFillColor(paper)
        ctx.fillPath()
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

        let acceptColor: UInt32 = sulky ? 0xA0A4AA : (look == .happy ? 0x22B573 : 0x2F7BF6)
        ctx.addPath(CGPath(roundedRect: accept, cornerWidth: buttonH / 2, cornerHeight: buttonH / 2, transform: nil))
        ctx.setFillColor(.hex(acceptColor))
        ctx.fillPath()
        text(look == .happy ? "Accepted! ✓" : "Accept all", centeredIn: accept, size: R * 0.15, weight: .semibold, color: .white)
    }

    /// How far the left (0) or right (1) foot is swung sideways.
    fileprivate func legSwing(_ i: Int, R: CGFloat, t: CGFloat) -> CGFloat {
        switch state {
        case .walk: return sin(t * 16 + CGFloat(i) * .pi) * R * 0.18
        case .fall, .drag: return (i == 0 ? -1 : 1) * R * 0.15 + sin(t * 20 + CGFloat(i)) * R * 0.08
        case .happy: return sin(t * 12 + CGFloat(i) * .pi) * R * 0.1
        default: return 0
        }
    }

    /// Two little legs behind the card, with a light outline so they show on dark backgrounds.
    fileprivate func drawLegs(_ ctx: CGContext, R: CGFloat, swings: [CGFloat]) {
        let hipY = Self.cardRect(R: R).minY + 2
        for (i, legX) in ([-0.42, 0.42] as [CGFloat]).enumerated() {
            let hip = CGPoint(x: legX * R, y: hipY)
            let foot = CGPoint(x: legX * R + swings[i], y: -R + R * 0.07)
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

/// The banner as layers. The card (with its text and buttons) changes only with the mood, so it's
/// a picture; the legs behind it are repainted only while they move.
private final class CookieBody: LayeredBody {
    let layer = CALayer()
    private let legs = PaintedLayer()
    private let card = CALayer()
    private weak var view: CookieBannerView?
    private let R: CGFloat
    private let scale: CGFloat
    private var shownCard: CreatureState?
    private var shownLegs: [Int]?

    init(view: CookieBannerView, R: CGFloat, scale: CGFloat) {
        self.view = view
        self.R = R
        self.scale = scale
        legs.contentsScale = scale
        card.shadowColor = .black
        card.shadowOpacity = 0.25
        card.shadowRadius = 3
        layer.addSublayer(legs)
        layer.addSublayer(card)
    }

    func update(state: CreatureState, palette: GooglyCharacterView.Palette, t: CGFloat) {
        guard let view else { return }
        let R = R
        let look: CreatureState = state == .sulk || state == .happy ? state : .idle
        if look != shownCard {
            shownCard = look
            let area = CookieBannerView.cardRect(R: R).insetBy(dx: -1, dy: -1)
            card.showPicture(of: area, scale: scale) { ctx in
                view.drawCard(ctx, R: R, look: look)
            }
            var toCard = CGAffineTransform(translationX: -area.minX, y: -area.minY)
            card.shadowPath = CookieBannerView.cardPath(R: R).copy(using: &toCard)
        }
        // The shadow falls down the screen however the card is turned (climbing, tumbling into the
        // trash). A layer's shadow turns with it, so the offset is turned back.
        if let root = view.layer {
            let from = card.convert(CGPoint.zero, from: root), to = card.convert(CGPoint(x: 0, y: -2), from: root)
            card.shadowOffset = CGSize(width: to.x - from.x, height: to.y - from.y)
        }
        let swings = [view.legSwing(0, R: R, t: t), view.legSwing(1, R: R, t: t)]
        let legsKey = swings.map { Int(($0 * 20).rounded()) }
        if legsKey != shownLegs {
            shownLegs = legsKey
            legs.repaint(CGRect(x: -R * 0.85, y: -R * 1.1, width: R * 1.7, height: R * 0.52)) { [weak view] ctx in
                view?.drawLegs(ctx, R: R, swings: swings)
            }
        }
    }
}

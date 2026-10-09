import AppKit

/// Hats and other accessories, drawn as vectors on top of any character.
enum Costume: String, CaseIterable {
    case santa, pumpkin, party, nightcap

    var title: String {
        switch self {
        case .santa: return "🎅 Santa Hat"
        case .pumpkin: return "🎃 Pumpkin"
        case .party: return "🥳 Party Hat"
        case .nightcap: return "😴 Nightcap"
        }
    }

    /// Pumpkin in October, Santa hat in December, party hat on New Year's Day.
    static func seasonal(for date: Date = Date()) -> Costume? {
        let parts = Calendar.current.dateComponents([.month, .day], from: date)
        switch (parts.month, parts.day) {
        case (10, _): return .pumpkin
        case (12, _): return .santa
        case (1, 1): return .party
        default: return nil
        }
    }

    /// Draws with the hat's bottom-center at `anchor`, `w` points wide, in a non-flipped context.
    func draw(in ctx: CGContext, anchor: CGPoint, width w: CGFloat) {
        ctx.saveGState()
        ctx.translateBy(x: anchor.x, y: anchor.y)
        ctx.setLineJoin(.round)
        switch self {
        case .santa: drawSanta(ctx, w)
        case .pumpkin: drawPumpkin(ctx, w)
        case .party: drawParty(ctx, w)
        case .nightcap: drawNightcap(ctx, w)
        }
        ctx.restoreGState()
    }

    private func drawSanta(_ ctx: CGContext, _ w: CGFloat) {
        let cone = CGMutablePath()
        cone.move(to: CGPoint(x: -w * 0.45, y: w * 0.12))
        cone.addCurve(to: CGPoint(x: w * 0.42, y: w * 0.8),
                      control1: CGPoint(x: -w * 0.32, y: w * 0.72), control2: CGPoint(x: w * 0.1, y: w * 0.95))
        cone.addCurve(to: CGPoint(x: w * 0.45, y: w * 0.12),
                      control1: CGPoint(x: w * 0.3, y: w * 0.6), control2: CGPoint(x: w * 0.42, y: w * 0.35))
        cone.closeSubpath()
        ctx.addPath(cone)
        ctx.setFillColor(.hex(0xD7263D))
        ctx.setStrokeColor(.hex(0x8E1020))
        ctx.setLineWidth(max(1, w * 0.03))
        ctx.drawPath(using: .fillStroke)

        let band = CGPath(roundedRect: CGRect(x: -w * 0.52, y: 0, width: w * 1.04, height: w * 0.24),
                          cornerWidth: w * 0.12, cornerHeight: w * 0.12, transform: nil)
        ctx.addPath(band)
        ctx.setFillColor(.white)
        ctx.setStrokeColor(.hex(0xCFCFCF))
        ctx.drawPath(using: .fillStroke)

        let r = w * 0.12
        ctx.addEllipse(in: CGRect(x: w * 0.42 - r, y: w * 0.8 - r, width: r * 2, height: r * 2))
        ctx.drawPath(using: .fillStroke)
    }

    private func drawPumpkin(_ ctx: CGContext, _ w: CGFloat) {
        let h = w * 0.72
        let body = CGRect(x: -w / 2, y: 0, width: w, height: h)
        ctx.setLineWidth(max(1, w * 0.03))
        ctx.setFillColor(.hex(0x4E7A2A))
        ctx.fill(CGRect(x: -w * 0.06, y: h - w * 0.06, width: w * 0.12, height: w * 0.2))

        ctx.addEllipse(in: body)
        ctx.setFillColor(.hex(0xF28C28))
        ctx.setStrokeColor(.hex(0xB85C12))
        ctx.drawPath(using: .fillStroke)
        ctx.setStrokeColor(.hex(0xD9731C))
        ctx.strokeEllipse(in: CGRect(x: -w * 0.24, y: 0, width: w * 0.48, height: h))
        ctx.strokeEllipse(in: CGRect(x: -w * 0.08, y: 0, width: w * 0.16, height: h))

        // Jack-o'-lantern face
        ctx.setFillColor(.hex(0x3A1F04))
        for side in [-1.0, 1.0] as [CGFloat] {
            ctx.move(to: CGPoint(x: side * w * 0.27, y: h * 0.5))
            ctx.addLine(to: CGPoint(x: side * w * 0.09, y: h * 0.5))
            ctx.addLine(to: CGPoint(x: side * w * 0.18, y: h * 0.7))
            ctx.closePath()
            ctx.fillPath()
        }
        let mouth: [CGPoint] = [
            CGPoint(x: -w * 0.3, y: h * 0.32), CGPoint(x: -w * 0.18, y: h * 0.26), CGPoint(x: -w * 0.1, y: h * 0.33),
            CGPoint(x: 0, y: h * 0.25), CGPoint(x: w * 0.1, y: h * 0.33), CGPoint(x: w * 0.18, y: h * 0.26),
            CGPoint(x: w * 0.3, y: h * 0.32), CGPoint(x: w * 0.2, y: h * 0.14), CGPoint(x: -w * 0.2, y: h * 0.14),
        ]
        ctx.addLines(between: mouth)
        ctx.closePath()
        ctx.fillPath()
    }

    private func drawNightcap(_ ctx: CGContext, _ w: CGFloat) {
        // A floppy striped sleeping cap drooping to the side.
        let cap = CGMutablePath()
        cap.move(to: CGPoint(x: -w * 0.48, y: w * 0.1))
        cap.addCurve(to: CGPoint(x: w * 0.62, y: w * 0.22),
                     control1: CGPoint(x: -w * 0.35, y: w * 1.05), control2: CGPoint(x: w * 0.45, y: w * 0.95))
        cap.addCurve(to: CGPoint(x: w * 0.46, y: w * 0.1),
                     control1: CGPoint(x: w * 0.4, y: w * 0.62), control2: CGPoint(x: w * 0.42, y: w * 0.3))
        cap.closeSubpath()
        ctx.saveGState()
        ctx.addPath(cap)
        ctx.clip()
        ctx.setFillColor(.hex(0x5B6CD9))
        ctx.fill(CGRect(x: -w, y: 0, width: w * 2, height: w * 1.2))
        ctx.setStrokeColor(.hex(0x8FA0F5))
        ctx.setLineWidth(w * 0.08)
        for i in 0..<6 {
            let y = w * 0.2 + CGFloat(i) * w * 0.17
            ctx.move(to: CGPoint(x: -w, y: y - w * 0.15))
            ctx.addLine(to: CGPoint(x: w, y: y + w * 0.15))
        }
        ctx.strokePath()
        ctx.restoreGState()
        ctx.addPath(cap)
        ctx.setStrokeColor(.hex(0x3A479E))
        ctx.setLineWidth(max(1, w * 0.03))
        ctx.strokePath()

        let band = CGPath(roundedRect: CGRect(x: -w * 0.52, y: 0, width: w * 1.04, height: w * 0.2),
                          cornerWidth: w * 0.1, cornerHeight: w * 0.1, transform: nil)
        ctx.addPath(band)
        ctx.setFillColor(.hex(0xF2F2F7))
        ctx.setStrokeColor(.hex(0xC9CBD9))
        ctx.drawPath(using: .fillStroke)
        let r = w * 0.12
        ctx.addEllipse(in: CGRect(x: w * 0.62 - r, y: w * 0.2 - r, width: r * 2, height: r * 2))
        ctx.drawPath(using: .fillStroke)
    }

    private func drawParty(_ ctx: CGContext, _ w: CGFloat) {
        let cone = CGMutablePath()
        cone.move(to: CGPoint(x: -w * 0.36, y: 0))
        cone.addLine(to: CGPoint(x: w * 0.36, y: 0))
        cone.addLine(to: CGPoint(x: 0, y: w * 0.95))
        cone.closeSubpath()

        ctx.saveGState()
        ctx.addPath(cone)
        ctx.clip()
        ctx.setFillColor(.hex(0xFF5DA2))
        ctx.fill(CGRect(x: -w, y: 0, width: w * 2, height: w))
        ctx.setStrokeColor(.hex(0xFFD23F))
        ctx.setLineWidth(w * 0.09)
        for i in -3...3 {
            let x = CGFloat(i) * w * 0.22
            ctx.move(to: CGPoint(x: x - w * 0.4, y: 0))
            ctx.addLine(to: CGPoint(x: x + w * 0.4, y: w))
        }
        ctx.strokePath()
        ctx.restoreGState()

        ctx.addPath(cone)
        ctx.setStrokeColor(.hex(0xB0306A))
        ctx.setLineWidth(max(1, w * 0.03))
        ctx.strokePath()
        let r = w * 0.11
        ctx.setFillColor(.hex(0xFFD23F))
        ctx.fillEllipse(in: CGRect(x: -r, y: w * 0.95 - r, width: r * 2, height: r * 2))
    }
}

/// Things a character can hold. Drawn as vectors next to the body.
enum Prop {
    case coffee

    /// Draws with its bottom-center at `anchor`, `h` points tall. `t` animates the steam.
    func draw(in ctx: CGContext, anchor: CGPoint, height h: CGFloat, t: CGFloat) {
        ctx.saveGState()
        ctx.translateBy(x: anchor.x, y: anchor.y)
        let w = h * 0.78
        let mug = CGRect(x: -w / 2, y: 0, width: w, height: h * 0.82)
        let grey = CGColor.hex(0x9AA0A6)
        // Handle
        ctx.setStrokeColor(grey)
        ctx.setLineWidth(h * 0.1)
        ctx.addArc(center: CGPoint(x: mug.maxX, y: mug.midY), radius: h * 0.2, startAngle: -.pi / 2, endAngle: .pi / 2, clockwise: false)
        ctx.strokePath()
        // Mug and coffee
        ctx.addPath(CGPath(roundedRect: mug, cornerWidth: h * 0.12, cornerHeight: h * 0.12, transform: nil))
        ctx.setFillColor(.white)
        ctx.setStrokeColor(grey)
        ctx.setLineWidth(max(1, h * 0.05))
        ctx.drawPath(using: .fillStroke)
        ctx.setFillColor(.hex(0x6F4A2E))
        ctx.fillEllipse(in: CGRect(x: mug.minX + h * 0.06, y: mug.maxY - h * 0.12, width: w - h * 0.12, height: h * 0.14))
        ctx.setFillColor(.hex(0xD97757))
        ctx.fill(CGRect(x: mug.minX, y: mug.minY + h * 0.25, width: w, height: h * 0.12))
        // Steam
        ctx.setLineWidth(max(1, h * 0.06))
        ctx.setLineCap(.round)
        for i in 0..<2 {
            let phase = (t * 0.8 + CGFloat(i) * 0.5).truncatingRemainder(dividingBy: 1)
            ctx.setStrokeColor(.hex(0xFFFFFF, alpha: 0.8 * (1 - phase)))
            let x = CGFloat(i == 0 ? -1 : 1) * w * 0.18
            let y0 = mug.maxY + h * 0.05 + phase * h * 0.4
            ctx.move(to: CGPoint(x: x, y: y0))
            ctx.addCurve(to: CGPoint(x: x, y: y0 + h * 0.35),
                         control1: CGPoint(x: x + h * 0.12, y: y0 + h * 0.12), control2: CGPoint(x: x - h * 0.12, y: y0 + h * 0.23))
            ctx.strokePath()
        }
        ctx.restoreGState()
    }
}

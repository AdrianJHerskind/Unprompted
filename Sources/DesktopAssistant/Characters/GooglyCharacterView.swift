import AppKit

/// The shared look of the code-drawn characters (Sparkle, Ghost, Cookie Banner):
/// googly eyes that follow the cursor, a mouth and blush for every mood, poses (hop, squash,
/// lean), twinkles, sleepy Z's, hats and props. Subclasses draw their own body in `drawBody`
/// and can change colors and where the hat and props go.
class GooglyCharacterView: CharacterView {
    struct Palette {
        let gradient: CGGradient
        let mid: CGColor
        let glow: CGColor
        /// The sulky eyelids.
        let lid: CGColor
    }

    /// A three-color gradient palette; the middle color is used for solid fills.
    static func palette(_ colors: [UInt32], glow: CGColor, lid: UInt32) -> Palette {
        let cg = colors.map { CGColor.hex($0) }
        let gradient = CGGradient(colorsSpace: CGColorSpace(name: CGColorSpace.sRGB), colors: cg as CFArray, locations: [0, 0.5, 1])!
        return Palette(gradient: gradient, mid: cg[1], glow: glow, lid: .hex(lid))
    }

    static let ink = CGColor.hex(0x22143A)
    private static let neutral = palette([0xFFFFFF, 0xF2F2F2, 0xE6E6E6], glow: .hex(0, alpha: 0.2), lid: 0xDDDDDD)

    /// Body radius, and how far the bottom of the body is above the view's bottom edge.
    let radius: CGFloat = 42
    let baseY: CGFloat = 14
    private var nextBlink: TimeInterval = 2.5
    private var blinkUntil: TimeInterval = 0

    // MARK: - For subclasses

    func palette(for state: CreatureState) -> Palette { Self.neutral }

    /// The body, centered on the origin with radius `R`. The face is drawn on top afterwards.
    func drawBody(_ ctx: CGContext, R: CGFloat, palette: Palette, t: CGFloat) {}

    /// Where the hat's bottom sits, as a fraction of the radius above the center.
    var hatHeight: CGFloat { 0.62 }

    /// Where a held prop's bottom-center sits, in fractions of the radius from the center.
    var propAnchor: CGPoint { CGPoint(x: 0.72, y: -0.35) }

    func twinkleColor(alpha: CGFloat) -> CGColor {
        CGColor(srgbRed: 1, green: 0.93, blue: 0.6, alpha: alpha)
    }

    // MARK: - Drawing

    override func advance(by dt: TimeInterval) {
        super.advance(by: dt)
        if time >= nextBlink {
            blinkUntil = time + 0.12
            nextBlink = time + .random(in: 2...6)
        }
    }

    override func draw(_ dirtyRect: NSRect) {
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }
        applyTurn(ctx)
        let R = radius
        let dir: CGFloat = facingRight ? 1 : -1
        let t = CGFloat(time)
        let pose = self.pose(dir: dir, t: t, st: CGFloat(stateTime))
        let palette = palette(for: state)
        let center = CGPoint(x: bounds.midX, y: baseY + pose.dy + R * pose.sy)
        let look = lookVector(dir: dir, t: t)

        ctx.saveGState()
        ctx.translateBy(x: bounds.midX, y: baseY + pose.dy)
        ctx.scaleBy(x: pose.sx, y: pose.sy)
        ctx.translateBy(x: 0, y: R)
        ctx.rotate(by: pose.rotation + spin)

        drawBody(ctx, R: R, palette: palette, t: t)
        drawFace(ctx, R: R, look: look, palette: palette, t: t)
        // The hat sits on top of the head, so it bobs and tilts with the body.
        costume?.draw(in: ctx, anchor: CGPoint(x: 0, y: R * hatHeight), width: R * 0.85)
        prop?.draw(in: ctx, anchor: CGPoint(x: R * propAnchor.x, y: R * propAnchor.y), height: R * 0.45, t: t)
        ctx.restoreGState()

        if state == .sleep {
            drawZs(center: center, dir: dir, t: t)
        } else if state != .sulk {
            drawTwinkles(ctx, center: center, R: R, t: t)
        }
    }

    /// Body pose for the current state: hop, squash, stretch, lean.
    private func pose(dir: CGFloat, t: CGFloat, st: CGFloat) -> (dy: CGFloat, sx: CGFloat, sy: CGFloat, rotation: CGFloat) {
        switch state {
        case .idle:
            return (3 + sin(t * 2.2) * 3, 1, 1, sin(t * 1.3) * 0.05)
        case .walk:
            let hop = abs(sin(st * 9))
            return (hop * 10, 1.08 - hop * 0.12, 0.9 + hop * 0.15, -0.1 * dir)
        case .fall:
            return (0, 0.9, 1.12, sin(t * 20) * 0.04)
        case .drag:
            return (4, 1, 1.08, sin(t * 9) * 0.3)
        case .talk:
            let pulse = abs(sin(t * 7))
            return (3 + pulse * 3, 1 + pulse * 0.03, 1 + pulse * 0.03, sin(t * 1.7) * 0.04)
        case .sulk:
            return (0, 1.04, 0.86, -0.12 * dir)
        case .happy:
            let hop = abs(sin(t * 10))
            return (4 + hop * 10, 1.05 - hop * 0.06, 0.95 + hop * 0.1, sin(t * 6) * 0.12)
        case .sleep:
            let breath = sin(t * 1.6)
            return (0, 1 + breath * 0.025, 1 - breath * 0.025, 0.22 * dir)
        }
    }

    // MARK: - Face

    private func lookVector(dir: CGFloat, t: CGFloat) -> CGVector {
        switch state {
        case .walk: return CGVector(dx: dir, dy: -0.1)
        case .fall: return CGVector(dx: 0, dy: 0.9)
        case .drag: return CGVector(dx: cos(t * 10), dy: sin(t * 10)) // dizzy
        case .sulk: return CGVector(dx: -dir * 0.9, dy: -0.5)          // pointedly looking away
        default:
            // Follow the cursor.
            guard let window else { return CGVector(dx: dir * 0.5, dy: 0) }
            let m = convert(window.convertPoint(fromScreen: NSEvent.mouseLocation), from: nil)
            let v = CGVector(dx: m.x - bounds.midX, dy: m.y - (baseY + radius))
            let d = hypot(v.dx, v.dy)
            guard d > 1 else { return .zero }
            let s = min(1, d / 40)
            return CGVector(dx: v.dx / d * s, dy: v.dy / d * s)
        }
    }

    private func drawFace(_ ctx: CGContext, R: CGFloat, look: CGVector, palette: Palette, t: CGFloat) {
        let eyeY = R * 0.1
        let eyeDX = R * 0.24
        let eyesClosed = state == .sleep || time < blinkUntil

        if [.idle, .walk, .talk, .drag, .happy].contains(state) {
            ctx.setFillColor(.hex(0xFF7AB8, alpha: state == .happy ? 0.75 : 0.45))
            for side in [-1.0, 1.0] as [CGFloat] {
                ctx.fillEllipse(in: CGRect(x: side * R * 0.4 - R * 0.07, y: eyeY - R * 0.24, width: R * 0.14, height: R * 0.08))
            }
        }

        for side in [-1.0, 1.0] as [CGFloat] {
            let x = side * eyeDX
            if state == .happy {
                drawHappyEye(ctx, x: x, y: eyeY, r: R * 0.13)
            } else if eyesClosed {
                drawClosedEye(ctx, x: x, y: eyeY, r: R * 0.13)
            } else {
                drawOpenEye(ctx, x: x, y: eyeY, R: R, look: look, palette: palette)
            }
        }

        drawMouth(ctx, R: R, t: t)
    }

    private func drawClosedEye(_ ctx: CGContext, x: CGFloat, y: CGFloat, r: CGFloat) {
        ctx.move(to: CGPoint(x: x - r, y: y))
        ctx.addQuadCurve(to: CGPoint(x: x + r, y: y), control: CGPoint(x: x, y: y - r * 0.9))
        ctx.setStrokeColor(Self.ink)
        ctx.setLineWidth(2.2)
        ctx.setLineCap(.round)
        ctx.strokePath()
    }

    /// "^" — squeezed shut with joy.
    private func drawHappyEye(_ ctx: CGContext, x: CGFloat, y: CGFloat, r: CGFloat) {
        ctx.move(to: CGPoint(x: x - r, y: y - r * 0.3))
        ctx.addQuadCurve(to: CGPoint(x: x + r, y: y - r * 0.3), control: CGPoint(x: x, y: y + r * 1.2))
        ctx.setStrokeColor(Self.ink)
        ctx.setLineWidth(2.4)
        ctx.setLineCap(.round)
        ctx.strokePath()
    }

    private func drawOpenEye(_ ctx: CGContext, x: CGFloat, y: CGFloat, R: CGFloat, look: CGVector, palette: Palette) {
        let eyeR = R * 0.16 * (state == .fall ? 1.25 : 1)
        let eyeRect = CGRect(x: x - eyeR, y: y - eyeR * 1.1, width: eyeR * 2, height: eyeR * 2.2)

        ctx.setFillColor(.white)
        ctx.fillEllipse(in: eyeRect)

        let pupilR = eyeR * (state == .fall ? 0.38 : 0.55)
        let reach = (eyeR - pupilR) * 0.85
        let pupil = CGPoint(x: x + look.dx * reach, y: y + look.dy * reach * 1.1)
        ctx.setFillColor(Self.ink)
        ctx.fillEllipse(in: CGRect(x: pupil.x - pupilR, y: pupil.y - pupilR, width: pupilR * 2, height: pupilR * 2))
        ctx.setFillColor(.white)
        let glint = pupilR * 0.35
        ctx.fillEllipse(in: CGRect(x: pupil.x - pupilR * 0.3 - glint, y: pupil.y + pupilR * 0.35 - glint,
                                   width: glint * 2, height: glint * 2))

        if state == .sulk {
            // Heavy, unimpressed eyelids.
            ctx.saveGState()
            ctx.addEllipse(in: eyeRect)
            ctx.clip()
            ctx.setFillColor(palette.lid)
            ctx.fill(CGRect(x: eyeRect.minX, y: y + eyeR * 0.05, width: eyeRect.width, height: eyeRect.height))
            ctx.restoreGState()
            ctx.move(to: CGPoint(x: eyeRect.minX, y: y + eyeR * 0.05))
            ctx.addLine(to: CGPoint(x: eyeRect.maxX, y: y + eyeR * 0.05))
            ctx.setStrokeColor(Self.ink)
            ctx.setLineWidth(1.5)
            ctx.strokePath()
        }

        ctx.addEllipse(in: eyeRect)
        ctx.setStrokeColor(.hex(0x22143A, alpha: 0.3))
        ctx.setLineWidth(1)
        ctx.strokePath()
    }

    private func drawMouth(_ ctx: CGContext, R: CGFloat, t: CGFloat) {
        let my = -R * 0.22
        let w = R * 0.12
        ctx.setStrokeColor(Self.ink)
        ctx.setFillColor(Self.ink)
        ctx.setLineWidth(2.2)
        ctx.setLineCap(.round)

        switch state {
        case .idle, .walk:
            ctx.move(to: CGPoint(x: -w, y: my))
            ctx.addQuadCurve(to: CGPoint(x: w, y: my), control: CGPoint(x: 0, y: my - w * 1.1))
            ctx.strokePath()
        case .talk:
            let open = 0.25 + 0.75 * abs(sin(t * 13))
            let h = R * 0.17 * open
            ctx.fillEllipse(in: CGRect(x: -R * 0.1, y: my - R * 0.03 - h / 2, width: R * 0.2, height: h))
        case .fall, .drag:
            ctx.fillEllipse(in: CGRect(x: -R * 0.065, y: my - R * 0.1, width: R * 0.13, height: R * 0.16))
        case .sulk:
            ctx.move(to: CGPoint(x: -w, y: my - w * 0.6))
            ctx.addQuadCurve(to: CGPoint(x: w, y: my - w * 0.6), control: CGPoint(x: 0, y: my + w * 0.4))
            ctx.strokePath()
        case .happy:
            // Big open grin with a little tongue.
            let gw = w * 1.4
            ctx.move(to: CGPoint(x: -gw, y: my + 1))
            ctx.addQuadCurve(to: CGPoint(x: gw, y: my + 1), control: CGPoint(x: 0, y: my - gw * 1.5))
            ctx.closePath()
            ctx.fillPath()
            ctx.setFillColor(.hex(0xFF7AB8))
            ctx.fillEllipse(in: CGRect(x: -gw * 0.4, y: my - gw * 0.62, width: gw * 0.8, height: gw * 0.36))
        case .sleep:
            let s = 1 + sin(t * 1.6) * 0.3
            ctx.fillEllipse(in: CGRect(x: -R * 0.035 * s, y: my - R * 0.06, width: R * 0.07 * s, height: R * 0.05 * s))
        }
    }

    // MARK: - Extras

    private func drawTwinkles(_ ctx: CGContext, center: CGPoint, R: CGFloat, t: CGFloat) {
        for i in 0..<3 {
            let phase = t * 0.8 + CGFloat(i) * 2.094
            let p = CGPoint(x: center.x + cos(phase) * R * 1.18, y: center.y + sin(phase) * R)
            let pulse = 0.5 + 0.5 * sin(t * 3 + CGFloat(i) * 1.7)
            ctx.saveGState()
            ctx.translateBy(x: p.x, y: p.y)
            ctx.addPath(Shapes.sparkle(radius: 3 + pulse * 4, pinch: 0.18))
            ctx.setFillColor(twinkleColor(alpha: 0.35 + 0.65 * pulse))
            ctx.fillPath()
            ctx.restoreGState()
        }
    }

    private func drawZs(center: CGPoint, dir: CGFloat, t: CGFloat) {
        for i in 0..<3 {
            let phase = (t * 0.35 + CGFloat(i) / 3).truncatingRemainder(dividingBy: 1)
            let alpha = sin(phase * .pi)
            let p = CGPoint(x: center.x + dir * (radius * 0.45 + phase * 20) - 5,
                            y: center.y + radius * 0.35 + phase * 24)
            let attrs: [NSAttributedString.Key: Any] = [
                .font: NSFont.systemFont(ofSize: 9 + phase * 8, weight: .heavy),
                .foregroundColor: NSColor(srgbRed: 0.45, green: 0.4, blue: 0.95, alpha: alpha),
                .strokeColor: NSColor(white: 1, alpha: alpha),
                .strokeWidth: -3,
            ]
            ("z" as NSString).draw(at: p, withAttributes: attrs)
        }
    }
}

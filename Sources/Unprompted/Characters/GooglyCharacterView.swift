import AppKit

/// A body made of Core Animation layers, which the window server animates on the GPU without
/// anything being redrawn. Its layer's origin is the middle of the body; the view poses it.
@MainActor
protocol LayeredBody: AnyObject {
    var layer: CALayer { get }
    /// Called for every update of the view with what the creature is doing, the colors for its
    /// mood and the view's clock.
    func update(state: CreatureState, palette: GooglyCharacterView.Palette, t: CGFloat)
}

/// The shared look of the code-drawn characters (Sparkle, Ghost, Cookie Banner):
/// googly eyes that follow the cursor, a mouth and blush for every mood, poses (hop, squash,
/// lean), twinkles, sleepy Z's, hats and props. Subclasses build their own body from layers in
/// `makeLayeredBody` (or draw it in `drawBody`) and can change colors and where the hat and props go.
///
/// The character is a stack of Core Animation layers rather than one drawing, because redrawing
/// everything for every update kept the CPU busy, mostly blurring the glow. The window server
/// moves, turns and fades layers on the GPU, so the pose is a transform, the twinkles are tiny
/// layers, the pupils that follow the cursor are layers moving over the eyes, and the rest of the
/// face and the hat are pictures that are redrawn only when they change.
class GooglyCharacterView: CharacterView {
    struct Palette {
        let colors: [CGColor]
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
        return Palette(colors: cg, gradient: gradient, mid: cg[1], glow: glow, lid: .hex(lid))
    }

    static let ink = CGColor.hex(0x22143A)
    private static let neutral = palette([0xFFFFFF, 0xF2F2F2, 0xE6E6E6], glow: .hex(0, alpha: 0.2), lid: 0xDDDDDD)

    /// Body radius, and how far the bottom of the body is above the view's bottom edge.
    let radius: CGFloat = 42
    let baseY: CGFloat = 14
    private var nextBlink: TimeInterval = 2.5
    private var blinkUntil: TimeInterval = 0

    // The layers in `contentLayer`, back to front:
    //   bodyCanvas: `drawBody`, painted for every update (only for a body that isn't layered)
    //   poseLayer: body coordinates (origin in the middle of the body), hopping and squashing
    //     layeredBody
    //     eyesLayer: the blush, and the eye whites or closed eyes
    //     pupilLayers: the pupils, which only move
    //     eyeRimsLayer: the rims, and sulky eyelids over the pupils
    //     mouthLayer, costumeLayer, propLayer
    //   twinkleLayers, zLayer
    private let bodyCanvas = PaintedLayer()
    private let poseLayer = CALayer()
    private var layeredBody: LayeredBody?
    private let eyesLayer = PaintedLayer()
    private let pupilLayers = [CALayer(), CALayer()]
    private let eyeRimsLayer = PaintedLayer()
    private let mouthLayer = PaintedLayer()
    private let costumeLayer = CALayer()
    private let propLayer = PaintedLayer()
    private let twinkleLayers = [CALayer(), CALayer(), CALayer()]
    private let zLayer = PaintedLayer()
    private var shownEyes: EyesKey?
    private var shownRims: RimsKey?
    private var shownPupilRadius: CGFloat?
    /// Where a pupil's layer goes, relative to the pupil's center.
    private var pupilOffset = CGPoint.zero
    private var shownLook: CGVector?
    private var shownMouth: MouthKey?
    private var shownCostume: Costume?

    override init(frame: NSRect) {
        super.init(frame: frame)
        // Twinkles shrink to less than half their picture's size as they pulse; mipmaps keep them smooth.
        for twinkle in twinkleLayers { twinkle.minificationFilter = .trilinear }
        contentLayer.addSublayer(bodyCanvas)
        contentLayer.addSublayer(poseLayer)
        poseLayer.addSublayer(eyesLayer)
        pupilLayers.forEach(poseLayer.addSublayer)
        poseLayer.addSublayer(eyeRimsLayer)
        poseLayer.addSublayer(mouthLayer)
        poseLayer.addSublayer(costumeLayer)
        poseLayer.addSublayer(propLayer)
        twinkleLayers.forEach(contentLayer.addSublayer)
        contentLayer.addSublayer(zLayer)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    // MARK: - For subclasses

    func palette(for state: CreatureState) -> Palette { Self.neutral }

    /// The body, centered on the origin with radius `R`, drawn for every update. The face is
    /// drawn on top afterwards. The simplest way to make a body, but painting it for every update
    /// costs far more than layers do (`makeLayeredBody`), which all the built-in characters use.
    func drawBody(_ ctx: CGContext, R: CGFloat, palette: Palette, t: CGFloat) {}

    /// A glow around what `drawBody` draws, which the window server blurs on the GPU. Much cheaper
    /// than `CGContext.setShadow`, which blurs on the CPU every time the body is drawn.
    struct Glow {
        var color: CGColor
        /// A Core Animation shadow radius: about half of a `setShadow` blur.
        var radius: CGFloat
    }

    func bodyGlow(for palette: Palette) -> Glow? { nil }

    /// The body built from layers instead of `drawBody`, which saves drawing it for every update.
    /// `scale` is pixels per point for pictures it makes. Nil = use `drawBody`.
    ///
    /// Called again whenever `pictureScale` changes (another screen, another size, shrinking into
    /// the trash), so keep no state across calls. A layered body brings its own glow: `bodyGlow`
    /// only applies to `drawBody`.
    func makeLayeredBody(R: CGFloat, scale: CGFloat) -> LayeredBody? { nil }

    /// Where the hat's bottom sits, as a fraction of the radius above the center.
    var hatHeight: CGFloat { 0.62 }

    /// Where a held prop's bottom-center sits, in fractions of the radius from the center.
    var propAnchor: CGPoint { CGPoint(x: 0.72, y: -0.35) }

    /// The twinkles' color, read when their pictures are made (not for every update).
    var twinkleColor: CGColor { CGColor(srgbRed: 1, green: 0.93, blue: 0.6, alpha: 1) }

    // MARK: - Updating

    override func advance(by dt: TimeInterval) {
        super.advance(by: dt)
        if time >= nextBlink {
            blinkUntil = time + 0.12
            nextBlink = time + .random(in: 2...6)
        }
    }

    override func updateContent() {
        let density = pixelDensity
        bodyCanvas.contentsScale = density
        zLayer.contentsScale = density
        let R = radius
        let dir: CGFloat = facingRight ? 1 : -1
        let t = CGFloat(time)
        let pose = self.pose(dir: dir, t: t, st: CGFloat(stateTime))
        let palette = palette(for: state)
        let center = CGPoint(x: bounds.midX, y: baseY + pose.dy + R * pose.sy)

        let toBody = CGAffineTransform(translationX: bounds.midX, y: baseY + pose.dy)
            .scaledBy(x: pose.sx, y: pose.sy)
            .translatedBy(x: 0, y: R)
            .rotated(by: pose.rotation + spin)
        poseLayer.setAffineTransform(toBody)

        if let layeredBody {
            layeredBody.update(state: state, palette: palette, t: t)
        } else {
            // Drawn with the pose already applied, so it's painted at the screen's resolution
            // instead of being resampled.
            bodyCanvas.repaint(bounds) { [weak self] ctx in
                guard let self else { return }
                ctx.concatenate(toBody)
                drawBody(ctx, R: R, palette: palette, t: t)
            }
            let glow = bodyGlow(for: palette)
            bodyCanvas.shadowOpacity = glow == nil ? 0 : 1
            bodyCanvas.shadowColor = glow?.color
            bodyCanvas.shadowRadius = glow?.radius ?? 0
            bodyCanvas.shadowOffset = .zero
        }

        updateFace(R: R, look: lookVector(dir: dir, t: t), palette: palette, t: t)
        updateAccessories(R: R, t: t)
        updateTwinkles(center: center, R: R, t: t)
        updateZs(center: center, dir: dir, t: t)
    }

    override func remakePictures() {
        for painted in [eyesLayer, eyeRimsLayer, mouthLayer, propLayer] {
            painted.contentsScale = pictureScale
        }
        layeredBody?.layer.removeFromSuperlayer()
        layeredBody = makeLayeredBody(R: radius, scale: pictureScale)
        if let layeredBody { poseLayer.insertSublayer(layeredBody.layer, at: 0) }
        bodyCanvas.isHidden = layeredBody != nil

        // One twinkle at its biggest; each one is scaled and faded.
        let r: CGFloat = 7
        let color = twinkleColor
        for twinkle in twinkleLayers {
            twinkle.showPicture(of: CGRect(x: -r - 1, y: -r - 1, width: 2 * r + 2, height: 2 * r + 2), scale: pictureScale) { ctx in
                ctx.addPath(Shapes.sparkle(radius: r, pinch: 0.18))
                ctx.setFillColor(color)
                ctx.fillPath()
            }
        }
        shownEyes = nil
        shownRims = nil
        shownPupilRadius = nil
        shownMouth = nil
        shownCostume = nil
        costumeLayer.contents = nil
    }

    // What the eyes and the mouth look like; they're repainted only when this changes. Where the
    // eyes look isn't part of it: the pupils move as layers.
    private struct EyesKey: Equatable {
        var state: CreatureState
        var closed: Bool
        var lid: CGColor
    }

    /// What the rims of open eyes look like: with sulky lids in their color (nil: no lids), and
    /// whether the eyes are wide open with fright (falling).
    private struct RimsKey: Equatable {
        var lid: CGColor?
        var wide: Bool
    }

    private struct MouthKey: Equatable {
        var state: CreatureState
        var motion: Int
    }

    /// The eyes (with the blush) and the mouth are painted separately, so talking only repaints the
    /// mouth, and following the cursor only moves the pupils.
    private func updateFace(R: CGFloat, look: CGVector, palette: Palette, t: CGFloat) {
        let eyes = EyesKey(state: state, closed: state == .sleep || time < blinkUntil, lid: palette.lid)
        let open = !eyes.closed && eyes.state != .happy
        if eyes != shownEyes {
            shownEyes = eyes
            let area = CGRect(x: -R * 0.6, y: -R * 0.25, width: R * 1.2, height: R * 0.65)
            eyesLayer.repaint(area) { [weak self] ctx in
                self?.drawEyes(ctx, R: R, eyes: eyes)
            }
            for layer in pupilLayers + [eyeRimsLayer] { layer.isHidden = !open }
            if open { showOpenEyes(R: R, area: area, eyes: eyes) }
            shownLook = nil
        }
        if open && look != shownLook {
            shownLook = look
            movePupils(R: R, look: look)
        }

        let motion = mouthMotion(t: t)
        let mouth = MouthKey(state: state, motion: Int((motion * 100).rounded()))
        if mouth != shownMouth {
            shownMouth = mouth
            mouthLayer.repaint(CGRect(x: -R * 0.3, y: -R * 0.5, width: R * 0.6, height: R * 0.36)) { [weak self] ctx in
                guard let self else { return }
                drawMouth(ctx, R: R, motion: motion)
            }
        }
    }

    private func updateAccessories(R: CGFloat, t: CGFloat) {
        if costume != shownCostume {
            shownCostume = costume
            costumeLayer.isHidden = costume == nil
            if let costume {
                let w = R * 0.85
                let anchor = CGPoint(x: 0, y: R * hatHeight)
                costumeLayer.showPicture(of: costume.area(anchor: anchor, width: w), scale: pictureScale) { ctx in
                    costume.draw(in: ctx, anchor: anchor, width: w)
                }
            }
        }

        // The prop's steam rises all the time, so it's painted for every update (it's small).
        propLayer.isHidden = prop == nil
        if let prop {
            let h = R * 0.45
            let anchor = CGPoint(x: R * propAnchor.x, y: R * propAnchor.y)
            propLayer.repaint(prop.area(anchor: anchor, height: h)) { ctx in
                prop.draw(in: ctx, anchor: anchor, height: h, t: t)
            }
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

    /// The middle of the left (-1) or right (1) eye.
    private func eyeCenter(side: CGFloat, R: CGFloat) -> CGPoint {
        CGPoint(x: side * R * 0.24, y: R * 0.1)
    }

    /// How big open eyes and their pupils are: bigger eyes with smaller pupils when they're wide
    /// open with fright (falling).
    private func eyeRadii(R: CGFloat, wide: Bool) -> (eye: CGFloat, pupil: CGFloat) {
        let eyeR = R * 0.16 * (wide ? 1.25 : 1)
        return (eyeR, eyeR * (wide ? 0.38 : 0.55))
    }

    private func eyeRect(side: CGFloat, R: CGFloat, wide: Bool) -> CGRect {
        let c = eyeCenter(side: side, R: R), eyeR = eyeRadii(R: R, wide: wide).eye
        return CGRect(x: c.x - eyeR, y: c.y - eyeR * 1.1, width: eyeR * 2, height: eyeR * 2.2)
    }

    /// Makes the parts of open eyes that stay put while the pupils move, the rims and the pupils'
    /// picture, unless they're there already (after a blink, or from a mood with the same eyes).
    private func showOpenEyes(R: CGFloat, area: CGRect, eyes: EyesKey) {
        let rims = RimsKey(lid: eyes.state == .sulk ? eyes.lid : nil, wide: eyes.state == .fall)
        if rims != shownRims {
            shownRims = rims
            eyeRimsLayer.repaint(area) { [weak self] ctx in
                self?.drawEyeRims(ctx, R: R, rims: rims)
            }
        }
        let r = eyeRadii(R: R, wide: rims.wide).pupil
        if r != shownPupilRadius {
            shownPupilRadius = r
            let first = pupilLayers[0]
            first.showPicture(of: CGRect(x: -r - 1, y: -r - 1, width: 2 * r + 2, height: 2 * r + 2), scale: pictureScale) { ctx in
                Self.drawPupil(ctx, at: .zero, r: r)
            }
            for pupil in pupilLayers.dropFirst() {
                pupil.contents = first.contents
                pupil.contentsScale = first.contentsScale
                pupil.bounds = first.bounds
            }
            // The picture is a whole number of pixels, so its middle may be a little off the pupil's.
            pupilOffset = first.position
        }
    }

    /// Moves the pupils of open eyes to look along `look`.
    private func movePupils(R: CGFloat, look: CGVector) {
        let (eyeR, pupilR) = eyeRadii(R: R, wide: state == .fall)
        let reach = (eyeR - pupilR) * 0.85
        for (side, pupil) in zip([-1.0, 1.0] as [CGFloat], pupilLayers) {
            let c = eyeCenter(side: side, R: R)
            pupil.position = CGPoint(x: c.x + look.dx * reach + pupilOffset.x, y: c.y + look.dy * reach * 1.1 + pupilOffset.y)
        }
    }

    /// What's under the pupils: the blush, and the eye whites (or closed or happy eyes).
    private func drawEyes(_ ctx: CGContext, R: CGFloat, eyes: EyesKey) {
        let state = eyes.state
        if [.idle, .walk, .talk, .drag, .happy].contains(state) {
            let eyeY = eyeCenter(side: 1, R: R).y
            ctx.setFillColor(.hex(0xFF7AB8, alpha: state == .happy ? 0.75 : 0.45))
            for side in [-1.0, 1.0] as [CGFloat] {
                ctx.fillEllipse(in: CGRect(x: side * R * 0.4 - R * 0.07, y: eyeY - R * 0.24, width: R * 0.14, height: R * 0.08))
            }
        }

        for side in [-1.0, 1.0] as [CGFloat] {
            let c = eyeCenter(side: side, R: R)
            if state == .happy {
                drawHappyEye(ctx, x: c.x, y: c.y, r: R * 0.13)
            } else if eyes.closed {
                drawClosedEye(ctx, x: c.x, y: c.y, r: R * 0.13)
            } else {
                ctx.setFillColor(.white)
                ctx.fillEllipse(in: eyeRect(side: side, R: R, wide: state == .fall))
            }
        }
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

    /// A pupil with its glint.
    private static func drawPupil(_ ctx: CGContext, at pupil: CGPoint, r pupilR: CGFloat) {
        ctx.setFillColor(ink)
        ctx.fillEllipse(in: CGRect(x: pupil.x - pupilR, y: pupil.y - pupilR, width: pupilR * 2, height: pupilR * 2))
        ctx.setFillColor(.white)
        let glint = pupilR * 0.35
        ctx.fillEllipse(in: CGRect(x: pupil.x - pupilR * 0.3 - glint, y: pupil.y + pupilR * 0.35 - glint,
                                   width: glint * 2, height: glint * 2))
    }

    /// What's over the pupils of open eyes: sulky eyelids, and the rims.
    private func drawEyeRims(_ ctx: CGContext, R: CGFloat, rims: RimsKey) {
        for side in [-1.0, 1.0] as [CGFloat] {
            let white = eyeRect(side: side, R: R, wide: rims.wide)
            if let lid = rims.lid {
                // Heavy, unimpressed eyelids.
                let lidY = eyeCenter(side: side, R: R).y + eyeRadii(R: R, wide: rims.wide).eye * 0.05
                ctx.saveGState()
                ctx.addEllipse(in: white)
                ctx.clip()
                ctx.setFillColor(lid)
                ctx.fill(CGRect(x: white.minX, y: lidY, width: white.width, height: white.height))
                ctx.restoreGState()
                ctx.move(to: CGPoint(x: white.minX, y: lidY))
                ctx.addLine(to: CGPoint(x: white.maxX, y: lidY))
                ctx.setStrokeColor(Self.ink)
                ctx.setLineWidth(1.5)
                ctx.strokePath()
            }

            ctx.addEllipse(in: white)
            ctx.setStrokeColor(.hex(0x22143A, alpha: 0.3))
            ctx.setLineWidth(1)
            ctx.strokePath()
        }
    }

    /// How far the mouth is open (talking) or how big it is (snoring): the only part of the face
    /// that moves by itself.
    private func mouthMotion(t: CGFloat) -> CGFloat {
        switch state {
        case .talk: return 0.25 + 0.75 * abs(sin(t * 13))
        case .sleep: return 1 + sin(t * 1.6) * 0.3
        default: return 0
        }
    }

    private func drawMouth(_ ctx: CGContext, R: CGFloat, motion: CGFloat) {
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
            let h = R * 0.17 * motion
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
            let s = motion
            ctx.fillEllipse(in: CGRect(x: -R * 0.035 * s, y: my - R * 0.06, width: R * 0.07 * s, height: R * 0.05 * s))
        }
    }

    // MARK: - Extras

    private func updateTwinkles(center: CGPoint, R: CGFloat, t: CGFloat) {
        let visible = state != .sleep && state != .sulk
        for (i, twinkle) in twinkleLayers.enumerated() {
            twinkle.isHidden = !visible
            guard visible else { continue }
            let phase = t * 0.8 + CGFloat(i) * 2.094
            let pulse = 0.5 + 0.5 * sin(t * 3 + CGFloat(i) * 1.7)
            let size = (3 + pulse * 4) / 7
            twinkle.position = CGPoint(x: center.x + cos(phase) * R * 1.18, y: center.y + sin(phase) * R)
            twinkle.setAffineTransform(CGAffineTransform(scaleX: size, y: size))
            twinkle.opacity = Float(0.35 + 0.65 * pulse)
        }
    }

    private func updateZs(center: CGPoint, dir: CGFloat, t: CGFloat) {
        zLayer.isHidden = state != .sleep
        guard state == .sleep else { return }
        // Where the Z's start; they drift up and away from there. The layer sits on whole pixels,
        // so its text isn't resampled.
        let start = CGPoint(x: center.x + dir * radius * 0.45 - 5, y: center.y + radius * 0.35)
        let scale = zLayer.contentsScale
        let area = CGRect(x: ((start.x - 24) * scale).rounded(.down) / scale, y: ((start.y - 6) * scale).rounded(.down) / scale,
                          width: 60, height: 56)
        zLayer.repaint(area) { [weak self] ctx in
            guard let self else { return }
            drawZs(start: start, dir: dir, t: t)
        }
    }

    private func drawZs(start: CGPoint, dir: CGFloat, t: CGFloat) {
        for i in 0..<3 {
            let phase = (t * 0.35 + CGFloat(i) / 3).truncatingRemainder(dividingBy: 1)
            let alpha = sin(phase * .pi)
            let p = CGPoint(x: start.x + dir * phase * 20, y: start.y + phase * 24)
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

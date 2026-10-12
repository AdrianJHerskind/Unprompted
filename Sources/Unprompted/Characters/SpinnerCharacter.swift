import AppKit

/// The loading spinner every app shows while it "thinks", now with googly eyes. It rolls instead
/// of walking, spins faster while it talks and stalls when it sulks. Drawn entirely in code.
final class SpinnerPack: CharacterPack {
    let id = "spinner"
    let name = "Loading Spinner"
    let size = NSSize(width: 120, height: 150)
    let headTop: CGFloat = 100
    // The ring reaches below the body's circle: 3 points with the big head dot at the bottom, less
    // with a tail dot.
    let footInset: CGFloat = 12
    let walkSpeed: CGFloat = 90
    let bounciness: CGFloat = 0.35
    let movement = MovementStyle.roll
    let quips = [
        "Reasoning for 47 seconds… This is the part where I look very busy.",
        "Almost there… almost there… I've been almost there since Tuesday.",
        "99% done! The last 1% takes the other 99% of the time.",
        "Estimated time remaining: 2 minutes. Then 6 hours. Then 2 minutes.",
        "I'm not stuck. I'm thinking in circles. It's a reasoning technique.",
        "Don't refresh! You'd lose all the waiting you've already done.",
        "A watched spinner never loads. ⏳",
    ]
    let chatReplies = [
        "Reasoning for 3 minutes… The answer is: it depends. ⏳",
        "Almost there… almost there… Timed out. It was a really good answer, too.",
        "Loading answer… 12%… 99%… 4%… Let's call it a yes.",
    ]

    func makeView() -> CharacterView {
        SpinnerView(frame: NSRect(origin: .zero, size: size))
    }
}

final class SpinnerView: GooglyCharacterView {
    // The face sits on a pale disc: the palette is the disc's gradient, halo and rim. Mint when done.
    private static let awake = palette([0xF1F3FF, 0xE3E7FF, 0xCDD3FA], glow: .hex(0x7B8CFF, alpha: 0.45), lid: 0xD9DDF5)
    private static let done = palette([0xFFFFFF, 0xF0FCF5, 0xD6F5E3], glow: .hex(0x3CCB7F, alpha: 0.45), lid: 0xD3EEDD)
    private static let drowsy = palette([0xEFF0F8, 0xE3E6F3, 0xCDD2E8], glow: .hex(0x7B8CFF, alpha: 0.25), lid: 0xCCD1E6)
    private static let frozen = palette([0xEEEEF0, 0xE1E1E4, 0xCBCBD0], glow: .hex(0x000000, alpha: 0.2), lid: 0xC8C8CD)

    override func palette(for state: CreatureState) -> Palette {
        switch state {
        case .sulk: return Self.frozen
        case .sleep: return Self.drowsy
        case .happy: return Self.done
        default: return Self.awake
        }
    }

    // Only the ring rolls, like a wheel around an upright face: the hat stays on, the coffee in.
    override var faceRollsAlong: Bool { false }
    override var hatHeight: CGFloat { 0.9 }
    override var propAnchor: CGPoint { CGPoint(x: 1.08, y: -0.62) }
    // No twinkles: they'd land on the ring's dots, and circling outside it they'd dip below the floor.
    override var hasTwinkles: Bool { false }

    /// How far the ring has rolled (radians, counterclockwise), and how far its bright head has
    /// stepped (dots clockwise, from 0 up to the number of dots). The head steps the way the ring
    /// rolls: clockwise while it faces right, counterclockwise while it faces left.
    fileprivate private(set) var rolled: CGFloat = 0
    fileprivate private(set) var steps: CGFloat = 0
    private var lastSpin: CGFloat = 0

    override func advance(by dt: TimeInterval) {
        super.advance(by: dt)
        let n = CGFloat(SpinnerBody.dotCount), dot = 2 * .pi / n
        // The ring rolls with `spin` while it rolls along or flies. Otherwise it settles onto the
        // nearest dot: once it stops, the creature turns `spin` back upright for faces that roll
        // along, up to half a turn, and the ring needn't roll back.
        if spinIsRoll && (state == .walk || state == .fall) && turn == 0 {
            rolled += spin - lastSpin
        } else {
            let off = rolled - (rolled / dot).rounded() * dot
            rolled -= abs(off) < 0.001 ? off : off * min(1, CGFloat(dt) * 6)
        }
        rolled = rolled.truncatingRemainder(dividingBy: 2 * .pi)
        lastSpin = spin
        steps = (steps + CGFloat(dt) * stepRate * (facingRight ? 1 : -1)).truncatingRemainder(dividingBy: n)
        if steps < 0 { steps += n }
    }

    /// "Not responding": a few lurching steps, then nothing for a while. Durations and dots per second.
    private static let stutter: [(duration: CGFloat, rate: CGFloat)] = [(0.27, 11), (1.4, 0), (0.1, 10), (0.9, 0), (0.2, 10), (0.7, 0)]
    private static let stutterCycle = stutter.reduce(0) { $0 + $1.duration }

    /// Dots per second. The head jumps from dot to dot like a real spinner's rather than gliding,
    /// so the calm poses' slower updates don't make it judder: 7.5 and 15 a second line up with
    /// updates 30 times a second.
    private var stepRate: CGFloat {
        switch state {
        case .idle, .walk: return 7.5
        case .talk: return 15 // thinking hard
        case .fall, .drag: return 20
        case .sleep: return 0.8
        case .happy: return 0 // done!
        case .sulk:
            var left = CGFloat(stateTime).truncatingRemainder(dividingBy: Self.stutterCycle)
            for part in Self.stutter {
                if left < part.duration { return part.rate }
                left -= part.duration
            }
            return 0
        }
    }

    override func makeLayeredBody(R: CGFloat, scale: CGFloat) -> LayeredBody? {
        SpinnerBody(view: self, R: R, scale: scale)
    }
}

/// The spinner as layers: pictures of the pale disc behind the face and its halo, and a ring of
/// round dot layers fading into a tail. The dots look the same until the mood changes; spinning
/// only turns the ring, by whole dots as it steps and smoothly as it rolls (and mirrors it when it
/// turns around), so nothing is painted.
private final class SpinnerBody: LayeredBody {
    static let dotCount = 12

    /// How the dots look, from the bright head (0) back along the tail.
    private struct Look {
        let colors: [CGColor]
        let sizes: [CGFloat]
        let opacities: [Float]
    }

    /// Dots that go from `head` to `tail` in color, fading and shrinking along the way.
    private static func look(head: UInt32, tail: UInt32, fade: CGFloat, shrink: CGFloat, dim: Float = 1) -> Look {
        let n = dotCount
        let a = CGColor.hex(head).components ?? [0, 0, 0, 1], b = CGColor.hex(tail).components ?? [0, 0, 0, 1]
        var colors: [CGColor] = [], sizes: [CGFloat] = [], opacities: [Float] = []
        for d in 0..<n {
            let f = CGFloat(d) / CGFloat(n - 1)
            colors.append(CGColor(srgbRed: a[0] + (b[0] - a[0]) * f, green: a[1] + (b[1] - a[1]) * f,
                                  blue: a[2] + (b[2] - a[2]) * f, alpha: 1))
            sizes.append(1 - shrink * f)
            opacities.append(Float(1 - fade * f) * dim)
        }
        return Look(colors: colors, sizes: sizes, opacities: opacities)
    }

    private enum Mood {
        case awake, sleepy, frozen, done

        init(_ state: CreatureState) {
            switch state {
            case .sleep: self = .sleepy
            case .sulk: self = .frozen
            case .happy: self = .done
            default: self = .awake
            }
        }
    }

    private static let awake = look(head: 0x3D7BFF, tail: 0x9C6BFF, fade: 0.85, shrink: 0.5)
    private static let sleepy = look(head: 0x8792D8, tail: 0xA79DD8, fade: 0.75, shrink: 0.42, dim: 0.55)
    private static let frozen = look(head: 0x8B8E96, tail: 0xBFC1C7, fade: 0.75, shrink: 0.4)
    private static let green = CGColor.hex(0x27C26C)

    let layer = CALayer()
    private let halo = CALayer()
    private let disc = CALayer()
    private let ring = CALayer()
    private let dots: [CALayer]
    private weak var view: SpinnerView?
    private let R: CGFloat
    private let scale: CGFloat
    private var shownGradient: CGGradient?
    private var shownMood: Mood?
    private var shownRing: CGAffineTransform?
    /// Whether the dots are still closing into a full ring (just done).
    private var closing = false

    init(view: SpinnerView, R: CGFloat, scale: CGFloat) {
        self.view = view
        self.R = R
        self.scale = scale
        let n = Self.dotCount
        let ringR = R * 0.9, dotR = R * 0.17
        dots = (0..<n).map { i in
            let dot = CALayer()
            dot.bounds = CGRect(x: 0, y: 0, width: 2 * dotR, height: 2 * dotR)
            dot.cornerRadius = dotR
            // A light rim, so the dots show on dark desktops too.
            dot.borderWidth = 1.2
            dot.borderColor = .hex(0xFFFFFF, alpha: 0.85)
            // Counterclockwise from the top: facing right, the head leads clockwise with the tail
            // behind it.
            let a = CGFloat.pi / 2 + CGFloat(i) * 2 * .pi / CGFloat(n)
            dot.position = CGPoint(x: cos(a) * ringR, y: sin(a) * ringR)
            return dot
        }
        dots.forEach(ring.addSublayer)
        layer.addSublayer(halo)
        layer.addSublayer(disc)
        layer.addSublayer(ring)
    }

    func update(state: CreatureState, palette: GooglyCharacterView.Palette, t: CGFloat) {
        guard let view else { return }
        if palette.gradient !== shownGradient {
            shownGradient = palette.gradient
            showDisc(palette)
        }

        let mood = Mood(state)
        if mood != shownMood {
            shownMood = mood
            switch mood {
            case .awake: show(Self.awake)
            case .sleepy: show(Self.sleepy)
            case .frozen: show(Self.frozen)
            case .done:
                // Turns green at once, then the tail closes up into a full ring.
                for dot in dots { dot.backgroundColor = Self.green }
                closing = true
            }
        }
        var pop: CGFloat = 1
        if mood == .done && closing {
            // The tail's dots grow to full size one after another.
            let st = CGFloat(view.stateTime), stagger: CGFloat = 0.045, grow: CGFloat = 0.1
            for (d, dot) in dots.enumerated() {
                let p = min(1, max(0, (st - CGFloat(d - 1) * stagger) / grow))
                let size = Self.awake.sizes[d] + (1 - Self.awake.sizes[d]) * p
                dot.setAffineTransform(CGAffineTransform(scaleX: size, y: size))
                dot.opacity = Self.awake.opacities[d] + (1 - Self.awake.opacities[d]) * Float(p)
            }
            // A little pop once it's whole, when the last dot is full.
            let whole = CGFloat(Self.dotCount - 2) * stagger + grow
            let after = (st - whole) / 0.25
            pop = after < 1 ? 1 + 0.1 * sin(.pi * max(0, after)) : 1
            closing = after < 1
        }

        // Mirrored while it faces left, so the head leads counterclockwise with the tail behind
        // it: the way it steps and rolls then.
        let step = 2 * CGFloat.pi / CGFloat(Self.dotCount)
        let ringTransform = CGAffineTransform(rotationAngle: view.rolled - view.steps.rounded(.down) * step)
            .scaledBy(x: view.facingRight ? pop : -pop, y: pop)
        if ringTransform != shownRing {
            shownRing = ringTransform
            ring.setAffineTransform(ringTransform)
        }
    }

    private func show(_ look: Look) {
        for (d, dot) in dots.enumerated() {
            dot.backgroundColor = look.colors[d]
            dot.setAffineTransform(CGAffineTransform(scaleX: look.sizes[d], y: look.sizes[d]))
            dot.opacity = look.opacities[d]
        }
    }

    /// The disc behind the face, lit from above, with a thin rim and a soft halo.
    private func showDisc(_ palette: GooglyCharacterView.Palette) {
        let r = R * 0.56
        let circle = CGPath(ellipseIn: CGRect(x: -r, y: -r, width: 2 * r, height: 2 * r), transform: nil)
        disc.showPicture(of: CGRect(x: -r - 1, y: -r - 1, width: 2 * r + 2, height: 2 * r + 2), scale: scale) { ctx in
            ctx.saveGState()
            ctx.addPath(circle)
            ctx.clip()
            ctx.drawLinearGradient(palette.gradient, start: CGPoint(x: 0, y: r), end: CGPoint(x: 0, y: -r), options: [])
            ctx.restoreGState()
            ctx.addPath(circle)
            ctx.setStrokeColor(palette.lid)
            ctx.setLineWidth(1.2)
            ctx.strokePath()
        }
        // A soft glow doesn't need the extra pixels.
        halo.showPicture(of: CGRect(x: -r - 12, y: -r - 12, width: 2 * r + 24, height: 2 * r + 24), scale: scale / 2) { ctx in
            ctx.setShadow(offset: .zero, blur: 8, color: palette.glow)
            ctx.addPath(circle)
            ctx.setFillColor(palette.mid)
            ctx.fillPath()
        }
    }
}

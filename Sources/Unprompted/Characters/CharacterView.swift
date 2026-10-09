import AppKit

/// Base class for a character's view. The creature sets `state`, `facingRight` and friends and
/// calls `advance(by:)` every frame; subclasses draw whatever they like in `draw(_:)`.
@MainActor
class CharacterView: NSView {
    var state: CreatureState = .idle {
        didSet { if state != oldValue { stateTime = 0; needsDisplay = true } }
    }
    var facingRight = true { didSet { if facingRight != oldValue { needsDisplay = true } } }
    /// Extra rotation in radians (counterclockwise) around the body's middle, for rolling and waddling.
    var spin: CGFloat = 0
    /// Whole-character rotation in degrees (counterclockwise) around the middle of the view, for
    /// climbing sideways and spinning into the trash. Subclasses call `applyTurn` before drawing.
    var turn: CGFloat = 0 { didSet { if turn != oldValue { needsDisplay = true } } }
    /// Seasonal hat or similar. Each view decides where its head is.
    var costume: Costume? { didSet { needsDisplay = true } }
    /// Something held next to the body, like a morning coffee.
    var prop: Prop? { didSet { needsDisplay = true } }

    /// The animation is redrawn at most this often; 0 = every frame. Calm poses can use less to
    /// save drawing work (see `Creature.tick`).
    var redrawInterval: TimeInterval = 0

    /// Seconds since the view was created.
    private(set) var time: TimeInterval = 0
    /// Seconds since `state` last changed.
    private(set) var stateTime: TimeInterval = 0
    private var sinceRedraw: TimeInterval = .infinity

    override init(frame: NSRect) {
        super.init(frame: frame)
        // 8 bits per channel is plenty for cartoons. On wide-color displays the default is 16-bit
        // float, which doubles the cost of every redraw. (`OverlayPanel` limits the window's depth
        // too; both are needed.)
        wantsLayer = true
        layer?.contentsFormat = .RGBA8Uint
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    func advance(by dt: TimeInterval) {
        time += dt
        stateTime += dt
        sinceRedraw += dt
        // A few milliseconds of slack: frames don't arrive exactly on time, and without it a frame
        // that's a hair early would push the redraw a whole frame later, making the motion uneven.
        if sinceRedraw + 0.004 >= redrawInterval {
            sinceRedraw = 0
            needsDisplay = true
        }
    }

    func applyTurn(_ ctx: CGContext) {
        guard turn != 0 else { return }
        ctx.translateBy(x: bounds.midX, y: bounds.midY)
        ctx.rotate(by: turn * .pi / 180)
        ctx.translateBy(x: -bounds.midX, y: -bounds.midY)
    }

    override var isOpaque: Bool { false }

    // Mouse handling lives in the creature's host view.
    override func hitTest(_ point: NSPoint) -> NSView? { nil }
}

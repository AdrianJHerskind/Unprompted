import AppKit

/// Base class for a character's view. The creature sets `state`, `facingRight` and friends and
/// calls `advance(by:)` every frame.
///
/// The character is made of Core Animation layers, which the window server moves, turns and scales
/// on the GPU. Subclasses add theirs to `contentLayer` (which shows `turn`) and bring them up to
/// date in `updateContent()`, including `spin`, `costume` and `prop`.
@MainActor
class CharacterView: NSView {
    var state: CreatureState = .idle {
        didSet { if state != oldValue { stateTime = 0; needsDisplay = true } }
    }
    var facingRight = true { didSet { if facingRight != oldValue { needsDisplay = true } } }
    /// Extra rotation in radians (counterclockwise) around the body's middle, for rolling and waddling.
    var spin: CGFloat = 0
    /// Whole-character rotation in degrees (counterclockwise) around the middle of the view, for
    /// climbing sideways and spinning into the trash.
    var turn: CGFloat = 0 { didSet { if turn != oldValue { needsDisplay = true } } }
    /// Seasonal hat or similar. Each view decides where its head is.
    var costume: Costume? { didSet { needsDisplay = true } }
    /// Something held next to the body, like a morning coffee.
    var prop: Prop? { didSet { needsDisplay = true } }

    /// The animation is updated at most this often; 0 = every frame. Calm poses can use less to
    /// save work (see `Creature.updateInterval(for:)`).
    var updateInterval: TimeInterval = 0

    /// Holds the character's layers, in `bounds` coordinates, turned by `turn`.
    let contentLayer = CALayer()

    /// Seconds since the view was created.
    private(set) var time: TimeInterval = 0
    /// Seconds since `state` last changed.
    private(set) var stateTime: TimeInterval = 0
    private var sinceUpdate: TimeInterval = .infinity
    /// Whether any of the window can be seen. AppKit goes on updating windows that are covered or
    /// off the screen, so the animation isn't updated while it can't.
    private var windowIsVisible = false

    /// Pixels per unit of `bounds` for pictures of parts that the layers scale and turn: twice the
    /// screen's, so they stay crisp. Pictures made for an older value are made again in `remakePictures()`.
    private(set) var pictureScale: CGFloat = 0
    private var picturesMadeAt: TimeInterval = -.infinity

    override init(frame: NSRect) {
        super.init(frame: frame)
        wantsLayer = true
        layer?.addSublayer(contentLayer)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    func advance(by dt: TimeInterval) {
        time += dt
        stateTime += dt
        sinceUpdate += dt
        // Rounded to the nearest frame: frames don't arrive exactly on time, and one that's a hair
        // early mustn't push the update a whole frame later, making the motion uneven.
        if windowIsVisible && sinceUpdate + dt / 2 >= updateInterval {
            sinceUpdate = 0
            needsDisplay = true
        }
    }

    // MARK: - For subclasses

    /// Shows the current frame in `contentLayer`.
    func updateContent() {}

    /// Called before `updateContent()` when `pictureScale` has changed.
    func remakePictures() {}

    /// Screen pixels per unit of `bounds`, which the creature scales for interns and while dying.
    var pixelDensity: CGFloat {
        (window?.backingScaleFactor ?? layer?.contentsScale ?? 2) * frame.width / max(bounds.width, 1)
    }

    // MARK: - Updating

    override var wantsUpdateLayer: Bool { true }

    /// Called by AppKit when `needsDisplay` is set (see `advance`).
    override final func updateLayer() {
        // Layer changes would be animated by default; the character moves on its own.
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        defer { CATransaction.commit() }

        contentLayer.bounds = bounds
        contentLayer.position = CGPoint(x: bounds.midX, y: bounds.midY)
        // Exact for quarter turns (climbing): a matrix a hair off a right angle makes Core Animation
        // show pictures unfiltered, with jagged edges.
        let c = __cospi(Double(turn) / 180), s = __sinpi(Double(turn) / 180)
        contentLayer.setAffineTransform(CGAffineTransform(a: c, b: s, c: -s, d: c, tx: 0, ty: 0))
        // Made again for every change of size or screen, but not for every frame of shrinking into
        // the trash. Never left coarser than the screen needs, though (coming back from the trash).
        let scale = 2 * pixelDensity
        if scale != pictureScale && (scale > pictureScale || time - picturesMadeAt >= 0.1) {
            pictureScale = scale
            picturesMadeAt = time
            remakePictures()
        }
        updateContent()
    }

    override func viewDidChangeBackingProperties() {
        super.viewDidChangeBackingProperties()
        needsDisplay = true
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        NotificationCenter.default.removeObserver(self, name: NSWindow.didChangeOcclusionStateNotification, object: nil)
        if let window {
            NotificationCenter.default.addObserver(self, selector: #selector(occlusionChanged),
                                                   name: NSWindow.didChangeOcclusionStateNotification, object: window)
        }
        occlusionChanged()
    }

    @objc private func occlusionChanged() {
        let visible = window?.occlusionState.contains(.visible) ?? false
        guard visible != windowIsVisible else { return }
        windowIsVisible = visible
        if visible { needsDisplay = true } // catch up right away
    }

    override var isOpaque: Bool { false }

    // Mouse handling lives in the creature's host view.
    override func hitTest(_ point: NSPoint) -> NSView? { nil }
}

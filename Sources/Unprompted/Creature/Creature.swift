import AppKit

enum CreatureEvent {
    case pickedUp
    case thrown
    case dropped
    case landedHard
    case clicked(NSEvent)
    case fileHover
    case filesDropped([URL])
    case petted
    case fetched
    case caughtCursor
    case startedHanging
    case climbedUp
    /// The window edge it was climbing or hanging from got covered or went away.
    case slipped
    /// You shook the window it was on until it flew off.
    case shakenOff
    /// Walked out one side of the screens and came back in on the other.
    case wrapped
    case peeking
    case died
}

/// The creature's body: its window, physics, activities (wandering, fetch, chasing, climbing,
/// hanging, peeking) and drag-and-throw. What it *says* is decided by `Assistant`.
///
/// This file has the outside interface and the per-frame update; movement and activities are in
/// `Creature+Movement.swift` and `Creature+Activities.swift`.
@MainActor
final class Creature {
    enum Activity {
        case wander
        case fetch(targetX: CGFloat, until: TimeInterval)
        case chase(until: TimeInterval)
        /// `side` is where the wall is relative to the creature: +1 = wall on its right.
        case approachClimb(windowID: Int, leftEdge: Bool, side: CGFloat, until: TimeInterval)
        case climb(windowID: Int, leftEdge: Bool, side: CGFloat)
        /// Dangling from a window's top corner. `dir` is the direction it walked off in.
        case hang(windowID: Int, dir: CGFloat, until: TimeInterval)
        case peek(phase: PeekPhase, edgeX: CGFloat, dir: CGFloat, until: TimeInterval)
        /// Slipping behind another app's window through its side edge at `edgeX` (`dir` points
        /// into the window), peeking out, then back out or on through to its far side.
        case sneak(windowID: Int, edgeX: CGFloat, dir: CGFloat, phase: SneakPhase, until: TimeInterval)
        /// Getting out of the way, to a corner at `targetX`, then turning to face `inward`.
        case retreat(targetX: CGFloat, inward: CGFloat, until: TimeInterval)
        /// Climbing the step up to a higher neighboring screen, at boundary `x`, up to `top`.
        case stepClimb(x: CGFloat, top: CGFloat, side: CGFloat)
        /// Walking out of the outermost screen edge (exiting) and back in on the far side (entering).
        case wrap(entering: Bool, edgeX: CGFloat, dir: CGFloat, floorY: CGFloat)
        case dying(from: CGPoint, to: CGPoint, start: TimeInterval)
        case dead
    }

    enum PeekPhase { case approach, peeking, returning }
    /// Walking up to the window (in front of it), then behind it: going in, peeking, and out.
    enum SneakPhase { case approach, entering, peeking, back, through }

    static let gravity: CGFloat = 2200
    /// Upward speed of each little hop for hopping characters.
    static let hopSpeed: CGFloat = 340
    /// How high floaters hover above what they "stand" on, on average, and how far they bob up and
    /// down around that.
    static let hoverHeight: CGFloat = 24
    static let hoverBob: CGFloat = 6
    /// How often a sleeping creature's pose is updated (see `updateInterval(for:)`).
    static let sleepUpdateInterval: TimeInterval = 1.0 / 10

    private(set) var pack: CharacterPack
    /// 1 = normal size; the interns are smaller. Change with `setScale`.
    private(set) var scale: CGFloat
    /// Multiplies walking and climbing speed (the Speed setting).
    var speedFactor: CGFloat = 1
    var onEvent: ((CreatureEvent) -> Void)?
    /// Called whenever it wakes up, whatever woke it (so a slowed-down frame loop can speed up).
    var onWake: (() -> Void)?
    /// Set by the assistant while a speech bubble or the chat is up; the creature stands still.
    var isTalking = false
    /// 0…1, from the assistant's mood. Happier creatures play more.
    var playfulness: Double = 0.5
    /// How much it wanders around on its own (the Wandering setting).
    var wandering = Wandering.often { didSet { if wandering != oldValue { settleDown() } } }
    /// While it stays put: get out of the way, to a corner of the screen, as soon as it can. Set by
    /// the assistant; picking it up or playing with it leaves it where that ends.
    var headsForCorner = false
    var costume: Costume? { didSet { view.costume = costume } }
    var prop: Prop? { didSet { view.prop = prop } }
    /// Replaces the character's own gait (chosen in the menu).
    var movementOverride: MovementStyle?
    var movement: MovementStyle { movementOverride ?? pack.movement }
    /// Set by the assistant to take the creature off the screen (snoozing, quiet mode) and back.
    /// It doesn't move while hidden, because the assistant stops calling `tick`.
    var isHidden = false { didSet { updateStageVisibility() } }

    /// The creature's window: a stage around it, larger than it (see `apply`).
    private let stage: OverlayPanel
    private let host = CreatureHostView(frame: NSRect(x: 0, y: 0, width: 1, height: 1))
    private var view: CharacterView
    private var isRemoved = false
    private var lastApplied: CGPoint?
    /// Where the character view sits inside the stage.
    private var viewOrigin: CGPoint = .zero
    /// The window it's behind while sneaking (see `updateStageOrder`).
    private var behindWindow: Int?
    /// The screen the stage was placed on, or nil when it needs to be placed again.
    private var stageScreen: NSScreen?
    private var viewTransform: (rotation: CGFloat, zoom: CGFloat) = (0, 1)
    private var isPressed = false
    private var mouseDownPoint: CGPoint = .zero
    private var grabOffset: CGVector = .zero
    private var drag = DragTracker()
    private var pet = PetDetector()

    // Simulation state, shared with the Creature+… extensions. From outside, use the methods.
    let world: World
    var activity = Activity.wander
    /// The origin of the creature's square (`frame`), in screen coordinates.
    var position: CGPoint = .zero
    var velocity: CGVector = .zero
    var grounded = false
    var groundWindow: World.WindowInfo?
    var walkDirection: CGFloat = 0
    var speedMultiplier: CGFloat = 1
    var facingRight = true
    var behaviorUntil: TimeInterval = 0
    var now: TimeInterval = 0
    var offscreenTime: TimeInterval = 0
    var hoverOffset: CGFloat = 0
    var hopping = false
    var rollAngle: CGFloat = 0
    var waddlePhase: CGFloat = 0
    var shake = ShakeDetector()
    /// nil = awake, .infinity = asleep until the assistant wakes it, otherwise a nap end time.
    var sleepingUntil: TimeInterval? {
        didSet { if sleepingUntil == nil && oldValue != nil { onWake?() } }
    }
    var sulkUntil: TimeInterval = 0
    var happyUntil: TimeInterval = 0
    /// Let go of (or flung off a window) by you and still in the air: only then can it land in the trash.
    private(set) var isThrown = false
    private(set) var isDragging = false

    init(pack: CharacterPack, world: World, scale: CGFloat = 1) {
        self.pack = pack
        self.world = world
        self.scale = scale
        let stageSize = Self.stageSize(for: Self.squareSize(for: pack, scale: scale))
        stage = OverlayPanel(size: stageSize)
        view = pack.makeView()
        host.frame = NSRect(origin: .zero, size: stageSize)
        host.addSubview(view)
        stage.contentView = host
        layoutView(rotation: 0, zoom: 1, force: true)

        host.onMouseDown = { [weak self] in self?.mouseDown($0) }
        host.onMouseDragged = { [weak self] _ in self?.mouseDragged() }
        host.onMouseUp = { [weak self] in self?.mouseUp($0) }
        host.onRightMouseDown = { [weak self] in self?.onEvent?(.clicked($0)) }
        host.onFileHover = { [weak self] in self?.onEvent?(.fileHover) }
        host.onFilesDropped = { [weak self] in self?.onEvent?(.filesDropped($0)) }
    }

    // MARK: - State

    var isSleeping: Bool { sleepingUntil != nil }
    /// Asleep on a screen's floor, with the cursor nowhere near: nothing it does then needs 60
    /// frames a second. (On a window it rides along when the window is dragged; floaters bob.)
    /// "Nowhere near" is far enough that the cursor can't get to it between two of those slower
    /// frames, so clicks on it land on it rather than going through to what's underneath.
    var isDozing: Bool {
        guard isSleeping, grounded, groundWindow == nil, movement != .float, !isPressed, !isDragging else { return false }
        return !frame.insetBy(dx: -200, dy: -200).contains(NSEvent.mouseLocation)
    }
    var isNapping: Bool { sleepingUntil.map { $0 != .infinity } ?? false }
    var isSulking: Bool { now < sulkUntil }
    var isHappy: Bool { now < happyUntil }
    var isVisible: Bool { stage.isVisible }

    var isDying: Bool {
        switch activity {
        case .dying, .dead: return true
        default: return false
        }
    }

    var isDead: Bool {
        if case .dead = activity { return true }
        return false
    }

    /// Climbing, hanging or being deleted: held in place rather than walking or falling.
    var isAttached: Bool {
        switch activity {
        case .climb, .stepClimb, .hang, .dying, .dead: return true
        default: return false
        }
    }

    /// Partly past the side of the screens on purpose: peeking, or walking around to the other side.
    var isAtScreenEdge: Bool {
        switch activity {
        case .peek, .wrap: return true
        default: return false
        }
    }

    /// Free-falling or thrown (not climbing, hanging, dragged or dying).
    var isFlying: Bool { !grounded && !isDragging && !isAttached }

    /// Standing still (or held still by talking, sulking...) on a screen's floor, just wandering: until
    /// it moves again, nothing it does depends on where windows are. (Standing on a window does: one
    /// dragged over its feet makes it fall.)
    var isRestingOnFloor: Bool {
        guard grounded, groundWindow == nil, walkDirection == 0 || !canWalk, !isDragging,
              case .wander = activity else { return false }
        return true
    }

    /// Free to walk around: not asleep, sulking, celebrating or talking.
    var canWalk: Bool { sleepingUntil == nil && !isSulking && !isHappy && !isTalking }
    /// Climbing only pauses for sleep and talking; frozen sideways on a wall for a whole sulk
    /// would look broken.
    var canClimb: Bool { sleepingUntil == nil && !isTalking }

    /// How fast it's moving through the air or being dragged, in points per second.
    var currentSpeed: CGFloat {
        if isDragging { return hypot(drag.velocity.dx, drag.velocity.dy) }
        return isFlying ? hypot(velocity.dx, velocity.dy) : 0
    }

    // MARK: - Geometry

    /// The creature is a square (the character's larger side), so the character can turn sideways to climb.
    var size: NSSize { Self.squareSize(for: pack, scale: scale) }
    var frame: CGRect { CGRect(origin: position, size: size) }
    var center: CGPoint { CGPoint(x: frame.midX, y: frame.midY) }
    /// Top of its head (plus room for a hat), for speech bubbles and hearts.
    var headTop: CGPoint {
        CGPoint(x: frame.midX, y: frame.minY + (pack.headTop + (costume == nil ? 0 : 28)) * scale)
    }
    /// The visible character, without the empty headroom above it, for placing speech bubbles and
    /// the chat box. A hovering floater's covers all of its bob: following the bob would move their
    /// windows several times a second.
    var bodyFrame: CGRect {
        var body = CGRect(x: frame.minX, y: frame.minY, width: frame.width, height: headTop.y - frame.minY + 10)
        if grounded && movement == .float {
            // Snapped like the square (see `apply`): taking the bob back out leaves tiny rounding
            // errors, which would count as moving and have the bubble placed again.
            body.origin.y = Self.snap(body.minY - (hoverOffset - Self.hoverHeight) - Self.hoverBob)
            body.size.height += 2 * Self.hoverBob
        }
        return body
    }
    var footInset: CGFloat { pack.footInset * scale }
    var walkSpeed: CGFloat { pack.walkSpeed * (scale < 0.8 ? 1.3 : 1) * speedFactor }
    /// From the middle of the square to the feet when turned sideways: how far it stands from a wall
    /// while climbing.
    var feetReach: CGFloat { size.width / 2 - footInset }
    /// Distance from a wall while climbing: feet against it, or (floating) a body's width away.
    var climbOffset: CGFloat { movement == .float ? pack.size.width * scale * 0.4 : feetReach }

    private static func squareSize(for pack: CharacterPack, scale: CGFloat) -> NSSize {
        let side = max(pack.size.width, pack.size.height) * scale
        return NSSize(width: side, height: side)
    }

    /// The window: the creature's square with room for one more on every side (see `apply`), or
    /// a little less for giant characters. In whole points, like where it's placed.
    private static func stageSize(for square: NSSize) -> NSSize {
        let margin = min(square.width, 300)
        return NSSize(width: (square.width + margin * 2).rounded(.up), height: (square.height + margin * 2).rounded(.up))
    }

    /// In whole points, the way AppKit places windows: rounded down, with an eighth of slack.
    private static func snap(_ v: CGFloat) -> CGFloat { (v + 0.125).rounded(.down) }

    // MARK: - Control

    /// Places the creature with its feet at `point` and lets it fall from there.
    func drop(at point: CGPoint) {
        activity = .wander
        position = CGPoint(x: point.x - size.width / 2, y: point.y - footInset)
        velocity = .zero
        grounded = false
        groundWindow = nil
        hopping = false
        isThrown = false
        offscreenTime = 0
        sleepingUntil = nil
        layoutView(rotation: 0, zoom: 1)
        stage.alphaValue = 1
        apply()
        updateStageVisibility()
    }

    /// Takes it off the screen for good (an intern that's leaving).
    func remove() {
        isRemoved = true
        updateStageVisibility()
    }

    func setPack(_ newPack: CharacterPack) {
        let feet = CGPoint(x: frame.midX, y: position.y + footInset)
        pack = newPack
        view.removeFromSuperview()
        view = newPack.makeView()
        view.costume = costume
        view.prop = prop
        resizeStage()
        host.needsDisplay = true
        host.addSubview(view)
        layoutView(rotation: viewTransform.rotation, zoom: viewTransform.zoom, force: true)
        position = CGPoint(x: feet.x - size.width / 2, y: feet.y - footInset)
        lastApplied = nil
        apply()
    }

    /// Resizes the creature, keeping its feet where they are.
    func setScale(_ newScale: CGFloat) {
        guard abs(newScale - scale) > 0.001 else { return }
        let feet = CGPoint(x: frame.midX, y: position.y + footInset)
        scale = newScale
        resizeStage()
        layoutView(rotation: viewTransform.rotation, zoom: viewTransform.zoom, force: true)
        position = CGPoint(x: feet.x - size.width / 2, y: feet.y - footInset)
        lastApplied = nil
        apply()
    }

    /// `duration` nil = sleep until woken.
    func sleep(for duration: TimeInterval?) {
        returnInside() // no napping half off the screen
        sleepingUntil = duration.map { now + $0 } ?? .infinity
        walkDirection = 0
    }

    func wake() {
        sleepingUntil = nil
        behaviorUntil = now + 1
    }

    func sulk(for duration: TimeInterval) {
        sulkUntil = now + duration
        walkDirection = 0
    }

    func stopSulking() {
        sulkUntil = 0
        behaviorUntil = now + 1
    }

    func beHappy(for duration: TimeInterval) {
        happyUntil = max(happyUntil, now + duration)
        walkDirection = 0
    }

    func jump() {
        // Not while partly off the screen: there's nothing to land on out there.
        guard grounded, !isDragging, !isAtScreenEdge else { return }
        sleepingUntil = nil
        leap(dx: 0, dy: .random(in: 800...1000))
    }

    func startChase(for duration: TimeInterval = 8) {
        guard !isDying else { return }
        returnInside()
        sulkUntil = 0
        sleepingUntil = nil
        activity = .chase(until: now + duration)
        behaviorUntil = now
        headsForCorner = false
    }

    /// Animates into the trash (spinning, shrinking), then hides and reports `.died`.
    func die(into target: CGPoint) {
        guard !isDying else { return }
        isDragging = false
        isPressed = false
        isThrown = false
        grounded = false
        velocity = .zero
        activity = .dying(from: center, to: target, start: now)
    }

    func popUp(_ menu: NSMenu, for event: NSEvent) {
        let p = host.convert(event.locationInWindow, from: nil)
        menu.popUp(positioning: nil, at: p, in: host)
    }

    // MARK: - Frame update

    func tick(dt: TimeInterval) {
        now += dt
        // Floaters hover above whatever they "stand" on, bobbing gently. Standing creatures move
        // with the hover height, so their feet stay on the surface when it changes.
        let hover: CGFloat = movement == .float ? Self.hoverHeight + Self.hoverBob * sin(CGFloat(now) * 2.1) : 0
        if grounded { position.y += hover - hoverOffset }
        hoverOffset = hover
        let xBefore = position.x
        if let until = sleepingUntil, now >= until { sleepingUntil = nil }

        switch activity {
        case .dead:
            return
        case .dying:
            updateDying()
        case .climb:
            updateClimb(CGFloat(dt))
        case .hang:
            updateHang(CGFloat(dt))
        case .stepClimb:
            updateStepClimb(CGFloat(dt))
        default:
            if isDragging {
                followMouse()
            } else {
                simulate(CGFloat(dt))
                recoverIfLost(dt)
            }
        }
        if grounded || isDragging || isAttached { isThrown = false }
        let dx = position.x - xBefore
        updateGait(dt: CGFloat(dt), dx: dx)
        shake.endFrame()
        if !isDying { detectPetting() }
        updateClickThrough()

        let (state, rotation) = pose()
        if !isDying { layoutView(rotation: rotation, zoom: 1) }
        view.state = state
        view.facingRight = facingRight
        // Walking around the screens or back from a peek doesn't stop for talking or sulking.
        view.updateInterval = dx == 0 ? updateInterval(for: state) : 0
        view.advance(by: dt)
        updateStageOrder()
        apply()
    }

    /// The look for what it's doing right now, and how far it's turned (sideways while climbing).
    private func pose() -> (CreatureState, rotation: CGFloat) {
        switch activity {
        case .dying, .dead:
            return (.fall, 0)
        case .climb(_, _, let side), .stepClimb(_, _, let side):
            // Turned sideways with its feet against the wall, "walking" upwards. Floaters just rise.
            facingRight = side > 0
            return (.walk, movement == .float ? 0 : (side > 0 ? 90 : -90))
        case .hang:
            return (.drag, 0)
        default:
            break
        }
        if isDragging { return (.drag, 0) }
        if !grounded {
            if hopping { return (.walk, 0) }
            if movement == .float && hypot(velocity.dx, velocity.dy) < 300 { return (walkDirection != 0 ? .walk : .idle, 0) }
            return (.fall, 0)
        }
        if isSleeping { return (.sleep, 0) }
        if isSulking { return (.sulk, 0) }
        if isHappy { return (.happy, 0) }
        if isTalking { return (.talk, 0) }
        return (walkDirection != 0 ? .walk : .idle, 0)
    }

    /// Calm poses change slowly, so updating them less often than every frame saves work without
    /// anyone noticing: each update hands Core Animation new layer properties (new paths for a
    /// ghost's waving hem) and repaints whatever moved (a talking mouth, the Z's). Talking counts
    /// as calm: it stands still for it. Each is a whole number of 60 Hz frames, so updates stay
    /// evenly spaced.
    private func updateInterval(for state: CreatureState) -> TimeInterval {
        switch state {
        // Fewer still once it's been asleep for a while: you've probably gone.
        case .sleep: return view.stateTime > 300 ? 1.0 / 5 : Self.sleepUpdateInterval
        case .sulk: return 1.0 / 15
        case .idle, .talk: return 1.0 / 30
        default: return 0
        }
    }

    /// Moves the character to `position`.
    ///
    /// Moving a window every frame is expensive (AppKit, the window server and the window manager
    /// all take part), so the window is a stage around the creature and only the character view
    /// moves inside it. The stage follows when the creature reaches its edge or another screen;
    /// the window and the view then change in the same frame.
    func apply() {
        guard position != lastApplied else { return }
        lastApplied = position
        let square = CGRect(origin: CGPoint(x: Self.snap(position.x), y: Self.snap(position.y)), size: size)
        let screen = world.screen(at: CGPoint(x: square.midX, y: square.midY))
        if stageScreen == nil || !stage.frame.contains(square) || (screen != nil && screen !== stageScreen) {
            placeStage(around: square, on: screen ?? NSScreen.nearest(to: CGPoint(x: square.midX, y: square.midY)))
        }
        let origin = CGPoint(x: square.minX - stage.frame.minX, y: square.minY - stage.frame.minY)
        guard origin != viewOrigin else { return }
        viewOrigin = origin
        view.setFrameOrigin(origin)
    }

    /// Centers the stage on the creature, but keeps it on the creature's screen give or take a
    /// creature: with "Displays have separate Spaces" (the default), a window only shows on the
    /// screen that has most of it.
    private func placeStage(around square: CGRect, on screen: NSScreen?) {
        let stageSize = Self.stageSize(for: size)
        var origin = CGPoint(x: square.midX - stageSize.width / 2, y: square.midY - stageSize.height / 2)
        if let screen {
            // Whole points, so the stage still holds the square after rounding.
            let bounds = screen.frame.insetBy(dx: -size.width, dy: -size.height).union(square).integral
            origin.x = max(min(origin.x, bounds.maxX - stageSize.width), bounds.minX)
            origin.y = max(min(origin.y, bounds.maxY - stageSize.height), bounds.minY)
        }
        stageScreen = screen
        stage.setFrameOrigin(CGPoint(x: origin.x.rounded(.down), y: origin.y.rounded(.down)))
    }

    /// After a size change: a stage to match, placed around the creature again by `apply`.
    private func resizeStage() {
        let stageSize = Self.stageSize(for: size)
        stage.setContentSize(stageSize)
        host.frame = NSRect(origin: .zero, size: stageSize)
        stageScreen = nil
    }

    /// Rotates and zooms the character inside its square (for climbing, shrinking and dying).
    func layoutView(rotation: CGFloat, zoom: CGFloat, force: Bool = false) {
        guard force || viewTransform.rotation != rotation || viewTransform.zoom != zoom else { return }
        viewTransform = (rotation, zoom)
        // The view fills the creature's square. Its bounds show the pack's drawing area, bottom-aligned
        // and centered, in a square the size of the pack's larger side (divided by `zoom` to shrink).
        let side = max(pack.size.width, pack.size.height)
        let b = side / zoom
        view.frame = NSRect(origin: viewOrigin, size: size)
        view.bounds = NSRect(x: pack.size.width / 2 - b / 2, y: side / 2 - b / 2, width: b, height: b)
        // Changing the bounds scale can shift the frame in AppKit, so put it back where it belongs.
        view.setFrameOrigin(viewOrigin)
        // The view turns itself, around the middle of the square.
        view.turn = rotation
    }

    /// Extra rotation of the body, for rolling and waddling.
    func setBodySpin(_ angle: CGFloat) {
        view.spin = angle
        view.spinIsRoll = movement == .roll
    }

    /// Hides the window once it's dead (after the trash animation) or removed.
    func updateStageVisibility() {
        let visible = !isHidden && !isRemoved && !isDead
        guard visible != stage.isVisible else { return }
        if visible {
            stage.orderFrontRegardless()
        } else {
            // Back out in front when it comes back.
            if case .sneak = activity { activity = .wander }
            updateStageOrder()
            stage.orderOut(nil)
        }
    }

    /// While it's behind a window (sneaking), the stage sits just below that window, so the window
    /// hides whatever part of it overlaps; otherwise it's above everything.
    private func updateStageOrder() {
        var wanted: Int?
        if case .sneak(let id, _, _, let phase, _) = activity, phase != .approach { wanted = id }
        guard wanted != behindWindow else { return }
        behindWindow = wanted
        if let wanted {
            stage.level = .normal
            if stage.isVisible { stage.order(.below, relativeTo: wanted) }
        } else {
            stage.level = .assistant
            if stage.isVisible { stage.orderFrontRegardless() }
        }
    }

    // MARK: - Mouse

    /// Clicks and file drags land on the creature only within a disc around its body; everywhere
    /// else in its window they pass through to whatever is underneath. Nothing is drawn for this.
    private func updateClickThrough() {
        let m = NSEvent.mouseLocation
        let c = bodyCenter
        let radius = min(pack.size.width, pack.headTop) * scale * 0.42
        let inside = hypot(m.x - c.x, m.y - c.y) <= radius
        let ignore = !(inside || isPressed || isDragging) || isDying
        if stage.ignoresMouseEvents != ignore { stage.ignoresMouseEvents = ignore }
    }

    /// The middle of the visible character, accounting for headroom and the sideways climbing pose.
    private var bodyCenter: CGPoint {
        let offset = (frame.minY + (pack.headTop * scale) / 2) - center.y // below center when upright
        let angle = viewTransform.rotation * .pi / 180
        return CGPoint(x: center.x - sin(angle) * offset, y: center.y + cos(angle) * offset)
    }

    private func detectPetting() {
        guard !isDragging, !isPressed, stage.isVisible else { return }
        let area = frame.insetBy(dx: size.width * 0.15, dy: size.height * 0.15)
        if pet.update(mouse: NSEvent.mouseLocation, over: area, now: now) {
            beHappy(for: 2)
            onEvent?(.petted)
        }
    }

    private func mouseDown(_ event: NSEvent) {
        guard !isDying else { return }
        let m = NSEvent.mouseLocation
        isPressed = true
        mouseDownPoint = m
        grabOffset = CGVector(dx: m.x - position.x, dy: m.y - position.y)
    }

    private func mouseDragged() {
        guard isPressed, !isDragging, !isDying else { return }
        let m = NSEvent.mouseLocation
        guard hypot(m.x - mouseDownPoint.x, m.y - mouseDownPoint.y) > 4 else { return }
        isDragging = true
        hopping = false
        headsForCorner = false
        activity = .wander
        grounded = false
        groundWindow = nil
        sleepingUntil = nil
        walkDirection = 0
        speedMultiplier = 1
        drag.start(at: m, now: now)
        onEvent?(.pickedUp)
    }

    private func followMouse() {
        let m = NSEvent.mouseLocation
        position = CGPoint(x: m.x - grabOffset.dx, y: m.y - grabOffset.dy)
        drag.add(m, now: now)
        if abs(drag.travel.dx) > 2 { facingRight = drag.travel.dx > 0 }
    }

    private func mouseUp(_ event: NSEvent) {
        isPressed = false
        guard isDragging else {
            if !isDying { onEvent?(.clicked(event)) }
            return
        }
        isDragging = false
        var v = drag.velocity
        let speed = hypot(v.dx, v.dy)
        if speed > 3500 {
            v = CGVector(dx: v.dx / speed * 3500, dy: v.dy / speed * 3500)
        }
        velocity = v
        grounded = false
        isThrown = true
        if speed > 1200 {
            // Fetch! Run back to where it was thrown from.
            activity = .fetch(targetX: NSEvent.mouseLocation.x, until: now + 15)
            onEvent?(.thrown)
        } else {
            onEvent?(.dropped)
        }
    }

    /// Flung off the window it held on to, with (some of) the window's momentum, tumbling.
    func shakeOff() {
        let v = shake.velocity
        letGo()
        shake.reset()
        velocity = CGVector(dx: max(-1500, min(1500, v.dx * 0.7)) + .random(in: -150...150),
                            dy: max(450, min(1400, v.dy * 0.7 + 500)))
        isThrown = true // your doing, so it can end up in the trash
        onEvent?(.shakenOff)
    }

    // MARK: - Debugging

    /// What it's up to, in words (shown in the menu).
    var statusDescription: String {
        if isDragging { return "Being carried" }
        switch activity {
        case .dying, .dead: return "Being deleted…"
        case .climb: return "Climbing a window"
        case .stepClimb: return "Climbing up to the next screen"
        case .hang: return "Hanging on for dear life"
        case .peek: return "Peeking from the edge"
        case .retreat: return "Getting out of your way"
        case .sneak(_, _, _, let phase, _): return phase == .peeking ? "Peeking from behind a window" : "Sneaking behind a window"
        case .wrap: return "Taking a shortcut around the screens"
        case .approachClimb: return "Heading for a window to climb"
        case .chase: return "Chasing your cursor"
        case .fetch: return "Fetching"
        case .wander: break
        }
        if let until = sleepingUntil {
            return until == .infinity ? "Asleep (wakes up when you're back)"
                                      : "Napping, \(max(1, Int((until - now) / 60))) min left"
        }
        if isSulking { return "Sulking, \(Int(sulkUntil - now)) s left" }
        if isHappy { return "Happy!" }
        if isTalking { return "Talking" }
        if !grounded { return movement == .float ? "Floating" : "In the air" }
        if walkDirection != 0 {
            switch movement {
            case .walk: return "Walking"
            case .waddle: return "Waddling"
            case .hop: return "Hopping"
            case .roll: return "Rolling"
            case .float: return "Drifting"
            }
        }
        return "Standing around"
    }

    /// Internal state for `UNPROMPTED_DEBUG=1` runs.
    var debugSummary: String {
        String(format: "%@ | activity=%@ grounded=%d walkDir=%.0f speedMult=%.1f pos=(%.0f,%.0f) vel=(%.0f,%.0f) "
               + "behaviorIn=%.1f talking=%d sulking=%d happy=%d sleeping=%d hopping=%d thrown=%d movement=%@",
               statusDescription, "\(activity)", grounded ? 1 : 0, walkDirection, speedMultiplier, position.x, position.y,
               velocity.dx, velocity.dy, behaviorUntil - now, isTalking ? 1 : 0, isSulking ? 1 : 0, isHappy ? 1 : 0,
               isSleeping ? 1 : 0, hopping ? 1 : 0, isThrown ? 1 : 0, movement.rawValue)
    }
}

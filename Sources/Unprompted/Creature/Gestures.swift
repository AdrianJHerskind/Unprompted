import CoreGraphics
import Foundation

/// Notices petting: the cursor moving back and forth over the creature.
struct PetDetector {
    private var lastX: CGFloat = 0
    private var lastDirection: CGFloat = 0
    private var reversals: [TimeInterval] = []
    private var lastPet: TimeInterval = -10

    /// Call every frame. True when this counts as a pet: four or more changes of direction
    /// within 1.2 seconds over `area`, at most once every 0.8 seconds.
    mutating func update(mouse m: CGPoint, over area: CGRect, now: TimeInterval) -> Bool {
        if area.contains(m) {
            let dx = m.x - lastX
            if abs(dx) > 2 {
                let direction: CGFloat = dx > 0 ? 1 : -1
                if lastDirection != 0 && direction != lastDirection { reversals.append(now) }
                lastDirection = direction
            }
        } else {
            lastDirection = 0
        }
        lastX = m.x
        reversals.removeAll { now - $0 > 1.2 }
        guard reversals.count >= 4, now - lastPet > 0.8 else { return false }
        lastPet = now
        reversals.removeAll()
        return true
    }
}

/// Notices the window the creature holds on to being shaken: three or more quick changes of
/// direction (on either axis) within 0.8 seconds.
struct ShakeDetector {
    private var windowID: Int?
    private var lastOrigin: CGPoint?
    private var lastDirection = CGVector.zero
    private var reversals: [TimeInterval] = []
    private var watchedThisFrame = false
    /// How fast the window moved in the last update, in points per second.
    private(set) var velocity = CGVector.zero

    /// Call every frame while attached to window `id`, with its current origin.
    mutating func update(windowID id: Int, origin: CGPoint, dt: CGFloat, now: TimeInterval) -> Bool {
        watchedThisFrame = true
        defer {
            windowID = id
            lastOrigin = origin
        }
        guard windowID == id, let last = lastOrigin, dt > 0 else {
            reversals = []
            lastDirection = .zero
            velocity = .zero
            return false
        }
        let dx = origin.x - last.x, dy = origin.y - last.y
        velocity = CGVector(dx: dx / dt, dy: dy / dt)
        if abs(dx) > 4 {
            let d: CGFloat = dx > 0 ? 1 : -1
            if lastDirection.dx != 0 && d != lastDirection.dx { reversals.append(now) }
            lastDirection.dx = d
        }
        if abs(dy) > 4 {
            let d: CGFloat = dy > 0 ? 1 : -1
            if lastDirection.dy != 0 && d != lastDirection.dy { reversals.append(now) }
            lastDirection.dy = d
        }
        reversals.removeAll { now - $0 > 0.8 }
        return reversals.count >= 3
    }

    /// Call at the end of every frame. A window that wasn't watched this frame is forgotten, so
    /// grabbing on again later starts fresh.
    mutating func endFrame() {
        if !watchedThisFrame { windowID = nil }
        watchedThisFrame = false
    }

    mutating func reset() {
        windowID = nil
        reversals = []
    }
}

/// The last few positions while the creature is dragged, to know how hard and which way it's thrown.
struct DragTracker {
    private var samples: [(t: TimeInterval, p: CGPoint)] = []

    mutating func start(at p: CGPoint, now: TimeInterval) {
        samples = [(now, p)]
    }

    mutating func add(_ p: CGPoint, now: TimeInterval) {
        samples.append((now, p))
        samples.removeAll { now - $0.t > 0.08 }
    }

    /// Distance covered recently.
    var travel: CGVector {
        guard let first = samples.first, let last = samples.last else { return .zero }
        return CGVector(dx: last.p.x - first.p.x, dy: last.p.y - first.p.y)
    }

    /// Points per second, over the last 0.08 seconds.
    var velocity: CGVector {
        guard let first = samples.first, let last = samples.last, last.t > first.t else { return .zero }
        let dt = CGFloat(last.t - first.t)
        return CGVector(dx: travel.dx / dt, dy: travel.dy / dt)
    }
}

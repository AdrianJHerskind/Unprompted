import AppKit

/// What the creature gets up to on its own: wandering, fetch, chasing the cursor, climbing and
/// hanging from windows, peeking from the screen edge, and being deleted.
extension Creature {
    /// Decides where to walk while standing on something.
    func steer(centerX: CGFloat, feetY: CGFloat) {
        switch activity {
        case .wander:
            decideWhatToDo(centerX: centerX, feetY: feetY)

        case .fetch(let targetX, let until):
            let dx = targetX - centerX
            if abs(dx) < max(16, arrivalTolerance) {
                endActivity()
                beHappy(for: 1.5)
                onEvent?(.fetched)
            } else if now > until {
                endActivity()
            } else {
                walkDirection = dx > 0 ? 1 : -1
                speedMultiplier = 1.8
            }

        case .chase(let until):
            guard now < until else { return endActivity() }
            let m = NSEvent.mouseLocation
            let dx = m.x - centerX
            speedMultiplier = 2
            if abs(dx) < max(22, arrivalTolerance) {
                walkDirection = 0
                if m.y > feetY - 10 && m.y < feetY + size.height {
                    endActivity()
                    beHappy(for: 1.5)
                    onEvent?(.caughtCursor)
                } else if m.y > feetY + size.height, m.y < feetY + 380, Double.random(in: 0..<1) < 0.05 {
                    leap(dx: 0, dy: 1000)
                }
            } else {
                walkDirection = dx > 0 ? 1 : -1
                if m.y > feetY + size.height * 0.8, m.y < feetY + 380, abs(dx) < 140,
                   Double.random(in: 0..<1) < 0.03 {
                    leap(dx: walkDirection * 300, dy: 950)
                }
            }

        case .approachClimb(let id, let leftEdge, let side, let until):
            guard now < until, let f = world.frame(ofWindow: id) else { return endActivity() }
            let wallX = leftEdge ? f.minX : f.maxX
            let targetX = wallX - side * climbOffset
            let dx = targetX - centerX
            if abs(dx) < arrivalTolerance {
                guard world.edgeVisibility(ofWindow: id, leftEdge: leftEdge,
                                           from: max(feetY, f.minY), to: f.maxY - 2) >= 0.9 else { return endActivity() }
                position.x = targetX - size.width / 2
                grounded = false
                groundWindow = nil
                walkDirection = 0
                activity = .climb(windowID: id, leftEdge: leftEdge, side: side)
            } else {
                walkDirection = dx > 0 ? 1 : -1
                speedMultiplier = 1.2
            }

        default:
            break
        }
    }

    /// How close counts as "there". Hoppers can't stop mid-hop, so they get most of a hop's length.
    private var arrivalTolerance: CGFloat {
        guard movement == .hop else { return 4 }
        let hopLength = walkSpeed * 1.2 * 2 * Self.hopSpeed / Self.gravity
        return hopLength * 0.6 + 4
    }

    /// Random wandering: stroll, stand around, jump, or start something more fun.
    private func decideWhatToDo(centerX: CGFloat, feetY: CGFloat) {
        guard now >= behaviorUntil else { return }
        speedMultiplier = 1
        var roll = Double.random(in: 0..<1)

        let chaseChance = 0.08 * playfulness
        if roll < chaseChance { return startChase() }
        roll -= chaseChance
        if roll < 0.07, startClimbApproach(centerX: centerX, feetY: feetY) { return }
        roll -= 0.07
        if roll < 0.04, startPeek(centerX: centerX, feetY: feetY) { return }
        roll -= 0.04
        if roll < 0.06 {
            let dir: CGFloat = walkDirection != 0 ? walkDirection : (Bool.random() ? 1 : -1)
            leap(dx: dir * .random(in: 80...220), dy: .random(in: 600...1100))
            behaviorUntil = now + 1
            return
        }
        roll -= 0.06
        if roll < 0.42 {
            walkDirection = Bool.random() ? 1 : -1
            behaviorUntil = now + .random(in: 1.5...5)
        } else {
            walkDirection = 0
            behaviorUntil = now + .random(in: 2...6)
        }
    }

    // MARK: Climbing and hanging

    /// Finds a nearby window side it can walk to and climb, and heads there.
    private func startClimbApproach(centerX: CGFloat, feetY: CGFloat) -> Bool {
        var best: (id: Int, leftEdge: Bool, side: CGFloat, distance: CGFloat)?
        for w in world.windows {
            let f = w.frame
            // The side must reach down to about our level, and be worth climbing.
            guard f.minY <= feetY + size.height * 0.6, f.maxY > feetY + size.height * 1.3,
                  groundWindow?.id != w.id,
                  let screen = world.screen(at: CGPoint(x: f.midX, y: f.maxY - 1)),
                  f.maxY < screen.visibleFrame.maxY - size.height * 0.5 else { continue }
            for leftEdge in [true, false] {
                let wallX = leftEdge ? f.minX : f.maxX
                let side: CGFloat = centerX < wallX ? 1 : -1
                let targetX = wallX - side * climbOffset
                let distance = abs(targetX - centerX)
                guard distance < 500, distance < (best?.distance ?? .infinity),
                      world.isOnScreen(CGPoint(x: targetX, y: feetY + 2)),
                      let g = world.ground(atX: targetX, below: feetY, tolerance: 3), abs(g.y - feetY) < 4,
                      grip(onWindow: w.id, leftEdge: leftEdge, frame: f, y: f.maxY - 4),
                      world.edgeVisibility(ofWindow: w.id, leftEdge: leftEdge,
                                           from: max(feetY, f.minY), to: f.maxY - 2) >= 0.9 else { continue }
                best = (w.id, leftEdge, side, distance)
            }
        }
        guard let best else { return false }
        activity = .approachClimb(windowID: best.id, leftEdge: best.leftEdge, side: best.side, until: now + 12)
        return true
    }

    func updateClimb(_ dt: CGFloat) {
        guard case .climb(let id, let leftEdge, let side) = activity, let f = world.liveFrame(ofWindow: id) else {
            return letGo()
        }
        let wallX = leftEdge ? f.minX : f.maxX
        position.x = wallX - side * climbOffset - size.width / 2
        guard grip(onWindow: id, leftEdge: leftEdge, frame: f, y: center.y) else { return slip() }
        if shake.update(windowID: id, origin: f.origin, dt: dt, now: now) { return shakeOff() }
        if canClimb { position.y += walkSpeed * 0.8 * dt }

        if position.y + size.height / 2 >= f.maxY {
            // Made it! Over the edge onto the window, which is to the right of its left edge (and
            // the other way round), whichever side of the edge it climbed.
            hopOver(edgeX: wallX, top: f.maxY, inward: leftEdge ? 1 : -1)
        } else if let screen = world.screen(at: center), frame.maxY > screen.visibleFrame.maxY {
            letGo()
        }
    }

    /// At the top of a climb: up and over the edge at `edgeX`, onto the surface at height `top`
    /// that continues in direction `inward`.
    func hopOver(edgeX: CGFloat, top: CGFloat, inward: CGFloat) {
        activity = .wander
        position = CGPoint(x: edgeX + inward * size.width * 0.4 - size.width / 2, y: top - footInset + 2)
        leap(dx: inward * 60, dy: 250)
        behaviorUntil = now + 2
        onEvent?(.climbedUp)
    }

    func startHang(on window: World.WindowInfo, dir: CGFloat) {
        activity = .hang(windowID: window.id, dir: dir, until: now + .random(in: 2...4))
        grounded = false
        groundWindow = nil
        walkDirection = 0
        facingRight = dir < 0 // facing the window it's holding on to
        placeHanging(on: window.frame, dir: dir)
        onEvent?(.startedHanging)
    }

    private func placeHanging(on f: CGRect, dir: CGFloat) {
        let edgeX = dir > 0 ? f.maxX : f.minX
        position = CGPoint(x: edgeX + dir * size.width * 0.3 - size.width / 2, y: f.maxY - size.height * 0.82)
    }

    func updateHang(_ dt: CGFloat) {
        guard case .hang(let id, let dir, let until) = activity, let f = world.liveFrame(ofWindow: id) else {
            return letGo()
        }
        placeHanging(on: f, dir: dir)
        // Holding the corner of the edge it walked off: dir > 0 means the right edge.
        guard grip(onWindow: id, leftEdge: dir < 0, frame: f, y: f.maxY - 4) else { return slip() }
        if shake.update(windowID: id, origin: f.origin, dt: dt, now: now) { return shakeOff() }
        guard now >= until else { return }
        if Bool.random() {
            hopOver(edgeX: dir > 0 ? f.maxX : f.minX, top: f.maxY, inward: -dir) // pull back up
        } else {
            letGo()
        }
    }

    /// Whether the window edge is visible at height `y`, so there's something to hold on to.
    private func grip(onWindow id: Int, leftEdge: Bool, frame f: CGRect, y: CGFloat) -> Bool {
        let x = leftEdge ? f.minX + 3 : f.maxX - 3
        return world.isVisible(CGPoint(x: x, y: min(max(y, f.minY + 2), f.maxY - 2)), onWindow: id)
    }

    private func slip() {
        letGo()
        onEvent?(.slipped)
    }

    func letGo() {
        activity = .wander
        grounded = false
        groundWindow = nil
        velocity = .zero
    }

    // MARK: Peeking

    /// Walks to a screen edge (one with no neighboring screen), hides most of the way, peeks, comes back.
    private func startPeek(centerX: CGFloat, feetY: CGFloat) -> Bool {
        guard groundWindow == nil, let screen = world.screen(at: CGPoint(x: centerX, y: feetY + 5)) else { return false }
        let options = [CGFloat(-1), 1].compactMap { dir -> (edgeX: CGFloat, dir: CGFloat)? in
            let edgeX = dir > 0 ? screen.frame.maxX : screen.frame.minX
            return world.isOnScreen(CGPoint(x: edgeX + dir * 20, y: feetY + 10)) ? nil : (edgeX, dir)
        }
        guard let pick = options.min(by: { abs($0.edgeX - centerX) < abs($1.edgeX - centerX) }) else { return false }
        activity = .peek(phase: .approach, edgeX: pick.edgeX, dir: pick.dir, until: now + 20)
        return true
    }

    func updatePeek(_ dt: CGFloat, centerX: CGFloat) {
        guard case .peek(let phase, let edgeX, let dir, let until) = activity else { return }
        switch phase {
        case .approach:
            let target = edgeX + dir * size.width * 0.22
            if (dir > 0 && centerX >= target) || (dir < 0 && centerX <= target) {
                activity = .peek(phase: .peeking, edgeX: edgeX, dir: dir, until: now + .random(in: 3...6))
                walkDirection = 0
                facingRight = dir < 0
                onEvent?(.peeking)
            } else if now > until {
                activity = .peek(phase: .returning, edgeX: edgeX, dir: dir, until: now + 10)
            } else if canWalk {
                walkDirection = dir
                facingRight = dir > 0
                position.x += dir * walkSpeed * dt
            } else {
                walkDirection = 0
            }
        case .peeking:
            walkDirection = 0
            facingRight = dir < 0
            if now > until { activity = .peek(phase: .returning, edgeX: edgeX, dir: dir, until: now + 10) }
        case .returning:
            // Getting back onto the screen doesn't wait for moods or chatting.
            let inside = dir > 0 ? centerX <= edgeX - size.width * 0.8 : centerX >= edgeX + size.width * 0.8
            if inside {
                endActivity()
            } else if now > until {
                returnInside()
            } else {
                walkDirection = -dir
                facingRight = dir < 0
                position.x -= dir * walkSpeed * dt
            }
        }
    }

    // MARK: Deleting

    func updateDying() {
        guard case .dying(let from, let to, let start) = activity else { return }
        let t = min(1, CGFloat((now - start) / 0.7))
        let eased = t * t
        let c = CGPoint(x: from.x + (to.x - from.x) * eased,
                        y: from.y + (to.y - from.y) * eased + sin(t * .pi) * 60)
        position = CGPoint(x: c.x - size.width / 2, y: c.y - size.height / 2)
        layoutView(rotation: t * 720, zoom: max(0.05, 1 - t))
        if t >= 1 {
            activity = .dead
            updatePanelVisibility()
            onEvent?(.died)
        }
    }
}

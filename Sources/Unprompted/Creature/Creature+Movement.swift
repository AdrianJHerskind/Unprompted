import AppKit

/// Walking, falling and landing, riding on windows, getting around multiple screens, and the gait.
extension Creature {
    func simulate(_ dt: CGFloat) {
        let width = size.width
        var feetY = position.y + footInset - hoverOffset
        var centerX = position.x + width / 2

        // Ride along when the window we're standing on is moved; fall when it disappears.
        if grounded, let gw = groundWindow {
            if let f = world.liveFrame(ofWindow: gw.id) {
                if shake.update(windowID: gw.id, origin: f.origin, dt: dt, now: now) { return shakeOff() }
                if f != gw.frame {
                    let dx = f.minX - gw.frame.minX
                    let dy = f.maxY - gw.frame.maxY
                    position.x += dx
                    position.y += dy
                    feetY += dy
                    centerX += dx
                    groundWindow?.frame = f
                }
            } else {
                groundWindow = nil
                grounded = false
            }
        }

        if grounded {
            walk(dt, centerX: centerX, feetY: feetY)
        } else {
            fly(dt)
        }
    }

    private func walk(_ dt: CGFloat, centerX: CGFloat, feetY: CGFloat) {
        switch activity {
        case .peek: return updatePeek(dt, centerX: centerX)
        case .wrap: return updateWrap(dt, centerX: centerX)
        default: break
        }
        let width = size.width
        var centerX = centerX
        if canWalk { steer(centerX: centerX, feetY: feetY) }
        guard grounded else { return } // steering may have jumped or started a climb
        let vx = canWalk ? walkDirection * walkSpeed * speedMultiplier : 0

        if vx != 0, groundWindow == nil,
           let screen = world.screen(at: CGPoint(x: centerX, y: feetY + 2)),
           crossesBoundary(of: screen, centerX: centerX + vx * dt) {
            // About to leave this screen: what's next door?
            switch world.beyond(screen, dir: walkDirection, feetY: feetY, height: size.height) {
            case .level, .wall:
                break
            case .step(let boundaryX, let floor):
                return startStepClimb(boundaryX: boundaryX, top: floor)
            case .drop(let boundaryX, let lower):
                // Walk off the edge and fall into the lower screen from its top.
                position = CGPoint(x: boundaryX + walkDirection * width * 0.6 - width / 2,
                                   y: lower.frame.maxY - size.height - 2)
                return leap(dx: walkDirection * walkSpeed, dy: 0)
            case .outerEdge(let edgeX):
                if case .wander = activity, Double.random(in: 0..<1) < 0.5 {
                    activity = .wrap(entering: false, edgeX: edgeX, dir: walkDirection, floorY: feetY)
                    return
                }
            }
        }

        if vx != 0 {
            let newCenter = centerX + vx * dt
            let leadingEdge = newCenter + walkDirection * width * 0.3
            if world.isOnScreen(CGPoint(x: newCenter, y: feetY + 2)),
               world.isOnScreen(CGPoint(x: leadingEdge, y: feetY + 2)) {
                if movement == .hop {
                    // Little hops instead of sliding along.
                    hopping = true
                    facingRight = walkDirection > 0
                    grounded = false
                    groundWindow = nil
                    velocity = CGVector(dx: walkDirection * walkSpeed * 1.2, dy: Self.hopSpeed)
                    return
                }
                position.x += vx * dt
                centerX = newCenter
            } else {
                walkDirection = -walkDirection
                if case .wander = activity {} else { endActivity() }
            }
            facingRight = walkDirection > 0
        }

        // Still standing on something? Walking off an edge starts a fall, or a dangle.
        if let g = world.ground(atX: centerX, below: feetY, tolerance: 3), g.y >= feetY - 3 {
            position.y = g.y - footInset + hoverOffset
            setGround(g)
            return
        }
        // Dangle from the end of the window it walked off (not from an edge that just got covered).
        if let gw = groundWindow, walkDirection != 0, movement != .float, case .wander = activity,
           walkDirection > 0 ? centerX >= gw.frame.maxX - 4 : centerX <= gw.frame.minX + 4,
           Double.random(in: 0..<1) < 0.35 {
            return startHang(on: gw, dir: walkDirection)
        }
        grounded = false
        groundWindow = nil
        velocity = CGVector(dx: vx, dy: 0)
    }

    private func fly(_ dt: CGFloat) {
        if movement == .float {
            velocity.dy = max(velocity.dy - Self.gravity * 0.2 * dt, -260)
            velocity.dx *= 1 - 1.5 * dt
        } else {
            velocity.dy -= Self.gravity * dt
            velocity.dx *= 1 - 0.3 * dt
        }
        if hopping && velocity.dy < -600 { hopping = false } // that's a real fall now
        var next = CGPoint(x: position.x + velocity.dx * dt, y: position.y + velocity.dy * dt)

        // Screen edges act as walls and ceiling.
        let oldCenter = CGPoint(x: position.x + size.width / 2, y: position.y + size.height / 2)
        let newCenter = CGPoint(x: next.x + size.width / 2, y: next.y + size.height / 2)
        if !world.isOnScreen(newCenter) {
            if !world.isOnScreen(CGPoint(x: newCenter.x, y: oldCenter.y)) {
                next.x = position.x
                velocity.dx = -velocity.dx * 0.5
            }
            if !world.isOnScreen(CGPoint(x: oldCenter.x, y: newCenter.y)), velocity.dy > 0 {
                next.y = position.y
                velocity.dy = -velocity.dy * 0.4
            }
        }
        if let screen = world.screen(at: newCenter),
           next.y + size.height > screen.frame.maxY, velocity.dy > 0,
           !world.isOnScreen(CGPoint(x: newCenter.x, y: screen.frame.maxY + 2)) { // a screen above? fly on up
            next.y = screen.frame.maxY - size.height
            velocity.dy = -velocity.dy * 0.4
        }

        // Landing
        let oldFeet = position.y + footInset - hoverOffset
        let newFeet = next.y + footInset - hoverOffset
        if velocity.dy <= 0,
           let g = world.ground(atX: next.x + size.width / 2, below: oldFeet, tolerance: 1),
           newFeet <= g.y {
            next.y = g.y - footInset + hoverOffset
            let impact = -velocity.dy
            if impact > 420 {
                // Even a "rubber ball" loses a little each bounce, so it always comes to rest.
                velocity.dy = impact * min(pack.bounciness, 0.9)
                velocity.dx *= 0.7
                if impact > 1500 { onEvent?(.landedHard) }
            } else {
                velocity = .zero
                grounded = true
                if hopping {
                    hopping = false // keep going: the next hop starts from here
                } else {
                    walkDirection = 0
                    behaviorUntil = now + .random(in: 0.8...2)
                }
                setGround(g)
            }
        }
        position = next
        if abs(velocity.dx) > 30 { facingRight = velocity.dx > 0 }
    }

    func setGround(_ g: World.Ground) {
        guard let id = g.windowID else {
            groundWindow = nil
            return
        }
        if groundWindow?.id != id {
            groundWindow = world.windows.first { $0.id == id }
        }
    }

    func leap(dx: CGFloat, dy: CGFloat) {
        grounded = false
        groundWindow = nil
        walkDirection = 0
        velocity = CGVector(dx: dx, dy: dy)
    }

    func endActivity() {
        activity = .wander
        walkDirection = 0
        speedMultiplier = 1
        behaviorUntil = now + .random(in: 1...2.5)
    }

    /// If screens change or it gets flung somewhere unreachable, drop it back onto the main screen.
    func recoverIfLost(_ dt: TimeInterval) {
        // Its feet count, not its middle: on a maximized window the middle is above the screen.
        let feet = CGPoint(x: center.x, y: position.y + footInset + 1)
        let outOnPurpose = isAtScreenEdge && grounded // peeking, or walking around the screens
        offscreenTime = world.isOnScreen(feet) || outOnPurpose ? 0 : offscreenTime + dt
        guard offscreenTime > 1.5, let screen = NSScreen.main ?? world.screens.first else { return }
        offscreenTime = 0
        drop(at: CGPoint(x: screen.visibleFrame.midX, y: screen.visibleFrame.maxY - size.height))
    }

    // MARK: Gait

    /// Rolling turns the body like a wheel (and rights it when stopped); waddling rocks it.
    func updateGait(dt: CGFloat, dx: CGFloat) {
        switch movement {
        case .roll where !isAttached && !isDragging:
            if abs(dx) > 0.01 {
                rollAngle -= dx / (pack.size.width * scale * 0.36)
            } else if grounded {
                rollAngle = atan2(sin(rollAngle), cos(rollAngle)) // nearest way back upright
                rollAngle -= rollAngle * min(1, dt * 6)
            }
        case .waddle where grounded && walkDirection != 0 && !isDragging && !isAttached:
            waddlePhase += dt * 11
        default:
            rollAngle -= rollAngle * min(1, dt * 8)
            waddlePhase = 0
        }
        setBodySpin(movement == .waddle ? sin(waddlePhase) * 0.14 : (movement == .roll ? rollAngle : 0))
    }

    // MARK: Multiple screens

    /// Whether the leading edge of the body would pass the side of `screen` at this position.
    private func crossesBoundary(of screen: NSScreen, centerX: CGFloat) -> Bool {
        let leading = centerX + walkDirection * size.width * 0.3
        return walkDirection > 0 ? leading >= screen.frame.maxX : leading <= screen.frame.minX
    }

    private func startStepClimb(boundaryX: CGFloat, top: CGFloat) {
        let side = walkDirection
        activity = .stepClimb(x: boundaryX, top: top, side: side)
        position.x = boundaryX - side * climbOffset - size.width / 2
        grounded = false
        groundWindow = nil
        walkDirection = 0
    }

    func updateStepClimb(_ dt: CGFloat) {
        guard case .stepClimb(let x, let top, let side) = activity else { return }
        position.x = x - side * climbOffset - size.width / 2
        if canClimb { position.y += walkSpeed * 0.8 * dt }
        guard position.y + size.height / 2 >= top else { return }
        hopOver(edgeX: x, top: top, inward: side) // onto the next screen's floor
    }

    /// Walks out past the outermost edge, reappears beyond the opposite outermost edge, walks in.
    /// It's partly off the screens throughout, so unlike normal walking it doesn't stop for moods.
    private func updateWrap(_ dt: CGFloat, centerX: CGFloat) {
        guard case .wrap(let entering, let edgeX, let dir, let floorY) = activity else { return }
        walkDirection = dir
        facingRight = dir > 0
        position.y = floorY - footInset + hoverOffset
        position.x += dir * walkSpeed * dt
        let cx = centerX + dir * walkSpeed * dt
        let pastEdge = dir < 0 ? cx < edgeX - size.width * 0.7 : cx > edgeX + size.width * 0.7
        guard pastEdge else { return }

        if entering { return endActivity() }
        let screens = world.screens
        let floorOf = { self.world.visibleFrame(of: $0).minY }
        guard let farEdge = dir < 0 ? screens.map(\.frame.maxX).max() : screens.map(\.frame.minX).min(),
              let target = screens.filter({ abs((dir < 0 ? $0.frame.maxX : $0.frame.minX) - farEdge) < 2 })
                .min(by: { abs(floorOf($0) - floorY) < abs(floorOf($1) - floorY) }) else {
            return endActivity()
        }
        let floor = floorOf(target)
        position = CGPoint(x: farEdge - dir * size.width * 0.7 - size.width / 2, y: floor - footInset + hoverOffset)
        activity = .wrap(entering: true, edgeX: farEdge, dir: dir, floorY: floor)
        onEvent?(.wrapped)
    }

    /// If it's partly past a screen edge (peeking or wrapping around), puts it back just inside,
    /// standing on the floor, and ends that. Used before anything that needs ground under its feet.
    func returnInside() {
        let insideX: CGFloat, outward: CGFloat
        switch activity {
        case .peek(_, let edgeX, let dir, _):
            (insideX, outward) = (edgeX - dir * size.width * 0.8, dir)
        case .wrap(let entering, let edgeX, let dir, let floorY):
            (insideX, outward) = entering ? (edgeX + dir * size.width * 0.8, -dir) : (edgeX - dir * size.width * 0.8, dir)
            position.y = floorY - footInset + hoverOffset
        default:
            return
        }
        if (center.x - insideX) * outward > 0 { position.x = insideX - size.width / 2 }
        endActivity()
    }
}

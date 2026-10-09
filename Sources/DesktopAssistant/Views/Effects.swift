import AppKit
import QuartzCore

/// Particle effects (glitter trail, confetti, hearts, sparkle bursts) drawn in transparent,
/// click-through overlay windows, one per screen. Overlays are only on screen while something is animating.
@MainActor
final class Effects {
    private var overlays: [EffectsOverlay] = []
    private var observer: NSObjectProtocol?

    init() {
        rebuild()
        observer = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.rebuild() }
        }
    }

    private func rebuild() {
        overlays.forEach { $0.close() }
        overlays = NSScreen.screens.map { EffectsOverlay(screen: $0) }
    }

    private func overlay(at p: CGPoint) -> EffectsOverlay? {
        overlays.first { $0.frame.contains(p) } ?? overlays.first
    }

    /// Call every frame: a point to leave glitter at, or nil for none.
    func trail(at point: CGPoint?) {
        let target = point.flatMap { overlay(at: $0) }
        for o in overlays { o.setTrail(o === target ? point : nil) }
    }

    func confetti(at p: CGPoint) { overlay(at: p)?.burst(.confetti, at: p) }
    func hearts(at p: CGPoint) { overlay(at: p)?.burst(.hearts, at: p) }
    func sparkles(at p: CGPoint) { overlay(at: p)?.burst(.sparkles, at: p) }

    /// Call every frame; hides overlays that have nothing left to show.
    func tick() {
        let now = CACurrentMediaTime()
        for o in overlays where o.isVisible && now > o.busyUntil { o.orderOut(nil) }
    }
}

private enum Burst { case confetti, hearts, sparkles }

private final class EffectsOverlay: OverlayPanel {
    var busyUntil: CFTimeInterval = 0
    private let trailEmitter = CAEmitterLayer()
    private var trailOn = false

    init(screen: NSScreen) {
        super.init(size: screen.frame.size)
        setFrame(screen.frame, display: false)
        ignoresMouseEvents = true // never block clicks
        let view = NSView(frame: NSRect(origin: .zero, size: screen.frame.size))
        view.wantsLayer = true
        contentView = view

        trailEmitter.frame = view.bounds
        trailEmitter.emitterShape = .point
        trailEmitter.birthRate = 0
        trailEmitter.emitterCells = Self.palette(0xFFE36E, 0xFF8AD8, 0x8EC5FF, 0xFFFFFF).map { color in
            let cell = Self.cell(image: Particles.sparkle, color: color)
            cell.birthRate = 22
            cell.lifetime = 0.9
            cell.lifetimeRange = 0.3
            cell.velocity = 25
            cell.velocityRange = 20
            cell.emissionRange = .pi * 2
            cell.scale = 0.5
            cell.scaleRange = 0.25
            cell.scaleSpeed = -0.45
            cell.alphaSpeed = -1
            cell.spin = 2
            cell.spinRange = 4
            return cell
        }
        view.layer?.addSublayer(trailEmitter)
    }

    func setTrail(_ point: CGPoint?) {
        guard point != nil || trailOn else { return } // nothing to change
        Self.withoutAnimation {
            if let point {
                trailEmitter.emitterPosition = local(point)
                if !trailOn { trailEmitter.beginTime = CACurrentMediaTime() }
                trailEmitter.birthRate = 1
                trailOn = true
                wake(for: 1.5)
            } else {
                trailEmitter.birthRate = 0
                trailOn = false
            }
        }
    }

    func burst(_ kind: Burst, at point: CGPoint) {
        let emitter = CAEmitterLayer()
        emitter.frame = contentView?.bounds ?? .zero
        emitter.emitterPosition = local(point)
        emitter.emitterShape = .point
        emitter.beginTime = CACurrentMediaTime()
        let duration: CFTimeInterval
        let lifetime: CFTimeInterval

        switch kind {
        case .confetti:
            emitter.emitterCells = Self.palette(0xFF5DA2, 0xFFD23F, 0x3BCEAC, 0x5B8CFF, 0x9D6BFF, 0xFF7A3D).map { color in
                let cell = Self.cell(image: Particles.confetti, color: color)
                cell.birthRate = 110
                cell.lifetime = 3.5
                cell.velocity = 430
                cell.velocityRange = 180
                cell.emissionLongitude = .pi / 2
                cell.emissionRange = .pi / 2.5
                cell.yAcceleration = -650
                cell.spin = 3
                cell.spinRange = 10
                cell.alphaSpeed = -0.22
                cell.scale = 1
                cell.scaleRange = 0.5
                return cell
            }
            duration = 0.15
            lifetime = 3.6
        case .hearts:
            let cell = Self.cell(image: Particles.heart, color: .white)
            cell.birthRate = 14
            cell.lifetime = 1.6
            cell.velocity = 70
            cell.velocityRange = 30
            cell.emissionLongitude = .pi / 2
            cell.emissionRange = .pi / 4
            cell.yAcceleration = 20
            cell.alphaSpeed = -0.6
            cell.scale = 0.5
            cell.scaleRange = 0.15
            cell.scaleSpeed = 0.1
            emitter.emitterCells = [cell]
            duration = 0.3
            lifetime = 1.7
        case .sparkles:
            emitter.emitterCells = Self.palette(0xFFE36E, 0xFF8AD8, 0x8EC5FF, 0xFFFFFF).map { color in
                let cell = Self.cell(image: Particles.sparkle, color: color)
                cell.birthRate = 90
                cell.lifetime = 1.2
                cell.lifetimeRange = 0.3
                cell.velocity = 170
                cell.velocityRange = 90
                cell.emissionRange = .pi * 2
                cell.yAcceleration = -120
                cell.alphaSpeed = -0.8
                cell.scale = 0.6
                cell.scaleRange = 0.3
                cell.spin = 3
                cell.spinRange = 6
                return cell
            }
            duration = 0.12
            lifetime = 1.5
        }

        contentView?.layer?.addSublayer(emitter)
        wake(for: duration + lifetime)
        DispatchQueue.main.asyncAfter(deadline: .now() + duration) {
            Self.withoutAnimation { emitter.birthRate = 0 }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + duration + lifetime) {
            Self.withoutAnimation { emitter.removeFromSuperlayer() }
        }
    }

    /// Layer changes are animated implicitly by default, which isn't wanted for these.
    private static func withoutAnimation(_ changes: () -> Void) {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        changes()
        CATransaction.commit()
    }

    private func local(_ p: CGPoint) -> CGPoint {
        CGPoint(x: p.x - frame.minX, y: p.y - frame.minY)
    }

    private func wake(for seconds: CFTimeInterval) {
        busyUntil = max(busyUntil, CACurrentMediaTime() + seconds)
        if !isVisible { orderFrontRegardless() }
    }

    private static func palette(_ colors: UInt32...) -> [CGColor] {
        colors.map { CGColor.hex($0) }
    }

    private static func cell(image: CGImage?, color: CGColor) -> CAEmitterCell {
        let cell = CAEmitterCell()
        cell.contents = image
        cell.color = color
        return cell
    }
}

/// Particle images, drawn once.
private enum Particles {
    static let sparkle: CGImage? = draw(width: 20, height: 20) { ctx in
        ctx.translateBy(x: 10, y: 10)
        ctx.addPath(Shapes.sparkle(radius: 9, pinch: 0.15))
        ctx.setFillColor(.white)
        ctx.fillPath()
    }

    static let confetti: CGImage? = draw(width: 10, height: 6) { ctx in
        ctx.setFillColor(.white)
        ctx.fill(CGRect(x: 0, y: 0, width: 10, height: 6))
    }

    static let heart: CGImage? = {
        let image = NSImage(size: NSSize(width: 40, height: 40), flipped: false) { rect in
            ("💖" as NSString).draw(in: rect.insetBy(dx: 2, dy: 2), withAttributes: [.font: NSFont.systemFont(ofSize: 30)])
            return true
        }
        return image.cgImage(forProposedRect: nil, context: nil, hints: nil)
    }()

    private static func draw(width: Int, height: Int, _ body: (CGContext) -> Void) -> CGImage? {
        guard let ctx = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
                                  space: CGColorSpace(name: CGColorSpace.sRGB)!,
                                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
        body(ctx)
        return ctx.makeImage()
    }
}

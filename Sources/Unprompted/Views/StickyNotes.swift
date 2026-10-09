import AppKit

/// Little yellow notes the assistant leaves on your screen. Click one to crumple it away.
@MainActor
final class StickyNotes {
    static let maxNotes = 3
    private static let size = NSSize(width: 160, height: 140)

    var onCrumpled: (() -> Void)?
    /// Crumpling makes a little "pop".
    var playsSound = true
    var count: Int { notes.count }
    private var notes: [OverlayPanel] = []
    private var isVisible = true

    /// Places a note somewhere in the upper half of the creature's screen, away from other notes.
    func add(_ text: String, signature: String, near creature: CGRect) {
        guard notes.count < Self.maxNotes,
              let screen = NSScreen.nearest(to: CGPoint(x: creature.midX, y: creature.midY)) else { return }
        let size = Self.size
        let area = screen.visibleFrame.insetBy(dx: 60, dy: 60)
        guard area.width > size.width, area.height > size.height else { return }

        var origin = NSPoint(x: area.maxX - size.width, y: area.maxY - size.height)
        // The upper half, or as much of it as a note fits into on short screens.
        let lowest = min(area.midY, area.maxY - size.height)
        for _ in 0..<12 {
            let candidate = NSPoint(x: .random(in: area.minX...(area.maxX - size.width)),
                                    y: .random(in: lowest...(area.maxY - size.height)))
            let rect = NSRect(origin: candidate, size: size)
            if !notes.contains(where: { $0.frame.insetBy(dx: -20, dy: -20).intersects(rect) }), !rect.intersects(creature) {
                origin = candidate
                break
            }
        }

        let panel = OverlayPanel(size: size)
        let view = NoteView(frame: NSRect(origin: .zero, size: size), text: text, signature: signature)
        view.onClick = { [weak self, weak panel] in
            guard let self, let panel else { return }
            self.crumple(panel)
        }
        panel.contentView = view
        panel.setFrameOrigin(origin)
        notes.append(panel)
        guard isVisible else { return }
        panel.alphaValue = 0
        panel.orderFrontRegardless()
        NSAnimationContext.runAnimationGroup { $0.duration = 0.3; panel.animator().alphaValue = 1 }
    }

    func setVisible(_ visible: Bool) {
        guard visible != isVisible else { return }
        isVisible = visible
        for note in notes {
            if visible { note.orderFrontRegardless() } else { note.orderOut(nil) }
        }
    }

    func removeAll() {
        notes.forEach { $0.orderOut(nil) }
        notes.removeAll()
    }

    private func crumple(_ panel: OverlayPanel) {
        guard let index = notes.firstIndex(where: { $0 === panel }) else { return }
        notes.remove(at: index)
        if playsSound { NSSound(named: "Pop")?.play() }
        let frame = panel.frame
        let target = NSRect(x: frame.midX - 10, y: frame.midY - 10, width: 20, height: 20)
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.25
            panel.animator().setFrame(target, display: true)
            panel.animator().alphaValue = 0
        }, completionHandler: {
            MainActor.assumeIsolated { panel.orderOut(nil) }
        })
        onCrumpled?()
    }
}

/// A slightly tilted sticky note with a strip of tape and handwritten-looking text.
final class NoteView: NSView {
    var onClick: (() -> Void)?
    private let text: String
    private let signature: String
    private let tilt = CGFloat.random(in: -5...5) * .pi / 180

    private static let paperColor = NSColor(srgbRed: 1, green: 0.93, blue: 0.48, alpha: 1)
    private static let stripColor = NSColor(srgbRed: 0.98, green: 0.86, blue: 0.36, alpha: 1)
    private static let ink = NSColor(srgbRed: 0.18, green: 0.2, blue: 0.35, alpha: 1)
    private static let font = NSFont(name: "Noteworthy-Bold", size: 14) ?? NSFont(name: "Marker Felt", size: 14)
        ?? NSFont.systemFont(ofSize: 13, weight: .medium)
    private static let signatureFont = NSFont(name: "Noteworthy-Light", size: 12) ?? font

    init(frame: NSRect, text: String, signature: String) {
        self.text = text
        self.signature = signature
        super.init(frame: frame)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
    override func mouseDown(with event: NSEvent) { onClick?() }

    override func draw(_ dirtyRect: NSRect) {
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }
        // Drawn scaled to the view, so the crumple animation shrinks the note smoothly.
        let scale = bounds.width / 160
        ctx.scaleBy(x: scale, y: scale)
        let paper = NSRect(x: 14, y: 12, width: 132, height: 116)
        ctx.translateBy(x: paper.midX, y: paper.midY)
        ctx.rotate(by: tilt)
        ctx.translateBy(x: -paper.midX, y: -paper.midY)

        ctx.saveGState()
        ctx.setShadow(offset: CGSize(width: 1, height: -3), blur: 6, color: NSColor(white: 0, alpha: 0.3).cgColor)
        Self.paperColor.setFill()
        NSBezierPath(rect: paper).fill()
        ctx.restoreGState()
        // A slightly darker strip at the top, like a real sticky note, and a bit of tape.
        Self.stripColor.setFill()
        NSBezierPath(rect: NSRect(x: paper.minX, y: paper.maxY - 14, width: paper.width, height: 14)).fill()
        NSColor(white: 1, alpha: 0.55).setFill()
        NSBezierPath(rect: NSRect(x: paper.midX - 22, y: paper.maxY - 8, width: 44, height: 14)).fill()

        (text as NSString).draw(in: NSRect(x: paper.minX + 10, y: paper.minY + 28, width: paper.width - 20, height: paper.height - 46),
                                withAttributes: [.font: Self.font, .foregroundColor: Self.ink])
        let sign = "— \(signature)" as NSString
        let signAttrs: [NSAttributedString.Key: Any] = [.font: Self.signatureFont, .foregroundColor: Self.ink]
        let signSize = sign.size(withAttributes: signAttrs)
        sign.draw(at: NSPoint(x: paper.maxX - 10 - signSize.width, y: paper.minY + 8), withAttributes: signAttrs)
    }
}

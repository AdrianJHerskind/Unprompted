import AppKit

/// Where you can throw the creature away. By default a trash can appears in the corner of the
/// screen while you drag it. With "Use Real Dock Trash", the Trash icon in the Dock is the target.
@MainActor
final class TrashCan {
    private let panel = OverlayPanel(size: NSSize(width: 86, height: 86))
    private let view = TrashCanView(frame: NSRect(x: 0, y: 0, width: 86, height: 86))
    private var visibleUntil: TimeInterval = 0
    private var dockTrashCache: (rect: CGRect?, time: TimeInterval) = (nil, -10)

    init() {
        panel.contentView = view
        panel.ignoresMouseEvents = true
    }

    /// Call every frame with the creature that's being carried or was just thrown, if any. The trash
    /// can shows (on that creature's screen) while it's carried and for a moment after. Returns the
    /// current target in screen coordinates. The Dock is only asked for its Trash while it matters.
    func update(focus: Creature?, useDockTrash: Bool, now: TimeInterval) -> CGRect? {
        if let focus, focus.isDragging {
            visibleUntil = now + 1.5
            if let screen = NSScreen.nearest(to: focus.center) { place(on: screen) }
        }
        guard focus != nil || now < visibleUntil else {
            hide()
            return nil
        }
        if useDockTrash, let dock = dockTrash(now: now) {
            if panel.isVisible { panel.orderOut(nil) }
            return dock
        }
        guard now < visibleUntil else {
            hide()
            return nil
        }
        if !panel.isVisible { panel.orderFrontRegardless() }
        return panel.frame
    }

    func setHighlighted(_ on: Bool) {
        if view.highlighted != on { view.highlighted = on }
    }

    /// Keeps it around a little longer, while something flies into it.
    func hideSoon(now: TimeInterval) {
        visibleUntil = min(visibleUntil, now + 0.8)
    }

    func playSound() {
        let dockSound = "/System/Library/Components/CoreAudio.component/Contents/SharedSupport/SystemSounds/dock/drag to trash.aif"
        (NSSound(contentsOfFile: dockSound, byReference: true) ?? NSSound(named: "Pop"))?.play()
    }

    private func place(on screen: NSScreen) {
        let visible = screen.visibleFrame
        let origin = NSPoint(x: visible.maxX - panel.frame.width - 24, y: visible.minY + 16)
        if panel.frame.origin != origin { panel.setFrameOrigin(origin) }
    }

    func hide() {
        visibleUntil = 0
        if panel.isVisible { panel.orderOut(nil) }
        setHighlighted(false)
    }

    /// Accessibility calls are slow-ish, so the Dock's Trash position is cached for a couple of seconds.
    private func dockTrash(now: TimeInterval) -> CGRect? {
        if now - dockTrashCache.time >= 2 {
            dockTrashCache = (DockTrashLocator.trashFrame(), now)
        }
        return dockTrashCache.rect
    }
}

private final class TrashCanView: NSView {
    var highlighted = false { didSet { needsDisplay = true } }

    override func draw(_ dirtyRect: NSRect) {
        let disc = NSBezierPath(ovalIn: bounds.insetBy(dx: 4, dy: 4))
        (highlighted ? NSColor(srgbRed: 1, green: 0.42, blue: 0.45, alpha: 0.92) : NSColor(white: 1, alpha: 0.88)).setFill()
        disc.fill()
        NSColor(white: 0, alpha: 0.25).setStroke()
        disc.stroke()

        let text = "🗑️" as NSString
        let attrs: [NSAttributedString.Key: Any] = [.font: NSFont.systemFont(ofSize: highlighted ? 50 : 42)]
        let size = text.size(withAttributes: attrs)
        text.draw(at: NSPoint(x: bounds.midX - size.width / 2, y: bounds.midY - size.height / 2), withAttributes: attrs)
    }
}

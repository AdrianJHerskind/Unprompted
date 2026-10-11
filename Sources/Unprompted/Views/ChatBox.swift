import AppKit

/// The "Ask me anything" input: a little field that sits next to the creature.
/// It's a non-activating panel, so you can type into it without the app you're working in
/// losing focus. Return sends, Esc (or clicking elsewhere) closes, ↑/↓ recall earlier questions.
@MainActor
final class ChatBox: NSObject, NSTextFieldDelegate, NSWindowDelegate {
    var onSubmit: ((String) -> Void)?
    var isOpen: Bool { panel.isVisible }

    private let panel = KeyablePanel(size: NSSize(width: 290, height: 40))
    private let field = NSTextField()
    private var history: [String] = []
    private var historyIndex = 0
    /// Where it was last placed (placing it reads the screen's visible frame, which is slow).
    private var placedAt: CGRect?

    override init() {
        super.init()
        let size = panel.frame.size
        let background = ChatBackgroundView(frame: NSRect(origin: .zero, size: size))

        field.frame = NSRect(x: 36, y: 10, width: size.width - 50, height: 20)
        field.isBordered = false
        field.drawsBackground = false
        field.focusRingType = .none
        field.font = .systemFont(ofSize: 13)
        field.textColor = .black
        field.usesSingleLineMode = true
        field.cell?.isScrollable = true
        field.cell?.wraps = false
        field.delegate = self
        background.addSubview(field)

        panel.contentView = background
        panel.delegate = self
        // Always light, so the caret and text stay readable on the yellow background.
        panel.appearance = NSAppearance(named: .aqua)
    }

    func open(near anchor: CGRect, name: String) {
        field.placeholderAttributedString = NSAttributedString(
            string: "Ask \(name) anything…",
            attributes: [.foregroundColor: NSColor(white: 0.45, alpha: 1), .font: NSFont.systemFont(ofSize: 13)])
        field.stringValue = ""
        historyIndex = history.count
        place(near: anchor) // before showing, so it never flashes at its old position
        panel.makeKeyAndOrderFront(nil)
        panel.makeFirstResponder(field)
    }

    func close() {
        panel.orderOut(nil)
    }

    /// Call every frame while open, so the box stays next to the creature.
    func follow(_ anchor: CGRect) {
        if isOpen && anchor != placedAt { place(near: anchor) }
    }

    /// Beside the anchor (the creature), on whichever side has room.
    private func place(near anchor: CGRect) {
        guard let screen = NSScreen.nearest(to: CGPoint(x: anchor.midX, y: anchor.midY)) else { return }
        placedAt = anchor
        let size = panel.frame.size
        let visible = screen.visibleFrame
        var x = anchor.maxX - 8
        if x + size.width > visible.maxX - 4 { x = anchor.minX - size.width + 8 }
        x = min(max(x, visible.minX + 4), visible.maxX - size.width - 4)
        let y = min(max(anchor.midY - size.height / 2 - 6, visible.minY + 4), visible.maxY - size.height - 4)
        let origin = NSPoint(x: x.rounded(), y: y.rounded())
        if panel.frame.origin != origin { panel.setFrameOrigin(origin) }
    }

    // MARK: - NSTextFieldDelegate

    func control(_ control: NSControl, textView: NSTextView, doCommandBy selector: Selector) -> Bool {
        switch selector {
        case #selector(NSResponder.insertNewline(_:)):
            let text = field.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !text.isEmpty else { return true }
            if history.last != text { history.append(text) }
            historyIndex = history.count
            field.stringValue = ""
            onSubmit?(text)
        case #selector(NSResponder.cancelOperation(_:)):
            close()
        case #selector(NSResponder.moveUp(_:)):
            guard historyIndex > 0 else { return true }
            historyIndex -= 1
            field.stringValue = history[historyIndex]
        case #selector(NSResponder.moveDown(_:)):
            guard historyIndex < history.count else { return true }
            historyIndex += 1
            field.stringValue = historyIndex < history.count ? history[historyIndex] : ""
        default:
            return false
        }
        return true
    }

    // MARK: - NSWindowDelegate

    func windowDidResignKey(_ notification: Notification) {
        close()
    }
}

private final class ChatBackgroundView: NSView {
    override func draw(_ dirtyRect: NSRect) {
        let box = NSBezierPath(roundedRect: bounds.insetBy(dx: 1, dy: 1), xRadius: 12, yRadius: 12)
        NSColor(srgbRed: 1, green: 1, blue: 0.88, alpha: 1).setFill()
        box.fill()
        NSColor(white: 0, alpha: 0.75).setStroke()
        box.lineWidth = 1
        box.stroke()
        ("💬" as NSString).draw(at: NSPoint(x: 11, y: 10), withAttributes: [.font: NSFont.systemFont(ofSize: 15)])
    }
}

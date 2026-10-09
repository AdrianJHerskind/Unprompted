import AppKit

/// A classic pale-yellow speech bubble that "streams" its text word by word like a chatbot,
/// optionally after a fake "Thinking…" phase, with optional Clippy-style buttons. Click it to dismiss.
@MainActor
final class SpeechBubble {
    private let panel = OverlayPanel(size: NSSize(width: 10, height: 10), level: .assistantBubble)
    private let view = BubbleView(frame: .zero)

    /// Called when the user clicks the bubble away (not when it fades out or a button is chosen,
    /// and not for sticky bubbles, where clicking just means "seen it").
    var onDismiss: (() -> Void)?
    private(set) var isShowing = false
    /// Stays until clicked away instead of fading out, for things you shouldn't miss (reminders).
    private(set) var isSticky = false
    private var buttons: [String] = []
    private var onChoice: ((Int) -> Void)?

    private var tokens: [String] = []
    private var fullLength = 0
    private var revealed = 0
    private var nextTokenAt: TimeInterval = 0
    private var thinkingUntil: TimeInterval = 0
    private var thinkingLabel = ""
    private var hideAt: TimeInterval = .infinity
    private var now: TimeInterval = 0
    /// What's currently drawn, so the view is only updated when something changed.
    private var rendered: (thinking: Bool, dots: Int, revealed: Int)?

    private static let thinkingLabels = [
        "Thinking", "Reasoning", "Consulting the vibes", "Hallucinating responsibly",
        "Aligning", "Pondering deeply", "Asking a bigger model",
    ]

    init() {
        panel.contentView = view
        view.onClick = { [weak self] in self?.dismiss() }
        view.onButton = { [weak self] index in self?.choose(index) }
    }

    /// Shows only the thinking label until `say` is called with the real answer.
    func showThinking(_ label: String, near anchor: CGRect) {
        tokens = []
        fullLength = 0
        revealed = 0
        thinkingLabel = label
        thinkingUntil = .infinity
        hideAt = .infinity
        isSticky = false
        buttons = []
        onChoice = nil
        present(fullText: "", near: anchor)
    }

    /// `buttons` appear under the text once it has finished "typing"; `onChoice` gets the index clicked.
    func say(_ text: String, think: Bool, near anchor: CGRect, sticky: Bool = false,
             buttons: [String] = [], onChoice: ((Int) -> Void)? = nil) {
        isSticky = sticky
        self.buttons = buttons
        self.onChoice = onChoice
        // Words (with their trailing space or newline) appear one at a time.
        tokens = []
        var current = ""
        for ch in text {
            current.append(ch)
            if ch == " " || ch == "\n" {
                tokens.append(current)
                current = ""
            }
        }
        if !current.isEmpty { tokens.append(current) }

        fullLength = text.count
        revealed = 0
        nextTokenAt = now
        thinkingLabel = "✨ " + (Self.thinkingLabels.randomElement() ?? "Thinking")
        thinkingUntil = think ? now + .random(in: 1.5...3.5) : now
        hideAt = .infinity
        present(fullText: text, near: anchor)
    }

    func hide() {
        isShowing = false
        isSticky = false
        onChoice = nil
        panel.orderOut(nil)
    }

    /// Call every frame with the rect it should point at (the top of the creature's body).
    func tick(dt: TimeInterval, anchor: CGRect) {
        now += dt
        guard isShowing else { return }

        if now >= thinkingUntil, revealed < tokens.count, now >= nextTokenAt {
            revealed += 1
            nextTokenAt = now + .random(in: 0.03...0.11)
            if revealed == tokens.count && !isSticky {
                // Time to read, and much longer when there are buttons to click.
                hideAt = now + (buttons.isEmpty ? 2.5 + Double(fullLength) * 0.045 : 25)
            }
        }
        if now >= hideAt {
            let alpha = 1 - (now - hideAt) / 0.4
            if alpha <= 0 { return hide() }
            panel.alphaValue = alpha
        }
        render()
        position(near: anchor)
    }

    private func present(fullText text: String, near anchor: CGRect) {
        let size = view.layout(fullText: text, thinkingText: thinkingLabel + "...", buttons: buttons)
        panel.setContentSize(size)
        view.frame = NSRect(origin: .zero, size: size)
        panel.alphaValue = 1
        isShowing = true
        rendered = nil
        render()
        position(near: anchor)
        panel.orderFrontRegardless()
    }

    private func choose(_ index: Int) {
        let handler = onChoice
        hide()
        handler?(index)
    }

    private func dismiss() {
        let wasSticky = isSticky
        hide()
        if !wasSticky { onDismiss?() }
    }

    private func render() {
        let thinking = now < thinkingUntil
        let dots = thinking ? Int(now * 3) % 4 : 0
        if let r = rendered, r.thinking == thinking, r.dots == dots, r.revealed == revealed { return }
        rendered = (thinking, dots, revealed)
        view.isThinking = thinking
        if thinking {
            view.text = thinkingLabel + String(repeating: ".", count: dots)
        } else {
            view.text = tokens.prefix(revealed).joined()
            view.showButtons = !buttons.isEmpty && revealed == tokens.count
        }
    }

    /// Above the anchor, or below it when there's no room under the menu bar.
    private func position(near anchor: CGRect) {
        guard let screen = NSScreen.nearest(to: CGPoint(x: anchor.midX, y: anchor.midY)) else { return }
        let size = panel.frame.size
        var x = anchor.midX - size.width / 2
        x = min(max(x, screen.frame.minX + 4), screen.frame.maxX - size.width - 4)

        var y = anchor.maxY - 12
        var tailDown = true
        if y + size.height > screen.visibleFrame.maxY {
            y = anchor.minY - size.height + 8
            tailDown = false
        }
        view.tailDown = tailDown
        view.tailX = anchor.midX - x
        let origin = NSPoint(x: x.rounded(), y: y.rounded())
        if panel.frame.origin != origin { panel.setFrameOrigin(origin) }
    }
}

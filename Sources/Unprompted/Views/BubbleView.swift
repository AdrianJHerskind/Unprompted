import AppKit

/// Draws a speech bubble: a rounded rectangle with a tail, the text, and optional buttons.
final class BubbleView: NSView {
    var text = "" {
        didSet {
            guard text != oldValue else { return }
            if let added = addedTextRect(since: oldValue) { setNeedsDisplay(added) } else { needsDisplay = true }
        }
    }
    var isThinking = false { didSet { if isThinking != oldValue { needsDisplay = true } } }
    /// Where the tail points, measured from the bubble's left edge.
    var tailX: CGFloat = 40 { didSet { if tailX != oldValue { needsDisplay = true } } }
    var tailDown = true { didSet { if tailDown != oldValue { needsDisplay = true } } }
    var showButtons = false { didSet { if showButtons != oldValue { needsDisplay = true } } }
    var onClick: (() -> Void)?
    var onButton: ((Int) -> Void)?

    private var buttonTitles: [String] = []
    private var buttonSizes: [NSSize] = []
    private var textSize = NSSize.zero

    /// The finished text, laid out once. While it "types", each new word is drawn on its own,
    /// instead of laying out and drawing everything said so far again for every word.
    private var fullText = ""
    private var isMultiline = false
    private let storage = NSTextStorage()
    private let container = NSTextContainer()
    private lazy var layoutManager: NSLayoutManager = {
        let manager = NSLayoutManager()
        manager.usesFontLeading = false // like NSString's draw(in:)
        container.lineFragmentPadding = 0
        manager.addTextContainer(container)
        storage.addLayoutManager(manager)
        return manager
    }()

    private static let font = NSFont.systemFont(ofSize: 13)
    private static let thinkingFont = NSFontManager.shared.convert(NSFont.systemFont(ofSize: 13), toHaveTrait: .italicFontMask)
    private static let buttonFont = NSFont.systemFont(ofSize: 12, weight: .medium)
    private static let buttonHeight: CGFloat = 22
    private static let buttonGap: CGFloat = 6
    private static let maxTextWidth: CGFloat = 260
    private static let padding: CGFloat = 10
    private static let tail: CGFloat = 11
    private static let cornerRadius: CGFloat = 10
    private static let fill = NSColor(srgbRed: 1, green: 1, blue: 0.88, alpha: 1) // the classic tooltip yellow

    /// Sizes the bubble for the finished text (and buttons) so it doesn't grow while "typing".
    func layout(fullText: String, thinkingText: String, buttons: [String]) -> NSSize {
        buttonTitles = buttons
        buttonSizes = buttons.map { title in
            let width = (title as NSString).size(withAttributes: [.font: Self.buttonFont]).width
            return NSSize(width: ceil(width) + 20, height: Self.buttonHeight)
        }
        showButtons = false
        let bound = NSSize(width: Self.maxTextWidth, height: 10_000)
        let options: NSString.DrawingOptions = [.usesLineFragmentOrigin, .usesFontLeading]
        let body = (fullText as NSString).boundingRect(with: bound, options: options, attributes: [.font: Self.font])
        let thinking = (thinkingText as NSString).boundingRect(with: bound, options: options, attributes: [.font: Self.thinkingFont])
        // A little slack so draw(in:) never wraps differently or clips the last line.
        textSize = NSSize(width: ceil(max(body.width, thinking.width, 60)) + 2, height: ceil(max(body.height, thinking.height)) + 2)
        self.fullText = fullText
        storage.setAttributedString(NSAttributedString(string: fullText, attributes: [.font: Self.font, .foregroundColor: NSColor.black]))
        container.size = NSSize(width: textSize.width, height: 10_000)
        layoutManager.ensureLayout(for: container)
        // A single line is quick to draw anyway, so short lines are drawn with NSString, like the
        // thinking text: the layout manager would put an emoji on them half a point higher.
        let glyphs = layoutManager.numberOfGlyphs
        isMultiline = glyphs > 0 && layoutManager.lineFragmentRect(forGlyphAt: glyphs - 1, effectiveRange: nil).minY > 0
        let buttonsWidth = buttonSizes.reduce(0) { $0 + $1.width } + Self.buttonGap * CGFloat(max(0, buttonSizes.count - 1))
        let buttonsHeight = buttonSizes.isEmpty ? 0 : Self.buttonHeight + 8
        return NSSize(width: max(textSize.width, buttonsWidth) + Self.padding * 2 + 2,
                      height: textSize.height + buttonsHeight + Self.padding * 2 + Self.tail + 2)
    }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func mouseDown(with event: NSEvent) {
        let p = convert(event.locationInWindow, from: nil)
        if showButtons, let index = buttonRects().firstIndex(where: { $0.contains(p) }) {
            onButton?(index)
        } else {
            onClick?()
        }
    }

    /// The bubble without its tail.
    private var bodyRect: NSRect {
        NSRect(x: 1, y: tailDown ? Self.tail + 1 : 1, width: bounds.width - 2, height: bounds.height - Self.tail - 2)
    }

    private var textRect: NSRect {
        let b = bodyRect
        return NSRect(x: b.minX + Self.padding, y: b.maxY - Self.padding - textSize.height,
                      width: textSize.width, height: textSize.height)
    }

    /// Showing the start of the finished (multi-line) text, which is laid out already.
    private var isTypingFullText: Bool { isMultiline && !isThinking && fullText.hasPrefix(text) }

    /// The shown part of the finished text that falls into `dirtyRect`.
    private func drawTypedText(_ dirtyRect: NSRect) {
        let r = textRect
        let shown = layoutManager.glyphRange(forCharacterRange: NSRange(location: 0, length: (text as NSString).length),
                                             actualCharacterRange: nil)
        // The layout runs top-down from the text's top-left corner, like in a flipped view.
        let dirty = NSRect(x: dirtyRect.minX - r.minX, y: r.maxY - dirtyRect.maxY, width: dirtyRect.width, height: dirtyRect.height)
        let glyphs = NSIntersectionRange(shown, layoutManager.glyphRange(forBoundingRect: dirty, in: container))
        guard glyphs.length > 0, let ctx = NSGraphicsContext.current?.cgContext else { return }
        NSGraphicsContext.saveGraphicsState()
        ctx.translateBy(x: r.minX, y: r.maxY)
        ctx.scaleBy(x: 1, y: -1)
        NSGraphicsContext.current = NSGraphicsContext(cgContext: ctx, flipped: true)
        layoutManager.drawGlyphs(forGlyphRange: glyphs, at: .zero)
        NSGraphicsContext.restoreGraphicsState()
    }

    /// Where the words added since `old` go, when they continue the finished text; nil otherwise.
    private func addedTextRect(since old: String) -> NSRect? {
        guard isTypingFullText, text.hasPrefix(old) else { return nil }
        let start = (old as NSString).length
        let added = NSRange(location: start, length: (text as NSString).length - start)
        let glyphs = layoutManager.glyphRange(forCharacterRange: added, actualCharacterRange: nil)
        let box = layoutManager.boundingRect(forGlyphRange: glyphs, in: container)
        let r = textRect
        // A little extra for antialiasing and glyphs (emoji) reaching past their box.
        return NSRect(x: r.minX + box.minX, y: r.maxY - box.maxY, width: box.width, height: box.height).insetBy(dx: -2, dy: -2)
    }

    private func buttonRects() -> [NSRect] {
        var x = bodyRect.minX + Self.padding
        return buttonSizes.map { size in
            defer { x += size.width + Self.buttonGap }
            return NSRect(x: x, y: bodyRect.minY + Self.padding, width: size.width, height: size.height)
        }
    }

    override func draw(_ dirtyRect: NSRect) {
        let outline = bubblePath()
        Self.fill.setFill()
        outline.fill()
        NSColor(white: 0, alpha: 0.75).setStroke()
        outline.lineWidth = 1
        outline.stroke()

        if isTypingFullText {
            drawTypedText(dirtyRect)
        } else {
            let attrs: [NSAttributedString.Key: Any] = [
                .font: isThinking ? Self.thinkingFont : Self.font,
                .foregroundColor: isThinking ? NSColor(white: 0.4, alpha: 1) : NSColor.black,
            ]
            (text as NSString).draw(in: textRect, withAttributes: attrs)
        }

        guard showButtons else { return }
        let titleAttrs: [NSAttributedString.Key: Any] = [.font: Self.buttonFont, .foregroundColor: NSColor.black]
        for (rect, title) in zip(buttonRects(), buttonTitles) {
            let pill = NSBezierPath(roundedRect: rect, xRadius: 6, yRadius: 6)
            NSColor.white.setFill()
            pill.fill()
            NSColor(white: 0, alpha: 0.45).setStroke()
            pill.lineWidth = 1
            pill.stroke()
            let size = (title as NSString).size(withAttributes: titleAttrs)
            (title as NSString).draw(at: NSPoint(x: rect.midX - size.width / 2, y: rect.midY - size.height / 2),
                                     withAttributes: titleAttrs)
        }
    }

    /// A rounded rectangle with the tail built into the outline, on the bottom or top edge.
    private func bubblePath() -> NSBezierPath {
        let t = Self.tail, r = Self.cornerRadius, b = bodyRect
        let tx = min(max(tailX, b.minX + r + 8), b.maxX - r - 8)
        let p = NSBezierPath()
        p.move(to: NSPoint(x: b.minX + r, y: b.minY))
        if tailDown {
            p.line(to: NSPoint(x: tx - 7, y: b.minY))
            p.line(to: NSPoint(x: tx - 1, y: b.minY - t))
            p.line(to: NSPoint(x: tx + 6, y: b.minY))
        }
        p.line(to: NSPoint(x: b.maxX - r, y: b.minY))
        p.appendArc(withCenter: NSPoint(x: b.maxX - r, y: b.minY + r), radius: r, startAngle: 270, endAngle: 360)
        p.line(to: NSPoint(x: b.maxX, y: b.maxY - r))
        p.appendArc(withCenter: NSPoint(x: b.maxX - r, y: b.maxY - r), radius: r, startAngle: 0, endAngle: 90)
        if !tailDown {
            p.line(to: NSPoint(x: tx + 6, y: b.maxY))
            p.line(to: NSPoint(x: tx - 1, y: b.maxY + t))
            p.line(to: NSPoint(x: tx - 7, y: b.maxY))
        }
        p.line(to: NSPoint(x: b.minX + r, y: b.maxY))
        p.appendArc(withCenter: NSPoint(x: b.minX + r, y: b.maxY - r), radius: r, startAngle: 90, endAngle: 180)
        p.line(to: NSPoint(x: b.minX, y: b.minY + r))
        p.appendArc(withCenter: NSPoint(x: b.minX + r, y: b.minY + r), radius: r, startAngle: 180, endAngle: 270)
        p.close()
        return p
    }
}

import AppKit

extension NSWindow.Level {
    /// The creature, its effects, notes and trash can: above normal windows, the menu bar and the Dock.
    static let assistant = NSWindow.Level.statusBar
    /// Speech bubbles, just above the creature.
    static let assistantBubble = NSWindow.Level(rawValue: NSWindow.Level.statusBar.rawValue + 1)
    /// The chat box, above everything else of ours.
    static let assistantChat = NSWindow.Level(rawValue: NSWindow.Level.statusBar.rawValue + 2)
}

/// Borderless, transparent panel that floats above normal windows, the menu bar and the Dock,
/// on every Space and over full-screen apps. Clicks on fully transparent pixels pass through
/// to whatever is underneath (as long as `ignoresMouseEvents` is left at its default).
class OverlayPanel: NSPanel {
    init(size: NSSize, level: NSWindow.Level = .assistant) {
        super.init(contentRect: NSRect(origin: .zero, size: size),
                   styleMask: [.borderless, .nonactivatingPanel],
                   backing: .buffered,
                   defer: false)
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        self.level = level
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        hidesOnDeactivate = false
        isReleasedWhenClosed = false
        isMovable = false
        animationBehavior = .none // appear instantly, no zoom-in
        // 8 bits per channel is plenty for cartoons; wide-color displays default to 16-bit float,
        // which doubles the cost of every redraw.
        depthLimit = .twentyfourBitRGB
    }

    // Never steal focus from the app the user is working in.
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}

/// An overlay that can take keyboard focus, still without activating the app (for the chat box).
final class KeyablePanel: OverlayPanel {
    init(size: NSSize) {
        super.init(size: size, level: .assistantChat)
        hasShadow = true
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
        becomesKeyOnlyIfNeeded = false
        isFloatingPanel = true
    }

    override var canBecomeKey: Bool { true }
}

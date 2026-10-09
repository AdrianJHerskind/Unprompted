import AppKit

enum ScreenGeometry {
    /// Converts a rect from Core Graphics / Accessibility coordinates (origin at the top-left of the
    /// primary screen, y down) to Cocoa screen coordinates (origin at its bottom-left, y up).
    static func cocoaRect(fromTopLeft r: CGRect) -> CGRect {
        let primaryTop = NSScreen.screens.first?.frame.maxY ?? 0
        return CGRect(x: r.minX, y: primaryTop - r.maxY, width: r.width, height: r.height)
    }
}

extension NSScreen {
    /// The screen containing `point`, or the closest one when it's off-screen (e.g. while the
    /// creature walks in from beyond an edge), so things never jump to the main screen.
    static func nearest(to point: CGPoint) -> NSScreen? {
        screens.min { $0.distance(to: point) < $1.distance(to: point) }
    }

    private func distance(to p: CGPoint) -> CGFloat {
        let dx = max(frame.minX - p.x, 0, p.x - frame.maxX)
        let dy = max(frame.minY - p.y, 0, p.y - frame.maxY)
        return hypot(dx, dy)
    }
}

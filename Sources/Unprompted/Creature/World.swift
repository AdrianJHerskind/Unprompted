import AppKit

/// What the creature can stand on: the bottom of each screen (top of the Dock) and the visible
/// top edges of other apps' windows. All rects are in Cocoa screen coordinates.
@MainActor
final class World {
    struct WindowInfo {
        let id: Int
        let ownerPID: Int
        var frame: CGRect
    }

    struct Ground {
        let y: CGFloat
        let windowID: Int?
    }

    /// What's past the side of a screen, for something standing on its floor.
    enum Beyond {
        /// Another screen continues at about the same level: just keep walking.
        case level
        /// The next screen's floor is higher: climb up the boundary to `floor`.
        case step(boundaryX: CGFloat, floor: CGFloat)
        /// The next screen is entirely lower: drop down into it.
        case drop(boundaryX: CGFloat, screen: NSScreen)
        /// Nothing there, and it's the far left/right of the whole setup: can wrap around.
        case outerEdge(edgeX: CGFloat)
        /// Nothing there: turn around.
        case wall
    }

    /// Other apps' normal windows, front to back.
    private(set) var windows: [WindowInfo] = []
    /// Cached, because `NSScreen.screens` builds a new array on every call.
    private(set) var screens: [NSScreen] = NSScreen.screens

    private let ownPID = Int(ProcessInfo.processInfo.processIdentifier)
    private var lastRefresh: TimeInterval = -1
    private var appWindowOwners: Set<Int> = []
    private var ownersNeedRefresh = true
    private var observers: [NSObjectProtocol] = []

    /// How often the full window list is read. Windows the creature is attached to are tracked
    /// live with `liveFrame(ofWindow:)`, so this can be relaxed.
    private static let refreshInterval: TimeInterval = 0.2

    init() {
        let workspace = NSWorkspace.shared.notificationCenter
        let appChanges: [Notification.Name] = [
            NSWorkspace.didLaunchApplicationNotification, NSWorkspace.didTerminateApplicationNotification,
            NSWorkspace.didHideApplicationNotification, NSWorkspace.didUnhideApplicationNotification,
        ]
        for name in appChanges {
            observers.append(workspace.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.ownersNeedRefresh = true }
            })
        }
        observers.append(NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.screens = NSScreen.screens }
        })
    }

    func refreshIfNeeded(now: TimeInterval) {
        guard now - lastRefresh >= Self.refreshInterval else { return }
        lastRefresh = now
        refresh()
    }

    /// Window positions are readable without Screen Recording permission (titles are not, and we don't need them).
    func refresh() {
        if ownersNeedRefresh {
            ownersNeedRefresh = false
            refreshAppWindowOwners()
        }
        guard let list = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID)
                as? [[String: Any]] else { return }
        windows = list.compactMap { info in
            guard (info[kCGWindowLayer as String] as? Int) == 0,
                  let owner = info[kCGWindowOwnerPID as String] as? Int,
                  owner != ownPID, appWindowOwners.contains(owner),
                  let id = info[kCGWindowNumber as String] as? Int,
                  let boundsDict = info[kCGWindowBounds as String] as? NSDictionary,
                  let r = CGRect(dictionaryRepresentation: boundsDict as CFDictionary),
                  r.width >= 80, r.height >= 40 else { return nil }
            if let alpha = info[kCGWindowAlpha as String] as? Double, alpha < 0.1 { return nil }
            return WindowInfo(id: id, ownerPID: owner, frame: ScreenGeometry.cocoaRect(fromTopLeft: r))
        }
    }

    /// Only regular, unhidden apps have windows worth standing on. Background helpers often own
    /// invisible windows that would otherwise act as invisible platforms and walls.
    private func refreshAppWindowOwners() {
        appWindowOwners = Set(NSWorkspace.shared.runningApplications
            .filter { $0.activationPolicy == .regular && !$0.isHidden }
            .map { Int($0.processIdentifier) })
    }

    // MARK: - Windows

    func frame(ofWindow id: Int) -> CGRect? {
        windows.first { $0.id == id }?.frame
    }

    /// The current frame of one window, read directly from the window server. Cheap enough to
    /// call every frame, so things attached to a window keep up while it's being dragged.
    /// nil when the window was closed, minimized or hidden.
    func liveFrame(ofWindow id: Int) -> CGRect? {
        guard let info = (CGWindowListCopyWindowInfo([.optionIncludingWindow], CGWindowID(id)) as? [[String: Any]])?.first,
              (info[kCGWindowIsOnscreen as String] as? Bool) == true,
              let boundsDict = info[kCGWindowBounds as String] as? NSDictionary,
              let r = CGRect(dictionaryRepresentation: boundsDict as CFDictionary) else { return nil }
        let frame = ScreenGeometry.cocoaRect(fromTopLeft: r)
        if let i = windows.firstIndex(where: { $0.id == id }) { windows[i].frame = frame }
        return frame
    }

    /// True if `point` shows window `id` itself, not a window in front of it (or empty space).
    func isVisible(_ point: CGPoint, onWindow id: Int) -> Bool {
        guard let index = windows.firstIndex(where: { $0.id == id }),
              windows[index].frame.contains(point), isOnScreen(point) else { return false }
        return !windows[..<index].contains { $0.frame.contains(point) }
    }

    /// How much (0…1) of a vertical edge of window `id`, between `y0` and `y1`, can actually be seen.
    func edgeVisibility(ofWindow id: Int, leftEdge: Bool, from y0: CGFloat, to y1: CGFloat) -> Double {
        guard let f = frame(ofWindow: id), y1 > y0 else { return 0 }
        let x = leftEdge ? f.minX + 3 : f.maxX - 3 // just inside the edge
        let samples = 16
        let visible = (0..<samples).filter { i in
            isVisible(CGPoint(x: x, y: y0 + (y1 - y0) * (CGFloat(i) + 0.5) / CGFloat(samples)), onWindow: id)
        }.count
        return Double(visible) / Double(samples)
    }

    /// Whether the app owns a window exactly covering a screen: full-screen apps, presentations, videos.
    func hasFullScreenWindow(ownedBy pid: Int) -> Bool {
        windows.contains { w in
            w.ownerPID == pid && screens.contains { s in
                abs(s.frame.minX - w.frame.minX) < 2 && abs(s.frame.minY - w.frame.minY) < 2
                    && abs(s.frame.width - w.frame.width) < 2 && abs(s.frame.height - w.frame.height) < 2
            }
        }
    }

    // MARK: - Ground and screens

    /// The highest surface at `x` that is at or below `feetY`. A screen's floor also counts when the
    /// feet are below it but still on that screen (down where the Dock is): the Dock moved or grew,
    /// or the creature was dropped there, and it should end up standing on top.
    func ground(atX x: CGFloat, below feetY: CGFloat, tolerance: CGFloat = 2) -> Ground? {
        var best: Ground?
        for screen in screens where x >= screen.frame.minX && x < screen.frame.maxX {
            let floor = screen.visibleFrame.minY
            let reachable = floor <= feetY + tolerance || feetY >= screen.frame.minY - 1
            if reachable, floor > (best?.y ?? -.infinity) {
                best = Ground(y: floor, windowID: nil)
            }
        }
        for (i, w) in windows.enumerated() {
            let top = w.frame.maxY
            guard x >= w.frame.minX + 4, x <= w.frame.maxX - 4,
                  top <= feetY + tolerance, top > (best?.y ?? -.infinity) else { continue }
            // Skip edges hidden behind a window that's in front.
            let probe = CGPoint(x: x, y: top + 1)
            if windows[..<i].contains(where: { $0.frame.contains(probe) }) { continue }
            guard isOnScreen(probe) else { continue }
            best = Ground(y: top, windowID: w.id)
        }
        return best
    }

    func isOnScreen(_ p: CGPoint) -> Bool {
        screens.contains { $0.frame.contains(p) }
    }

    func screen(at p: CGPoint) -> NSScreen? {
        screens.first { $0.frame.contains(p) }
    }

    func beyond(_ screen: NSScreen, dir: CGFloat, feetY: CGFloat, height: CGFloat) -> Beyond {
        let boundaryX = dir > 0 ? screen.frame.maxX : screen.frame.minX
        // Screens that touch this side, including one that only meets it at the bottom corner.
        let neighbors = screens.filter { s in
            s != screen && abs((dir > 0 ? s.frame.minX : s.frame.maxX) - boundaryX) < 2
                && s.frame.maxY >= screen.frame.minY - 2 && s.frame.minY < screen.frame.maxY
        }
        if neighbors.contains(where: { $0.frame.minY <= feetY + 2 && $0.frame.maxY > feetY + 2 && $0.visibleFrame.minY <= feetY + 3 }) {
            return .level
        }
        // Climbable: the higher floor must be within this screen's height, with room to stand.
        if let up = neighbors.filter({ $0.visibleFrame.minY > feetY + 3 && $0.visibleFrame.minY < screen.frame.maxY - height * 0.6 })
            .min(by: { $0.visibleFrame.minY < $1.visibleFrame.minY }) {
            return .step(boundaryX: boundaryX, floor: up.visibleFrame.minY)
        }
        if let down = neighbors.filter({ $0.frame.maxY <= feetY + 2 }).max(by: { $0.frame.maxY < $1.frame.maxY }) {
            return .drop(boundaryX: boundaryX, screen: down)
        }
        if neighbors.isEmpty {
            let outermost = dir > 0 ? screens.map(\.frame.maxX).max() : screens.map(\.frame.minX).min()
            if let outermost, abs(outermost - boundaryX) < 2 { return .outerEdge(edgeX: boundaryX) }
        }
        return .wall
    }
}

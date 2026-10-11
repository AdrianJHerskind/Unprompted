import AppKit

/// Whether anyone could be looking at the screens. Nobody can while the displays sleep, the screen
/// is locked, the screen saver runs or someone else is using the Mac (fast user switching), so the
/// assistant stops animating then: macOS keeps drawing windows nobody can see.
@MainActor
final class Audience: NSObject {
    /// Called when `isWatching` changes.
    var onChange: (() -> Void)?
    private(set) var isWatching = true

    private var displaysAsleep = false
    private var screenSaverSince: TimeInterval?
    private var screenLocked = false
    private var switchedOut = false
    private var observers: [NSObjectProtocol] = []

    // Not documented, but posted by macOS for many years and widely relied on.
    private static let lockedName = Notification.Name("com.apple.screenIsLocked")
    private static let unlockedName = Notification.Name("com.apple.screenIsUnlocked")
    private static let screenSaverStartedName = Notification.Name("com.apple.screensaver.didstart")
    private static let screenSaverStoppedName = Notification.Name("com.apple.screensaver.didstop")

    override init() {
        super.init()
        let workspace = NSWorkspace.shared.notificationCenter
        observe(workspace, NSWorkspace.screensDidSleepNotification) { $0.displaysAsleep = true }
        observe(workspace, NSWorkspace.screensDidWakeNotification) { $0.displaysAsleep = false }
        observe(workspace, NSWorkspace.sessionDidResignActiveNotification) { $0.switchedOut = true }
        observe(workspace, NSWorkspace.sessionDidBecomeActiveNotification) { $0.switchedOut = false }
        // Needed right away, even if AppKit holds distributed notifications back while the app is
        // inactive (as it is again after the Settings window was up, say).
        for name in [Self.lockedName, Self.unlockedName, Self.screenSaverStartedName, Self.screenSaverStoppedName] {
            DistributedNotificationCenter.default().addObserver(self, selector: #selector(distributedNotification(_:)),
                                                                name: name, object: nil, suspensionBehavior: .deliverImmediately)
        }
        // It may be started while the screen is locked (from a terminal, say).
        readSession()
        isWatching = watching
    }

    /// A missed notification mustn't freeze it for good, so while nobody is watching this checks
    /// every second (`idle` = seconds since the last input) whether that's still true.
    func recheck(idle: TimeInterval) {
        guard !isWatching else { return }
        displaysAsleep = CGDisplayIsAsleep(CGMainDisplayID()) != 0
        // Input ends the screen saver: any since it started means it's over.
        if let since = screenSaverSince, idle < Self.now - since - 1 { screenSaverSince = nil }
        readSession()
        update()
    }

    private func readSession() {
        guard let session = CGSessionCopyCurrentDictionary() as? [String: Any] else { return }
        screenLocked = session["CGSSessionScreenIsLocked"] as? Bool ?? false
        switchedOut = !(session[kCGSessionOnConsoleKey as String] as? Bool ?? true)
    }

    private var watching: Bool { !displaysAsleep && screenSaverSince == nil && !screenLocked && !switchedOut }

    private func update() {
        guard watching != isWatching else { return }
        isWatching = watching
        onChange?()
    }

    @objc private func distributedNotification(_ notification: Notification) {
        switch notification.name {
        case Self.lockedName: screenLocked = true
        case Self.unlockedName: screenLocked = false
        case Self.screenSaverStartedName: screenSaverSince = Self.now
        case Self.screenSaverStoppedName: screenSaverSince = nil
        default: return
        }
        update()
    }

    private func observe(_ center: NotificationCenter, _ name: Notification.Name, _ change: @escaping @MainActor (Audience) -> Void) {
        let token = center.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self else { return }
                change(self)
                self.update()
            }
        }
        observers.append(token)
    }

    private static var now: TimeInterval { ProcessInfo.processInfo.systemUptime }
}

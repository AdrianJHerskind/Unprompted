import AppKit

/// Decides when the assistant should keep quiet: during calls, while something is full screen,
/// and during quiet hours.
@MainActor
final class QuietMonitor {
    struct State: Equatable {
        var reason: String
        /// Hide completely (rather than just staying silent).
        var hidden: Bool
    }

    private static let callApps: Set<String> = [
        "us.zoom.xos", "com.microsoft.teams", "com.microsoft.teams2", "com.apple.FaceTime",
        "com.cisco.webexmeetingsapp", "com.webex.meetingmanager", "com.cisco.webex.webex",
        "com.skype.skype", "com.gotomeeting.GoToMeetingWinStore", "com.logmein.GoToMeeting",
    ]

    /// Zoom runs a "CptHost" helper only while a meeting (or screen share) is active. Apps starting
    /// and quitting are followed as it happens: asking every running app for its name takes 10-20 ms.
    private var zoomMeetingHelpers: Set<pid_t> = []
    private var appsObservation: NSKeyValueObservation?

    init() {
        appsObservation = NSWorkspace.shared.observe(\.runningApplications, options: [.initial, .old, .new]) { [weak self] _, change in
            // The list only changes on the main thread.
            MainActor.assumeIsolated { self?.runningAppsChanged(change) }
        }
    }

    private func runningAppsChanged(_ change: NSKeyValueObservedChange<[NSRunningApplication]>) {
        if change.kind == .setting { zoomMeetingHelpers.removeAll() }
        for app in change.oldValue ?? [] { zoomMeetingHelpers.remove(app.processIdentifier) }
        for app in change.newValue ?? [] where app.bundleIdentifier == "us.zoom.CptHost" || app.localizedName == "CptHost" {
            zoomMeetingHelpers.insert(app.processIdentifier)
        }
    }

    func evaluate(settings: AppSettings, world: World) -> State? {
        if settings.quietMode != .off, let reason = callOrFullScreen(world: world) {
            return State(reason: reason, hidden: settings.quietMode == .hide)
        }
        if settings.isQuietHour {
            return State(reason: "it's quiet hours", hidden: false)
        }
        return nil
    }

    private func callOrFullScreen(world: World) -> String? {
        let frontmost = NSWorkspace.shared.frontmostApplication
        if let id = frontmost?.bundleIdentifier, Self.callApps.contains(id) { return "you're on a call" }
        if !zoomMeetingHelpers.isEmpty { return "you're in a Zoom meeting" }
        if let pid = frontmost?.processIdentifier, pid != ProcessInfo.processInfo.processIdentifier,
           world.hasFullScreenWindow(ownedBy: Int(pid)) {
            return "something is full screen"
        }
        return nil
    }
}

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

    private var inZoomMeeting = false
    private var lastZoomCheck = Date.distantPast

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
        // Zoom runs a "CptHost" helper only while a meeting (or screen share) is active. Scanning
        // every running app is relatively slow, so it's checked every few seconds.
        if Date().timeIntervalSince(lastZoomCheck) > 5 {
            lastZoomCheck = Date()
            inZoomMeeting = NSWorkspace.shared.runningApplications.contains {
                $0.bundleIdentifier == "us.zoom.CptHost" || $0.localizedName == "CptHost"
            }
        }
        if inZoomMeeting { return "you're in a Zoom meeting" }
        if let pid = frontmost?.processIdentifier, pid != ProcessInfo.processInfo.processIdentifier,
           world.hasFullScreenWindow(ownedBy: Int(pid)) {
            return "something is full screen"
        }
        return nil
    }
}

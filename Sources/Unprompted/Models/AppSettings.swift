import Combine
import Foundation

/// What to do while you're in a call or something is full screen.
enum QuietMode: String, CaseIterable {
    case hide, silent, off

    var title: String {
        switch self {
        case .hide: return "Hide completely"
        case .silent: return "Stay, but be quiet"
        case .off: return "Do nothing special"
        }
    }
}

/// Every user preference, persisted in UserDefaults. The menus and the Settings window write here;
/// the assistant observes `objectWillChange` and applies changes.
@MainActor
final class AppSettings: ObservableObject {
    static let shared = AppSettings()
    private let defaults = UserDefaults.standard

    @Published var characterID: String { didSet { defaults.set(characterID, forKey: "character") } }
    @Published var annoyance: Annoyance { didSet { defaults.set(annoyance.rawValue, forKey: "annoyance") } }
    /// "auto" (seasonal), "none", or a `Costume` raw value.
    @Published var costume: String { didSet { defaults.set(costume, forKey: "costume") } }
    /// "" = each character's own gait, otherwise a `MovementStyle` raw value.
    @Published var movement: String { didSet { defaults.set(movement, forKey: "movement") } }
    /// 0.5…1.8, 1 = normal.
    @Published var size: Double { didSet { defaults.set(size, forKey: "size") } }
    /// 0.5…2, 1 = normal.
    @Published var speed: Double { didSet { defaults.set(speed, forKey: "speed") } }

    @Published var unpromptedRemarks: Bool { didSet { defaults.set(unpromptedRemarks, forKey: "unpromptedRemarks") } }
    @Published var appRemarks: Bool { didSet { defaults.set(appRemarks, forKey: "appRemarks") } }
    @Published var typingRemarks: Bool { didSet { defaults.set(typingRemarks, forKey: "typingRemarks") } }
    @Published var clippyButtons: Bool { didSet { defaults.set(clippyButtons, forKey: "clippyButtons") } }
    @Published var interns: Bool { didSet { defaults.set(interns, forKey: "interns") } }
    @Published var stickyNotes: Bool { didSet { defaults.set(stickyNotes, forKey: "stickyNotes") } }
    @Published var dayNight: Bool { didSet { defaults.set(dayNight, forKey: "dayNight") } }
    @Published var sounds: Bool { didSet { defaults.set(sounds, forKey: "sounds") } }
    @Published var eveningReport: Bool { didSet { defaults.set(eveningReport, forKey: "eveningReport") } }
    /// Aim for the real Trash in the Dock (needs Accessibility permission) instead of its own trash can.
    @Published var useDockTrash: Bool { didSet { defaults.set(useDockTrash, forKey: "useDockTrash") } }

    @Published var quietMode: QuietMode { didSet { defaults.set(quietMode.rawValue, forKey: "quietMode") } }
    @Published var quietHours: Bool { didSet { defaults.set(quietHours, forKey: "quietHours") } }
    /// Hours of the day, 0…23. Quiet from `quietStart` until `quietEnd` (may wrap past midnight).
    @Published var quietStart: Int { didSet { defaults.set(quietStart, forKey: "quietStart") } }
    @Published var quietEnd: Int { didSet { defaults.set(quietEnd, forKey: "quietEnd") } }

    private init() {
        let d = UserDefaults.standard
        func bool(_ key: String, _ fallback: Bool) -> Bool { d.object(forKey: key) as? Bool ?? fallback }
        characterID = d.string(forKey: "character") ?? "sparkle"
        annoyance = Annoyance(rawValue: d.string(forKey: "annoyance") ?? "") ?? .eager
        costume = d.string(forKey: "costume") ?? "auto"
        movement = d.string(forKey: "movement") ?? ""
        size = d.object(forKey: "size") as? Double ?? 1
        speed = d.object(forKey: "speed") as? Double ?? 1
        unpromptedRemarks = bool("unpromptedRemarks", true)
        appRemarks = bool("appRemarks", true)
        typingRemarks = bool("typingRemarks", true)
        clippyButtons = bool("clippyButtons", true)
        interns = bool("interns", true)
        stickyNotes = bool("stickyNotes", true)
        dayNight = bool("dayNight", true)
        sounds = bool("sounds", true)
        eveningReport = bool("eveningReport", true)
        useDockTrash = bool("useDockTrash", false)
        quietMode = QuietMode(rawValue: d.string(forKey: "quietMode") ?? "") ?? .hide
        quietHours = bool("quietHours", false)
        quietStart = d.object(forKey: "quietStart") as? Int ?? 22
        quietEnd = d.object(forKey: "quietEnd") as? Int ?? 8
    }

    var movementOverride: MovementStyle? { MovementStyle(rawValue: movement) }

    var isQuietHour: Bool {
        guard quietHours else { return false }
        let hour = Calendar.current.component(.hour, from: Date())
        return quietStart <= quietEnd ? (quietStart..<quietEnd).contains(hour)
                                      : hour >= quietStart || hour < quietEnd
    }
}

import Foundation

/// How the assistant feels about you, 0…100. Goes up when you're nice to it, down when you're
/// not, and slowly drifts back toward neutral.
struct Mood {
    private(set) var value: Double

    private static let key = "mood"

    static func load() -> Mood {
        Mood(value: UserDefaults.standard.object(forKey: key) as? Double ?? 60)
    }

    func save() {
        UserDefaults.standard.set(value, forKey: Self.key)
    }

    mutating func adjust(by delta: Double) {
        value = min(100, max(0, value + delta))
    }

    /// Called once a minute.
    mutating func driftTowardNeutral() {
        value += (50 - value) * 0.02
    }

    /// 0…1. Happier assistants play more.
    var playfulness: Double { value / 100 }
    var isElated: Bool { value > 80 }
    var isMiserable: Bool { value < 20 }

    var label: String {
        switch value {
        case 80...: return "🤩 Ecstatic"
        case 60..<80: return "😊 Happy"
        case 40..<60: return "🙂 Fine"
        case 20..<40: return "😕 Meh"
        default: return "😢 Sad"
        }
    }

    var emoji: String { String(label.prefix(1)) }

    /// Five segments, e.g. "▰▰▰▱▱".
    var bar: String {
        let filled = Int((value / 20).rounded())
        return String(repeating: "▰", count: filled) + String(repeating: "▱", count: 5 - filled)
    }
}

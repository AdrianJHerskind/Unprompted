import Foundation

/// How eager the assistant is to "help". Drives how often it speaks up, interrupts and hires interns.
enum Annoyance: String, CaseIterable {
    case polite, eager, clingy, unhinged

    var title: String {
        switch self {
        case .polite: return "Polite (rarely speaks)"
        case .eager: return "Eager"
        case .clingy: return "Clingy"
        case .unhinged: return "Unhinged"
        }
    }

    /// Seconds between unprompted remarks.
    var remarkInterval: ClosedRange<TimeInterval> {
        switch self {
        case .polite: return 600...1200
        case .eager: return 150...300
        case .clingy: return 50...110
        case .unhinged: return 12...30
        }
    }

    /// Chance of commenting when you switch apps.
    var appReactChance: Double {
        switch self {
        case .polite: return 0.08
        case .eager: return 0.3
        case .clingy: return 0.6
        case .unhinged: return 1
        }
    }

    /// Seconds of continuous typing before it "helpfully" interrupts. nil = never.
    var typingThreshold: TimeInterval? {
        switch self {
        case .polite: return nil
        case .eager: return 90
        case .clingy: return 45
        case .unhinged: return 15
        }
    }

    /// Seconds of being ignored (while you're at the computer) before it hires an intern. nil = never.
    var ignoreThreshold: TimeInterval? {
        switch self {
        case .polite: return nil
        case .eager: return 30 * 60
        case .clingy: return 15 * 60
        case .unhinged: return 4 * 60
        }
    }

    var maxInterns: Int { self == .unhinged ? 2 : 1 }

    /// Seconds between sticky notes.
    var noteInterval: ClosedRange<TimeInterval> {
        switch self {
        case .polite: return 120 * 60...240 * 60
        case .eager: return 60 * 60...120 * 60
        case .clingy: return 30 * 60...60 * 60
        case .unhinged: return 10 * 60...20 * 60
        }
    }
}

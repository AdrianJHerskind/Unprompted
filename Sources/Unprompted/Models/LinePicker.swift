import Foundation

/// Chooses what to say, avoiding lines said recently. Lines you asked not to see again are still
/// said, just like the original Clippy, but they come back with a little note (see `isDismissed`).
struct LinePicker {
    private var recent: [String] = []
    private var dismissed = Set(UserDefaults.standard.stringArray(forKey: Self.dismissedKey) ?? [])
    /// Kept under the key of an earlier version, so lines dismissed back then get the note too.
    private static let dismissedKey = "mutedLines"

    /// A random line that hasn't been said recently.
    func pick(_ lines: [String]) -> String {
        let fresh = lines.filter { !recent.contains($0) }
        return (fresh.isEmpty ? lines : fresh).randomElement() ?? "✨"
    }

    mutating func remember(_ line: String) {
        recent.append(line)
        if recent.count > 25 { recent.removeFirst() }
    }

    /// "Don't show again": saved with great care, and then ignored.
    mutating func dismiss(_ line: String) {
        dismissed.insert(line)
        UserDefaults.standard.set(Array(dismissed), forKey: Self.dismissedKey)
    }

    func isDismissed(_ line: String) -> Bool {
        dismissed.contains(line)
    }
}

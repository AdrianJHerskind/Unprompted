import Foundation

/// Chooses what to say: avoids repeating recent lines and skips lines muted with "Don't show again".
struct LinePicker {
    private var recent: [String] = []
    private var muted = Set(UserDefaults.standard.stringArray(forKey: Self.mutedKey) ?? [])
    private static let mutedKey = "mutedLines"

    /// A random line that hasn't been said recently.
    func pick(_ lines: [String]) -> String {
        let allowed = lines.filter { !muted.contains($0) }
        let pool = allowed.isEmpty ? lines : allowed
        let fresh = pool.filter { !recent.contains($0) }
        return (fresh.isEmpty ? pool : fresh).randomElement() ?? "✨"
    }

    mutating func remember(_ line: String) {
        recent.append(line)
        if recent.count > 25 { recent.removeFirst() }
    }

    mutating func mute(_ line: String) {
        muted.insert(line)
        UserDefaults.standard.set(Array(muted), forKey: Self.mutedKey)
    }
}

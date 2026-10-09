import AppKit

/// One day's worth of honest numbers for the "AI-generated" daily report.
struct DayStats: Codable {
    var day: String
    var activeSeconds = 0
    var keystrokes = 0
    var appSwitches = 0
    /// Seconds each app was in front while you were active, keyed by app name.
    var appSeconds: [String: Int] = [:]

    var pets = 0
    var pickups = 0
    var throwsCount = 0
    var fetches = 0
    var trashed = 0
    var goAways = 0
    var dismissals = 0
    var files = 0
    var questions = 0
    var rewrites = 0
    var remarks = 0
    var notes = 0

    init(day: String) {
        self.day = day
    }

    /// Counters added in later versions are missing from older saved days, so every field is optional
    /// when reading (the synthesized decoder would reject the whole day instead).
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        func count(_ key: CodingKeys) throws -> Int { try c.decodeIfPresent(Int.self, forKey: key) ?? 0 }
        day = try c.decode(String.self, forKey: .day)
        activeSeconds = try count(.activeSeconds)
        keystrokes = try count(.keystrokes)
        appSwitches = try count(.appSwitches)
        appSeconds = try c.decodeIfPresent([String: Int].self, forKey: .appSeconds) ?? [:]
        pets = try count(.pets)
        pickups = try count(.pickups)
        throwsCount = try count(.throwsCount)
        fetches = try count(.fetches)
        trashed = try count(.trashed)
        goAways = try count(.goAways)
        dismissals = try count(.dismissals)
        files = try count(.files)
        questions = try count(.questions)
        rewrites = try count(.rewrites)
        remarks = try count(.remarks)
        notes = try count(.notes)
    }

    /// Most-used apps first (ties alphabetically, so the order is stable).
    var topApps: [(name: String, seconds: Int)] {
        appSeconds.sorted { $0.value != $1.value ? $0.value > $1.value : $0.key < $1.key }.map { ($0.key, $0.value) }
    }
}

/// Counts things through the day and keeps a week of history in UserDefaults.
@MainActor
final class StatsTracker {
    private(set) var today: DayStats
    private var lastKeyCount: UInt32?
    private var unsaved = 0
    private static let keyPrefix = "stats-"
    private static let dayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    static func dayKey(_ date: Date = Date()) -> String {
        dayFormatter.string(from: date)
    }

    init() {
        today = Self.load(Self.dayKey()) ?? DayStats(day: Self.dayKey())
    }

    static func load(_ day: String) -> DayStats? {
        guard let data = UserDefaults.standard.data(forKey: keyPrefix + day) else { return nil }
        return try? JSONDecoder().decode(DayStats.self, from: data)
    }

    func stats(daysAgo: Int) -> DayStats? {
        if daysAgo == 0 { return today }
        guard let date = Calendar.current.date(byAdding: .day, value: -daysAgo, to: Date()) else { return nil }
        return Self.load(Self.dayKey(date))
    }

    /// Call once a second.
    func tick(idle: TimeInterval) {
        rollOverIfNeeded()
        if idle < 60 {
            today.activeSeconds += 1
            if let app = NSWorkspace.shared.frontmostApplication,
               app.processIdentifier != ProcessInfo.processInfo.processIdentifier,
               let name = app.localizedName {
                today.appSeconds[name, default: 0] += 1
            }
        }
        let keys = SystemInfo.keyPressCount()
        if let last = lastKeyCount {
            today.keystrokes += Int(keys >= last ? keys - last : keys) // the counter resets at login
        }
        lastKeyCount = keys
        unsaved += 1
        if unsaved >= 30 { save() }
    }

    func record(_ counter: WritableKeyPath<DayStats, Int>) {
        rollOverIfNeeded()
        today[keyPath: counter] += 1
        unsaved += 1
    }

    func save() {
        unsaved = 0
        if let data = try? JSONEncoder().encode(today) {
            UserDefaults.standard.set(data, forKey: Self.keyPrefix + today.day)
        }
    }

    private func rollOverIfNeeded() {
        let key = Self.dayKey()
        guard key != today.day else { return }
        save()
        today = DayStats(day: key)
        // Keep a week of history.
        if let old = Calendar.current.date(byAdding: .day, value: -8, to: Date()) {
            UserDefaults.standard.removeObject(forKey: Self.keyPrefix + Self.dayKey(old))
        }
    }
}

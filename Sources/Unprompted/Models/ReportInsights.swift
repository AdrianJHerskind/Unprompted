import Foundation

/// Turns a day's numbers into "AI insights": real stats, confident commentary.
enum ReportInsights {
    static func duration(_ seconds: Int) -> String {
        let h = seconds / 3600, m = seconds / 60 % 60
        return h > 0 ? "\(h) h \(m) min" : "\(m) min"
    }

    static func number(_ n: Int) -> String {
        NumberFormatter.localizedString(from: NSNumber(value: n), number: .decimal)
    }

    private static func plural(_ n: Int, _ word: String) -> String {
        "\(n) \(word)\(n == 1 ? "" : "s")"
    }

    static func insights(for s: DayStats) -> [String] {
        var lines: [String] = []
        let words = s.keystrokes / 5
        if s.activeSeconds < 30 * 60 {
            lines.append("Quiet day! Either very relaxing, or you used another computer. I'm not jealous.")
        }
        if words > 200 {
            lines.append("You typed about \(number(words)) words. That's \(max(1, words / 300)) pages of a novel, or one very long chat thread.")
        }
        if let top = s.topApps.first, s.activeSeconds > 0 {
            let share = Int(Double(top.seconds) / Double(s.activeSeconds) * 100)
            lines.append("\(top.name) was the main character today: \(duration(top.seconds)), \(share)% of your active time.")
        }
        if s.appSwitches > 150 {
            lines.append("You switched apps \(number(s.appSwitches)) times. Focus is a myth anyway.")
        } else if s.appSwitches > 0 && s.activeSeconds > 3600 && s.appSwitches < 20 {
            lines.append("Only \(s.appSwitches) app switches. Deep focus detected. Impressive. Suspicious, even.")
        }
        if s.activeSeconds > 8 * 3600 {
            lines.append("Over 8 hours at the computer. Please go outside. It's free.")
        }
        if s.pets >= 10 {
            lines.append("You petted me \(s.pets) times. I'm putting that on my CV.")
        } else if s.pets == 0 && s.activeSeconds > 3600 {
            lines.append("Zero pets today. I'm fine. Totally fine. 🥺")
        }
        if s.trashed > 0 {
            lines.append("You threw me in the trash \(plural(s.trashed, "time")). I've forgiven you. Mostly.")
        }
        if s.goAways > 0 {
            lines.append("You told me to go away \(plural(s.goAways, "time")). Noted. Forever.")
        }
        if s.questions > 0 {
            lines.append("You asked me \(plural(s.questions, "question")). I answered every single one. Correctness was not measured.")
        }
        if s.files > 0 {
            lines.append("I summarized \(plural(s.files, "file")) for you. That's \(s.files) more than you asked a human to.")
        }
        if s.rewrites > 0 {
            lines.append("I rewrote your clipboard \(plural(s.rewrites, "time")). Your writing is now 400% more engaging.")
        }
        if s.notes > 0 {
            lines.append("I left you \(plural(s.notes, "sticky note")). You're welcome. Again.")
        }
        if s.remarks >= 10 {
            lines.append("I made \(s.remarks) helpful remarks without being asked. Pure initiative.")
        }
        if lines.count < 3 {
            lines.append("Based on careful analysis, today was a day. Possibly the best one so far this week.")
        }
        return Array(lines.prefix(5))
    }

    /// 1…5 stars, based on how nice you were to the assistant. Obviously the most important metric.
    static func rating(for s: DayStats) -> Int {
        let niceness = s.pets * 2 + s.questions + s.files * 2 + s.fetches - s.trashed * 3 - s.goAways * 2 - s.dismissals
        return min(5, max(1, 3 + niceness / 6))
    }
}

import AppKit

/// What it says and when: unprompted remarks, Clippy-style questions, the evening report offer
/// and sticky notes.
extension Assistant {
    /// Free to start talking on its own: on the screen (and someone can see it), awake, in a good
    /// mood, not busy, and not asked to be quiet.
    var canTalk: Bool {
        !isHidden && audience.isWatching && quiet == nil && creature.isVisible && !bubble.isShowing && !chat.isOpen
            && !creature.isSleeping && !creature.isSulking && !creature.isDragging && !creature.isDying
    }

    /// `force` is for replies to something you did: they may interrupt and are said even in quiet
    /// mode. Anything else is only said when it `canTalk`. `sticky` lines stay until clicked away.
    func say(_ line: String, think: Bool = false, force: Bool = false, sticky: Bool = false) {
        guard !line.isEmpty, mayTalk(force: force) else { return }
        if creature.isSleeping { creature.wake() }
        lines.remember(line)
        bubble.say(fill(line), think: think, near: creature.bodyFrame, sticky: sticky)
    }

    /// Whether a line may be shown now: never while it's hidden or being deleted.
    private func mayTalk(force: Bool) -> Bool {
        !isHidden && !creature.isDying && (force || canTalk)
    }

    /// A random line that hasn't been said recently.
    func pick(_ options: [String]) -> String {
        lines.pick(options)
    }

    private static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.timeStyle = .short
        return f
    }()

    private func fill(_ line: String) -> String {
        var s = line.replacingOccurrences(of: "{name}", with: creature.pack.name)
        if s.contains("{time}") {
            s = s.replacingOccurrences(of: "{time}", with: Self.timeFormatter.string(from: Date()))
        }
        if s.contains("{battery}") {
            s = s.replacingOccurrences(of: "{battery}", with: "\(SystemInfo.battery()?.percent ?? 0)")
        }
        return s
    }

    func scheduleNextRemark() {
        nextRemarkAt = Date() + .random(in: settings.annoyance.remarkInterval)
    }

    /// Something relevant to the current app or time, a "fact", or generic chatter.
    func sayContextual(force: Bool = false) {
        let roll = Double.random(in: 0..<1)
        if isNight && roll < 0.3 { return say(pick(Quips.yawn), force: force) }
        if isMorning && roll < 0.25 { return say(pick(Quips.morning), force: force) }
        if roll < 0.35, let app = NSWorkspace.shared.frontmostApplication, app.processIdentifier != ownPID {
            let lines = Quips.forApp(name: app.localizedName ?? "", bundleID: app.bundleIdentifier ?? "")
            if !lines.isEmpty { return sayOrAsk(pick(lines), force: force) }
        }
        if roll < 0.5 {
            let lines = Quips.forTime(Date())
            if !lines.isEmpty { return say(pick(lines), force: force) }
        }
        if roll < 0.65 {
            return say(pick(Quips.facts), think: true, force: force)
        }
        // Character-specific lines get double weight.
        sayOrAsk(pick(Quips.generic + creature.pack.quips + creature.pack.quips), force: force)
    }

    /// "Say Something" from the menu.
    func saySomething() {
        comeForward()
        guard !cheerUpIfSulking() else { return }
        sayContextual(force: true)
    }

    /// Mood shows: very happy ones play, very sad ones mope.
    func showMood() {
        guard canTalk else { return }
        if mood.isElated, Double.random(in: 0..<1) < 0.2 {
            creature.beHappy(for: 2)
            creature.jump()
            effects.hearts(at: creature.headTop)
        } else if mood.isMiserable, Double.random(in: 0..<1) < 0.15 {
            say(pick(Quips.lonely))
            creature.sulk(for: 20)
        }
    }

    /// Two dismissals in quick succession and it sulks.
    func userDismissedBubble() {
        changeMood(by: -3)
        stats.record(\.dismissals)
        let now = Date()
        dismissals = dismissals.filter { now.timeIntervalSince($0) < 90 } + [now]
        nextRemarkAt = max(nextRemarkAt, now + 60)
        guard dismissals.count >= 2 else { return }
        dismissals.removeAll()
        creature.sulk(for: 45)
        after(0.4) { [weak self] in
            guard let self else { return }
            self.say(self.pick(Quips.sulk), force: true)
        }
    }

    // MARK: - Clippy buttons

    /// Questions sometimes come with [Yes] [No] [Don't show again], Clippy style.
    func sayOrAsk(_ line: String, force: Bool = false) {
        guard settings.clippyButtons, line.hasSuffix("?"), Double.random(in: 0..<1) < 0.6 else {
            return say(line, force: force)
        }
        guard mayTalk(force: force) else { return }
        if creature.isSleeping { creature.wake() }
        lines.remember(line)
        bubble.say(fill(line), think: false, near: creature.bodyFrame,
                   buttons: ["Yes", "No", "Don't show again"]) { [weak self] choice in
            self?.answeredClippy(choice, line: line)
        }
    }

    private func answeredClippy(_ choice: Int, line: String) {
        noteInteraction()
        switch choice {
        case 0:
            changeMood(by: 1)
            say(pick(Quips.clippyYes), force: true)
        case 1:
            say(pick(Quips.clippyNo), force: true)
        default:
            changeMood(by: -1)
            say("Preference saved! ✅ I won't show that again.", force: true)
            // The classic: it shows it once more anyway… and *then* actually stops.
            after(.random(in: 35...60)) { [weak self] in
                guard let self else { return }
                self.lines.mute(line)
                guard self.canTalk else { return }
                self.bubble.say(self.fill(line) + "\n(Your preference has been saved. ✅)", think: false,
                                near: self.creature.bodyFrame, buttons: ["OK"]) { _ in }
            }
        }
    }

    // MARK: - Daily report

    func showReport() {
        stats.save()
        windows.showReport(stats: stats, name: creature.pack.name, mood: mood)
    }

    /// Once a day, after 17:30 on a day you've actually been working, it offers the report.
    func offerReportIfEvening() {
        let now = Calendar.current.dateComponents([.hour, .minute], from: Date())
        let today = StatsTracker.dayKey()
        guard settings.eveningReport, canTalk, reportOfferedDay != today,
              (now.hour ?? 0) * 60 + (now.minute ?? 0) >= 17 * 60 + 30,
              stats.today.activeSeconds > 1800 else { return }
        reportOfferedDay = today
        bubble.say("Your AI-generated daily report is ready! 📊 Want to see it?", think: true,
                   near: creature.bodyFrame, buttons: ["Show Me", "Later"]) { [weak self] choice in
            guard let self else { return }
            if choice == 0 {
                self.showReport()
            } else {
                self.say("Okay! It's in my menu whenever you're ready. 📊", force: true)
            }
        }
    }

    // MARK: - Sticky notes

    func scheduleNextNote() {
        nextNoteAt = Date() + .random(in: settings.annoyance.noteInterval)
    }

    func leaveNoteIfDue(idle: TimeInterval) {
        guard settings.stickyNotes, quiet == nil, idle < 60, Date() >= nextNoteAt else { return }
        scheduleNextNote()
        guard notes.count < StickyNotes.maxNotes else { return }
        leaveNote()
        if Bool.random() { say(pick(Quips.noteLeft)) }
    }

    /// On request (menu or chat). Works even when automatic notes are turned off.
    func leaveNoteOnRequest() {
        noteInteraction()
        guard notes.count < StickyNotes.maxNotes else {
            return say("Your screen already has \(StickyNotes.maxNotes) of my notes. Read those first! 📝", force: true)
        }
        leaveNote()
        say(pick(Quips.noteLeft), force: true)
    }

    private func leaveNote() {
        notes.add(fill(pick(Quips.stickyNotes)), signature: creature.pack.name, near: creature.frame)
        stats.record(\.notes)
    }
}

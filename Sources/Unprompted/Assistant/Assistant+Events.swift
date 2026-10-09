import AppKit

/// Reactions to what happens to the creature and around it: being picked up, thrown, petted,
/// clicked, fed files, switching apps, and the trash.
extension Assistant {
    func handle(_ event: CreatureEvent) {
        switch event {
        case .pickedUp:
            noteInteraction()
            stats.record(\.pickups)
            if cheerUpIfSulking() { return }
            if Double.random(in: 0..<1) < 0.7 { say(pick(Quips.pickedUp), force: true) }
        case .thrown:
            stats.record(\.throwsCount)
            say(pick(Quips.thrown), force: true)
        case .dropped:
            if Double.random(in: 0..<1) < 0.35 { say(pick(Quips.dropped), force: true) }
        case .landedHard:
            // Its own entrances (start, resurrection, "Come Here") aren't your fault and
            // shouldn't drown out what it's saying.
            guard Date() >= landingGraceUntil else { return }
            changeMood(by: -3)
            after(0.4) { [weak self] in
                guard let self else { return }
                self.say(self.pick(Quips.landedHard), force: true)
            }
        case .clicked(let event):
            noteInteraction()
            changeMood(by: 1)
            cheerUpIfSulking()
            showAssistantMenu(for: event)
        case .fileHover:
            guard Date().timeIntervalSince(lastFileHoverRemark) > 6 else { return }
            lastFileHoverRemark = Date()
            creature.stopSulking()
            say(pick(Quips.fileHover), force: true)
        case .filesDropped(let urls):
            noteInteraction()
            changeMood(by: 3)
            summarize(urls)
        case .petted:
            pet()
        case .fetched:
            stats.record(\.fetches)
            changeMood(by: 4)
            effects.hearts(at: creature.headTop)
            say(pick(Quips.fetched), force: true)
        case .caughtCursor:
            changeMood(by: 2)
            say(pick(Quips.caughtCursor), force: true)
        case .shakenOff:
            changeMood(by: -1)
            say(pick(Quips.shakenOff), force: true)
        case .slipped:
            guard Date().timeIntervalSince(lastHangRemark) > 8 else { return }
            lastHangRemark = Date()
            say(pick(Quips.slipped), force: true)
        // Things it does on its own get remarks only when it's free to chat.
        case .startedHanging:
            guard Date().timeIntervalSince(lastHangRemark) > 20, Double.random(in: 0..<1) < 0.6 else { return }
            lastHangRemark = Date()
            say(pick(Quips.hanging))
        case .wrapped:
            if Double.random(in: 0..<1) < 0.5 { say(pick(Quips.wrapped)) }
        case .climbedUp:
            if Double.random(in: 0..<1) < 0.4 { say(pick(Quips.climbedUp)) }
        case .peeking:
            if Double.random(in: 0..<1) < 0.5 { say(pick(Quips.peeking)) }
        case .died:
            changeMood(by: -8)
            after(2.5) { [weak self] in self?.resurrect() }
        }
    }

    /// Any interaction counts as attention: it resets the "ignored" clock and sends the interns home.
    func noteInteraction() {
        ignoredSeconds = 0
        extendComeForward()
        guard !interns.isEmpty, !isDismissingInterns else { return }
        isDismissingInterns = true
        after(0.8) { [weak self] in
            guard let self else { return }
            self.say(self.pick(Quips.internsDismissed))
            self.after(1.8) { [weak self] in
                self?.removeAllInterns()
                self?.isDismissingInterns = false
            }
        }
    }

    /// Any attention ends a sulk. Returns true if it was sulking (and has now said so).
    @discardableResult
    func cheerUpIfSulking() -> Bool {
        guard creature.isSulking else { return false }
        creature.stopSulking()
        dismissals.removeAll()
        scheduleNextRemark()
        say(pick(Quips.cheerUp), force: true)
        return true
    }

    /// Hearts, a purr, a happy face. Petting also cures sulking. `remark` false when something
    /// else already replied (the chat).
    func pet(remark: Bool = true) {
        noteInteraction()
        stats.record(\.pets)
        changeMood(by: 2)
        if creature.isSulking { creature.stopSulking() }
        effects.hearts(at: creature.headTop)
        if settings.sounds, Date().timeIntervalSince(lastPurr) > 3 {
            lastPurr = Date()
            let purr = NSSound(named: "Purr")
            purr?.volume = 0.4
            purr?.play()
        }
        if remark, !creature.isSleeping, Date().timeIntervalSince(lastPetRemark) > 10 {
            lastPetRemark = Date()
            say(pick(Quips.petted), force: true)
        }
    }

    @objc func appActivated(_ note: Notification) {
        guard let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
              app.processIdentifier != ownPID else { return }
        stats.record(\.appSwitches)
        let lines = Quips.forApp(name: app.localizedName ?? "", bundleID: app.bundleIdentifier ?? "")
        guard settings.appRemarks, !lines.isEmpty, Double.random(in: 0..<1) < settings.annoyance.appReactChance else { return }
        after(1.2) { [weak self] in
            guard let self, NSWorkspace.shared.frontmostApplication == app else { return }
            self.sayOrAsk(self.pick(lines))
        }
    }

    // MARK: - Trash

    /// Shows the trash can while something is carried, and deletes (temporarily) whatever you
    /// throw into it.
    func updateTrash(now: TimeInterval) {
        let creatures = allCreatures
        let carried = creatures.first { $0.isDragging }
        let thrown = creatures.filter { $0.isThrown && !$0.isDying }
        guard let target = trash.update(focus: carried ?? thrown.first, useDockTrash: settings.useDockTrash, now: now) else { return }
        let zone = target.insetBy(dx: -20, dy: -20)
        func isOver(_ c: Creature) -> Bool {
            c.frame.insetBy(dx: c.size.width * 0.15, dy: c.size.height * 0.15).intersects(zone)
        }
        trash.setHighlighted(carried.map(isOver) ?? false)
        for c in thrown where isOver(c) { sendToTrash(c, target: target) }
    }

    private func sendToTrash(_ victim: Creature, target: CGRect) {
        let center = CGPoint(x: target.midX, y: target.midY)
        victim.die(into: center)
        effects.sparkles(at: center)
        trash.hideSoon(now: CACurrentMediaTime())
        if settings.sounds { after(0.7) { [weak self] in self?.trash.playSound() } }
        if victim === creature {
            stats.record(\.trashed)
            bubble.hide()
            chat.close()
        }
    }

    /// Back from the dead, from the top of the screen, with confetti. Waits while it's hidden
    /// (then it comes back when it reappears), and does nothing if something already brought it back.
    func resurrect() {
        guard creature.isDead, !isHidden else { return }
        dropIn()
        let top = creature.center
        effects.sparkles(at: top)
        effects.confetti(at: top)
        // Not forced: if it was brought back to answer something, that answer goes first.
        after(1.2) { [weak self] in
            guard let self else { return }
            self.say(self.pick(Quips.resurrected))
        }
    }
}

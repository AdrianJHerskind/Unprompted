import AppKit

/// A smaller copy that shows up when the main one feels ignored.
struct Intern {
    static let scale: CGFloat = 0.6

    let creature: Creature
    let bubble: SpeechBubble
    var nextRemark: Date
}

/// Interns: hired when you ignore the assistant for too long, sent home when you pay attention.
extension Assistant {
    func updateInterns(idle: TimeInterval) {
        // Being ignored (while you're actually at the computer) leads to... hiring help.
        if idle < 60 && !creature.isDying { ignoredSeconds += 1 }
        if settings.interns, let threshold = settings.annoyance.ignoreThreshold,
           interns.count < settings.annoyance.maxInterns,
           ignoredSeconds > threshold * (1 + Double(interns.count) * 0.5), canTalk {
            hireIntern()
        }
        for i in interns.indices where Date() >= interns[i].nextRemark {
            interns[i].nextRemark = Date() + .random(in: 40...90)
            if !interns[i].bubble.isShowing { internSay(pick(Quips.internChatter), interns[i]) }
        }
    }

    private func hireIntern() {
        ignoredSeconds = 0
        let mini = Creature(pack: creature.pack, world: world, scale: CGFloat(settings.size) * Intern.scale)
        mini.movementOverride = settings.movementOverride
        mini.playfulness = 0.8
        mini.onEvent = { [weak self, weak mini] event in
            guard let self, let mini else { return }
            self.handleIntern(event, mini)
        }
        let screen = NSScreen.nearest(to: creature.center)
        let x = creature.frame.midX + (Bool.random() ? 160 : -160)
        mini.drop(at: CGPoint(x: x, y: (screen?.visibleFrame.maxY ?? creature.frame.maxY) - mini.size.height))
        interns.append(Intern(creature: mini, bubble: SpeechBubble(), nextRemark: Date() + 3))
        applyTimeOfDay() // its speed and costume

        effects.sparkles(at: mini.center)
        say(pick(Quips.internHired))
        after(2.5) { [weak self, weak mini] in
            guard let self, let mini, let intern = self.interns.first(where: { $0.creature === mini }) else { return }
            self.internSay(self.pick(Quips.internIntro), intern)
        }
    }

    /// Interns keep quiet when the main one has to, unless they're replying to you (`force`).
    private func internSay(_ line: String, _ intern: Intern, force: Bool = false) {
        guard !isHidden, force || quiet == nil else { return }
        intern.bubble.say(line, think: false, near: intern.creature.bodyFrame)
    }

    private func handleIntern(_ event: CreatureEvent, _ mini: Creature) {
        guard let intern = interns.first(where: { $0.creature === mini }) else { return }
        switch event {
        case .clicked:
            removeIntern(mini, poof: true)
            say(pick(Quips.internPopped), force: true)
        case .pickedUp:
            internSay(pick(Quips.internPickedUp), intern, force: true)
        case .thrown:
            internSay("Is this part of the job?! 😱", intern, force: true)
        case .petted:
            effects.hearts(at: mini.headTop)
        case .filesDropped(let urls):
            summarize(urls)
        case .died:
            removeIntern(mini, poof: false)
            after(0.5) { [weak self] in
                guard let self else { return }
                self.say(self.pick(Quips.internDeleted), force: true)
            }
        default:
            break
        }
    }

    private func removeIntern(_ mini: Creature, poof: Bool) {
        guard let index = interns.firstIndex(where: { $0.creature === mini }) else { return }
        if poof && !isHidden { effects.sparkles(at: mini.center) }
        interns[index].bubble.hide()
        mini.remove()
        interns.remove(at: index)
    }

    func removeAllInterns() {
        for intern in interns { removeIntern(intern.creature, poof: true) }
    }
}

import AppKit

/// Things you ask it to do, from the chat or the menus.
extension Assistant {
    // MARK: - Chat

    func openChat() {
        guard snoozedUntil == nil else { return }
        comeForward()
        noteInteraction()
        creature.stopSulking()
        if creature.isSleeping { creature.wake() }
        chat.open(near: creature.bodyFrame, name: creature.pack.name)
        if !bubble.isShowing { say(pick(Quips.chatOpen), force: true) }
    }

    func answer(_ question: String) {
        noteInteraction()
        changeMood(by: 1)
        stats.record(\.questions)
        let reply = ChatBrain.reply(to: question, name: creature.pack.name, characterID: creature.pack.id,
                                    characterReplies: creature.pack.chatReplies)
        if !reply.text.isEmpty { say(reply.text, think: reply.think, force: true) }
        guard let action = reply.action else { return }
        switch action {
        case .leaveNote:
            leaveNoteOnRequest()
        case .rewrite(let style):
            rewriteClipboard(as: style)
        case .undoRewrite:
            undoRewrite()
        case .remind(let seconds, let message):
            reminders.schedule(after: seconds, message: message)
        case .cancelReminders:
            reminders.cancelAll()
        case .openApp(let url):
            NSWorkspace.shared.openApplication(at: url, configuration: NSWorkspace.OpenConfiguration())
        case .openURL(let url):
            NSWorkspace.shared.open(url)
        case .play:
            chat.close()
            creature.startChase(for: 10)
        case .confetti:
            effects.confetti(at: creature.headTop)
            creature.beHappy(for: 2)
        case .pet:
            pet(remark: false)
        case .sulk:
            changeMood(by: -12)
            chat.close()
            creature.sulk(for: 45)
        case .goAway:
            goAway()
        case .jump:
            creature.jump()
        case .nap:
            nap()
        }
    }

    /// A reminder is due: it shows up wherever it was (snoozing, hidden, in the trash), and the
    /// bubble stays until you've seen it.
    func deliverReminder(_ message: String) {
        // Not over a line that's still being read: a reminder can wait a few seconds.
        afterBubbleIsRead { [weak self] in self?.showReminder(message) }
    }

    private func showReminder(_ message: String) {
        let wasSnoozed = snoozedUntil != nil
        snoozedUntil = nil
        if wasSnoozed || creature.isDying { dropIn() } // even mid-way into the trash
        comeForward()
        creature.stopSulking()
        if creature.isSleeping { creature.wake() }
        if settings.sounds { NSSound(named: "Glass")?.play() }
        creature.jump()
        effects.confetti(at: creature.headTop)
        let text = message.hasPrefix("Time's up") ? "⏰ \(message)" : "⏰ Reminder: \(message)!"
        after(0.3) { [weak self] in self?.say(text, force: true, sticky: true) }
    }

    // MARK: - Files and clipboard

    /// Shows a "Reading…" bubble, works out the stats in the background, then presents them.
    func summarize(_ urls: [URL]) {
        guard !urls.isEmpty, !isHidden else { return }
        stats.record(\.files)
        creature.stopSulking()
        if creature.isSleeping { creature.wake() }
        summaryGeneration += 1
        let generation = summaryGeneration
        let label = urls.count == 1
            ? "📖 Reading “\(FileSummarizer.shortName(urls[0]))”"
            : "📖 Reading \(urls.count) things"
        bubble.showThinking(label, near: creature.bodyFrame)

        let started = Date()
        Task { [weak self] in
            let summary = await Task.detached(priority: .userInitiated) {
                await FileSummarizer.summarize(urls)
            }.value
            // Take at least a moment, for that authentic "AI is thinking" feel.
            let remaining = 1.8 - Date().timeIntervalSince(started)
            if remaining > 0 { try? await Task.sleep(nanoseconds: UInt64(remaining * 1_000_000_000)) }
            guard let self, generation == self.summaryGeneration else { return }
            self.say(summary, force: true)
        }
    }

    func chooseFileToSummarize() {
        NSApp.activate(ignoringOtherApps: true)
        let panel = NSOpenPanel()
        panel.title = "Feed \(creature.pack.name) a File"
        panel.prompt = "Summarize"
        panel.canChooseFiles = true
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = true
        if panel.runModal() == .OK { summarize(panel.urls) }
    }

    func rewriteClipboard(as style: TextStyle) {
        creature.stopSulking()
        switch rewriter.rewrite(as: style) {
        case .noText:
            say("Your clipboard has no text. Copy some first, then I'll... improve it. ✨", force: true)
        case .unchanged:
            say(style == .cleanUp ? "Already tidy! Nothing to clean up. 🧹"
                                  : "That text was already perfect. I changed nothing. (Rare.)", force: true)
        case .rewritten(let result):
            stats.record(\.rewrites)
            noteInteraction()
            changeMood(by: 1)
            let flat = result.replacingOccurrences(of: "\n", with: " ")
            let preview = flat.count > 90 ? flat.prefix(88) + "…" : flat
            say("✍️ Done! Your clipboard now says:\n“\(preview)”\n\(style.flair) Paste it anywhere.", force: true)
        }
    }

    func undoRewrite() {
        switch rewriter.undo() {
        case .restored:
            say("↩︎ Restored your original text. As if I never helped.", force: true)
        case .nothingToUndo:
            say("Nothing to undo. My conscience is clean. 😇", force: true)
        case .clipboardChanged:
            say("You've copied something new since then, so I'll leave your clipboard alone. 🤐", force: true)
        }
    }

    // MARK: - Coming and going

    /// Drops in from the top of the main screen.
    func dropIn() {
        guard let screen = NSScreen.main ?? world.screens.first else { return }
        landingGraceUntil = Date() + 4
        let x = screen.visibleFrame.midX + .random(in: -200...200)
        creature.drop(at: CGPoint(x: x, y: screen.visibleFrame.maxY - creature.size.height))
        // Staying put, it lands in the middle and then gets out of your way.
        creature.headsForCorner = settings.wandering == .still
    }

    /// "Come Here": drops in right by the cursor.
    func summon() {
        let m = NSEvent.mouseLocation
        landingGraceUntil = Date() + 4
        creature.drop(at: CGPoint(x: m.x, y: m.y + 20))
        creature.headsForCorner = false // you called it here
        comeForward()
        noteInteraction()
        creature.stopSulking()
        after(0.9) { [weak self] in
            guard let self else { return }
            self.say(self.pick(Quips.summon), force: true)
        }
    }

    func snooze() {
        say(pick(Quips.snoozeBye), force: true)
        after(2.5) { [weak self] in
            guard let self else { return }
            self.snoozedUntil = Date() + 3600
            self.updatePresence()
        }
    }

    /// `asked`: "Wake Up Now" from the menu, rather than the hour being up.
    func unsnooze(asked: Bool) {
        snoozedUntil = nil
        dropIn()
        if asked { comeForward() } else { updatePresence() }
        scheduleNextRemark()
        after(1.8) { [weak self] in
            guard let self else { return }
            self.say(self.pick(Quips.snoozeBack), force: asked)
        }
    }

    func nap() {
        chat.close()
        say(pick(Quips.nap), force: true)
        after(2.5) { [weak self] in self?.creature.sleep(for: 600) }
    }

    func goAway() {
        stats.record(\.goAways)
        changeMood(by: -8)
        chat.close()
        say(pick(Quips.goAway), force: true)
        creature.sulk(for: 60)
        nextRemarkAt = Date() + 300
    }

    // MARK: - Characters

    func switchTo(_ pack: CharacterPack) {
        removeAllInterns()
        creature.setPack(pack)
        settings.characterID = pack.id
        say(pick(Quips.newLook), force: true)
    }

    func reloadCharacters() {
        packs = CharacterLibrary.loadAll()
        // Swap in the freshly loaded copy so edits to the current character show up.
        let current = packs.first { $0.id == creature.pack.id } ?? packs[0]
        creature.setPack(current)
        say("Reloaded! I now come in \(packs.count) flavors. ✨", force: true)
    }

    func showSettings() {
        windows.showSettings(characters: packs)
    }
}

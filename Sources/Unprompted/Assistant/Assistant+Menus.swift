import AppKit
import ServiceManagement

/// The menu you get by clicking the creature, and the one in the menu bar.
extension Assistant {
    func showAssistantMenu(for event: NSEvent) {
        let menu = NSMenu()
        menu.autoenablesItems = false
        menu.addLabel("\(creature.pack.name) · How can I help? \(mood.emoji)")
        menu.addItem(.separator())
        // Things that actually do something…
        menu.addAction("💬 Ask Me Anything…") { [weak self] in self?.openChat() }
        menu.addSubmenu("✍️ Rewrite Clipboard", rewriteMenu())
        menu.addAction("📄 Summarize a File…") { [weak self] in self?.chooseFileToSummarize() }
        menu.addAction("📊 My Daily Report") { [weak self] in self?.showReport() }
        menu.addAction("📝 Leave Me a Note") { [weak self] in self?.leaveNoteOnRequest() }

        // …and the "AI features" nobody asked for.
        let features = NSMenu()
        for option in Quips.menuOptions {
            features.addAction(option.title) { [weak self] in
                guard let self else { return }
                self.say(self.pick(option.replies), think: option.think, force: true)
            }
        }
        menu.addSubmenu("✨ AI Features", features)
        menu.addItem(.separator())
        menu.addAction("🎾 Let's Play!") { [weak self] in
            guard let self else { return }
            self.creature.startChase(for: 10)
            self.say(self.pick(Quips.playTime), force: true)
        }
        menu.addAction("💤 Take a Nap") { [weak self] in self?.nap() }
        menu.addAction("🙄 Go Away") { [weak self] in self?.goAway() }
        menu.addSubmenu("🎭 Change My Look", characterMenu())
        creature.popUp(menu, for: event)
    }

    /// Rebuilt each time the menu bar menu opens, so checkmarks and status are current.
    func populateStatusMenu(_ menu: NSMenu) {
        let status = snoozedUntil != nil ? "Snoozing"
            : quiet.map { "Quiet, \($0.reason)" + (isHidden ? " (hidden)" : "") } ?? creature.statusDescription
        menu.addLabel("\(creature.pack.name) · Your AI Assistant")
        menu.addLabel("Mood: \(mood.label)  \(mood.bar)")
        menu.addLabel("Status: \(status)")
        menu.addItem(.separator())

        if snoozedUntil != nil {
            menu.addAction("Wake Up Now") { [weak self] in self?.unsnooze(asked: true) }
        } else {
            menu.addAction("Ask Me Anything…") { [weak self] in self?.openChat() }
            menu.addAction("Say Something") { [weak self] in self?.saySomething() }
            menu.addAction("Come Here") { [weak self] in self?.summon() }
            menu.addAction("Snooze for 1 Hour") { [weak self] in self?.snooze() }
        }
        menu.addItem(.separator())

        menu.addSubmenu("Character", characterMenu())
        menu.addSubmenu("Annoyance Level", annoyanceMenu())
        menu.addSubmenu("Movement", movementMenu())
        menu.addSubmenu("Wandering", wanderingMenu())
        menu.addSubmenu("Costume", costumeMenu())
        let dockTrash = menu.addAction("Use Real Dock Trash") { [weak self] in self?.settings.useDockTrash.toggle() }
        // Mixed: switched on, but it can't find the Trash without Accessibility permission.
        dockTrash.state = !settings.useDockTrash ? .off : DockTrashLocator.hasPermission ? .on : .mixed
        menu.addItem(.separator())

        let launch = menu.addAction("Launch at Login") { [weak self] in self?.toggleLaunchAtLogin() }
        switch SMAppService.mainApp.status {
        case .enabled: launch.state = .on
        case .requiresApproval: launch.state = .mixed
        default: launch.state = .off
        }
        menu.addItem(.separator())

        menu.addAction("Reload Characters") { [weak self] in self?.reloadCharacters() }
        menu.addAction("Open Characters Folder…") { NSWorkspace.shared.open(CharacterLibrary.prepareUserFolder()) }
        menu.addItem(.separator())
        menu.addAction("Daily Report…") { [weak self] in self?.showReport() }
        menu.addAction("Settings…", key: ",") { [weak self] in self?.showSettings() }
        menu.addItem(.separator())
        menu.addAction("Quit", key: "q") { NSApp.terminate(nil) }
    }

    // MARK: - Submenus

    private func rewriteMenu() -> NSMenu {
        let menu = NSMenu()
        menu.autoenablesItems = false
        for style in TextStyle.fun {
            menu.addAction(style.menuTitle) { [weak self] in self?.rewriteClipboard(as: style) }
        }
        menu.addItem(.separator())
        for style in TextStyle.utility {
            menu.addAction(style.menuTitle) { [weak self] in self?.rewriteClipboard(as: style) }
        }
        menu.addItem(.separator())
        menu.addAction("↩︎ Undo Last Rewrite", enabled: rewriter.canUndo) { [weak self] in self?.undoRewrite() }
        return menu
    }

    private func characterMenu() -> NSMenu {
        let menu = NSMenu()
        for pack in packs {
            menu.addAction(pack.name, checked: pack.id == creature.pack.id) { [weak self] in self?.switchTo(pack) }
        }
        return menu
    }

    private func annoyanceMenu() -> NSMenu {
        let menu = NSMenu()
        for level in Annoyance.allCases {
            menu.addAction(level.title, checked: level == settings.annoyance) { [weak self] in self?.settings.annoyance = level }
        }
        return menu
    }

    private func movementMenu() -> NSMenu {
        let menu = NSMenu()
        let current = settings.movementOverride
        menu.addAction("Character's Own (\(creature.pack.movement.title))", checked: current == nil) { [weak self] in
            self?.settings.movement = ""
        }
        menu.addItem(.separator())
        for style in MovementStyle.allCases {
            menu.addAction(style.title, checked: current == style) { [weak self] in self?.settings.movement = style.rawValue }
        }
        return menu
    }

    private func wanderingMenu() -> NSMenu {
        let menu = NSMenu()
        for level in Wandering.allCases {
            menu.addAction(level.title, checked: level == settings.wandering) { [weak self] in self?.settings.wandering = level }
        }
        return menu
    }

    private func costumeMenu() -> NSMenu {
        let menu = NSMenu()
        let seasonal = Costume.seasonal().map { " (now: \($0.title))" } ?? " (nothing this month)"
        let options = [("auto", "Seasonal" + seasonal), ("none", "None")] + Costume.allCases.map { ($0.rawValue, $0.title) }
        for (value, title) in options {
            menu.addAction(title, checked: settings.costume == value) { [weak self] in self?.settings.costume = value }
            if value == "none" { menu.addItem(.separator()) }
        }
        return menu
    }

    private func toggleLaunchAtLogin() {
        let service = SMAppService.mainApp
        do {
            if service.status == .enabled {
                try service.unregister()
                say(pick(Quips.launchAtLoginOff), force: true)
            } else {
                try service.register()
                if service.status == .requiresApproval {
                    say("Almost! Please allow me in Login Items. I'll wait. Right here. ✨", force: true)
                    SMAppService.openSystemSettingsLoginItems()
                } else {
                    say(pick(Quips.launchAtLoginOn), force: true)
                }
            }
        } catch {
            NSLog("Launch at login failed: %@", String(describing: error))
            say("I tried to move in at login, but macOS said no. Rude. (\(error.localizedDescription))", force: true)
        }
    }
}

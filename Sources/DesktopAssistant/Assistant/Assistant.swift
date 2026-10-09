import AppKit
import Combine
import QuartzCore

/// The brain: decides when to talk and what to say, based on what you're doing, and owns
/// everything on screen (the creature, its bubble, the chat box, notes, interns, effects).
///
/// This file has the setup, the update loops, presence (snoozing, quiet mode) and settings.
/// Talking, reactions to events, actions, interns and menus are in the Assistant+… files.
@MainActor
final class Assistant: NSObject {
    let settings = AppSettings.shared
    var packs: [CharacterPack]
    let world: World
    let creature: Creature
    let bubble = SpeechBubble()
    let chat = ChatBox()
    let effects = Effects()
    let trash = TrashCan()
    let notes = StickyNotes()
    let windows = WindowPresenter()
    let stats = StatsTracker()
    let reminders = ReminderScheduler()
    let rewriter = ClipboardRewriter()
    private let quietMonitor = QuietMonitor()
    var lines = LinePicker()
    var mood = Mood.load()
    var interns: [Intern] = []

    // MARK: Presence

    /// Set while snoozing ("Snooze for 1 Hour").
    var snoozedUntil: Date?
    /// Set during calls, full-screen apps and quiet hours.
    private(set) var quiet: QuietMonitor.State?
    /// Asking for it (menu, chat, reminders) brings it back for a while, even if quiet mode hid it.
    private var presenceOverrideUntil = Date.distantPast
    /// Off the screen: snoozing, or hidden by quiet mode.
    private(set) var isHidden = false

    // MARK: Timing and bookkeeping

    var nextRemarkAt = Date.distantFuture
    var nextNoteAt = Date.distantFuture
    var ignoredSeconds: TimeInterval = 0
    var isDismissingInterns = false
    var dismissals: [Date] = []
    var lastPurr = Date.distantPast
    var lastPetRemark = Date.distantPast
    var lastHangRemark = Date.distantPast
    var lastFileHoverRemark = Date.distantPast
    /// Hard landings right after it drops itself in don't count.
    var landingGraceUntil = Date.distantPast
    var summaryGeneration = 0
    var reportOfferedDay = UserDefaults.standard.string(forKey: "reportOfferedDay") ?? "" {
        didSet { UserDefaults.standard.set(reportOfferedDay, forKey: "reportOfferedDay") }
    }
    private var typingStreak: TimeInterval = 0
    private var lastBatteryWarning = Date.distantPast
    private(set) var secondsElapsed = 0
    private var lastFrame = CACurrentMediaTime()
    private var timers: [Timer] = []
    private var settingsObserver: AnyCancellable?
    /// The settings that only matter when they change.
    private var applied: (annoyance: Annoyance, stickyNotes: Bool, useDockTrash: Bool)
    let ownPID = ProcessInfo.processInfo.processIdentifier
    private static let debugLogging = ProcessInfo.processInfo.environment["DA_DEBUG"] != nil

    init(packs: [CharacterPack]) {
        self.packs = packs
        let settings = AppSettings.shared
        let world = World()
        self.world = world
        let pack = packs.first { $0.id == settings.characterID } ?? packs[0]
        creature = Creature(pack: pack, world: world, scale: CGFloat(settings.size))
        applied = (settings.annoyance, settings.stickyNotes, settings.useDockTrash)
        super.init()
        creature.playfulness = mood.playfulness
        applySettings()
        settingsObserver = settings.objectWillChange.sink { [weak self] _ in
            // objectWillChange fires before the new value is stored, so apply it on the next turn.
            DispatchQueue.main.async { MainActor.assumeIsolated { self?.applySettings() } }
        }
    }

    func start() {
        creature.onEvent = { [weak self] in self?.handle($0) }
        bubble.onDismiss = { [weak self] in self?.userDismissedBubble() }
        chat.onSubmit = { [weak self] in self?.answer($0) }
        notes.onCrumpled = { [weak self] in self?.noteInteraction() }
        reminders.onDue = { [weak self] in self?.deliverReminder($0) }
        NSWorkspace.shared.notificationCenter.addObserver(
            self, selector: #selector(appActivated(_:)),
            name: NSWorkspace.didActivateApplicationNotification, object: nil)

        repeatEvery(1.0 / 60) { [weak self] in self?.frameTick() }
        repeatEvery(1) { [weak self] in self?.secondTick() }

        updateQuiet()
        updatePresence()
        dropIn()
        after(1.8) { [weak self] in
            guard let self else { return }
            self.say(self.pick(Quips.greeting))
        }
        scheduleNextRemark()
        scheduleNextNote()
    }

    /// Called when the app quits.
    func saveState() {
        stats.save()
        mood.save()
    }

    var allCreatures: [Creature] { [creature] + interns.map(\.creature) }

    // MARK: - Loops

    private func frameTick() {
        let now = CACurrentMediaTime()
        let dt = min(now - lastFrame, 1.0 / 20)
        lastFrame = now
        effects.tick()
        guard !isHidden else { return }
        // A creature asleep on the ground doesn't need to know where windows are (one it's lying
        // on is tracked live), and quiet mode refreshes the list every couple of seconds anyway.
        if !(creature.isSleeping && creature.grounded) || !interns.isEmpty { world.refreshIfNeeded(now: now) }
        // Before moving anything: something released over the trash this frame still counts,
        // even if it lands right away.
        updateTrash(now: now)
        creature.isTalking = bubble.isShowing || chat.isOpen
        creature.tick(dt: dt)
        bubble.tick(dt: dt, anchor: creature.bodyFrame)
        chat.follow(creature.bodyFrame)
        for intern in interns {
            intern.creature.isTalking = intern.bubble.isShowing
            intern.creature.tick(dt: dt)
            intern.bubble.tick(dt: dt, anchor: intern.creature.bodyFrame)
        }
        // Glitter when flying fast.
        effects.trail(at: creature.currentSpeed > 500 ? creature.center : nil)
    }

    private func secondTick() {
        secondsElapsed += 1
        if Self.debugLogging {
            print("[debug] t=\(secondsElapsed) \(creature.debugSummary)")
            fflush(stdout)
        }
        let idle = SystemInfo.secondsSinceAnyInput()
        stats.tick(idle: idle)
        if let until = snoozedUntil, Date() >= until { unsnooze(asked: false) }
        if secondsElapsed % 2 == 0 { updateQuiet() }
        updatePresence()
        guard !isHidden else { return }
        if secondsElapsed % 60 == 0 {
            mood.driftTowardNeutral()
            moodChanged()
            applyTimeOfDay()
        }

        // Fall asleep when you're away (sooner at night), wake up (loudly) when you're back.
        if creature.isSleeping {
            if !creature.isNapping && idle < 1.5 {
                creature.wake()
                after(0.6) { [weak self] in
                    guard let self else { return }
                    self.say(self.pick(Quips.wake))
                }
            }
            return
        }
        // A sticky bubble (a reminder) stays until you've seen it, so no dozing off over it.
        if idle > (isNight ? 60 : 150) && !creature.isDragging && !bubble.isSticky {
            bubble.hide()
            creature.sleep(for: nil)
            return
        }

        // "Helpfully" interrupt long typing sessions (typing to *me* doesn't count).
        typingStreak = SystemInfo.secondsSinceKeyPress() < 1.5 && !chat.isOpen ? typingStreak + 1 : 0
        if settings.typingRemarks, let threshold = settings.annoyance.typingThreshold, typingStreak >= threshold {
            typingStreak = 0
            say(pick(Quips.typing))
        }

        if secondsElapsed % 30 == 0, canTalk, Date().timeIntervalSince(lastBatteryWarning) > 600,
           let battery = SystemInfo.battery(), !battery.charging, battery.percent <= 15 {
            lastBatteryWarning = Date()
            say(pick(Quips.lowBattery))
        }

        if Date() >= nextRemarkAt {
            if canTalk && settings.unpromptedRemarks {
                stats.record(\.remarks)
                sayContextual()
            }
            scheduleNextRemark()
        }

        offerReportIfEvening()
        leaveNoteIfDue(idle: idle)
        updateInterns(idle: idle)
        if secondsElapsed % 30 == 0 { showMood() }
    }

    // MARK: - Presence

    private func updateQuiet() {
        world.refreshIfNeeded(now: CACurrentMediaTime()) // its window list shows full-screen apps
        let next = quietMonitor.evaluate(settings: settings, world: world)
        guard next != quiet else { return }
        let wasHiding = quiet?.hidden == true
        quiet = next
        if next == nil, wasHiding, Double.random(in: 0..<1) < 0.5 {
            after(1.5) { [weak self] in
                guard let self else { return }
                self.say(self.pick(Quips.quietOver))
            }
        }
    }

    /// Takes everything off the screen while snoozing, or (with "Hide completely") during calls and
    /// full-screen apps, and brings it back afterwards. A conversation in progress isn't cut off.
    func updatePresence() {
        let busy = bubble.isShowing || chat.isOpen || allCreatures.contains { $0.isDragging || $0.isThrown }
        let hide = snoozedUntil != nil || (quiet?.hidden == true && Date() >= presenceOverrideUntil && !busy)
        guard hide != isHidden else { return }
        isHidden = hide
        if hide {
            bubble.hide()
            chat.close()
            trash.hide()
            for intern in interns { intern.bubble.hide() }
        } else {
            // It may still be on its way down from dropping in while hidden: not your fault.
            landingGraceUntil = max(landingGraceUntil, Date() + 4)
        }
        for c in allCreatures { c.isHidden = hide }
        notes.setVisible(!hide)
        if !hide && creature.isDead { resurrect() }
    }

    /// You asked for it (menu, chat, reminder): it stays on the screen for a minute even if quiet
    /// mode would hide it, and as long as you keep interacting with it.
    func comeForward() {
        presenceOverrideUntil = Date() + 60
        updatePresence()
    }

    /// While it's on the screen because you asked for it, using it keeps it there.
    func extendComeForward() {
        if Date() < presenceOverrideUntil { presenceOverrideUntil = Date() + 60 }
    }

    // MARK: - Settings

    /// Brings the creature(s) in line with the settings. Runs whenever they change, from any
    /// menu or the Settings window.
    private func applySettings() {
        if creature.pack.id != settings.characterID, let pack = packs.first(where: { $0.id == settings.characterID }) {
            switchTo(pack)
        }
        for c in allCreatures { c.movementOverride = settings.movementOverride }
        creature.setScale(CGFloat(settings.size))
        for intern in interns { intern.creature.setScale(CGFloat(settings.size) * Intern.scale) }
        notes.playsSound = settings.sounds
        applyTimeOfDay()

        if settings.annoyance != applied.annoyance { scheduleNextRemark() }
        // Only when switched off: notes asked for in the chat stay while automatic ones are off.
        if !settings.stickyNotes && applied.stickyNotes { notes.removeAll() }
        if !settings.interns { removeAllInterns() }
        if settings.useDockTrash != applied.useDockTrash { dockTrashChanged() }
        applied = (settings.annoyance, settings.stickyNotes, settings.useDockTrash)
    }

    /// Slower with a nightcap late at night, coffee in the morning, seasonal costumes.
    /// Runs every minute too, to follow the clock.
    func applyTimeOfDay() {
        let speed = CGFloat(settings.speed) * (isNight ? 0.75 : 1)
        let costume = currentCostume
        for c in allCreatures {
            c.speedFactor = speed
            if c.costume != costume { c.costume = costume }
        }
        creature.prop = isMorning ? .coffee : nil
    }

    private func dockTrashChanged() {
        if !settings.useDockTrash {
            say("Back to my own trash can. It's cozier. 🗑️", force: true)
        } else if DockTrashLocator.hasPermission {
            say("Now aiming for your real Dock Trash. Please don't. 🥺", force: true)
        } else {
            DockTrashLocator.requestPermission()
            say("To find the Dock Trash I need Accessibility permission: System Settings → Privacy & Security → Accessibility. Until then, I'll use my own trash can.", force: true)
        }
    }

    var isNight: Bool {
        let hour = Calendar.current.component(.hour, from: Date())
        return settings.dayNight && (hour >= 22 || hour < 5)
    }

    var isMorning: Bool {
        settings.dayNight && (6..<10).contains(Calendar.current.component(.hour, from: Date()))
    }

    private var currentCostume: Costume? {
        switch settings.costume {
        case "auto": return isNight ? .nightcap : Costume.seasonal()
        case "none": return nil
        default: return Costume(rawValue: settings.costume)
        }
    }

    // MARK: - Mood

    func changeMood(by delta: Double) {
        mood.adjust(by: delta)
        moodChanged()
    }

    private func moodChanged() {
        mood.save()
        creature.playfulness = mood.playfulness
    }

    // MARK: - Timers

    private func repeatEvery(_ interval: TimeInterval, _ block: @escaping @MainActor () -> Void) {
        let timer = Timer(timeInterval: interval, repeats: true) { _ in
            MainActor.assumeIsolated { block() }
        }
        // .common keeps the creature animating while menus are open.
        RunLoop.main.add(timer, forMode: .common)
        timers.append(timer)
    }

    func after(_ seconds: TimeInterval, _ block: @escaping @MainActor () -> Void) {
        DispatchQueue.main.asyncAfter(deadline: .now() + seconds) {
            MainActor.assumeIsolated { block() }
        }
    }
}

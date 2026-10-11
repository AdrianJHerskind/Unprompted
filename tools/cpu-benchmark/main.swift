import AppKit

// Measures what one creature costs: hosts a real Creature (its window, physics and layers) on a
// frame loop like the app's, holds it in one pose and reports the CPU used by this process, the
// window server and the window manager. tools/cpu-benchmark.sh builds it together with the app's
// sources and runs it for every character (see "Checking CPU use" in the README).
//
//   cpu-benchmark --character <id> --mode <mode> --seconds <n> [--screen <index>] [--accessories]
//                 [--moving-cursor]
//   cpu-benchmark --list | --screens
//
// Modes: idle, walk (back and forth), talk (with a speech bubble), sleep, or none (no creature:
// the background). The screen index defaults to 0, the main screen. --accessories puts on a party
// hat and a coffee. The cursor seems to stay in the screen's top-left corner, or with
// --moving-cursor, to circle the creature as a real cursor moves about, so the eyes follow it.
// Prints: RESULT <character> <mode> <screen scale> <app %> <app M instructions/s> <WindowServer %>
// <WindowManager %>, with "-" for what it couldn't measure. It fails (exit 3) if the creature
// couldn't be seen for part of the time: it stops drawing then, so the numbers would be wrong.
//
// It's built against the sources of the commit being compared with too (--compare), so it may only
// use what the app had when the benchmark was added.

func fail(_ message: String, code: Int32 = 64) -> Never {
    FileHandle.standardError.write(Data((message + "\n").utf8))
    exit(code)
}

let usage = "usage: cpu-benchmark --character <id> --mode <idle|walk|talk|sleep|none> --seconds <n> [--screen <index>] [--accessories] [--moving-cursor] | --list | --screens"

/// Options with a value, and flags (present or not).
let (options, flags): ([String: String], Set<String>) = {
    var options: [String: String] = [:], flags: Set<String> = []
    var rest = CommandLine.arguments.dropFirst()
    while let arg = rest.popFirst() {
        switch arg {
        case "--character", "--mode", "--seconds", "--screen":
            guard let value = rest.popFirst() else { fail("\(arg) needs a value\n\(usage)") }
            options[arg] = value
        case "--accessories", "--moving-cursor", "--list", "--screens":
            flags.insert(arg)
        default:
            fail("unknown argument \(arg)\n\(usage)")
        }
    }
    return (options, flags)
}()

/// CPU seconds and instructions retired by this process so far. Instructions don't depend on
/// which cores macOS runs it on, or how fast they're clocked, so they compare builds more steadily.
func ownUsage() -> (cpu: Double, instructions: Double?) {
    var usage = rusage_info_v4()
    let ok = withUnsafeMutablePointer(to: &usage) {
        $0.withMemoryRebound(to: rusage_info_t?.self, capacity: 1) { proc_pid_rusage(getpid(), RUSAGE_INFO_V4, $0) }
    } == 0
    var timebase = mach_timebase_info()
    mach_timebase_info(&timebase)
    let ticks = Double(usage.ri_user_time + usage.ri_system_time)
    return (ticks * Double(timebase.numer) / Double(timebase.denom) / 1e9, ok && usage.ri_instructions > 0 ? Double(usage.ri_instructions) : nil)
}

/// The process with this name (and owner, if given).
func process(named name: String, owner: uid_t? = nil) -> pid_t? {
    var pids = [pid_t](repeating: 0, count: 8192)
    let count = Int(proc_listallpids(&pids, Int32(pids.count * MemoryLayout<pid_t>.size)))
    for pid in pids.prefix(max(count, 0)) where pid > 0 {
        var info = proc_bsdshortinfo()
        guard proc_pidinfo(pid, PROC_PIDT_SHORTBSDINFO, 0, &info, Int32(MemoryLayout<proc_bsdshortinfo>.size)) > 0 else { continue }
        let command = withUnsafeBytes(of: info.pbsi_comm) { String(decoding: $0.prefix { $0 != 0 }, as: UTF8.self) }
        if command == name && (owner == nil || info.pbsi_uid == owner) { return pid }
    }
    return nil
}

/// The running `top`. It gets its own process group, so Ctrl-C doesn't reach it: see `passOnSignals`.
nonisolated(unsafe) var runningTop: Process?
nonisolated(unsafe) var signalSources: [DispatchSourceSignal] = []

/// Stops `top` too when this is interrupted, then goes the way the signal says.
func passOnSignals() {
    for number in [SIGINT, SIGTERM] {
        signal(number, SIG_IGN)
        let source = DispatchSource.makeSignalSource(signal: number, queue: .main)
        source.setEventHandler {
            runningTop?.terminate()
            signal(number, SIG_DFL)
            kill(getpid(), number)
        }
        source.resume()
        signalSources.append(source)
    }
}

/// Starts `top`, which can read processes of other users (the window server's), and returns a
/// function that waits for it and gives each process's CPU over the next `seconds`.
func startTop(pids: [pid_t], seconds: Int) -> () -> [pid_t: Double] {
    guard !pids.isEmpty else { return { [:] } }
    let top = Process()
    runningTop = top
    top.executableURL = URL(fileURLWithPath: "/usr/bin/top")
    top.arguments = ["-l", "2", "-s", String(seconds), "-stats", "pid,cpu"] + pids.flatMap { ["-pid", String($0)] }
    let output = Pipe()
    top.standardOutput = output
    guard (try? top.run()) != nil else { return { [:] } }
    return {
        let text = String(decoding: output.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)
        top.waitUntilExit()
        // The second sample, the last table, covers the interval.
        let lines = text.components(separatedBy: "\n")
        guard let header = lines.lastIndex(where: { $0.hasPrefix("PID") }) else { return [:] }
        var cpu: [pid_t: Double] = [:]
        for line in lines[(header + 1)...] {
            let fields = line.split(separator: " ")
            if fields.count == 2, let pid = pid_t(fields[0]), let value = Double(fields[1]) { cpu[pid] = value }
        }
        return cpu
    }
}

/// What the cursor circles with --moving-cursor (the creature's middle), updated every frame.
nonisolated(unsafe) var cursorCircleCenter: CGPoint?

/// Makes the app see a cursor that moves the same way in every run: resting at `point`, or while
/// `cursorCircleCenter` is set, going round it once every 4 s, 300 pt away. On that circle it
/// comes near enough to a sleeper now and then to keep it from dozing, as a real cursor would.
func fakeCursor(restingAt point: CGPoint) {
    guard let method = class_getClassMethod(NSEvent.self, #selector(getter: NSEvent.mouseLocation)) else { return }
    let start = CACurrentMediaTime()
    let location: @convention(block) (AnyObject) -> NSPoint = { _ in
        guard let center = cursorCircleCenter else { return point }
        let angle = (CACurrentMediaTime() - start) / 4 * 2 * .pi
        return CGPoint(x: center.x + 300 * cos(angle), y: center.y + 300 * sin(angle))
    }
    method_setImplementation(method, imp_implementationWithBlock(location))
}

func format(_ value: Double?) -> String { value.map { String(format: "%.1f", $0) } ?? "-" }

MainActor.assumeIsolated {
    if flags.contains("--list") {
        print(CharacterLibrary.loadAll().map(\.id).joined(separator: " "))
        exit(0)
    }
    if flags.contains("--screens") {
        print(NSScreen.screens.count)
        exit(0)
    }
    passOnSignals()
    guard let characterID = options["--character"], let mode = options["--mode"],
          let seconds = options["--seconds"].flatMap({ Int($0) }), seconds > 0 else { fail(usage) }
    guard ["idle", "walk", "talk", "sleep", "none"].contains(mode) else { fail("unknown mode \(mode)") }
    let screenIndex = Int(options["--screen"] ?? "0") ?? -1
    guard NSScreen.screens.indices.contains(screenIndex) else {
        fail("no screen \(options["--screen"] ?? ""): there are \(NSScreen.screens.count)")
    }
    let screen = NSScreen.screens[screenIndex]
    let movingCursor = flags.contains("--moving-cursor")

    let app = NSApplication.shared
    app.setActivationPolicy(.accessory)
    fakeCursor(restingAt: CGPoint(x: screen.visibleFrame.minX + 40, y: screen.visibleFrame.maxY - 40))
    let world = World()
    let bubble = SpeechBubble()
    var creature: Creature?
    if mode != "none" {
        guard let pack = CharacterLibrary.loadAll().first(where: { $0.id == characterID }) else {
            fail("no character \(characterID)", code: 2)
        }
        let c = Creature(pack: pack, world: world, scale: 1)
        if flags.contains("--accessories") {
            c.costume = .party
            c.prop = .coffee
        }
        c.drop(at: CGPoint(x: screen.visibleFrame.midX, y: screen.visibleFrame.minY + 200))
        creature = c
    }
    let systemPIDs = [process(named: "WindowServer"), process(named: "WindowManager", owner: getuid())]

    var last = CACurrentMediaTime()
    let begin = last
    // The first line comes before measuring starts (at 2.5 s): a window that has only just appeared
    // doesn't count as visible yet.
    var nextLine = begin + 1
    var measureStart: (wall: TimeInterval, usage: (cpu: Double, instructions: Double?))?
    var finishTop: (() -> [pid_t: Double])?
    var timer: Timer?
    var interval: TimeInterval = 0
    /// How long the creature's window couldn't be seen while measuring.
    var unseenTime: TimeInterval = 0

    @MainActor func frame() {
        let now = CACurrentMediaTime()
        let dt = min(now - last, max(1.0 / 20, interval * 1.5))
        last = now
        if let c = creature {
            // What Assistant.frameTick does for one creature, with the pose held.
            world.refreshIfNeeded(now: now, for: [c])
            switch mode {
            case "walk":
                // Back and forth, turning well before the screen's edges.
                c.behaviorUntil = .infinity
                if c.center.x > screen.frame.maxX - 250 { c.walkDirection = -1 }
                else if c.center.x < screen.frame.minX + 250 || c.walkDirection == 0 { c.walkDirection = 1 }
            case "talk":
                c.behaviorUntil = .infinity
                c.walkDirection = 0
                // Something new to say every few seconds, so typing is part of it.
                if now >= nextLine {
                    nextLine = now + 4
                    bubble.say("Have you tried turning your calendar off and on again? It fixed my afternoon. 📅",
                               think: false, near: c.bodyFrame, sticky: true)
                }
            case "sleep": if !c.isSleeping { c.sleep(for: nil) }
            default: c.behaviorUntil = .infinity; c.walkDirection = 0
            }
            c.isTalking = bubble.isShowing
            if movingCursor { cursorCircleCenter = c.center }
            c.tick(dt: dt)
            bubble.tick(dt: dt, anchor: c.bodyFrame)
        }

        // Measured once it has landed and settled.
        if let start = measureStart {
            // Only the creature's own window: the character stops drawing while it can't be seen
            // (a speech bubble that has just appeared doesn't count as visible for a moment either).
            let hidden = app.windows.contains { window in
                window.isVisible && !window.occlusionState.contains(.visible)
                    && window.contentView?.subviews.contains(where: { $0 is CharacterView }) == true
            }
            if hidden { unseenTime += dt }
            if now - start.wall >= Double(seconds) {
                if unseenTime > Double(seconds) * 0.05 {
                    fail("it couldn't be seen for part of the time (the screen locked or asleep, the screen saver, or a window over it), so it didn't draw", code: 3)
                }
                let usage = ownUsage(), wall = now - start.wall
                var instructions: Double?
                if let end = usage.instructions, let first = start.usage.instructions { instructions = (end - first) / wall / 1e6 }
                let system = finishTop?() ?? [:]
                let shown = systemPIDs.map { pid in format(pid.flatMap { system[$0] }) }
                print("RESULT \(characterID) \(mode) \(Int(screen.backingScaleFactor)) \(format((usage.cpu - start.usage.cpu) / wall * 100)) \(format(instructions)) \(shown[0]) \(shown[1])")
                exit(0)
            }
        } else if now - begin > 2.5 {
            measureStart = (now, ownUsage())
            finishTop = startTop(pids: systemPIDs.compactMap { $0 }, seconds: seconds)
        }

        // The app's frame loop runs at 60 Hz, or only as often as a sleeping pose changes while it
        // dozes on the floor (Assistant.updateFrameLoop).
        let wanted = creature?.isDozing == true ? Creature.sleepUpdateInterval : 1.0 / 60
        if wanted != interval {
            interval = wanted
            timer?.invalidate()
            let next = Timer(timeInterval: wanted, repeats: true) { _ in MainActor.assumeIsolated { frame() } }
            if wanted > 1.0 / 30 { next.tolerance = wanted * 0.1 }
            RunLoop.main.add(next, forMode: .common)
            timer = next
        }
    }
    frame()
    app.run()
}

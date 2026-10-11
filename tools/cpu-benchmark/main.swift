import AppKit

// Measures what one creature costs: hosts a real Creature (its window, physics and layers) on a
// frame loop like the app's, holds it in one pose and reports the CPU used by this process, the
// window server and the window manager. tools/cpu-benchmark.sh builds it together with the app's
// sources and runs it for every character (see "Checking CPU use" in the README).
//
//   cpu-benchmark <character id> <mode> <seconds> [screen index] [accessories]
//   cpu-benchmark --list | --screens
//
// Modes: idle, walk (back and forth), talk (with a speech bubble), sleep, or none (no creature:
// the background). "accessories" puts on a party hat and a coffee.
// Prints: RESULT <character> <mode> <screen scale> <app %> <app M instructions/s> <WindowServer %>
// <WindowManager %>, with "-" for what it couldn't measure. It fails (exit 3) if the creature
// couldn't be seen for part of the time: it stops drawing then, so the numbers would be wrong.

let args = CommandLine.arguments

func fail(_ message: String, code: Int32 = 64) -> Never {
    FileHandle.standardError.write(Data((message + "\n").utf8))
    exit(code)
}

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

/// Fixes where the cursor seems to be, so the eyes look the same way in every run.
func pinCursor(at point: CGPoint) {
    guard let method = class_getClassMethod(NSEvent.self, #selector(getter: NSEvent.mouseLocation)) else { return }
    let location: @convention(block) (AnyObject) -> NSPoint = { _ in point }
    method_setImplementation(method, imp_implementationWithBlock(location))
}

func format(_ value: Double?) -> String { value.map { String(format: "%.1f", $0) } ?? "-" }

MainActor.assumeIsolated {
    if args.count == 2 && args[1] == "--list" {
        print(CharacterLibrary.loadAll().map(\.id).joined(separator: " "))
        exit(0)
    }
    if args.count == 2 && args[1] == "--screens" {
        print(NSScreen.screens.count)
        exit(0)
    }
    passOnSignals()
    guard args.count >= 4, let seconds = Int(args[3]), seconds > 0 else {
        fail("usage: cpu-benchmark <character id> <idle|walk|talk|sleep|none> <seconds> [screen index] [accessories] | --list")
    }
    let characterID = args[1], mode = args[2]
    guard ["idle", "walk", "talk", "sleep", "none"].contains(mode) else { fail("unknown mode \(mode)") }
    let screenIndex = args.count > 4 ? Int(args[4]) ?? -1 : 0
    guard NSScreen.screens.indices.contains(screenIndex) else { fail("no screen \(args[4]): there are \(NSScreen.screens.count)") }
    let screen = NSScreen.screens[screenIndex]

    let app = NSApplication.shared
    app.setActivationPolicy(.accessory)
    pinCursor(at: CGPoint(x: screen.visibleFrame.minX + 40, y: screen.visibleFrame.maxY - 40))
    let world = World()
    let bubble = SpeechBubble()
    var creature: Creature?
    if mode != "none" {
        guard let pack = CharacterLibrary.loadAll().first(where: { $0.id == characterID }) else {
            fail("no character \(characterID)", code: 2)
        }
        let c = Creature(pack: pack, world: world, scale: 1)
        if args.count > 5 && args[5] == "accessories" {
            c.costume = .party
            c.prop = .coffee
        }
        c.drop(at: CGPoint(x: screen.visibleFrame.midX, y: screen.visibleFrame.minY + 200))
        creature = c
    }
    let systemPIDs = [process(named: "WindowServer"), process(named: "WindowManager", owner: getuid())]

    var last = CACurrentMediaTime()
    let begin = last
    var nextLine = begin + 2.5
    var measureStart: (wall: TimeInterval, usage: (cpu: Double, instructions: Double?))?
    var finishTop: (() -> [pid_t: Double])?
    var timer: Timer?
    var interval: TimeInterval = 0
    var unseen = false

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
            c.tick(dt: dt)
            bubble.tick(dt: dt, anchor: c.bodyFrame)
        }

        // Measured once it has landed and settled.
        if let start = measureStart {
            if app.windows.contains(where: { $0.isVisible && !$0.occlusionState.contains(.visible) }) { unseen = true }
            if now - start.wall >= Double(seconds) {
                if unseen {
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

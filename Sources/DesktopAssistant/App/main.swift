import AppKit

MainActor.assumeIsolated {
    let app = NSApplication.shared
    let delegate = AppDelegate()
    app.delegate = delegate
    // Agent app: no Dock icon, no app switcher entry, only the menu bar item.
    app.setActivationPolicy(.accessory)
    app.run()
}

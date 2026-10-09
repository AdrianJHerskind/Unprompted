import AppKit
import SwiftUI

/// Opens the Settings and Daily Report windows (SwiftUI views in ordinary windows).
@MainActor
final class WindowPresenter {
    private var settingsWindow: NSWindow?
    private var reportWindow: NSWindow?

    func showSettings(characters: [CharacterPack]) {
        let options = characters.map { CharacterOption(id: $0.id, name: $0.name, movement: $0.movement) }
        settingsWindow = present(settingsWindow, title: "Unprompted Settings",
                                 content: SettingsView(settings: .shared, characters: options))
    }

    func showReport(stats: StatsTracker, name: String, mood: Mood) {
        reportWindow = present(reportWindow, title: "Daily Report", content: ReportView(stats: stats, name: name, mood: mood))
    }

    private func present<V: View>(_ existing: NSWindow?, title: String, content: V) -> NSWindow {
        let window = existing ?? NSWindow(contentRect: .zero, styleMask: [.titled, .closable, .miniaturizable],
                                          backing: .buffered, defer: false)
        window.title = title
        window.isReleasedWhenClosed = false
        window.contentViewController = NSHostingController(rootView: content)
        if existing == nil { window.center() }
        // An agent app has to activate itself for its windows to come to the front.
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
        return window
    }
}

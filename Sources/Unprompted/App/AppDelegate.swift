import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private var statusItem: NSStatusItem?
    private var assistant: Assistant?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let assistant = Assistant(packs: CharacterLibrary.loadAll())
        self.assistant = assistant

        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        item.button?.image = MenuBarIcon.image()
        item.button?.toolTip = "Unprompted"
        let menu = NSMenu()
        menu.autoenablesItems = false
        menu.delegate = self
        item.menu = menu
        statusItem = item

        assistant.start()
    }

    func applicationWillTerminate(_ notification: Notification) {
        assistant?.saveState()
    }

    // Rebuilt every time it opens so checkmarks and snooze state are current.
    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()
        assistant?.populateStatusMenu(menu)
    }
}

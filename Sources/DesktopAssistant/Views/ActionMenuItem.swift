import AppKit

/// NSMenuItem that runs a closure, so menus can be built without selector plumbing.
final class ActionMenuItem: NSMenuItem {
    private let handler: () -> Void

    init(_ title: String, key: String = "", handler: @escaping () -> Void) {
        self.handler = handler
        super.init(title: title, action: #selector(fire), keyEquivalent: key)
        target = self
    }

    required init(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    @objc private func fire() { handler() }
}

extension NSMenu {
    /// Adds an item that runs `handler` when chosen.
    @discardableResult
    func addAction(_ title: String, key: String = "", checked: Bool = false, enabled: Bool = true,
                   _ handler: @escaping () -> Void) -> NSMenuItem {
        let item = ActionMenuItem(title, key: key, handler: handler)
        item.state = checked ? .on : .off
        item.isEnabled = enabled
        addItem(item)
        return item
    }

    func addSubmenu(_ title: String, _ submenu: NSMenu) {
        let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        item.submenu = submenu
        addItem(item)
    }

    /// A greyed-out line of information.
    func addLabel(_ title: String) {
        let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        item.isEnabled = false
        addItem(item)
    }
}

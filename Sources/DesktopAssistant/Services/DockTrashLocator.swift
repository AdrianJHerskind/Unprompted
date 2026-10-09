import AppKit
import ApplicationServices

/// Finds the Trash icon in the Dock through the Accessibility API (needs Accessibility permission).
@MainActor
enum DockTrashLocator {
    static var hasPermission: Bool { AXIsProcessTrusted() }

    /// Asks macOS to show the Accessibility permission prompt.
    static func requestPermission() {
        let key = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
        _ = AXIsProcessTrustedWithOptions([key: true] as CFDictionary)
    }

    /// The Trash icon's frame in Cocoa screen coordinates, or nil without permission or when not found.
    static func trashFrame() -> CGRect? {
        guard hasPermission,
              let dock = NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.dock").first else { return nil }
        let app = AXUIElementCreateApplication(dock.processIdentifier)
        // Called on the main thread: a busy Dock mustn't freeze the creature for the default 6 s.
        AXUIElementSetMessagingTimeout(app, 0.25)
        for list in children(of: app) {
            for item in children(of: list) where attribute(kAXSubroleAttribute, of: item) as? String == "AXTrashDockItem" {
                guard let position = pointValue(attribute(kAXPositionAttribute, of: item)),
                      let size = sizeValue(attribute(kAXSizeAttribute, of: item)) else { return nil }
                return ScreenGeometry.cocoaRect(fromTopLeft: CGRect(origin: position, size: size))
            }
        }
        return nil
    }

    private static func attribute(_ name: String, of element: AXUIElement) -> CFTypeRef? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, name as CFString, &value) == .success else { return nil }
        return value
    }

    private static func children(of element: AXUIElement) -> [AXUIElement] {
        attribute(kAXChildrenAttribute, of: element) as? [AXUIElement] ?? []
    }

    // AXValues are checked by type before unpacking, so an unexpected value can't crash the app.
    private static func pointValue(_ value: CFTypeRef?) -> CGPoint? {
        guard let value, CFGetTypeID(value) == AXValueGetTypeID() else { return nil }
        var point = CGPoint.zero
        return AXValueGetValue(value as! AXValue, .cgPoint, &point) ? point : nil
    }

    private static func sizeValue(_ value: CFTypeRef?) -> CGSize? {
        guard let value, CFGetTypeID(value) == AXValueGetTypeID() else { return nil }
        var size = CGSize.zero
        return AXValueGetValue(value as! AXValue, .cgSize, &size) ? size : nil
    }
}

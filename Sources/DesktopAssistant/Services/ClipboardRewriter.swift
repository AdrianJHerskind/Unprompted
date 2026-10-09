import AppKit

/// Rewrites the text on the clipboard in a `TextStyle`, with a one-step undo.
/// The clipboard is only read when a rewrite is requested, never in the background.
@MainActor
final class ClipboardRewriter {
    enum Outcome {
        case noText
        case unchanged
        case rewritten(String)
    }

    private var lastRewrite: (original: String, changeCount: Int)?

    /// Only while the clipboard still holds the rewritten text: undoing after you've copied
    /// something else would throw that away.
    var canUndo: Bool {
        lastRewrite?.changeCount == NSPasteboard.general.changeCount
    }

    func rewrite(as style: TextStyle) -> Outcome {
        let pasteboard = NSPasteboard.general
        guard let original = pasteboard.string(forType: .string),
              !original.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return .noText }
        let result = TextRewriter.rewrite(original, as: style)
        guard result != original else { return .unchanged }
        pasteboard.clearContents()
        pasteboard.setString(result, forType: .string)
        lastRewrite = (original, pasteboard.changeCount)
        return .rewritten(result)
    }

    enum UndoOutcome {
        case restored
        case nothingToUndo
        /// Something else was copied since, and that stays.
        case clipboardChanged
    }

    /// Puts the text from before the last rewrite back.
    func undo() -> UndoOutcome {
        guard let original = lastRewrite?.original else { return .nothingToUndo }
        guard canUndo else {
            lastRewrite = nil
            return .clipboardChanged
        }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(original, forType: .string)
        lastRewrite = nil
        return .restored
    }
}

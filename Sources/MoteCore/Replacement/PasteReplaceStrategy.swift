import AppKit
import Foundation

public enum PasteReplaceStrategyError: LocalizedError {
    case eventCreationFailed

    public var errorDescription: String? {
        switch self {
            case .eventCreationFailed:
                "Could not synthesize paste event"
        }
    }
}

public final class PasteReplaceStrategy {
    public init() {}

    @MainActor
    public func apply(_ text: String, to _: AXSelectionSnapshot) throws {
        let transaction = ClipboardTransaction()
        transaction.write(string: text)
        defer {
            transaction.restore()
        }

        try postPasteShortcut()
    }

    private func postPasteShortcut() throws {
        guard
            let source = CGEventSource(stateID: .hidSystemState),
            let keyDown = CGEvent(keyboardEventSource: source, virtualKey: 9, keyDown: true),
            let keyUp = CGEvent(keyboardEventSource: source, virtualKey: 9, keyDown: false)
        else {
            throw PasteReplaceStrategyError.eventCreationFailed
        }

        keyDown.flags = .maskCommand
        keyUp.flags = .maskCommand
        keyDown.post(tap: .cghidEventTap)
        keyUp.post(tap: .cghidEventTap)
    }
}

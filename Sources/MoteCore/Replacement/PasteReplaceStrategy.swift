import AppKit
import Foundation

public enum PasteReplaceStrategyError: LocalizedError {
    case activationFailed
    case eventCreationFailed

    public var errorDescription: String? {
        switch self {
        case .activationFailed:
            return "Could not restore focus to the target app"
        case .eventCreationFailed:
            return "Could not synthesize paste event"
        }
    }
}

public final class PasteReplaceStrategy {
    public init() {
    }

    @MainActor
    public func apply(_ text: String, to snapshot: AXSelectionSnapshot) throws {
        let transaction = ClipboardTransaction()
        transaction.write(string: text)
        defer {
            transaction.restore()
        }

        try activateApplication(processIdentifier: snapshot.context.processIdentifier)
        try postPasteShortcut()
    }

    @MainActor
    private func activateApplication(processIdentifier: Int32) throws {
        guard processIdentifier != 0 else {
            throw PasteReplaceStrategyError.activationFailed
        }

        guard let application = NSRunningApplication(processIdentifier: processIdentifier) else {
            throw PasteReplaceStrategyError.activationFailed
        }

        _ = application.activate()
        RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.08))
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

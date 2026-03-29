import ApplicationServices
import Foundation

public enum KeyEventDispatchError: LocalizedError {
    case eventCreationFailed

    public var errorDescription: String? {
        switch self {
            case .eventCreationFailed:
                "Could not synthesize keyboard shortcut"
        }
    }
}

public enum KeyEventDispatch {
    public static func postShortcut(key: UInt16, modifiers: CGEventFlags) throws {
        guard
            let source = CGEventSource(stateID: .hidSystemState),
            let keyDown = CGEvent(keyboardEventSource: source, virtualKey: key, keyDown: true),
            let keyUp = CGEvent(keyboardEventSource: source, virtualKey: key, keyDown: false)
        else {
            throw KeyEventDispatchError.eventCreationFailed
        }
        keyDown.flags = modifiers
        keyUp.flags = modifiers
        keyDown.post(tap: .cghidEventTap)
        keyUp.post(tap: .cghidEventTap)
    }
}

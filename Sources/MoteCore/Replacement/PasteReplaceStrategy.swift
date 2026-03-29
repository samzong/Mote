import AppKit

public enum PasteReplaceStrategyError: LocalizedError {
    case targetNotFrontmost

    public var errorDescription: String? {
        switch self {
            case .targetNotFrontmost:
                "Target application lost focus before paste"
        }
    }
}

public final class PasteReplaceStrategy {
    public init() {}

    @MainActor
    public func apply(_ text: String, to snapshot: AXSelectionSnapshot) async throws {
        guard snapshot.writebackCapability != .manualOnly else {
            return
        }

        guard AXTextElementSupport.isFrontmost(processIdentifier: snapshot.context.processIdentifier) else {
            throw PasteReplaceStrategyError.targetNotFrontmost
        }

        let transaction = ClipboardTransaction()
        transaction.write(string: text)

        do {
            try KeyEventDispatch.postShortcut(key: 9, modifiers: .maskCommand)
        } catch {
            _ = transaction.restoreIfOwned()
            throw error
        }

        try? await Task.sleep(for: .milliseconds(200))

        if !transaction.restoreIfOwned() {
            Logger.debug("paste-apply: skipped clipboard restore because contents changed")
        }
    }

    @MainActor
    public func applySafeFieldReplacement(_ text: String, to snapshot: AXSelectionSnapshot) async throws -> Bool {
        guard let fieldText = snapshot.fieldText else {
            return false
        }

        let range: SelectionRange
        switch snapshot.proof {
            case let .exactRange(provenRange):
                range = provenRange
            case .textMarker, .hostAdapterProof, .unproven:
                return false
        }

        let nsFieldText = fieldText as NSString
        let nsRange = NSRange(location: range.location, length: range.length)
        guard NSMaxRange(nsRange) <= nsFieldText.length else {
            return false
        }

        let transaction = ClipboardTransaction()
        let pasteboard = NSPasteboard.general

        try KeyEventDispatch.postShortcut(key: 0, modifiers: .maskCommand)
        try? await Task.sleep(for: .milliseconds(50))

        let changeCountBeforeCopy = pasteboard.changeCount
        try KeyEventDispatch.postShortcut(key: 8, modifiers: .maskCommand)
        try? await Task.sleep(for: .milliseconds(200))

        guard pasteboard.changeCount != changeCountBeforeCopy else {
            return false
        }

        transaction.claimCurrentContents(from: pasteboard)
        guard let currentFieldText = pasteboard.string(forType: .string),
              currentFieldText == fieldText
        else {
            _ = transaction.restoreIfOwned(to: pasteboard)
            Logger.debug("paste-apply: field snapshot mismatch, refusing full-field replace")
            return false
        }

        guard AXTextElementSupport.isFrontmost(processIdentifier: snapshot.context.processIdentifier) else {
            _ = transaction.restoreIfOwned(to: pasteboard)
            return false
        }

        let modifiedFieldText = nsFieldText.replacingCharacters(in: nsRange, with: text)
        transaction.write(string: modifiedFieldText, to: pasteboard)

        try KeyEventDispatch.postShortcut(key: 0, modifiers: .maskCommand)
        try? await Task.sleep(for: .milliseconds(50))
        try KeyEventDispatch.postShortcut(key: 9, modifiers: .maskCommand)
        try? await Task.sleep(for: .milliseconds(200))

        if !transaction.restoreIfOwned(to: pasteboard) {
            Logger.debug("paste-apply: skipped clipboard restore after full-field replace because contents changed")
        }

        return true
    }
}

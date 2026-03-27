import AppKit
import Foundation

public enum ReplacementMethod: String, Sendable {
    case direct
    case paste
}

public final class ReplacementCoordinator {
    private let directStrategy: DirectReplaceStrategy
    private let pasteStrategy: PasteReplaceStrategy

    public init(
        directStrategy: DirectReplaceStrategy = DirectReplaceStrategy(),
        pasteStrategy: PasteReplaceStrategy = PasteReplaceStrategy()
    ) {
        self.directStrategy = directStrategy
        self.pasteStrategy = pasteStrategy
    }

    @MainActor
    public func apply(_ output: String, to snapshot: AXSelectionSnapshot) throws -> ReplacementMethod {
        try activateTargetApplication(processIdentifier: snapshot.context.processIdentifier)

        do {
            try directStrategy.apply(output, to: snapshot)
            return .direct
        } catch {
            try pasteStrategy.apply(output, to: snapshot)
            return .paste
        }
    }

    @MainActor
    private func activateTargetApplication(processIdentifier: Int32) throws {
        guard processIdentifier != 0 else {
            return
        }

        guard let application = NSRunningApplication(processIdentifier: processIdentifier) else {
            return
        }

        _ = application.activate()
        RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.05))
    }
}

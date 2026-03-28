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
    public func apply(_ output: String, to snapshot: AXSelectionSnapshot) async throws -> ReplacementMethod {
        try await Self.activateTargetApplication(processIdentifier: snapshot.context.processIdentifier)

        do {
            try directStrategy.apply(output, to: snapshot)
            return .direct
        } catch {
            try pasteStrategy.apply(output, to: snapshot)
            return .paste
        }
    }

    private static func activateTargetApplication(processIdentifier: Int32) async throws {
        guard processIdentifier != 0,
              let application = NSRunningApplication(processIdentifier: processIdentifier)
        else {
            return
        }

        application.activate()
        try await Task.sleep(for: .milliseconds(80))
    }
}

import AppKit

typealias SelectionValidation = (AXSelectionSnapshot) -> AXSelectionSnapshot?
typealias CurrentSelectionValidation = @MainActor (AXSelectionSnapshot) async -> AXSelectionSnapshot?
typealias SelectionRestoration = (AXSelectionSnapshot) -> Bool
typealias DirectReplacement = (String, AXSelectionSnapshot) throws -> Void
typealias PasteReplacement = @MainActor (String, AXSelectionSnapshot) async throws -> Void
typealias SafeFieldReplacement = @MainActor (String, AXSelectionSnapshot) async throws -> Bool

public final class ReplacementCoordinator {
    private let validateSelection: SelectionValidation
    private let validateCurrentSelection: CurrentSelectionValidation
    private let restoreSelection: SelectionRestoration
    private let applyDirect: DirectReplacement
    private let applyPaste: PasteReplacement
    private let applySafeFieldReplacement: SafeFieldReplacement

    public init() {
        validateSelection = { AXSelectionReader().validatedSelection(for: $0) }
        validateCurrentSelection = { @MainActor in
            await ClipboardSelectionReader().validatedCurrentSelection(for: $0)
        }
        restoreSelection = { AXSelectionRestorer().restoreSelection(from: $0) }
        applyDirect = { try DirectReplaceStrategy().apply($0, to: $1) }
        applyPaste = { @MainActor in
            try await PasteReplaceStrategy().apply($0, to: $1)
        }
        applySafeFieldReplacement = { @MainActor in
            try await PasteReplaceStrategy().applySafeFieldReplacement($0, to: $1)
        }
    }

    init(
        validateSelection: @escaping SelectionValidation,
        validateCurrentSelection: @escaping CurrentSelectionValidation,
        restoreSelection: @escaping SelectionRestoration,
        applyDirect: @escaping DirectReplacement,
        applyPaste: @escaping PasteReplacement,
        applySafeFieldReplacement: @escaping SafeFieldReplacement
    ) {
        self.validateSelection = validateSelection
        self.validateCurrentSelection = validateCurrentSelection
        self.restoreSelection = restoreSelection
        self.applyDirect = applyDirect
        self.applyPaste = applyPaste
        self.applySafeFieldReplacement = applySafeFieldReplacement
    }

    @MainActor
    public func apply(_ output: String, to snapshot: AXSelectionSnapshot) async -> WritebackOutcome {
        await Self.activateTargetApplication(processIdentifier: snapshot.context.processIdentifier)

        let candidateSnapshot: AXSelectionSnapshot? = if let snapshotFromProof =
            validatedSnapshotFromProof(for: snapshot)
        {
            snapshotFromProof
        } else if restoredSnapshotNeeded(for: snapshot) {
            await restoredSnapshot(for: snapshot)
        } else {
            await validateCurrentSelection(snapshot)
        }

        guard let validatedSnapshot = candidateSnapshot else {
            if let safeFieldOutcome = await safeFieldReplacementOutcome(output, snapshot: snapshot) {
                return safeFieldOutcome
            }
            return .needsManualApply
        }

        if validatedSnapshot.writebackCapability == .directAX {
            do {
                try applyDirect(output, validatedSnapshot)
                return .appliedDirect
            } catch {
                Logger.debug("direct replace failed, falling back to paste")
            }
        }

        guard validatedSnapshot.writebackCapability == .pasteCurrentSelection
            || validatedSnapshot.writebackCapability == .directAX
        else {
            return .needsManualApply
        }

        do {
            try await applyPaste(output, validatedSnapshot)
            return .appliedPaste
        } catch {
            Logger.info("replace failed: \(error.localizedDescription)")
            return .failed
        }
    }

    private static func activateTargetApplication(processIdentifier: Int32) async {
        guard processIdentifier != 0,
              let application = NSRunningApplication(processIdentifier: processIdentifier)
        else {
            return
        }

        if application.isActive { return }
        application.activate()
        try? await Task.sleep(for: .milliseconds(80))
    }

    private func validatedSnapshotFromProof(for snapshot: AXSelectionSnapshot) -> AXSelectionSnapshot? {
        guard snapshot.proof.isProven else {
            return nil
        }

        return validateSelection(snapshot)
    }

    @MainActor
    private func restoredSnapshot(for snapshot: AXSelectionSnapshot) async -> AXSelectionSnapshot? {
        guard restoreSelection(snapshot) else {
            return await validateCurrentSelection(snapshot)
        }

        try? await Task.sleep(for: .milliseconds(80))
        if let restoredSnapshot = validatedSnapshotFromProof(for: snapshot) {
            return restoredSnapshot
        }

        return await validateCurrentSelection(snapshot)
    }

    private func restoredSnapshotNeeded(for snapshot: AXSelectionSnapshot) -> Bool {
        switch snapshot.proof {
            case .exactRange, .textMarker:
                true
            case .hostAdapterProof, .unproven:
                false
        }
    }

    @MainActor
    private func safeFieldReplacementOutcome(
        _ output: String,
        snapshot: AXSelectionSnapshot
    ) async -> WritebackOutcome? {
        do {
            if try await applySafeFieldReplacement(output, snapshot) {
                return .appliedPaste
            }
        } catch {
            Logger.info("replace failed: \(error.localizedDescription)")
            return .failed
        }

        return nil
    }
}

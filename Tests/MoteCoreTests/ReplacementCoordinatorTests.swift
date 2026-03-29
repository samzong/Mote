import ApplicationServices
@testable import MoteCore
import Testing

struct ReplacementCoordinatorTests {
    @Test
    @MainActor
    func manualOnlySelectionReturnsManualFallbackWithoutValidation() async {
        var selectionValidationCalls = 0
        var currentSelectionValidationCalls = 0
        var restorationCalls = 0
        var directCalls = 0
        var pasteCalls = 0

        let coordinator = makeCoordinator(
            validateSelection: { _ in
                selectionValidationCalls += 1
                return nil
            },
            validateCurrentSelection: { _ in
                currentSelectionValidationCalls += 1
                return nil
            },
            restoreSelection: { _ in
                restorationCalls += 1
                return false
            },
            applyDirect: { _, _ in
                directCalls += 1
            },
            applyPaste: { _, _ in
                pasteCalls += 1
            },
            applySafeFieldReplacement: { _, _ in false }
        )

        let snapshot = makeSnapshot(
            proof: .unproven,
            capability: .manualOnly,
            isWritable: false
        )

        let outcome = await coordinator.apply("Updated", to: snapshot)

        #expect(outcome == .needsManualApply)
        #expect(selectionValidationCalls == 0)
        #expect(currentSelectionValidationCalls == 1)
        #expect(restorationCalls == 0)
        #expect(directCalls == 0)
        #expect(pasteCalls == 0)
    }

    @Test
    @MainActor
    func exactRangeSelectionUsesDirectWriteWhenValidationSucceeds() async {
        var selectionValidationCalls = 0
        var currentSelectionValidationCalls = 0
        var restorationCalls = 0
        var directCalls = 0
        var pasteCalls = 0

        let snapshot = makeSnapshot(
            proof: .exactRange(SelectionRange(location: 4, length: 6)),
            capability: .directAX,
            isWritable: true
        )

        let coordinator = makeCoordinator(
            validateSelection: { _ in
                selectionValidationCalls += 1
                return snapshot
            },
            validateCurrentSelection: { _ in
                currentSelectionValidationCalls += 1
                return nil
            },
            restoreSelection: { _ in
                restorationCalls += 1
                return false
            },
            applyDirect: { _, _ in
                directCalls += 1
            },
            applyPaste: { _, _ in
                pasteCalls += 1
            },
            applySafeFieldReplacement: { _, _ in false }
        )

        let outcome = await coordinator.apply("Updated", to: snapshot)

        #expect(outcome == .appliedDirect)
        #expect(selectionValidationCalls == 1)
        #expect(currentSelectionValidationCalls == 0)
        #expect(restorationCalls == 0)
        #expect(directCalls == 1)
        #expect(pasteCalls == 0)
    }

    @Test
    @MainActor
    func failedDirectWriteFallsBackToPasteForProvenSelection() async {
        var directCalls = 0
        var pasteCalls = 0

        let snapshot = makeSnapshot(
            proof: .exactRange(SelectionRange(location: 0, length: 7)),
            capability: .directAX,
            isWritable: true
        )

        let coordinator = makeCoordinator(
            validateSelection: { _ in snapshot },
            validateCurrentSelection: { _ in nil },
            restoreSelection: { _ in false },
            applyDirect: { _, _ in
                directCalls += 1
                throw TestError()
            },
            applyPaste: { _, _ in
                pasteCalls += 1
            },
            applySafeFieldReplacement: { _, _ in false }
        )

        let outcome = await coordinator.apply("Updated", to: snapshot)

        #expect(outcome == .appliedPaste)
        #expect(directCalls == 1)
        #expect(pasteCalls == 1)
    }

    @Test
    @MainActor
    func lostProofAtApplyTimeReturnsManualFallback() async {
        var selectionValidationCalls = 0
        var currentSelectionValidationCalls = 0
        var restorationCalls = 0

        let snapshot = makeSnapshot(
            proof: .exactRange(SelectionRange(location: 1, length: 4)),
            capability: .directAX,
            isWritable: true
        )

        let coordinator = makeCoordinator(
            validateSelection: { _ in
                defer { selectionValidationCalls += 1 }
                return nil
            },
            validateCurrentSelection: { _ in
                currentSelectionValidationCalls += 1
                return nil
            },
            restoreSelection: { _ in
                restorationCalls += 1
                return false
            },
            applyDirect: { _, _ in
                Issue.record("direct write should not run")
            },
            applyPaste: { _, _ in
                Issue.record("paste should not run")
            },
            applySafeFieldReplacement: { _, _ in false }
        )

        let outcome = await coordinator.apply("Updated", to: snapshot)

        #expect(outcome == .needsManualApply)
        #expect(selectionValidationCalls == 1)
        #expect(currentSelectionValidationCalls == 1)
        #expect(restorationCalls == 1)
    }

    @Test
    @MainActor
    func clipboardValidatedSelectionRestoresAutomaticPasteForUnprovenSnapshot() async {
        var selectionValidationCalls = 0
        var currentSelectionValidationCalls = 0
        var restorationCalls = 0
        var pasteCalls = 0

        let originalSnapshot = makeSnapshot(
            proof: .unproven,
            capability: .manualOnly,
            isWritable: false
        )
        let validatedSnapshot = makeSnapshot(
            proof: .hostAdapterProof(
                HostAdapterProofToken(
                    adapterIdentifier: "clipboard-current-selection",
                    token: Data([0x01])
                )
            ),
            capability: .pasteCurrentSelection,
            isWritable: false
        )

        let coordinator = makeCoordinator(
            validateSelection: { _ in
                selectionValidationCalls += 1
                return nil
            },
            validateCurrentSelection: { _ in
                currentSelectionValidationCalls += 1
                return validatedSnapshot
            },
            restoreSelection: { _ in
                restorationCalls += 1
                return false
            },
            applyDirect: { _, _ in
                Issue.record("direct write should not run")
            },
            applyPaste: { _, _ in
                pasteCalls += 1
            },
            applySafeFieldReplacement: { _, _ in false }
        )

        let outcome = await coordinator.apply("Updated", to: originalSnapshot)

        #expect(outcome == .appliedPaste)
        #expect(selectionValidationCalls == 0)
        #expect(currentSelectionValidationCalls == 1)
        #expect(restorationCalls == 0)
        #expect(pasteCalls == 1)
    }

    @Test
    @MainActor
    func restorerCanRecoverExactRangeBeforeFallingBackToClipboardValidation() async {
        var selectionValidationCalls = 0
        var currentSelectionValidationCalls = 0
        var restorationCalls = 0
        var directCalls = 0

        let snapshot = makeSnapshot(
            proof: .exactRange(SelectionRange(location: 0, length: 7)),
            capability: .directAX,
            isWritable: true
        )

        let coordinator = makeCoordinator(
            validateSelection: { _ in
                defer { selectionValidationCalls += 1 }
                return selectionValidationCalls == 0 ? nil : snapshot
            },
            validateCurrentSelection: { _ in
                currentSelectionValidationCalls += 1
                return nil
            },
            restoreSelection: { _ in
                restorationCalls += 1
                return true
            },
            applyDirect: { _, _ in
                directCalls += 1
            },
            applyPaste: { _, _ in
                Issue.record("paste should not run")
            },
            applySafeFieldReplacement: { _, _ in false }
        )

        let outcome = await coordinator.apply("Updated", to: snapshot)

        #expect(outcome == .appliedDirect)
        #expect(selectionValidationCalls == 2)
        #expect(restorationCalls == 1)
        #expect(currentSelectionValidationCalls == 0)
        #expect(directCalls == 1)
    }

    @Test
    @MainActor
    func safeFieldReplacementRunsWhenSelectionCannotBeRecovered() async {
        var restorationCalls = 0
        var currentSelectionValidationCalls = 0
        var safeFieldReplacementCalls = 0

        let snapshot = makeSnapshot(
            proof: .exactRange(SelectionRange(location: 0, length: 7)),
            capability: .directAX,
            isWritable: false,
            fieldText: "Example field"
        )

        let coordinator = makeCoordinator(
            validateSelection: { _ in nil },
            validateCurrentSelection: { _ in
                currentSelectionValidationCalls += 1
                return nil
            },
            restoreSelection: { _ in
                restorationCalls += 1
                return false
            },
            applyDirect: { _, _ in
                Issue.record("direct write should not run")
            },
            applyPaste: { _, _ in
                Issue.record("paste should not run")
            },
            applySafeFieldReplacement: { _, _ in
                safeFieldReplacementCalls += 1
                return true
            }
        )

        let outcome = await coordinator.apply("Updated", to: snapshot)

        #expect(outcome == .appliedPaste)
        #expect(restorationCalls == 1)
        #expect(currentSelectionValidationCalls == 1)
        #expect(safeFieldReplacementCalls == 1)
    }

    @MainActor
    private func makeCoordinator(
        validateSelection: @escaping SelectionValidation,
        validateCurrentSelection: @escaping CurrentSelectionValidation,
        restoreSelection: @escaping SelectionRestoration,
        applyDirect: @escaping DirectReplacement,
        applyPaste: @escaping PasteReplacement,
        applySafeFieldReplacement: @escaping SafeFieldReplacement
    ) -> ReplacementCoordinator {
        ReplacementCoordinator(
            validateSelection: validateSelection,
            validateCurrentSelection: validateCurrentSelection,
            restoreSelection: restoreSelection,
            applyDirect: applyDirect,
            applyPaste: applyPaste,
            applySafeFieldReplacement: applySafeFieldReplacement
        )
    }

    @MainActor
    private func makeSnapshot(
        proof: SelectionProof,
        capability: WritebackCapability,
        isWritable: Bool,
        fieldText: String? = nil
    ) -> AXSelectionSnapshot {
        let context = SelectionContext(
            bundleIdentifier: "com.apple.TextEdit",
            processIdentifier: 0,
            text: "Example",
            range: SelectionRange(location: 0, length: 7),
            bounds: nil,
            isSecure: false,
            isWritable: isWritable
        )

        return AXSelectionSnapshot(
            element: AXUIElementCreateSystemWide(),
            context: context,
            proof: proof,
            writebackCapability: capability,
            fieldText: fieldText
        )
    }
}

private struct TestError: Error {}

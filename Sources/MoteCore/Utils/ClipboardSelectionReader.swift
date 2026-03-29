import AppKit
import ApplicationServices

public final class ClipboardSelectionReader {
    public init() {}

    @MainActor
    public func readSelectedText() async -> AXSelectionSnapshot? {
        await readCurrentSelectionSnapshot(
            expected: nil,
            proof: .unproven,
            capability: .manualOnly
        )
    }

    @MainActor
    public func validatedCurrentSelection(for snapshot: AXSelectionSnapshot) async -> AXSelectionSnapshot? {
        guard let currentSnapshot = await readCurrentSelectionSnapshot(
            expected: snapshot,
            proof: .hostAdapterProof(makeCurrentSelectionToken(for: snapshot)),
            capability: .pasteCurrentSelection
        ) else {
            return nil
        }

        guard currentSnapshot.context.processIdentifier == snapshot.context.processIdentifier,
              currentSnapshot.context.text == snapshot.context.text
        else {
            Logger.debug("clipboard-read: current selection mismatch")
            return nil
        }

        return currentSnapshot
    }

    @MainActor
    private func readCurrentSelectionSnapshot(
        expected: AXSelectionSnapshot?,
        proof initialProof: SelectionProof,
        capability initialCapability: WritebackCapability
    ) async -> AXSelectionSnapshot? {
        let pasteboard = NSPasteboard.general
        let changeCountBefore = pasteboard.changeCount
        let transaction = ClipboardTransaction()

        do {
            try KeyEventDispatch.postShortcut(key: 8, modifiers: .maskCommand)
        } catch {
            Logger.debug("clipboard-read: failed to post Cmd+C")
            return nil
        }

        try? await Task.sleep(for: .milliseconds(200))

        guard pasteboard.changeCount != changeCountBefore else {
            Logger.debug("clipboard-read: clipboard unchanged after Cmd+C")
            return nil
        }

        transaction.claimCurrentContents(from: pasteboard)
        let text = pasteboard.string(forType: .string)
        let restored = transaction.restoreIfOwned(to: pasteboard)

        guard let text, !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            Logger.debug("clipboard-read: empty text from clipboard")
            return nil
        }

        let frontmostApp = NSWorkspace.shared.frontmostApplication
        let pid = frontmostApp?.processIdentifier ?? 0
        let bundleId = frontmostApp?.bundleIdentifier

        if let expected,
           expected.context.processIdentifier != 0,
           pid != expected.context.processIdentifier
        {
            Logger.debug("clipboard-read: frontmost pid mismatch")
            return nil
        }

        let axOrigin = AXTextElementSupport.mousePositionInAXCoordinates().origin

        let systemWide = AXUIElementCreateSystemWide()
        let element = AXTextElementSupport.focusedElement(from: systemWide) ?? systemWide
        let isSecure = AXTextElementSupport.isSecure(element: element)
        let fieldText = AXTextElementSupport.stringAttribute(kAXValueAttribute as CFString, element: element)
        let exactRange = AXTextElementSupport.uniqueRange(of: text, in: fieldText)
        let isWritable = AXTextElementSupport.isWritable(element: element)

        let context = SelectionContext(
            bundleIdentifier: bundleId,
            processIdentifier: pid,
            text: text,
            range: exactRange ?? SelectionRange(location: 0, length: (text as NSString).length),
            bounds: CGRect(origin: axOrigin, size: .zero),
            isSecure: isSecure,
            isWritable: isWritable
        )

        if !restored {
            Logger.debug("clipboard-read: skipped clipboard restore because contents changed")
        }

        Logger.debug("clipboard-read: got \(text.count) chars from \(bundleId ?? "unknown")")
        let effectiveProof: SelectionProof = if let exactRange {
            .exactRange(exactRange)
        } else {
            initialProof
        }
        let effectiveCapability = effectiveProof.defaultWritebackCapability(isWritable: isWritable)
        return AXSelectionSnapshot(
            element: element,
            context: context,
            proof: effectiveProof,
            writebackCapability: effectiveCapability == .manualOnly ? initialCapability : effectiveCapability,
            fieldText: fieldText
        )
    }

    private func makeCurrentSelectionToken(for snapshot: AXSelectionSnapshot) -> HostAdapterProofToken {
        var data = Data()
        data.append(Data(snapshot.context.text.utf8))
        data.append(0x00)
        data.append(Data("\(snapshot.context.processIdentifier)".utf8))
        return HostAdapterProofToken(
            adapterIdentifier: "clipboard-current-selection",
            token: data
        )
    }
}

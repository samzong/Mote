import ApplicationServices

public final class AXSelectionRestorer {
    public init() {}

    public func restoreSelection(from snapshot: AXSelectionSnapshot) -> Bool {
        switch snapshot.proof {
            case let .exactRange(range):
                restoreExactRange(range, in: snapshot.element)
            case let .textMarker(proof):
                restoreTextMarkerRange(proof, in: snapshot.element)
            case .hostAdapterProof, .unproven:
                false
        }
    }

    private func restoreExactRange(_ range: SelectionRange, in element: AXUIElement) -> Bool {
        guard element.axIsSettable(kAXSelectedTextRangeAttribute as CFString) else {
            return false
        }
        return element.axSetRange(
            kAXSelectedTextRangeAttribute as CFString,
            range: CFRange(location: range.location, length: range.length)
        )
    }

    private func restoreTextMarkerRange(_ proof: TextMarkerRangeProof, in element: AXUIElement) -> Bool {
        guard element.axIsSettable("AXSelectedTextMarkerRange" as CFString),
              let textMarkerRange = AXTextElementSupport.textMarkerRange(from: proof)
        else {
            return false
        }
        return element.axSet("AXSelectedTextMarkerRange" as CFString, value: textMarkerRange)
    }
}

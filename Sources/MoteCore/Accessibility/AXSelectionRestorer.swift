import ApplicationServices
import Foundation

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
        var settable = DarwinBoolean(false)
        guard AXUIElementIsAttributeSettable(
            element,
            kAXSelectedTextRangeAttribute as CFString,
            &settable
        ) == .success, settable.boolValue else {
            return false
        }

        var cfRange = CFRange(location: range.location, length: range.length)
        guard let value = AXValueCreate(.cfRange, &cfRange) else {
            return false
        }

        return AXUIElementSetAttributeValue(
            element,
            kAXSelectedTextRangeAttribute as CFString,
            value
        ) == .success
    }

    private func restoreTextMarkerRange(_ proof: TextMarkerRangeProof, in element: AXUIElement) -> Bool {
        var settable = DarwinBoolean(false)
        guard AXUIElementIsAttributeSettable(
            element,
            "AXSelectedTextMarkerRange" as CFString,
            &settable
        ) == .success, settable.boolValue,
            let textMarkerRange = AXTextElementSupport.textMarkerRange(from: proof)
        else {
            return false
        }

        return AXUIElementSetAttributeValue(
            element,
            "AXSelectedTextMarkerRange" as CFString,
            textMarkerRange
        ) == .success
    }
}

import ApplicationServices

public final class AXBoundsResolver {
    public init() {}

    public func resolveSelectionBounds(for element: AXUIElement, range: SelectionRange) -> CGRect? {
        var cfRange = CFRange(location: range.location, length: range.length)
        guard let rangeValue = AXValueCreate(.cfRange, &cfRange) else {
            return nil
        }

        guard let rect = element.axParameterizedRect(
            kAXBoundsForRangeParameterizedAttribute as CFString,
            param: rangeValue
        ) else { return nil }

        return rect.isNull || rect.isEmpty ? nil : rect
    }

    public func resolveTextMarkerRangeBounds(
        for element: AXUIElement,
        proof: TextMarkerRangeProof
    ) -> CGRect? {
        guard let rangeValue = AXTextElementSupport.textMarkerRange(from: proof) else {
            return nil
        }

        guard let rect = element.axParameterizedRect(
            "AXBoundsForTextMarkerRange" as CFString,
            param: rangeValue
        ) else { return nil }

        return rect.isNull || rect.isEmpty ? nil : rect
    }

    public func resolveElementBounds(for element: AXUIElement) -> CGRect? {
        guard
            let position = element.axPoint(kAXPositionAttribute as CFString),
            let size = element.axSize(kAXSizeAttribute as CFString)
        else {
            return nil
        }

        let rect = CGRect(origin: position, size: size)
        return rect.isEmpty ? nil : rect
    }
}

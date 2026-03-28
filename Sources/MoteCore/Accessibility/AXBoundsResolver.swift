import ApplicationServices
import Foundation

public final class AXBoundsResolver {
    public init() {}

    public func resolveSelectionBounds(for element: AXUIElement, range: SelectionRange) -> CGRect? {
        var cfRange = CFRange(location: range.location, length: range.length)
        guard let rangeValue = AXValueCreate(.cfRange, &cfRange) else {
            return nil
        }

        var value: CFTypeRef?
        let result = AXUIElementCopyParameterizedAttributeValue(
            element,
            kAXBoundsForRangeParameterizedAttribute as CFString,
            rangeValue,
            &value
        )

        guard result == .success, let axValue = value, CFGetTypeID(axValue) == AXValueGetTypeID() else {
            return nil
        }

        let castValue = axValue as! AXValue
        guard AXValueGetType(castValue) == .cgRect else {
            return nil
        }

        var rect = CGRect.zero
        guard AXValueGetValue(castValue, .cgRect, &rect) else {
            return nil
        }

        return rect.isNull || rect.isEmpty ? nil : rect
    }

    public func resolveElementBounds(for element: AXUIElement) -> CGRect? {
        guard
            let position = pointAttribute(kAXPositionAttribute as CFString, element: element),
            let size = sizeAttribute(kAXSizeAttribute as CFString, element: element)
        else {
            return nil
        }

        let rect = CGRect(origin: position, size: size)
        return rect.isEmpty ? nil : rect
    }

    private func pointAttribute(_ attribute: CFString, element: AXUIElement) -> CGPoint? {
        var value: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(element, attribute, &value)
        guard result == .success, let axValue = value, CFGetTypeID(axValue) == AXValueGetTypeID() else {
            return nil
        }

        let castValue = axValue as! AXValue
        guard AXValueGetType(castValue) == .cgPoint else {
            return nil
        }

        var point = CGPoint.zero
        return AXValueGetValue(castValue, .cgPoint, &point) ? point : nil
    }

    private func sizeAttribute(_ attribute: CFString, element: AXUIElement) -> CGSize? {
        var value: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(element, attribute, &value)
        guard result == .success, let axValue = value, CFGetTypeID(axValue) == AXValueGetTypeID() else {
            return nil
        }

        let castValue = axValue as! AXValue
        guard AXValueGetType(castValue) == .cgSize else {
            return nil
        }

        var size = CGSize.zero
        return AXValueGetValue(castValue, .cgSize, &size) ? size : nil
    }
}

import ApplicationServices
import Foundation

public enum AXReplacementWriterError: LocalizedError {
    case unsupportedSelection
    case failedWrite

    public var errorDescription: String? {
        switch self {
            case .unsupportedSelection:
                "Selection cannot be replaced directly"
            case .failedWrite:
                "Direct replacement failed"
        }
    }
}

public final class AXReplacementWriter {
    public init() {}

    public func replaceSelectedText(
        in element: AXUIElement,
        context: SelectionContext,
        with replacement: String
    ) throws {
        if replaceViaSelectedTextAttribute(in: element, with: replacement) {
            return
        }

        guard replaceViaValueAttribute(in: element, context: context, with: replacement) else {
            throw AXReplacementWriterError.failedWrite
        }
    }

    private func replaceViaSelectedTextAttribute(in element: AXUIElement, with replacement: String) -> Bool {
        let result = AXUIElementSetAttributeValue(
            element,
            kAXSelectedTextAttribute as CFString,
            replacement as CFTypeRef
        )

        return result == .success
    }

    private func replaceViaValueAttribute(
        in element: AXUIElement,
        context: SelectionContext,
        with replacement: String
    ) -> Bool {
        var value: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(element, kAXValueAttribute as CFString, &value)
        guard result == .success, let currentValue = value as? String else {
            return false
        }

        let currentNSString = currentValue as NSString
        let range = NSRange(location: context.range.location, length: context.range.length)
        guard NSMaxRange(range) <= currentNSString.length else {
            return false
        }

        let updated = currentNSString.replacingCharacters(in: range, with: replacement)
        guard AXUIElementSetAttributeValue(element, kAXValueAttribute as CFString, updated as CFTypeRef) == .success
        else {
            return false
        }

        var cursorRange = CFRange(location: range.location + (replacement as NSString).length, length: 0)
        guard let cursorValue = AXValueCreate(.cfRange, &cursorRange) else {
            return true
        }

        _ = AXUIElementSetAttributeValue(
            element,
            kAXSelectedTextRangeAttribute as CFString,
            cursorValue
        )
        return true
    }
}

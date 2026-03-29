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
        if element.axSet(kAXSelectedTextAttribute as CFString, value: replacement as CFTypeRef) {
            return
        }

        guard replaceViaValueAttribute(in: element, context: context, with: replacement) else {
            throw AXReplacementWriterError.failedWrite
        }
    }

    private func replaceViaValueAttribute(
        in element: AXUIElement,
        context: SelectionContext,
        with replacement: String
    ) -> Bool {
        guard let currentValue: String = element.axAttribute(kAXValueAttribute as CFString) else {
            return false
        }

        let currentNSString = currentValue as NSString
        let range = NSRange(location: context.range.location, length: context.range.length)
        guard NSMaxRange(range) <= currentNSString.length else {
            return false
        }

        let updated = currentNSString.replacingCharacters(in: range, with: replacement)
        guard element.axSet(kAXValueAttribute as CFString, value: updated as CFTypeRef) else {
            return false
        }

        element.axSetRange(
            kAXSelectedTextRangeAttribute as CFString,
            range: CFRange(location: range.location + (replacement as NSString).length, length: 0)
        )
        return true
    }
}

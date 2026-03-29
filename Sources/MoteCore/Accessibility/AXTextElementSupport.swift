import AppKit
import ApplicationServices

public enum AXTextElementSupport {
    public static func stringAttribute(_ attribute: CFString, element: AXUIElement) -> String? {
        element.axAttribute(attribute)
    }

    public static func isWritable(element: AXUIElement) -> Bool {
        element.axIsSettable(kAXSelectedTextAttribute as CFString)
            || element.axIsSettable(kAXValueAttribute as CFString)
    }

    public static func uniqueRange(of selectedText: String, in fieldText: String?) -> SelectionRange? {
        guard let fieldText, !fieldText.isEmpty else {
            return nil
        }

        let nsFieldText = fieldText as NSString
        let nsSelectedText = selectedText as NSString
        guard nsSelectedText.length > 0 else {
            return nil
        }

        let firstMatch = nsFieldText.range(of: selectedText)
        guard firstMatch.location != NSNotFound else {
            return nil
        }

        let searchStart = firstMatch.location + 1
        if searchStart < nsFieldText.length {
            let remainingRange = NSRange(location: searchStart, length: nsFieldText.length - searchStart)
            let secondMatch = nsFieldText.range(of: selectedText, options: [], range: remainingRange)
            guard secondMatch.location == NSNotFound else {
                return nil
            }
        }

        return SelectionRange(location: firstMatch.location, length: firstMatch.length)
    }

    public static func focusedElement(from systemWide: AXUIElement) -> AXUIElement? {
        systemWide.axElement(kAXFocusedUIElementAttribute as CFString)
    }

    public static func textMarkerRange(from proof: TextMarkerRangeProof) -> AXTextMarkerRange? {
        guard
            let startMarker = textMarker(from: proof.startMarker),
            let endMarker = textMarker(from: proof.endMarker)
        else {
            return nil
        }
        return AXTextMarkerRangeCreate(nil, startMarker, endMarker)
    }

    public static func textMarker(from data: Data) -> AXTextMarker? {
        guard !data.isEmpty else {
            return nil
        }
        return data.withUnsafeBytes { rawBuffer in
            guard let baseAddress = rawBuffer.baseAddress else {
                return nil
            }
            let bytePointer = baseAddress.assumingMemoryBound(to: UInt8.self)
            return AXTextMarkerCreate(nil, bytePointer, rawBuffer.count)
        }
    }

    public static func isSecure(element: AXUIElement) -> Bool {
        let protected: Bool? = element.axAttribute("AXValueProtected" as CFString)
        let content: Bool? = element.axAttribute("AXProtectedContent" as CFString)
        return protected == true || content == true
    }

    public static func isFrontmost(processIdentifier: Int32) -> Bool {
        guard processIdentifier != 0 else { return false }
        return NSWorkspace.shared.frontmostApplication?.processIdentifier == processIdentifier
    }

    public static func mousePositionInAXCoordinates() -> CGRect {
        let mouse = NSEvent.mouseLocation
        let screenHeight = NSScreen.main?.frame.height ?? 0
        return CGRect(
            origin: CGPoint(x: mouse.x, y: screenHeight - mouse.y),
            size: .zero
        )
    }
}

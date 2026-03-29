import AppKit
import ApplicationServices
import Foundation

public enum AXTextElementSupport {
    public static func stringAttribute(_ attribute: CFString, element: AXUIElement) -> String? {
        var value: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(element, attribute, &value)
        guard result == .success, let value else {
            return nil
        }

        return value as? String
    }

    public static func isWritable(element: AXUIElement) -> Bool {
        var selectedTextSettable = DarwinBoolean(false)
        if AXUIElementIsAttributeSettable(
            element,
            kAXSelectedTextAttribute as CFString,
            &selectedTextSettable
        ) == .success, selectedTextSettable.boolValue {
            return true
        }

        var valueSettable = DarwinBoolean(false)
        return AXUIElementIsAttributeSettable(
            element,
            kAXValueAttribute as CFString,
            &valueSettable
        ) == .success && valueSettable.boolValue
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
        var value: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(
            systemWide,
            kAXFocusedUIElementAttribute as CFString,
            &value
        )
        guard result == .success, let value, CFGetTypeID(value) == AXUIElementGetTypeID() else {
            return nil
        }
        return (value as! AXUIElement)
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
        if boolAttribute("AXValueProtected" as CFString, element: element) == true {
            return true
        }
        if boolAttribute("AXProtectedContent" as CFString, element: element) == true {
            return true
        }
        return false
    }

    static func boolAttribute(_ attribute: CFString, element: AXUIElement) -> Bool? {
        var value: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(element, attribute, &value)
        guard result == .success, let value else {
            return nil
        }
        return value as? Bool
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

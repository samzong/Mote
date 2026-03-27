import ApplicationServices
import AppKit
import Foundation

public final class AXSelectionReader {
    private let boundsResolver: AXBoundsResolver

    public init(boundsResolver: AXBoundsResolver = AXBoundsResolver()) {
        self.boundsResolver = boundsResolver
    }

    public func readFocusedSelection() -> AXSelectionSnapshot? {
        guard AccessibilityPermission.isTrusted() else {
            return nil
        }

        let systemWide = AXUIElementCreateSystemWide()
        guard let focusedElement = focusedElement(from: systemWide) else {
            return nil
        }

        let candidates = candidateElements(startingAt: focusedElement)
        for element in candidates {
            if let snapshot = snapshot(for: element, fallbackElement: focusedElement) {
                return snapshot
            }
        }

        return nil
    }

    public func frontmostBundleIdentifier() -> String? {
        NSWorkspace.shared.frontmostApplication?.bundleIdentifier
    }

    private func focusedElement(from systemWide: AXUIElement) -> AXUIElement? {
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

    private func snapshot(for element: AXUIElement, fallbackElement: AXUIElement) -> AXSelectionSnapshot? {
        guard let range = selectedRange(for: element), range.length > 0 else {
            return nil
        }

        guard let text = selectedText(for: element, range: range), !text.isEmpty else {
            return nil
        }

        let processIdentifier = processIdentifier(for: element) ?? processIdentifier(for: fallbackElement)
        let bundleIdentifier = processIdentifier.flatMap { NSRunningApplication(processIdentifier: $0)?.bundleIdentifier }
        let bounds = boundsResolver.resolveSelectionBounds(for: element, range: range)
            ?? boundsResolver.resolveElementBounds(for: element)
            ?? boundsResolver.resolveElementBounds(for: fallbackElement)
        let context = SelectionContext(
            bundleIdentifier: bundleIdentifier,
            processIdentifier: processIdentifier ?? 0,
            text: text,
            range: range,
            bounds: bounds,
            isSecure: isSecure(element: element) || isSecure(element: fallbackElement),
            isWritable: isWritable(element: element) || isWritable(element: fallbackElement)
        )

        guard context.isValid else {
            return nil
        }

        return AXSelectionSnapshot(element: element, context: context)
    }

    private func candidateElements(startingAt focusedElement: AXUIElement) -> [AXUIElement] {
        var ordered: [AXUIElement] = []
        var visited = Set<OpaquePointer>()

        func append(_ element: AXUIElement?) {
            guard let element else {
                return
            }

            let pointer = opaquePointer(for: element)
            guard !visited.contains(pointer) else {
                return
            }

            visited.insert(pointer)
            ordered.append(element)
        }

        append(focusedElement)

        var currentParent = parent(of: focusedElement)
        var ancestorDepth = 0
        while ancestorDepth < 4 {
            append(currentParent)
            currentParent = currentParent.flatMap(parent(of:))
            ancestorDepth += 1
        }

        for element in ordered {
            for descendant in descendants(of: element, maxDepth: 3) {
                append(descendant)
            }
        }

        return ordered
    }

    private func descendants(of element: AXUIElement, maxDepth: Int) -> [AXUIElement] {
        guard maxDepth > 0 else {
            return []
        }

        let children = children(of: element)
        return children + children.flatMap { descendants(of: $0, maxDepth: maxDepth - 1) }
    }

    private func children(of element: AXUIElement) -> [AXUIElement] {
        var value: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(element, kAXChildrenAttribute as CFString, &value)
        guard result == .success, let value, let array = value as? [Any] else {
            return []
        }

        return array.compactMap { item in
            guard CFGetTypeID(item as CFTypeRef) == AXUIElementGetTypeID() else {
                return nil
            }

            return (item as! AXUIElement)
        }
    }

    private func parent(of element: AXUIElement) -> AXUIElement? {
        var value: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(element, kAXParentAttribute as CFString, &value)
        guard result == .success, let value, CFGetTypeID(value) == AXUIElementGetTypeID() else {
            return nil
        }

        return (value as! AXUIElement)
    }

    private func selectedRange(for element: AXUIElement) -> SelectionRange? {
        var value: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(element, kAXSelectedTextRangeAttribute as CFString, &value)
        guard result == .success, let axValue = value, CFGetTypeID(axValue) == AXValueGetTypeID() else {
            return nil
        }

        let castValue = axValue as! AXValue
        guard AXValueGetType(castValue) == .cfRange else {
            return nil
        }

        var range = CFRange()
        guard AXValueGetValue(castValue, .cfRange, &range) else {
            return nil
        }

        return SelectionRange(location: range.location, length: range.length)
    }

    private func stringAttribute(_ attribute: CFString, element: AXUIElement) -> String? {
        var value: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(element, attribute, &value)
        guard result == .success, let value else {
            return nil
        }

        return value as? String
    }

    private func selectedText(for element: AXUIElement, range: SelectionRange) -> String? {
        if let text = stringAttribute(kAXSelectedTextAttribute as CFString, element: element), !text.isEmpty {
            return text
        }

        if let text = stringForRange(element: element, range: range), !text.isEmpty {
            return text
        }

        guard let value = stringAttribute(kAXValueAttribute as CFString, element: element) else {
            return nil
        }

        let nsValue = value as NSString
        let selectedRange = NSRange(location: range.location, length: range.length)
        guard NSMaxRange(selectedRange) <= nsValue.length else {
            return nil
        }

        return nsValue.substring(with: selectedRange)
    }

    private func stringForRange(element: AXUIElement, range: SelectionRange) -> String? {
        var cfRange = CFRange(location: range.location, length: range.length)
        guard let rangeValue = AXValueCreate(.cfRange, &cfRange) else {
            return nil
        }

        var value: CFTypeRef?
        let result = AXUIElementCopyParameterizedAttributeValue(
            element,
            kAXStringForRangeParameterizedAttribute as CFString,
            rangeValue,
            &value
        )

        guard result == .success, let value else {
            return nil
        }

        return value as? String
    }

    private func boolAttribute(_ attribute: CFString, element: AXUIElement) -> Bool? {
        var value: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(element, attribute, &value)
        guard result == .success, let value else {
            return nil
        }

        return value as? Bool
    }

    private func isSecure(element: AXUIElement) -> Bool {
        if boolAttribute("AXValueProtected" as CFString, element: element) == true {
            return true
        }

        if boolAttribute("AXProtectedContent" as CFString, element: element) == true {
            return true
        }

        return false
    }

    private func processIdentifier(for element: AXUIElement) -> pid_t? {
        var pid: pid_t = 0
        guard AXUIElementGetPid(element, &pid) == .success else {
            return nil
        }

        return pid
    }

    private func isWritable(element: AXUIElement) -> Bool {
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

    private func opaquePointer(for element: AXUIElement) -> OpaquePointer {
        OpaquePointer(Unmanaged.passUnretained(element).toOpaque())
    }
}

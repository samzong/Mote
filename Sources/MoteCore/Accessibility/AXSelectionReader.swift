import AppKit
import ApplicationServices
import Foundation

public final class AXSelectionReader {
    private let boundsResolver: AXBoundsResolver

    public init(boundsResolver: AXBoundsResolver = AXBoundsResolver()) {
        self.boundsResolver = boundsResolver
    }

    public func readFocusedSelection() -> AXSelectionSnapshot? {
        guard AccessibilityPermission.isTrusted() else {
            Logger.debug("ax-read: NOT TRUSTED")
            return nil
        }

        let systemWide = AXUIElementCreateSystemWide()
        guard let focusedElement = AXTextElementSupport.focusedElement(from: systemWide) else {
            Logger.debug("ax-read: no focused element")
            return nil
        }

        Logger.debug("ax-read: focused element found")
        let candidates = candidateElements(startingAt: focusedElement)
        Logger.debug("ax-read: \(candidates.count) candidate elements")

        for (i, element) in candidates.enumerated() {
            if let snapshot = snapshot(for: element, fallbackElement: focusedElement) {
                let b = String(describing: snapshot.context.bounds)
                Logger.debug("ax-read: candidate[\(i)] text.count=\(snapshot.context.text.count) bounds=\(b)")
                return snapshot
            }
        }

        Logger.debug("ax-read: no snapshot from any candidate")
        return nil
    }

    public func frontmostBundleIdentifier() -> String? {
        NSWorkspace.shared.frontmostApplication?.bundleIdentifier
    }

    public func validatedSelection(for snapshot: AXSelectionSnapshot) -> AXSelectionSnapshot? {
        guard snapshot.proof.isProven,
              let currentSnapshot = readFocusedSelection(),
              currentSnapshot.context.processIdentifier == snapshot.context.processIdentifier,
              currentSnapshot.context.text == snapshot.context.text
        else {
            return nil
        }

        switch (snapshot.proof, currentSnapshot.proof) {
            case let (.exactRange(lhs), .exactRange(rhs)):
                return lhs == rhs ? currentSnapshot : nil
            case let (.textMarker(lhs), .textMarker(rhs)):
                return lhs == rhs ? currentSnapshot : nil
            case let (.hostAdapterProof(lhs), .hostAdapterProof(rhs)):
                return lhs == rhs ? currentSnapshot : nil
            case (.unproven, _), (_, .unproven):
                return nil
            default:
                return nil
        }
    }

    private func snapshot(for element: AXUIElement, fallbackElement: AXUIElement) -> AXSelectionSnapshot? {
        let range = selectedRange(for: element)
        let textMarkerRange = selectedTextMarkerRange(for: element)
        let fieldText = AXTextElementSupport.stringAttribute(kAXValueAttribute as CFString, element: element)

        let text: String? = if let range, range.length > 0 {
            selectedText(for: element, range: range)
        } else if let textMarkerRange {
            selectedText(for: element, textMarkerRange: textMarkerRange)
        } else {
            AXTextElementSupport.stringAttribute(kAXSelectedTextAttribute as CFString, element: element)
        }

        guard let text, !text.isEmpty else {
            Logger.debug("ax-snap: no text from any method")
            return nil
        }

        let proof: SelectionProof
        let effectiveRange: SelectionRange
        if let range, range.length > 0 {
            proof = .exactRange(range)
            effectiveRange = range
        } else if let uniqueRange = AXTextElementSupport.uniqueRange(of: text, in: fieldText) {
            proof = .exactRange(uniqueRange)
            effectiveRange = uniqueRange
        } else if let textMarkerRange {
            proof = .textMarker(textMarkerRange)
            effectiveRange = SelectionRange(location: 0, length: (text as NSString).length)
        } else {
            proof = .unproven
            effectiveRange = SelectionRange(location: 0, length: (text as NSString).length)
        }

        let processIdentifier = processIdentifier(for: element) ?? processIdentifier(for: fallbackElement)
        let bundleIdentifier = processIdentifier
            .flatMap { NSRunningApplication(processIdentifier: $0)?.bundleIdentifier }

        let bounds: CGRect? = switch proof {
            case let .exactRange(range):
                boundsResolver.resolveSelectionBounds(for: element, range: range)
                    ?? boundsResolver.resolveElementBounds(for: element)
                    ?? boundsResolver.resolveElementBounds(for: fallbackElement)
            case let .textMarker(textMarkerRange):
                boundsResolver.resolveTextMarkerRangeBounds(for: element, proof: textMarkerRange)
                    ?? boundsResolver.resolveElementBounds(for: element)
                    ?? boundsResolver.resolveElementBounds(for: fallbackElement)
            case .hostAdapterProof, .unproven:
                boundsResolver.resolveElementBounds(for: element)
                    ?? boundsResolver.resolveElementBounds(for: fallbackElement)
        }

        let sec = AXTextElementSupport.isSecure(element: element)
        let wrt = AXTextElementSupport.isWritable(element: element)
        Logger.debug(
            "ax-snap: text=\(text.count) pid=\(processIdentifier ?? 0) " +
                "bundle=\(bundleIdentifier ?? "nil") sec=\(sec) wrt=\(wrt)"
        )

        let context = SelectionContext(
            bundleIdentifier: bundleIdentifier,
            processIdentifier: processIdentifier ?? 0,
            text: text,
            range: effectiveRange,
            bounds: bounds,
            isSecure: AXTextElementSupport.isSecure(element: element) || AXTextElementSupport
                .isSecure(element: fallbackElement),
            isWritable: AXTextElementSupport.isWritable(element: element) ||
                AXTextElementSupport.isWritable(element: fallbackElement)
        )

        guard context.isValid else {
            Logger.debug("ax-snap: context.isValid=false")
            return nil
        }

        let writebackCapability = proof.defaultWritebackCapability(isWritable: context.isWritable)
        return AXSelectionSnapshot(
            element: element,
            context: context,
            proof: proof,
            writebackCapability: writebackCapability,
            fieldText: fieldText
        )
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

    private func selectedTextMarkerRange(for element: AXUIElement) -> TextMarkerRangeProof? {
        var value: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(
            element,
            "AXSelectedTextMarkerRange" as CFString,
            &value
        )
        guard result == .success,
              let value,
              CFGetTypeID(value) == AXTextMarkerRangeGetTypeID()
        else {
            return nil
        }

        let textMarkerRange = value as! AXTextMarkerRange
        return serializeTextMarkerRange(textMarkerRange)
    }

    private func selectedText(for element: AXUIElement, range: SelectionRange) -> String? {
        if let text = AXTextElementSupport.stringAttribute(kAXSelectedTextAttribute as CFString, element: element),
           !text.isEmpty
        {
            return text
        }

        if let text = stringForRange(element: element, range: range), !text.isEmpty {
            return text
        }

        guard let value = AXTextElementSupport.stringAttribute(kAXValueAttribute as CFString, element: element) else {
            return nil
        }

        let nsValue = value as NSString
        let selectedRange = NSRange(location: range.location, length: range.length)
        guard NSMaxRange(selectedRange) <= nsValue.length else {
            return nil
        }

        return nsValue.substring(with: selectedRange)
    }

    private func selectedText(for element: AXUIElement, textMarkerRange: TextMarkerRangeProof) -> String? {
        if let text = stringForTextMarkerRange(element: element, proof: textMarkerRange), !text.isEmpty {
            return text
        }

        if let text = AXTextElementSupport.stringAttribute(kAXSelectedTextAttribute as CFString, element: element),
           !text.isEmpty
        {
            return text
        }

        return nil
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

    private func stringForTextMarkerRange(
        element: AXUIElement,
        proof: TextMarkerRangeProof
    ) -> String? {
        guard let textMarkerRange = AXTextElementSupport.textMarkerRange(from: proof) else {
            return nil
        }

        var value: CFTypeRef?
        let result = AXUIElementCopyParameterizedAttributeValue(
            element,
            "AXStringForTextMarkerRange" as CFString,
            textMarkerRange,
            &value
        )

        guard result == .success, let value else {
            return nil
        }

        return value as? String
    }

    private func processIdentifier(for element: AXUIElement) -> pid_t? {
        var pid: pid_t = 0
        guard AXUIElementGetPid(element, &pid) == .success else {
            return nil
        }

        return pid
    }

    private func opaquePointer(for element: AXUIElement) -> OpaquePointer {
        OpaquePointer(Unmanaged.passUnretained(element).toOpaque())
    }

    private func serializeTextMarkerRange(_ textMarkerRange: AXTextMarkerRange) -> TextMarkerRangeProof? {
        let startMarker = AXTextMarkerRangeCopyStartMarker(textMarkerRange)
        let endMarker = AXTextMarkerRangeCopyEndMarker(textMarkerRange)

        guard let startData = data(for: startMarker),
              let endData = data(for: endMarker)
        else {
            return nil
        }

        return TextMarkerRangeProof(startMarker: startData, endMarker: endData)
    }

    private func data(for textMarker: AXTextMarker) -> Data? {
        let length = AXTextMarkerGetLength(textMarker)
        guard length > 0 else {
            return nil
        }

        let bytePointer = AXTextMarkerGetBytePtr(textMarker)
        return Data(bytes: bytePointer, count: length)
    }
}

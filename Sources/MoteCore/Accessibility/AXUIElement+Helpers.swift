import ApplicationServices

extension AXUIElement {
    func axAttribute<T>(_ attr: CFString) -> T? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(self, attr, &value) == .success,
              let value else { return nil }
        return value as? T
    }

    func axElement(_ attr: CFString) -> AXUIElement? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(self, attr, &value) == .success,
              let value,
              CFGetTypeID(value) == AXUIElementGetTypeID() else { return nil }
        return (value as! AXUIElement)
    }

    func axElements(_ attr: CFString) -> [AXUIElement] {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(self, attr, &value) == .success,
              let value,
              let array = value as? [Any] else { return [] }
        return array.compactMap { item in
            let ref = item as CFTypeRef
            guard CFGetTypeID(ref) == AXUIElementGetTypeID() else { return nil }
            return (ref as! AXUIElement)
        }
    }

    func axIsSettable(_ attr: CFString) -> Bool {
        var settable = DarwinBoolean(false)
        return AXUIElementIsAttributeSettable(self, attr, &settable) == .success
            && settable.boolValue
    }

    @discardableResult
    func axSet(_ attr: CFString, value: CFTypeRef) -> Bool {
        AXUIElementSetAttributeValue(self, attr, value) == .success
    }

    func axPoint(_ attr: CFString) -> CGPoint? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(self, attr, &value) == .success,
              let value,
              CFGetTypeID(value) == AXValueGetTypeID() else { return nil }
        let axVal = value as! AXValue
        guard AXValueGetType(axVal) == .cgPoint else { return nil }
        var pt = CGPoint.zero
        return AXValueGetValue(axVal, .cgPoint, &pt) ? pt : nil
    }

    func axSize(_ attr: CFString) -> CGSize? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(self, attr, &value) == .success,
              let value,
              CFGetTypeID(value) == AXValueGetTypeID() else { return nil }
        let axVal = value as! AXValue
        guard AXValueGetType(axVal) == .cgSize else { return nil }
        var sz = CGSize.zero
        return AXValueGetValue(axVal, .cgSize, &sz) ? sz : nil
    }

    func axCFRange(_ attr: CFString) -> CFRange? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(self, attr, &value) == .success,
              let value,
              CFGetTypeID(value) == AXValueGetTypeID() else { return nil }
        let axVal = value as! AXValue
        guard AXValueGetType(axVal) == .cfRange else { return nil }
        var range = CFRange()
        return AXValueGetValue(axVal, .cfRange, &range) ? range : nil
    }

    func axParameterized<T>(_ attr: CFString, param: CFTypeRef) -> T? {
        var value: CFTypeRef?
        guard AXUIElementCopyParameterizedAttributeValue(self, attr, param, &value) == .success,
              let value else { return nil }
        return value as? T
    }

    func axParameterizedRect(_ attr: CFString, param: CFTypeRef) -> CGRect? {
        var value: CFTypeRef?
        guard AXUIElementCopyParameterizedAttributeValue(self, attr, param, &value) == .success,
              let value,
              CFGetTypeID(value) == AXValueGetTypeID() else { return nil }
        let axVal = value as! AXValue
        guard AXValueGetType(axVal) == .cgRect else { return nil }
        var rect = CGRect.zero
        return AXValueGetValue(axVal, .cgRect, &rect) ? rect : nil
    }

    func axPid() -> pid_t? {
        var pid: pid_t = 0
        return AXUIElementGetPid(self, &pid) == .success ? pid : nil
    }

    @discardableResult
    func axSetRange(_ attr: CFString, range: CFRange) -> Bool {
        var range = range
        guard let value = AXValueCreate(.cfRange, &range) else { return false }
        return axSet(attr, value: value)
    }
}

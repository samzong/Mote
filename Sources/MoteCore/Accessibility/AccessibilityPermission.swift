import ApplicationServices

public enum AccessibilityPermission {
    public static func isTrusted() -> Bool {
        AXIsProcessTrusted()
    }

    @discardableResult
    public static func requestAccess() -> Bool {
        let options = ["AXTrustedCheckOptionPrompt": true] as CFDictionary
        return AXIsProcessTrustedWithOptions(options)
    }
}

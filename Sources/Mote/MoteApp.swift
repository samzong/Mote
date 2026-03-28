import AppKit
import MoteCore

@main
struct MoteApp {
    static func main() {
        if !AccessibilityPermission.isTrusted() {
            AccessibilityPermission.requestAccess()
        }

        let app = NSApplication.shared
        app.setActivationPolicy(.accessory)
        let delegate = AppDelegate()
        app.delegate = delegate
        withExtendedLifetime(delegate) {
            app.run()
        }
    }
}

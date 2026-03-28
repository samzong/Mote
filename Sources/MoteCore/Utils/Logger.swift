import Foundation

public enum Logger {
    public nonisolated(unsafe) static var debugEnabled = true

    public static func info(_ message: String) {
        fputs("[Mote] \(message)\n", stderr)
    }

    public static func debug(_ message: String) {
        guard debugEnabled else { return }
        fputs("[Mote:DBG] \(message)\n", stderr)
    }
}

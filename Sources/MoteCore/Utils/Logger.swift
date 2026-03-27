import Foundation

public enum Logger {
    public static func info(_ message: String) {
        fputs("[Mote] \(message)\n", stderr)
    }
}

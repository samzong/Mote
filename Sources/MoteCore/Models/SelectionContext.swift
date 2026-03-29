import CoreGraphics
import Foundation

public struct SelectionRange: Equatable, Sendable {
    public var location: Int
    public var length: Int

    public init(location: Int, length: Int) {
        self.location = location
        self.length = length
    }
}

public struct SelectionContext: Equatable, Sendable {
    public var bundleIdentifier: String?
    public var processIdentifier: Int32
    public var text: String
    public var range: SelectionRange
    public var bounds: CGRect?
    public var isSecure: Bool
    public var isWritable: Bool

    public init(
        bundleIdentifier: String?,
        processIdentifier: Int32,
        text: String,
        range: SelectionRange,
        bounds: CGRect?,
        isSecure: Bool,
        isWritable: Bool
    ) {
        self.bundleIdentifier = bundleIdentifier
        self.processIdentifier = processIdentifier
        self.text = text
        self.range = range
        self.bounds = bounds
        self.isSecure = isSecure
        self.isWritable = isWritable
    }

    public init(bundleIdentifier: String?, text: String) {
        self.init(
            bundleIdentifier: bundleIdentifier,
            processIdentifier: 0,
            text: text,
            range: SelectionRange(location: 0, length: (text as NSString).length),
            bounds: nil,
            isSecure: false,
            isWritable: true
        )
    }

    public var isValid: Bool {
        !text.isEmpty && range.length > 0 && !isSecure
    }
}

import Foundation

public struct RewriteResult: Equatable, Sendable {
    public var output: String

    public init(output: String) {
        self.output = output
    }
}

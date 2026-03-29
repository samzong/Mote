public struct RewritePreset: Equatable, Sendable {
    public var prompt: String

    public init(prompt: String) {
        self.prompt = prompt
    }
}

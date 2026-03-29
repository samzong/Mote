public struct RewriteRequest: Equatable, Sendable {
    public var instruction: String
    public var selection: SelectionContext

    public init(instruction: String, selection: SelectionContext) {
        self.instruction = instruction
        self.selection = selection
    }
}

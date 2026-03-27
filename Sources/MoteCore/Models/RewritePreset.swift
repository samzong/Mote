public struct RewritePreset: Equatable, Sendable {
    public var id: String
    public var name: String
    public var description: String
    public var order: Int
    public var prompt: String

    public init(id: String, name: String, description: String, order: Int, prompt: String) {
        self.id = id
        self.name = name
        self.description = description
        self.order = order
        self.prompt = prompt
    }
}

import Foundation

public struct ChatMessage: Codable, Equatable, Sendable {
    public var role: String
    public var content: String

    public init(role: String, content: String) {
        self.role = role
        self.content = content
    }
}

public struct ChatCompletionRequest: Codable, Equatable, Sendable {
    public var model: String
    public var messages: [ChatMessage]
    public var temperature: Double
    public var maxTokens: Int
    public var stream: Bool

    public init(model: String, messages: [ChatMessage], temperature: Double, maxTokens: Int, stream: Bool) {
        self.model = model
        self.messages = messages
        self.temperature = temperature
        self.maxTokens = maxTokens
        self.stream = stream
    }
}

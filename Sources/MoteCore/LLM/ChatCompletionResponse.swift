import Foundation

public struct ChatCompletionResponse: Codable, Equatable, Sendable {
    public struct Choice: Codable, Equatable, Sendable {
        public struct Message: Codable, Equatable, Sendable {
            public var role: String
            public var content: String

            public init(role: String, content: String) {
                self.role = role
                self.content = content
            }
        }

        public var message: Message

        public init(message: Message) {
            self.message = message
        }
    }

    public var choices: [Choice]

    public init(choices: [Choice]) {
        self.choices = choices
    }
}

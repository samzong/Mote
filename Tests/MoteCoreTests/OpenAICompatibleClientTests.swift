import Foundation
import Testing
@testable import MoteCore

struct OpenAICompatibleClientTests {
    private let config = AppConfig(
        baseURL: "http://127.0.0.1:1234/v1",
        apiKey: "lm-studio",
        model: "qwen2.5-7b-instruct",
        temperature: 0.2,
        maxTokens: 1024,
        hotkey: .init(key: "space", modifiers: ["option"])
    )

    @Test
    func buildsExpectedEndpointURL() throws {
        let client = OpenAICompatibleClient()

        let url = try #require(client.buildURL(from: config))

        #expect(url.absoluteString == "http://127.0.0.1:1234/v1/chat/completions")
    }

    @Test
    func requestConstructionUsesConfigAndOpenAIShape() throws {
        let client = OpenAICompatibleClient()

        let request = try client.makeRequest(
            config: config,
            messages: [ChatMessage(role: "user", content: "Ping")]
        )

        #expect(request.httpMethod == "POST")
        #expect(request.url?.absoluteString == "http://127.0.0.1:1234/v1/chat/completions")
        #expect(request.value(forHTTPHeaderField: "Content-Type") == "application/json")
        #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer lm-studio")

        let data = try #require(request.httpBody)
        let object = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
        let messages = try #require(object["messages"] as? [[String: String]])
        let firstMessage = try #require(messages.first)

        #expect(object["model"] as? String == "qwen2.5-7b-instruct")
        #expect(object["temperature"] as? Double == 0.2)
        #expect(object["max_tokens"] as? Int == 1024)
        #expect(object["stream"] as? Bool == false)
        #expect(firstMessage["role"] == "user")
        #expect(firstMessage["content"] == "Ping")
    }
}

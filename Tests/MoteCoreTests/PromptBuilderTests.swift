@testable import MoteCore
import Testing

struct PromptBuilderTests {
    @Test
    func buildsSystemAndUserMessages() {
        let request = RewriteRequest(
            instruction: "Shorten this.",
            selection: SelectionContext(bundleIdentifier: "com.apple.TextEdit", text: "Long text")
        )

        let messages = PromptBuilder.buildMessages(for: request)

        #expect(messages.count == 2)
        #expect(messages[0].role == "system")
        #expect(messages[0].content.contains("text rewriting engine"))
        #expect(messages[1].content == "Instruction:\nShorten this.\n\nSelected text:\nLong text")
    }
}

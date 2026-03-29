@testable import MoteCore
import Testing

struct PromptBuilderTests {
    @Test
    func usesPresetTemplateWhenInstructionIsBlank() {
        let request = RewriteRequest(
            preset: RewritePreset(
                id: "shorten",
                name: "Shorten",
                description: "Shorten text.",
                order: 30,
                prompt: "Shorten this."
            ),
            instruction: "   ",
            selection: SelectionContext(bundleIdentifier: "com.apple.TextEdit", text: "Long text")
        )

        let messages = PromptBuilder.buildMessages(for: request)

        #expect(messages.count == 2)
        #expect(messages[0].role == "system")
        #expect(messages[0].content.contains("precise rewrite assistant"))
        #expect(messages[1].content == "Instruction:\nShorten this.\n\nSelected text:\nLong text")
    }
}

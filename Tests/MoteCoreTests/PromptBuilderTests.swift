import Testing
@testable import MoteCore

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

    @Test
    func prefersExplicitInstructionOverPresetTemplate() {
        let request = RewriteRequest(
            preset: RewritePreset(
                id: "translate",
                name: "Translate",
                description: "Translate text.",
                order: 10,
                prompt: "Translate this."
            ),
            instruction: "Rewrite in plain English.",
            selection: SelectionContext(bundleIdentifier: nil, text: "原文")
        )

        let messages = PromptBuilder.buildMessages(for: request)

        #expect(messages[1].content == "Instruction:\nRewrite in plain English.\n\nSelected text:\n原文")
    }
}

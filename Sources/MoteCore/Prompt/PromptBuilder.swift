import Foundation

public enum PromptBuilder {
    private static let systemPrompt =
        "You are a text rewriting engine. " +
        "Output ONLY the rewritten text — nothing else. " +
        "Do NOT include explanations, notes, alternatives, or commentary. " +
        "Do NOT wrap the output in code blocks, quotes, or markdown formatting. " +
        "The output must be a direct, drop-in replacement for the original text. " +
        "Preserve structure and formatting unless the instruction explicitly changes them."

    public static func buildMessages(for request: RewriteRequest) -> [ChatMessage] {
        let raw = request.instruction.trimmingCharacters(in: .whitespacesAndNewlines)
        let instruction = raw.isEmpty ? request.preset.prompt : CommandLoader.resolve(instruction: raw)
        let content = "Instruction:\n\(instruction)\n\nSelected text:\n\(request.selection.text)"
        return [
            ChatMessage(role: "system", content: systemPrompt),
            ChatMessage(role: "user", content: content),
        ]
    }
}

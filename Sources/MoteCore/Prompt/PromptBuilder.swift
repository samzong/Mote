import Foundation

public enum PromptBuilder {
    private static let systemPrompt = "You are a precise rewrite assistant. Follow the instruction exactly. Preserve meaning, structure, and formatting unless the instruction explicitly changes them."

    public static func buildMessages(for request: RewriteRequest) -> [ChatMessage] {
        let trimmedInstruction = request.instruction.trimmingCharacters(in: .whitespacesAndNewlines)
        let instruction = trimmedInstruction.isEmpty ? request.preset.prompt : trimmedInstruction
        let content = "Instruction:\n\(instruction)\n\nSelected text:\n\(request.selection.text)"
        return [
            ChatMessage(role: "system", content: systemPrompt),
            ChatMessage(role: "user", content: content),
        ]
    }
}

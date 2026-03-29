import Foundation

public enum CommandLoader {
    public static func commandsDirectory() -> URL {
        ConfigLoader.configDirectory()
            .appendingPathComponent("commands", isDirectory: true)
    }

    public static func loadCommands() -> [String: String] {
        let dir = commandsDirectory()
        guard let files = try? FileManager.default.contentsOfDirectory(
            at: dir, includingPropertiesForKeys: nil
        ) else {
            return [:]
        }

        var commands: [String: String] = [:]
        for file in files {
            let name = file.deletingPathExtension().lastPathComponent
            guard file.pathExtension == "md",
                  !name.hasPrefix("_"),
                  let content = try? String(contentsOf: file, encoding: .utf8)
            else { continue }
            let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty {
                commands[name] = trimmed
            }
        }
        return commands
    }

    public static func resolve(instruction: String) -> String {
        let trimmed = instruction.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.hasPrefix("/") else { return trimmed }

        let parts = trimmed.split(separator: " ", maxSplits: 1)
        let commandName = String(parts[0].dropFirst())
        guard !commandName.isEmpty else { return trimmed }

        let commands = loadCommands()
        guard let prompt = commands[commandName] else { return trimmed }

        if parts.count > 1 {
            return prompt + "\n" + String(parts[1])
        }
        return prompt
    }
}

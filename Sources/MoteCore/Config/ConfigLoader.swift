import Foundation

public enum ConfigLoader {
    public static func configDirectory() -> URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".config", isDirectory: true)
            .appendingPathComponent("mote", isDirectory: true)
    }

    public static func configURL() -> URL {
        configDirectory().appendingPathComponent("config.json")
    }

    public static func loadConfig() throws -> AppConfig {
        let data = try Data(contentsOf: configURL())
        return try JSONDecoder().decode(AppConfig.self, from: data)
    }

    public static func saveDefaultFilesIfNeeded() throws {
        let fileManager = FileManager.default
        try fileManager.createDirectory(at: configDirectory(), withIntermediateDirectories: true)

        if !fileManager.fileExists(atPath: configURL().path) {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
            let data = try encoder.encode(AppConfig.default)
            try data.write(to: configURL(), options: .atomic)
        }

        try saveDefaultCommandsIfNeeded()
    }

    private static func saveDefaultCommandsIfNeeded() throws {
        let fileManager = FileManager.default
        let commandsDir = CommandLoader.commandsDirectory()
        try fileManager.createDirectory(at: commandsDir, withIntermediateDirectories: true)

        let defaults: [(String, String)] = [
            ("translate", "Translate the text to English."),
            ("fix", "Fix grammar, spelling, and punctuation errors."),
            ("polish", "Improve clarity and readability while preserving the original meaning."),
            ("shorten", "Make the text more concise without losing key information."),
            ("expand", "Elaborate and add more detail to the text."),
            ("formal", "Rewrite in a formal, professional tone."),
            ("casual", "Rewrite in a casual, conversational tone."),
        ]

        for (name, prompt) in defaults {
            let url = commandsDir.appendingPathComponent("\(name).md")
            if !fileManager.fileExists(atPath: url.path) {
                try prompt.write(to: url, atomically: true, encoding: .utf8)
            }
        }
    }
}

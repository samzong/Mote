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
    }
}

import Foundation

public enum CommandStoreError: LocalizedError {
    case invalidFileName(String)
    case invalidFrontmatter(String)
    case missingField(String, URL)
    case invalidOrder(String, URL)
    case emptyPrompt(URL)

    public var errorDescription: String? {
        switch self {
        case let .invalidFileName(path):
            return "Invalid command file name: \(path)"
        case let .invalidFrontmatter(path):
            return "Invalid frontmatter in \(path)"
        case let .missingField(field, url):
            return "Missing `\(field)` in \(url.lastPathComponent)"
        case let .invalidOrder(value, url):
            return "Invalid `order` value `\(value)` in \(url.lastPathComponent)"
        case let .emptyPrompt(url):
            return "Command body is empty in \(url.lastPathComponent)"
        }
    }
}

public enum CommandStore {
    public static let defaultVisibleLimit = 5
    public static let templateFileName = "_template.md"

    public static func load(from directoryURL: URL = ConfigLoader.commandsDirectory()) throws -> [RewritePreset] {
        let fileManager = FileManager.default

        guard fileManager.fileExists(atPath: directoryURL.path) else {
            return []
        }

        let fileURLs = try fileManager.contentsOfDirectory(
            at: directoryURL,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        )
        .filter {
            $0.pathExtension == "md"
                && !$0.deletingPathExtension().lastPathComponent.hasPrefix("_")
                && $0.lastPathComponent != "README.md"
        }
        .sorted { $0.lastPathComponent < $1.lastPathComponent }

        return try fileURLs.map(loadCommand)
            .sorted {
                if $0.order == $1.order {
                    return $0.id < $1.id
                }

                return $0.order < $1.order
            }
    }

    public static func loadFeatured(
        limit: Int = defaultVisibleLimit,
        from directoryURL: URL = ConfigLoader.commandsDirectory()
    ) throws -> [RewritePreset] {
        Array(try load(from: directoryURL).prefix(limit))
    }

    public static func saveTemplateIfNeeded(to directoryURL: URL = ConfigLoader.commandsDirectory()) throws {
        let fileManager = FileManager.default
        try fileManager.createDirectory(at: directoryURL, withIntermediateDirectories: true)

        let templateURL = directoryURL.appendingPathComponent(templateFileName)
        guard !fileManager.fileExists(atPath: templateURL.path) else {
            return
        }

        let content = """
        ---
        name: Example
        description: Describe what this command does.
        order: 10
        ---

        Write the default instruction here.
        """
        try content.write(to: templateURL, atomically: true, encoding: .utf8)
    }

    private static func loadCommand(from fileURL: URL) throws -> RewritePreset {
        let content = try String(contentsOf: fileURL, encoding: .utf8)
        let sections = try parseFrontmatter(in: content, fileURL: fileURL)
        let id = fileURL.deletingPathExtension().lastPathComponent

        guard !id.isEmpty else {
            throw CommandStoreError.invalidFileName(fileURL.path)
        }

        guard let name = sections["name"], !name.isEmpty else {
            throw CommandStoreError.missingField("name", fileURL)
        }

        guard let description = sections["description"], !description.isEmpty else {
            throw CommandStoreError.missingField("description", fileURL)
        }

        guard let orderValue = sections["order"], !orderValue.isEmpty else {
            throw CommandStoreError.missingField("order", fileURL)
        }

        guard let order = Int(orderValue) else {
            throw CommandStoreError.invalidOrder(orderValue, fileURL)
        }

        let prompt = bodyFromContent(content).trimmingCharacters(in: .whitespacesAndNewlines)
        guard !prompt.isEmpty else {
            throw CommandStoreError.emptyPrompt(fileURL)
        }

        return RewritePreset(
            id: id,
            name: name,
            description: description,
            order: order,
            prompt: prompt
        )
    }

    private static func parseFrontmatter(in content: String, fileURL: URL) throws -> [String: String] {
        let marker = "---"
        guard content.hasPrefix("\(marker)\n") else {
            throw CommandStoreError.invalidFrontmatter(fileURL.path)
        }

        let bodyStart = content.index(content.startIndex, offsetBy: marker.count + 1)
        guard let closingRange = content.range(of: "\n\(marker)\n", range: bodyStart..<content.endIndex) else {
            throw CommandStoreError.invalidFrontmatter(fileURL.path)
        }

        let frontmatter = content[bodyStart..<closingRange.lowerBound]
        var values: [String: String] = [:]

        for line in frontmatter.split(separator: "\n", omittingEmptySubsequences: true) {
            guard let colonIndex = line.firstIndex(of: ":") else {
                throw CommandStoreError.invalidFrontmatter(fileURL.path)
            }

            let rawKey = line[..<colonIndex].trimmingCharacters(in: .whitespacesAndNewlines)
            let rawValue = line[line.index(after: colonIndex)...].trimmingCharacters(in: .whitespacesAndNewlines)
            values[rawKey] = unquote(rawValue)
        }

        return values
    }

    private static func bodyFromContent(_ content: String) -> String {
        guard let range = content.range(of: "\n---\n") else {
            return ""
        }

        return String(content[range.upperBound...])
    }

    private static func unquote(_ value: String) -> String {
        guard value.count >= 2 else {
            return value
        }

        if value.hasPrefix("\""), value.hasSuffix("\"") {
            return String(value.dropFirst().dropLast())
        }

        if value.hasPrefix("'"), value.hasSuffix("'") {
            return String(value.dropFirst().dropLast())
        }

        return value
    }
}

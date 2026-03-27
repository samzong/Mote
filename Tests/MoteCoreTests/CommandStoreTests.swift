import Foundation
import Testing
@testable import MoteCore

struct CommandStoreTests {
    @Test
    func loadsMarkdownCommandsSortedByOrder() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        try """
        ---
        name: Shorten
        description: Shorten text.
        order: 20
        ---

        Shorten the selected text.
        """.write(to: directory.appendingPathComponent("shorten.md"), atomically: true, encoding: .utf8)

        try """
        ---
        name: Translate
        description: Translate text.
        order: 10
        ---

        Translate the selected text.
        """.write(to: directory.appendingPathComponent("translate.md"), atomically: true, encoding: .utf8)

        let commands = try CommandStore.load(from: directory)

        #expect(commands.map(\.id) == ["translate", "shorten"])
        #expect(commands[0].name == "Translate")
        #expect(commands[0].description == "Translate text.")
        #expect(commands[0].order == 10)
        #expect(commands[0].prompt == "Translate the selected text.")
    }

    @Test
    func featuredCommandsAreLimitedToFive() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        for index in 1...6 {
            try """
            ---
            name: Command \(index)
            description: Description \(index)
            order: \(index)
            ---

            Prompt \(index)
            """.write(
                to: directory.appendingPathComponent("command-\(index).md"),
                atomically: true,
                encoding: .utf8
            )
        }

        let commands = try CommandStore.loadFeatured(from: directory)

        #expect(commands.count == 5)
        #expect(commands.map(\.order) == [1, 2, 3, 4, 5])
    }

    @Test
    func ignoresTemplateMarkdownFiles() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        try """
        ---
        name: Example
        description: Template.
        order: 1
        ---

        Example prompt.
        """.write(
            to: directory.appendingPathComponent("_template.md"),
            atomically: true,
            encoding: .utf8
        )

        let commands = try CommandStore.load(from: directory)

        #expect(commands.isEmpty)
    }

    @Test
    func writesTemplateWhenMissing() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)

        try CommandStore.saveTemplateIfNeeded(to: directory)

        let templateURL = directory.appendingPathComponent(CommandStore.templateFileName)
        let content = try String(contentsOf: templateURL, encoding: .utf8)

        #expect(FileManager.default.fileExists(atPath: templateURL.path))
        #expect(content.contains("name: Example"))
        #expect(content.contains("description: Describe what this command does."))
        #expect(content.contains("order: 10"))
    }
}

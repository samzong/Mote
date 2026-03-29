@testable import MoteCore
import Testing

struct CommandLoaderTests {
    @Test
    func resolvePassesThroughPlainInstruction() {
        let result = CommandLoader.resolve(instruction: "Fix the typos")
        #expect(result == "Fix the typos")
    }

    @Test
    func resolvePassesThroughUnknownCommand() {
        let result = CommandLoader.resolve(instruction: "/nonexistent")
        #expect(result == "/nonexistent")
    }

    @Test
    func resolveTrimsWhitespace() {
        let result = CommandLoader.resolve(instruction: "  hello world  ")
        #expect(result == "hello world")
    }

    @Test
    func resolvePassesThroughSlashOnly() {
        let result = CommandLoader.resolve(instruction: "/")
        #expect(result == "/")
    }
}

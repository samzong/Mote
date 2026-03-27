import Foundation
import MoteCore

enum CLIError: LocalizedError {
    case invalidCommand(String)
    case missingConfig
    case incompleteConfig([String])

    var errorDescription: String? {
        switch self {
        case let .invalidCommand(command):
            return "Unknown command: \(command)"
        case .missingConfig:
            return "Config is missing. Run `motectl init` first."
        case let .incompleteConfig(fields):
            return "Config is incomplete. Set \(fields.joined(separator: ", ")) in config.json."
        }
    }
}

@main
struct MoteCLI {
    static func main() async {
        do {
            try await run()
        } catch {
            let message = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            fputs("error: \(message)\n", stderr)
            Foundation.exit(1)
        }
    }

    private static func run() async throws {
        let args = Array(CommandLine.arguments.dropFirst())
        let command = args.first ?? "help"

        switch command {
        case "help", "-h", "--help":
            print("motectl init")
            print("motectl doctor")
            print("motectl config")
            print("motectl probe")
        case "init":
            try ConfigLoader.saveDefaultFilesIfNeeded()
            print(ConfigLoader.configDirectory().path)
        case "doctor":
            try await runDoctor()
        case "config":
            print(ConfigLoader.configURL().path)
        case "probe":
            try await runProbe()
        default:
            throw CLIError.invalidCommand(command)
        }
    }

    private static func runDoctor() async throws {
        let fileManager = FileManager.default
        let configExists = fileManager.fileExists(atPath: ConfigLoader.configURL().path)
        let commands = try CommandStore.load()
        print("config: \(configExists ? "ok" : "missing")")
        print("commands: ok (\(commands.count))")
        print("accessibility: \(AccessibilityPermission.isTrusted() ? "granted" : "missing")")

        guard configExists else {
            print("endpoint: skipped")
            return
        }

        let config = try ConfigLoader.loadConfig()

        if config.baseURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            print("endpoint: missing")
            print("model: \(config.model.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "missing" : "configured")")
            return
        }

        print("model: \(config.model.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "missing" : "configured")")
        let client = OpenAICompatibleClient()
        let reachability = await client.checkReachability(config: config)

        guard reachability.reachable else {
            if let statusCode = reachability.statusCode {
                print("endpoint: invalid (\(statusCode))")
            } else {
                print("endpoint: unreachable")
            }
            return
        }

        if let statusCode = reachability.statusCode {
            print("endpoint: ok (\(statusCode))")
        } else {
            print("endpoint: ok")
        }
    }

    private static func runProbe() async throws {
        guard FileManager.default.fileExists(atPath: ConfigLoader.configURL().path) else {
            throw CLIError.missingConfig
        }

        let config = try ConfigLoader.loadConfig()
        let missingFields = config.missingRequiredFields
        guard missingFields.isEmpty else {
            throw CLIError.incompleteConfig(missingFields)
        }

        let response = try await OpenAICompatibleClient().probe(config: config)
        print("probe: ok")
        print(response)
    }
}

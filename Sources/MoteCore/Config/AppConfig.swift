import Foundation

public struct AppConfig: Codable, Equatable, Sendable {
    public struct Hotkey: Codable, Equatable, Sendable {
        public var key: String
        public var modifiers: [String]

        public init(key: String, modifiers: [String]) {
            self.key = key
            self.modifiers = modifiers
        }
    }

    public var baseURL: String
    public var apiKey: String
    public var model: String
    public var temperature: Double
    public var maxTokens: Int
    public var hotkey: Hotkey

    enum CodingKeys: String, CodingKey {
        case baseURL = "base_url"
        case apiKey = "api_key"
        case model
        case temperature
        case maxTokens = "max_tokens"
        case hotkey
    }

    public init(
        baseURL: String,
        apiKey: String,
        model: String,
        temperature: Double,
        maxTokens: Int,
        hotkey: Hotkey
    ) {
        self.baseURL = baseURL
        self.apiKey = apiKey
        self.model = model
        self.temperature = temperature
        self.maxTokens = maxTokens
        self.hotkey = hotkey
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        if container.contains(.baseURL) || container.contains(.apiKey) || container.contains(.model) {
            self.baseURL = try container.decodeIfPresent(String.self, forKey: .baseURL) ?? ""
            self.apiKey = try container.decodeIfPresent(String.self, forKey: .apiKey) ?? ""
            self.model = try container.decodeIfPresent(String.self, forKey: .model) ?? ""
            self.temperature = try container.decodeIfPresent(Double.self, forKey: .temperature) ?? 0.2
            self.maxTokens = try container.decodeIfPresent(Int.self, forKey: .maxTokens) ?? 1024
            self.hotkey = try container.decodeIfPresent(Hotkey.self, forKey: .hotkey) ?? .init(key: "space", modifiers: ["option"])
            return
        }

        let legacy = try LegacyConfig(from: decoder)
        self.baseURL = legacy.provider.baseURL
        self.apiKey = legacy.provider.apiKey
        self.model = legacy.provider.model
        self.temperature = legacy.provider.temperature
        self.maxTokens = legacy.provider.maxTokens
        self.hotkey = .init(key: legacy.hotkey.key, modifiers: legacy.hotkey.modifiers)
    }

    public static let `default` = AppConfig(
        baseURL: "",
        apiKey: "",
        model: "",
        temperature: 0.2,
        maxTokens: 1024,
        hotkey: .init(key: "space", modifiers: ["option"])
    )

    public var missingRequiredFields: [String] {
        var fields: [String] = []

        if baseURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            fields.append("base_url")
        }

        if model.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            fields.append("model")
        }

        return fields
    }
}

private struct LegacyConfig: Decodable {
    struct Provider: Decodable {
        var baseURL: String
        var apiKey: String
        var model: String
        var temperature: Double
        var maxTokens: Int

        enum CodingKeys: String, CodingKey {
            case baseURL = "base_url"
            case apiKey = "api_key"
            case model
            case temperature
            case maxTokens = "max_tokens"
        }
    }

    struct Hotkey: Decodable {
        var key: String
        var modifiers: [String]
    }

    var provider: Provider
    var hotkey: Hotkey
}

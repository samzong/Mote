import Foundation

public struct AppConfig: Codable, Equatable, Sendable {
    public var baseURL: String
    public var apiKey: String
    public var model: String
    public var temperature: Double
    public var maxTokens: Int

    enum CodingKeys: String, CodingKey {
        case baseURL = "base_url"
        case apiKey = "api_key"
        case model
        case temperature
        case maxTokens = "max_tokens"
    }

    public init(
        baseURL: String,
        apiKey: String,
        model: String,
        temperature: Double,
        maxTokens: Int
    ) {
        self.baseURL = baseURL
        self.apiKey = apiKey
        self.model = model
        self.temperature = temperature
        self.maxTokens = maxTokens
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.baseURL = try container.decodeIfPresent(String.self, forKey: .baseURL) ?? ""
        self.apiKey = try container.decodeIfPresent(String.self, forKey: .apiKey) ?? ""
        self.model = try container.decodeIfPresent(String.self, forKey: .model) ?? ""
        self.temperature = try container.decodeIfPresent(Double.self, forKey: .temperature) ?? 0.2
        self.maxTokens = try container.decodeIfPresent(Int.self, forKey: .maxTokens) ?? 1024
    }

    public static let `default` = AppConfig(
        baseURL: "",
        apiKey: "",
        model: "",
        temperature: 0.2,
        maxTokens: 1024
    )
}

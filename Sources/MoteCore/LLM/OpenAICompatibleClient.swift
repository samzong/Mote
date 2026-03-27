import Foundation

public enum OpenAICompatibleClientError: LocalizedError {
    case invalidEndpoint(String)
    case transport(Error)
    case invalidResponse
    case serverStatus(Int, String)
    case emptyResponse
    case apiError(String)
    case malformedResponse(String)

    public var errorDescription: String? {
        switch self {
        case let .invalidEndpoint(value):
            return "Invalid endpoint URL: \(value)"
        case let .transport(error):
            return error.localizedDescription
        case .invalidResponse:
            return "Invalid response from endpoint"
        case let .serverStatus(statusCode, body):
            if body.isEmpty {
                return "Endpoint returned HTTP \(statusCode)"
            }

            return "Endpoint returned HTTP \(statusCode): \(body)"
        case .emptyResponse:
            return "Endpoint returned an empty response"
        case let .apiError(message):
            return message
        case let .malformedResponse(message):
            return message
        }
    }
}

public struct EndpointReachability: Equatable, Sendable {
    public let reachable: Bool
    public let statusCode: Int?

    public init(reachable: Bool, statusCode: Int?) {
        self.reachable = reachable
        self.statusCode = statusCode
    }
}

public final class OpenAICompatibleClient {
    private let session: URLSession

    public init(session: URLSession = .shared) {
        self.session = session
    }

    public func buildURL(from config: AppConfig) -> URL? {
        guard !config.baseURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return nil
        }

        guard var components = URLComponents(string: config.baseURL) else {
            return nil
        }

        let requestPath = normalizedPath("/chat/completions")
        let basePath = normalizedPath(components.path)

        if basePath.isEmpty {
            components.path = requestPath
        } else {
            components.path = "\(basePath)\(requestPath)"
        }

        return components.url
    }

    public func makeRequest(config: AppConfig, messages: [ChatMessage]) throws -> URLRequest {
        guard let url = buildURL(from: config) else {
            throw OpenAICompatibleClientError.invalidEndpoint(config.baseURL)
        }

        let payload = ChatCompletionRequest(
            model: config.model,
            messages: messages,
            temperature: config.temperature,
            maxTokens: config.maxTokens,
            stream: false
        )
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 20
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        if !config.apiKey.isEmpty {
            request.setValue("Bearer \(config.apiKey)", forHTTPHeaderField: "Authorization")
        }

        request.httpBody = try encoder.encode(payload)
        return request
    }

    public func checkReachability(config: AppConfig) async -> EndpointReachability {
        guard let url = buildURL(from: config), !config.baseURL.isEmpty else {
            return EndpointReachability(reachable: false, statusCode: nil)
        }

        var request = URLRequest(url: url)
        request.httpMethod = "OPTIONS"
        request.timeoutInterval = 20

        do {
            let (data, response) = try await session.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse else {
                return EndpointReachability(reachable: false, statusCode: nil)
            }

            if apiErrorMessage(from: data) != nil {
                return EndpointReachability(reachable: false, statusCode: httpResponse.statusCode)
            }

            return EndpointReachability(reachable: (200..<500).contains(httpResponse.statusCode), statusCode: httpResponse.statusCode)
        } catch {
            return EndpointReachability(reachable: false, statusCode: nil)
        }
    }

    public func probe(config: AppConfig) async throws -> String {
        let messages = [
            ChatMessage(role: "system", content: "You are a connectivity test."),
            ChatMessage(role: "user", content: "Reply with OK."),
        ]
        let request = try makeRequest(
            config: AppConfig(
                baseURL: config.baseURL,
                apiKey: config.apiKey,
                model: config.model,
                temperature: 0,
                maxTokens: min(config.maxTokens, 32),
                hotkey: config.hotkey
            ),
            messages: messages
        )

        return try await execute(request: request)
    }

    public func rewrite(request: RewriteRequest, config: AppConfig) async throws -> RewriteResult {
        let messages = PromptBuilder.buildMessages(for: request)
        let urlRequest = try makeRequest(config: config, messages: messages)
        return RewriteResult(output: try await execute(request: urlRequest))
    }

    private func execute(request: URLRequest) async throws -> String {
        do {
            let (data, response) = try await session.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse else {
                throw OpenAICompatibleClientError.invalidResponse
            }

            guard (200..<300).contains(httpResponse.statusCode) else {
                let body = String(data: data, encoding: .utf8)?
                    .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                throw OpenAICompatibleClientError.serverStatus(httpResponse.statusCode, body)
            }

            if let errorMessage = apiErrorMessage(from: data) {
                throw OpenAICompatibleClientError.apiError(errorMessage)
            }

            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = .convertFromSnakeCase
            let completion: ChatCompletionResponse

            do {
                completion = try decoder.decode(ChatCompletionResponse.self, from: data)
            } catch {
                let responseBody = String(data: data, encoding: .utf8)?
                    .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                throw OpenAICompatibleClientError.malformedResponse(
                    responseBody.isEmpty
                        ? "Model response could not be parsed."
                        : "Model response could not be parsed: \(responseBody)"
                )
            }

            let content = completion.choices.first?.message.content
                .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

            guard !content.isEmpty else {
                throw OpenAICompatibleClientError.malformedResponse("Model response did not include assistant content.")
            }

            return content
        } catch let error as OpenAICompatibleClientError {
            throw error
        } catch {
            throw OpenAICompatibleClientError.transport(error)
        }
    }

    private func apiErrorMessage(from data: Data) -> String? {
        guard
            let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let error = object["error"]
        else {
            return nil
        }

        if let message = error as? String {
            return message
        }

        if
            let dictionary = error as? [String: Any],
            let message = dictionary["message"] as? String
        {
            return message
        }

        return nil
    }

    private func normalizedPath(_ value: String) -> String {
        guard !value.isEmpty, value != "/" else {
            return ""
        }

        let trimmed = value.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        guard !trimmed.isEmpty else {
            return ""
        }

        return "/\(trimmed)"
    }
}

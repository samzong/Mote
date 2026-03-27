import Foundation
import Testing
@testable import MoteCore

struct ConfigLoaderTests {
    @Test
    func defaultConfigStartsWithMinimalValues() {
        #expect(AppConfig.default.baseURL.isEmpty)
        #expect(AppConfig.default.apiKey.isEmpty)
        #expect(AppConfig.default.model.isEmpty)
        #expect(AppConfig.default.temperature == 0.2)
        #expect(AppConfig.default.maxTokens == 1024)
    }

    @Test
    func defaultConfigRoundTripsThroughJSON() throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let data = try encoder.encode(AppConfig.default)

        let decoded = try JSONDecoder().decode(AppConfig.self, from: data)

        #expect(decoded == AppConfig.default)
    }

    @Test
    func configRoundTripsWithProjectStrategies() throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let data = try encoder.encode(AppConfig.default)

        let decoded = try JSONDecoder().decode(AppConfig.self, from: data)

        #expect(decoded.baseURL == AppConfig.default.baseURL)
        #expect(decoded.hotkey == AppConfig.default.hotkey)
        #expect(decoded.maxTokens == AppConfig.default.maxTokens)
    }

    @Test
    func decodesLegacyConfigShape() throws {
        let data = Data(
            """
            {
              "provider": {
                "base_url": "http://127.0.0.1:1234/v1",
                "api_key": "lm-studio",
                "model": "qwen2.5-7b-instruct",
                "request_path": "/chat/completions",
                "temperature": 0.2,
                "max_tokens": 1024,
                "timeout_seconds": 20
              },
              "hotkey": {
                "enabled": true,
                "key": "space",
                "modifiers": ["option"]
              },
              "fn_trigger": {
                "enabled": false,
                "mode": "double_press"
              },
              "overlay": {
                "show_bubble": true,
                "bubble_size": 14,
                "appear_delay_ms": 120
              },
              "blacklist_apps": [],
              "privacy": {
                "disable_in_secure_fields": true,
                "persist_logs": false
              }
            }
            """.utf8
        )

        let decoded = try JSONDecoder().decode(AppConfig.self, from: data)

        #expect(decoded.baseURL == "http://127.0.0.1:1234/v1")
        #expect(decoded.apiKey == "lm-studio")
        #expect(decoded.model == "qwen2.5-7b-instruct")
        #expect(decoded.temperature == 0.2)
        #expect(decoded.maxTokens == 1024)
        #expect(decoded.hotkey == .init(key: "space", modifiers: ["option"]))
    }
}

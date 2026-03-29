import Foundation
@testable import MoteCore
import Testing

struct ConfigLoaderTests {
    @Test
    func defaultConfigRoundTripsThroughJSON() throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let data = try encoder.encode(AppConfig.default)

        let decoded = try JSONDecoder().decode(AppConfig.self, from: data)

        #expect(decoded == AppConfig.default)
    }
}

import Foundation
@testable import MoteCore
import Testing

struct SelectionContextTests {
    @Test
    func rangeRejectsNegativeBounds() {
        let value = "abcdef" as NSString

        #expect(SelectionRange(location: -1, length: 1).nsRange(in: value) == nil)
        #expect(SelectionRange(location: 0, length: -1).nsRange(in: value) == nil)
        #expect(SelectionRange(location: 2, length: 3).nsRange(in: value) == NSRange(location: 2, length: 3))
        #expect(SelectionRange(location: 5, length: 2).nsRange(in: value) == nil)
    }

    @Test
    func validContextRejectsSecureOrInvalidRanges() {
        let valid = SelectionContext(
            bundleIdentifier: "com.apple.TextEdit",
            processIdentifier: 42,
            text: "Example",
            range: SelectionRange(location: 0, length: 7),
            bounds: nil,
            isSecure: false,
            isWritable: true
        )

        let secure = SelectionContext(
            bundleIdentifier: valid.bundleIdentifier,
            processIdentifier: valid.processIdentifier,
            text: valid.text,
            range: valid.range,
            bounds: valid.bounds,
            isSecure: true,
            isWritable: valid.isWritable
        )

        let invalidRange = SelectionContext(
            bundleIdentifier: valid.bundleIdentifier,
            processIdentifier: valid.processIdentifier,
            text: valid.text,
            range: SelectionRange(location: -1, length: 1),
            bounds: valid.bounds,
            isSecure: false,
            isWritable: valid.isWritable
        )

        #expect(valid.isValid)
        #expect(!secure.isValid)
        #expect(!invalidRange.isValid)
    }
}

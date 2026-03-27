import Foundation

public struct RewriteRequest: Equatable, Sendable {
    public var preset: RewritePreset
    public var instruction: String
    public var selection: SelectionContext

    public init(preset: RewritePreset, instruction: String, selection: SelectionContext) {
        self.preset = preset
        self.instruction = instruction
        self.selection = selection
    }
}

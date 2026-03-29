final class DirectReplaceStrategy {
    private let writer: AXReplacementWriter

    init(writer: AXReplacementWriter = AXReplacementWriter()) {
        self.writer = writer
    }

    func apply(_ text: String, to snapshot: AXSelectionSnapshot) throws {
        try writer.replaceSelectedText(in: snapshot.element, context: snapshot.context, with: text)
    }
}

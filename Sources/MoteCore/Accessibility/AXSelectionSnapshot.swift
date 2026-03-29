import ApplicationServices

public final class AXSelectionSnapshot {
    public let element: AXUIElement
    public let context: SelectionContext
    public let proof: SelectionProof
    public let writebackCapability: WritebackCapability
    public let fieldText: String?

    public init(
        element: AXUIElement,
        context: SelectionContext,
        proof: SelectionProof,
        writebackCapability: WritebackCapability,
        fieldText: String? = nil
    ) {
        self.element = element
        self.context = context
        self.proof = proof
        self.writebackCapability = writebackCapability
        self.fieldText = fieldText
    }
}

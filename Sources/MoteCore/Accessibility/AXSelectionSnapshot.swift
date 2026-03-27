import ApplicationServices
import Foundation

public final class AXSelectionSnapshot {
    public let element: AXUIElement
    public let context: SelectionContext

    public init(element: AXUIElement, context: SelectionContext) {
        self.element = element
        self.context = context
    }
}

import AppKit
import Foundation

public final class ClipboardTransaction {
    private struct ItemSnapshot {
        var values: [String: Data]
    }

    private let snapshots: [ItemSnapshot]
    private var ownedChangeCount: Int?

    public init(pasteboard: NSPasteboard = .general) {
        snapshots = (pasteboard.pasteboardItems ?? []).map { item in
            let values = item.types.reduce(into: [String: Data]()) { partialResult, type in
                if let data = item.data(forType: type) {
                    partialResult[type.rawValue] = data
                }
            }

            return ItemSnapshot(values: values)
        }
    }

    public func write(string: String, to pasteboard: NSPasteboard = .general) {
        pasteboard.clearContents()
        pasteboard.setString(string, forType: .string)
        ownedChangeCount = pasteboard.changeCount
    }

    public func claimCurrentContents(from pasteboard: NSPasteboard = .general) {
        ownedChangeCount = pasteboard.changeCount
    }

    public func restore(to pasteboard: NSPasteboard = .general) {
        pasteboard.clearContents()
        ownedChangeCount = nil

        guard !snapshots.isEmpty else {
            return
        }

        let items = snapshots.map { snapshot in
            let item = NSPasteboardItem()
            for (rawType, data) in snapshot.values {
                item.setData(data, forType: NSPasteboard.PasteboardType(rawValue: rawType))
            }
            return item
        }

        pasteboard.writeObjects(items)
    }

    @discardableResult
    public func restoreIfOwned(to pasteboard: NSPasteboard = .general) -> Bool {
        guard let ownedChangeCount, pasteboard.changeCount == ownedChangeCount else {
            return false
        }

        restore(to: pasteboard)
        return true
    }
}

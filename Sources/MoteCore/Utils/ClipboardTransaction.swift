import AppKit
import Foundation

public struct ClipboardTransaction {
    private struct ItemSnapshot {
        var values: [String: Data]
    }

    private let snapshots: [ItemSnapshot]

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
    }

    public func restore(to pasteboard: NSPasteboard = .general) {
        pasteboard.clearContents()

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
}

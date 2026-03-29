import AppKit

final class KeyablePanel: NSPanel {
    override var canBecomeKey: Bool { true }
}

final class RoundedContainer: NSView {
    var cornerRadius: CGFloat = 26 {
        didSet { layer?.cornerRadius = cornerRadius }
    }

    override init(frame: NSRect) {
        super.init(frame: frame)
        wantsLayer = true
        layer?.cornerRadius = cornerRadius
        layer?.masksToBounds = true
        layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor
        layer?.borderColor = NSColor.separatorColor.withAlphaComponent(0.15).cgColor
        layer?.borderWidth = 0.5
    }

    required init?(coder _: NSCoder) { nil }

    override func updateLayer() {
        layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor
        layer?.borderColor = NSColor.separatorColor.withAlphaComponent(0.15).cgColor
    }
}

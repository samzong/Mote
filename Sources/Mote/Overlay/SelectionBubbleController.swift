import AppKit
import MoteCore

@MainActor
final class SelectionBubbleController {
    var onActivate: (() -> Void)?

    private let panel: BubblePanel
    private let button: BubbleButton

    init() {
        panel = BubblePanel(
            contentRect: CGRect(x: 0, y: 0, width: 18, height: 18),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.isFloatingPanel = true
        panel.level = .statusBar
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.hidesOnDeactivate = false

        button = BubbleButton(frame: CGRect(x: 0, y: 0, width: 18, height: 18))
        button.target = self
        button.action = #selector(handleActivate)

        let contentView = NSView(frame: button.frame)
        contentView.wantsLayer = true
        contentView.layer?.backgroundColor = NSColor.clear.cgColor
        contentView.addSubview(button)
        panel.contentView = contentView
        panel.orderOut(nil)
    }

    func show(for snapshot: AXSelectionSnapshot) {
        guard let bounds = snapshot.context.bounds else {
            hide()
            return
        }

        let bubbleFrame = frameForBubble(near: convertAccessibilityRect(bounds))
        panel.setFrame(bubbleFrame, display: true)
        panel.orderFrontRegardless()
    }

    func hide() {
        panel.orderOut(nil)
    }

    @objc
    private func handleActivate() {
        onActivate?()
    }

    private func frameForBubble(near rect: CGRect) -> CGRect {
        CGRect(x: rect.minX - 7, y: rect.midY - 9, width: 18, height: 18)
    }

    private func convertAccessibilityRect(_ rect: CGRect) -> CGRect {
        let screen = NSScreen.screens.first(where: { $0.frame.minX <= rect.midX && $0.frame.maxX >= rect.midX }) ?? NSScreen.main
        let screenFrame = screen?.frame ?? .zero
        return CGRect(
            x: rect.minX,
            y: screenFrame.maxY - rect.maxY,
            width: rect.width,
            height: rect.height
        )
    }
}

private final class BubblePanel: NSPanel {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}

private final class BubbleButton: NSButton {
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        isBordered = false
        bezelStyle = .regularSquare
        setButtonType(.momentaryChange)
        wantsLayer = true
        layer = CALayer()
        layer?.backgroundColor = NSColor.controlAccentColor.cgColor
        layer?.cornerRadius = frameRect.width / 2
        layer?.masksToBounds = true
    }

    required init?(coder: NSCoder) {
        nil
    }

    override func layout() {
        super.layout()
        layer?.cornerRadius = bounds.width / 2
        layer?.backgroundColor = NSColor.controlAccentColor.cgColor
    }

    override func mouseEntered(with event: NSEvent) {
        alphaValue = 0.9
    }

    override func mouseExited(with event: NSEvent) {
        alphaValue = 1
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        addTrackingArea(
            NSTrackingArea(
                rect: bounds,
                options: [.activeAlways, .mouseEnteredAndExited, .inVisibleRect],
                owner: self,
                userInfo: nil
            )
        )
    }
}

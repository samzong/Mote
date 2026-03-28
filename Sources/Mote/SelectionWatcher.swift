import AppKit
import MoteCore

@MainActor
final class SelectionWatcher {
    private var mouseMonitor: Any?
    private var keyUpMonitor: Any?
    private var keyDownMonitor: Any?
    private let reader = AXSelectionReader()
    private let dot = DotIndicator()
    private var currentSnapshot: AXSelectionSnapshot?
    private var dotVisible = false
    var onActivate: ((AXSelectionSnapshot) -> Void)?
    var isEnabled = true
    var activeSnapshot: AXSelectionSnapshot? { currentSnapshot }

    func start() {
        Logger.debug("SelectionWatcher.start() called")

        mouseMonitor = NSEvent.addGlobalMonitorForEvents(matching: .leftMouseUp) { _ in
            Task { @MainActor [weak self] in
                Logger.debug("mouseUp event received")
                try? await Task.sleep(nanoseconds: 100_000_000)
                self?.checkSelection()
            }
        }
        Logger.debug("mouseMonitor registered: \(mouseMonitor != nil)")

        keyUpMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyUp) { event in
            let shift = event.modifierFlags.contains(.shift)
            let cmdA = event.modifierFlags.contains(.command)
                && event.charactersIgnoringModifiers == "a"
            guard shift || cmdA else { return }
            Logger.debug("keyUp event: shift=\(shift) cmdA=\(cmdA)")
            Task { @MainActor [weak self] in
                try? await Task.sleep(nanoseconds: 100_000_000)
                self?.checkSelection()
            }
        }
        Logger.debug("keyUpMonitor registered: \(keyUpMonitor != nil)")

        keyDownMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { event in
            let mods = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
            let modified = mods.contains(.command) || mods.contains(.control) || mods.contains(.shift)
            guard !modified else { return }
            Task { @MainActor [weak self] in
                guard let self, self.dotVisible else { return }
                Logger.debug("keyDown (unmodified) -> hideDot")
                self.hideDot()
            }
        }

        dot.onClick = { [weak self] in
            Logger.debug("dot clicked, currentSnapshot=\(self?.currentSnapshot != nil)")
            guard let snapshot = self?.currentSnapshot else { return }
            self?.hideDot()
            self?.onActivate?(snapshot)
        }

        Logger.debug("SelectionWatcher.start() complete")
    }

    func stop() {
        Logger.debug("SelectionWatcher.stop()")
        if let m = mouseMonitor { NSEvent.removeMonitor(m) }
        if let m = keyUpMonitor { NSEvent.removeMonitor(m) }
        if let m = keyDownMonitor { NSEvent.removeMonitor(m) }
        mouseMonitor = nil
        keyUpMonitor = nil
        keyDownMonitor = nil
        hideDot()
    }

    func hideDot() {
        guard dotVisible else { return }
        Logger.debug("hideDot() called")
        dot.hide()
        dotVisible = false
        currentSnapshot = nil
    }

    func recheckAfterDelay() {
        Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 200_000_000)
            self?.checkSelection()
        }
    }

    private func checkSelection() {
        Logger.debug("checkSelection() isEnabled=\(isEnabled)")
        guard isEnabled else {
            Logger.debug("checkSelection() SKIP: disabled")
            return
        }

        let trusted = AccessibilityPermission.isTrusted()
        Logger.debug("checkSelection() accessibilityTrusted=\(trusted)")
        guard trusted else { return }

        let reader = self.reader
        guard let snapshot = reader.readFocusedSelection() else {
            Logger.debug("checkSelection() no snapshot from reader")
            hideDot()
            return
        }

        let text = snapshot.context.text
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, let bounds = snapshot.context.bounds else {
            Logger.debug("checkSelection() SKIP: empty text or nil bounds")
            hideDot()
            return
        }

        Logger.debug("checkSelection() text.count=\(text.count) bounds=\(bounds)")
        currentSnapshot = snapshot
        dotVisible = true
        dot.show(near: bounds)
    }
}

@MainActor
private final class DotIndicator {
    private let window: NSWindow
    private let dotView: DotContentView
    var onClick: (() -> Void)?

    private let smallRadius: CGFloat = 5
    private let largeRadius: CGFloat = 11
    private let hitSize: CGFloat = 22

    init() {
        window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: hitSize, height: hitSize),
            styleMask: .borderless,
            backing: .buffered,
            defer: false
        )
        window.level = .floating
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = false
        window.isReleasedWhenClosed = false
        window.collectionBehavior = [.canJoinAllSpaces, .transient]

        dotView = DotContentView()
        dotView.autoresizingMask = [.width, .height]
        dotView.dotRadius = smallRadius
        window.contentView = dotView

        dotView.onHover = { [weak self] hovered in
            guard let self else { return }
            Logger.debug("DotIndicator hover=\(hovered)")
            self.dotView.animateRadius(to: hovered ? self.largeRadius : self.smallRadius)
        }
        dotView.onClicked = { [weak self] in self?.onClick?() }
    }

    func show(near bounds: CGRect?) {
        guard let screen = NSScreen.main, let bounds else {
            Logger.debug("DotIndicator.show() SKIP: screen=\(NSScreen.main != nil) bounds=\(bounds != nil)")
            return
        }

        let sh = screen.frame.height
        let cx = bounds.origin.x
        let cy = sh - bounds.origin.y + 2
        let x = cx - hitSize / 2
        let y = cy - hitSize / 2

        Logger.debug("DotIndicator.show() screenH=\(sh) axBounds=\(bounds) -> center=(\(cx), \(cy))")

        dotView.dotRadius = smallRadius
        dotView.needsDisplay = true
        window.setFrameOrigin(NSPoint(x: x, y: y))
        window.orderFront(nil)
        Logger.debug("DotIndicator.show() window.isVisible=\(window.isVisible) frame=\(window.frame)")
    }

    func hide() {
        Logger.debug("DotIndicator.hide()")
        window.orderOut(nil)
        dotView.dotRadius = smallRadius
    }
}

private final class DotContentView: NSView {
    var onHover: ((Bool) -> Void)?
    var onClicked: (() -> Void)?
    var dotRadius: CGFloat = 5 {
        didSet { needsDisplay = true }
    }

    private var animationGeneration = 0

    override func draw(_: NSRect) {
        let d = dotRadius * 2
        let rect = NSRect(
            x: (bounds.width - d) / 2,
            y: (bounds.height - d) / 2,
            width: d, height: d
        )
        let shadow = NSShadow()
        shadow.shadowColor = NSColor.black.withAlphaComponent(0.25)
        shadow.shadowBlurRadius = 3
        shadow.shadowOffset = NSSize(width: 0, height: -1)
        shadow.set()
        NSColor.controlAccentColor.setFill()
        NSBezierPath(ovalIn: rect).fill()
    }

    func animateRadius(to target: CGFloat) {
        animationGeneration += 1
        let gen = animationGeneration
        let start = dotRadius
        let steps = 12
        let interval = 0.018
        for i in 1 ... steps {
            let fraction = CGFloat(i) / CGFloat(steps)
            let eased = fraction * fraction * (3 - 2 * fraction)
            let r = start + (target - start) * eased
            DispatchQueue.main.asyncAfter(deadline: .now() + interval * Double(i)) { [weak self] in
                guard let self, self.animationGeneration == gen else { return }
                self.dotRadius = r
            }
        }
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        for area in trackingAreas {
            removeTrackingArea(area)
        }
        addTrackingArea(NSTrackingArea(
            rect: bounds,
            options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect],
            owner: self
        ))
    }

    override func acceptsFirstMouse(for _: NSEvent?) -> Bool { true }
    override func mouseUp(with _: NSEvent) { onClicked?() }
    override func mouseEntered(with _: NSEvent) { onHover?(true) }
    override func mouseExited(with _: NSEvent) { onHover?(false) }
}

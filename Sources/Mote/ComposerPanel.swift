import AppKit
import MoteCore

private final class KeyablePanel: NSPanel {
    override var canBecomeKey: Bool { true }
}

private final class RoundedContainer: NSView {
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

@MainActor
final class ComposerPanel: NSObject, NSTextFieldDelegate {
    private let panel: KeyablePanel
    private let container: RoundedContainer
    private let instructionField: NSTextField
    private let sendButton: NSButton
    private let spinner: NSProgressIndicator
    private let resultLabel: NSTextField
    private let cancelButton: NSButton
    private let updateButton: NSButton
    private let separator: NSView

    private var currentSnapshot: AXSelectionSnapshot?
    private var currentResult: String?
    private var rewriteTask: Task<Void, Never>?
    private var hasResult = false
    private var ignoreResign = false
    private var instructionWasEmpty = true
    var onDismiss: (() -> Void)?

    private let panelWidth: CGFloat = 420
    private let barHeight: CGFloat = 48
    private let hPad: CGFloat = 18
    private let panelCornerRadius: CGFloat = 24

    var isVisible: Bool { panel.isVisible }

    override init() {
        panel = KeyablePanel(
            contentRect: NSRect(x: 0, y: 0, width: panelWidth, height: barHeight),
            styleMask: .borderless,
            backing: .buffered,
            defer: false
        )
        panel.level = .floating
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.isReleasedWhenClosed = false

        container = RoundedContainer(frame: NSRect(x: 0, y: 0, width: panelWidth, height: barHeight))
        container.cornerRadius = panelCornerRadius
        container.autoresizingMask = [.width, .height]

        instructionField = NSTextField()
        instructionField.placeholderString = "Describe your change"
        instructionField.font = .systemFont(ofSize: 14)
        instructionField.isBordered = false
        instructionField.drawsBackground = false
        instructionField.focusRingType = .none
        instructionField.cell?.wraps = false
        instructionField.cell?.isScrollable = true

        let symbolCfg = NSImage.SymbolConfiguration(pointSize: 18, weight: .semibold)
        let sendImage = NSImage(systemSymbolName: "arrow.up.circle.fill", accessibilityDescription: "Send")?
            .withSymbolConfiguration(symbolCfg) ?? NSImage()
        sendButton = NSButton(image: sendImage, target: nil, action: nil)
        sendButton.bezelStyle = .inline
        sendButton.isBordered = false
        sendButton.contentTintColor = .controlAccentColor
        sendButton.isHidden = true

        spinner = NSProgressIndicator()
        spinner.style = .spinning
        spinner.controlSize = .small
        spinner.isHidden = true

        resultLabel = NSTextField(wrappingLabelWithString: "")
        resultLabel.font = .systemFont(ofSize: 14)
        resultLabel.textColor = .labelColor
        resultLabel.isSelectable = true
        resultLabel.drawsBackground = false
        resultLabel.isHidden = true

        cancelButton = NSButton(title: "Cancel", target: nil, action: nil)
        cancelButton.isBordered = false
        cancelButton.font = .systemFont(ofSize: 13)
        cancelButton.contentTintColor = .secondaryLabelColor
        cancelButton.isHidden = true

        updateButton = NSButton(title: "Update", target: nil, action: nil)
        updateButton.bezelStyle = .rounded
        updateButton.font = .systemFont(ofSize: 13, weight: .medium)
        updateButton.isHidden = true

        separator = NSView()
        separator.wantsLayer = true
        separator.layer?.backgroundColor = NSColor.separatorColor.cgColor
        separator.isHidden = true

        super.init()

        panel.contentView?.wantsLayer = true
        panel.contentView?.addSubview(container)

        for v: NSView in [resultLabel, separator, instructionField, sendButton, spinner, cancelButton, updateButton] {
            container.addSubview(v)
        }

        instructionField.delegate = self
        sendButton.target = self
        sendButton.action = #selector(sendClicked)
        cancelButton.target = self
        cancelButton.action = #selector(cancelClicked)
        updateButton.target = self
        updateButton.action = #selector(updateClicked)

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(panelDidResignKey),
            name: NSWindow.didResignKeyNotification,
            object: panel
        )

        layoutInputBar()
    }

    @objc private func panelDidResignKey(_: Notification) {
        if ignoreResign {
            Logger.debug("panelDidResignKey -> ignored (grace period)")
            return
        }
        Logger.debug("panelDidResignKey -> dismiss")
        dismiss()
    }

    func show(for snapshot: AXSelectionSnapshot) {
        currentSnapshot = snapshot
        currentResult = nil
        hasResult = false
        instructionWasEmpty = true

        instructionField.stringValue = ""
        instructionField.placeholderString = "Describe your change"
        instructionField.isEnabled = true
        resultLabel.isHidden = true
        separator.isHidden = true
        cancelButton.isHidden = true
        updateButton.isHidden = true
        sendButton.isHidden = true
        spinner.isHidden = true

        container.cornerRadius = panelCornerRadius

        layoutInputBar()
        panel.setFrame(
            NSRect(x: 0, y: 0, width: panelWidth, height: barHeight),
            display: false
        )
        positionPanel(near: snapshot.context.bounds)

        ignoreResign = true
        panel.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        panel.makeFirstResponder(instructionField)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            self?.ignoreResign = false
        }
    }

    func dismiss() {
        rewriteTask?.cancel()
        rewriteTask = nil
        let pid = currentSnapshot?.context.processIdentifier ?? 0
        panel.orderOut(nil)
        currentSnapshot = nil
        currentResult = nil
        hasResult = false
        onDismiss?()

        if pid != 0, let app = NSRunningApplication(processIdentifier: pid) {
            app.activate()
        }
    }

    func controlTextDidChange(_: Notification) {
        guard !hasResult else { return }
        let empty = instructionField.stringValue
            .trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        guard empty != instructionWasEmpty else { return }
        instructionWasEmpty = empty
        sendButton.isHidden = empty
        layoutInputBar()
    }

    func control(
        _: NSControl,
        textView _: NSTextView,
        doCommandBy sel: Selector
    ) -> Bool {
        if sel == #selector(NSResponder.insertNewline(_:)) {
            let text = instructionField.stringValue
                .trimmingCharacters(in: .whitespacesAndNewlines)
            if !text.isEmpty {
                submit()
            } else if hasResult {
                applyReplacement()
            }
            return true
        }
        if sel == #selector(NSResponder.cancelOperation(_:)) {
            dismiss()
            return true
        }
        return false
    }

    @objc private func sendClicked() { submit() }
    @objc private func cancelClicked() { dismiss() }
    @objc private func updateClicked() { applyReplacement() }

    private func submit() {
        guard let snapshot = currentSnapshot else { return }
        let instruction = instructionField.stringValue
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !instruction.isEmpty else { return }

        rewriteTask?.cancel()
        instructionField.isEnabled = false
        sendButton.isHidden = true
        spinner.isHidden = false
        spinner.startAnimation(nil)

        if hasResult {
            cancelButton.isHidden = true
            updateButton.isHidden = true
        }
        layoutInputBar()

        let selectionText = (hasResult ? currentResult : nil) ?? snapshot.context.text
        let context = SelectionContext(
            bundleIdentifier: snapshot.context.bundleIdentifier,
            processIdentifier: snapshot.context.processIdentifier,
            text: selectionText,
            range: SelectionRange(location: 0, length: (selectionText as NSString).length),
            bounds: snapshot.context.bounds,
            isSecure: false,
            isWritable: true
        )

        rewriteTask = Task { [weak self] in
            do {
                let config = try ConfigLoader.loadConfig()
                let request = RewriteRequest(
                    preset: RewritePreset(
                        id: "custom", name: "Custom",
                        description: "", order: 0, prompt: instruction
                    ),
                    instruction: instruction,
                    selection: context
                )
                let result = try await OpenAICompatibleClient()
                    .rewrite(request: request, config: config)
                guard !Task.isCancelled else { return }
                self?.onResult(result.output)
            } catch {
                guard !Task.isCancelled else { return }
                self?.onResult("Error: \(error.localizedDescription)")
            }
            self?.spinner.isHidden = true
            self?.spinner.stopAnimation(nil)
            self?.instructionField.isEnabled = true
        }
    }

    private func onResult(_ text: String) {
        hasResult = true
        currentResult = text
        resultLabel.stringValue = text
        resultLabel.isHidden = false
        separator.isHidden = false
        cancelButton.isHidden = false
        updateButton.isHidden = false
        sendButton.isHidden = true
        instructionField.stringValue = ""
        instructionField.placeholderString = "Ask for another edit"

        layoutResultState(animate: true)
        panel.makeFirstResponder(instructionField)
    }

    private func applyReplacement() {
        guard let snapshot = currentSnapshot,
              let output = currentResult,
              !output.isEmpty else { return }
        dismiss()

        Task {
            do {
                let coordinator = ReplacementCoordinator()
                let method = try await coordinator.apply(output, to: snapshot)
                Logger.info("replaced via \(method.rawValue)")
            } catch {
                Logger.info("replace failed: \(error.localizedDescription)")
            }
        }
    }

    private func layoutInputBar() {
        let h = barHeight
        let w = panelWidth
        let showSend = !sendButton.isHidden
        let showSpin = !spinner.isHidden

        let rightSize: CGFloat = showSend ? 24 : (showSpin ? 16 : 0)
        let rightGap: CGFloat = rightSize > 0 ? 10 : 0
        let fieldW = w - hPad * 2 - rightSize - rightGap
        instructionField.frame = NSRect(x: hPad, y: (h - 22) / 2, width: fieldW, height: 22)

        sendButton.frame = NSRect(x: w - hPad - 24, y: (h - 24) / 2, width: 24, height: 24)
        spinner.frame = NSRect(x: w - hPad - 16, y: (h - 16) / 2, width: 16, height: 16)
    }

    private func layoutResultState(animate: Bool) {
        let w = panelWidth
        let textW = w - hPad * 2

        resultLabel.preferredMaxLayoutWidth = textW
        let resultH = max(resultLabel.intrinsicContentSize.height, 18)

        let topPad: CGFloat = 16
        let sepGap: CGFloat = 12
        let totalH = topPad + resultH + sepGap + barHeight

        resultLabel.frame = NSRect(
            x: hPad, y: barHeight + sepGap,
            width: textW, height: resultH
        )

        separator.frame = NSRect(
            x: hPad, y: barHeight - 0.5,
            width: w - hPad * 2, height: 0.5
        )

        let cy = barHeight / 2

        let updateW = max(updateButton.intrinsicContentSize.width + 20, 76)
        let cancelW = cancelButton.intrinsicContentSize.width + 8
        updateButton.frame = NSRect(
            x: w - hPad - updateW, y: cy - 14,
            width: updateW, height: 28
        )
        cancelButton.frame = NSRect(
            x: updateButton.frame.minX - cancelW - 6, y: cy - 14,
            width: cancelW, height: 28
        )

        let fieldW = cancelButton.frame.minX - hPad - 8
        instructionField.frame = NSRect(
            x: hPad, y: cy - 11,
            width: fieldW, height: 22
        )

        spinner.frame = NSRect(x: w - hPad - 16, y: cy - 8, width: 16, height: 16)

        container.cornerRadius = panelCornerRadius

        var frame = panel.frame
        frame.size.height = totalH

        if animate {
            NSAnimationContext.runAnimationGroup { ctx in
                ctx.duration = 0.25
                ctx.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
                self.panel.animator().setFrame(frame, display: true)
            }
        } else {
            panel.setFrame(frame, display: true)
        }
    }

    private func positionPanel(near bounds: CGRect?) {
        guard let screen = NSScreen.main else { panel.center(); return }
        guard let bounds else { panel.center(); return }

        let sh = screen.frame.height
        var x = bounds.origin.x
        var y = sh - bounds.origin.y + 4

        if y + barHeight > screen.frame.maxY {
            y = sh - bounds.maxY - barHeight - 4
        }

        x = max(screen.frame.origin.x + 8, min(x, screen.frame.maxX - panelWidth - 8))
        y = max(screen.frame.origin.y + 8, min(y, screen.frame.maxY - barHeight - 8))

        panel.setFrameOrigin(NSPoint(x: x, y: y))
    }
}

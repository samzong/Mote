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
    private let statusLabel: NSTextField
    private let cancelButton: NSButton
    private let updateButton: NSButton
    private let separator: NSView

    private nonisolated(unsafe) var localKeyMonitor: Any?
    private var currentSnapshot: AXSelectionSnapshot?
    private var currentResult: String?
    private var rewriteTask: Task<Void, Never>?
    private var hasResult = false
    private var ignoreResign = false
    private var instructionWasEmpty = true
    private var currentWritebackCapability: WritebackCapability = .manualOnly
    private var isManualFallbackOnly = false
    var onDismiss: (() -> Void)?

    private let panelWidth: CGFloat = 420
    private let barHeight: CGFloat = 48
    private let hPad: CGFloat = 18
    private let panelCornerRadius: CGFloat = 24

    var isVisible: Bool { panel.isVisible }

    override init() {
        panel = KeyablePanel(
            contentRect: NSRect(x: 0, y: 0, width: panelWidth, height: barHeight),
            styleMask: .nonactivatingPanel,
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

        statusLabel = NSTextField(wrappingLabelWithString: "")
        statusLabel.font = .systemFont(ofSize: 12)
        statusLabel.textColor = .secondaryLabelColor
        statusLabel.drawsBackground = false
        statusLabel.isHidden = true

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

        for v: NSView in [
            resultLabel,
            statusLabel,
            separator,
            instructionField,
            sendButton,
            spinner,
            cancelButton,
            updateButton,
        ] {
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

        localKeyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self else { return event }
            return self.handleLocalKeyDown(event)
        }

        layoutInputBar()
    }

    deinit {
        if let localKeyMonitor {
            NSEvent.removeMonitor(localKeyMonitor)
        }
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
        currentWritebackCapability = snapshot.writebackCapability
        isManualFallbackOnly = false

        instructionField.stringValue = ""
        instructionField.placeholderString = "Describe your change"
        instructionField.isEnabled = true
        resultLabel.isHidden = true
        statusLabel.stringValue = ""
        statusLabel.isHidden = true
        separator.isHidden = true
        cancelButton.isHidden = true
        updateButton.isHidden = true
        updateButton.title = "Update"
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
        panel.makeFirstResponder(instructionField)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            self?.ignoreResign = false
        }
    }

    func dismiss() {
        rewriteTask?.cancel()
        rewriteTask = nil
        panel.orderOut(nil)
        currentSnapshot = nil
        currentResult = nil
        hasResult = false
        currentWritebackCapability = .manualOnly
        isManualFallbackOnly = false
        statusLabel.stringValue = ""
        statusLabel.isHidden = true
        onDismiss?()
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
        let newlineSelectors: [Selector] = [
            #selector(NSResponder.insertNewline(_:)),
            #selector(NSResponder.insertLineBreak(_:)),
            #selector(NSResponder.insertNewlineIgnoringFieldEditor(_:)),
        ]

        if newlineSelectors.contains(sel) {
            performPrimaryAction()
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
    @objc private func updateClicked() {
        if isManualFallbackOnly {
            copyCurrentResult()
        } else {
            applyReplacement()
        }
    }

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

    private func handleLocalKeyDown(_ event: NSEvent) -> NSEvent? {
        guard panel.isVisible,
              panel.isKeyWindow,
              event.modifierFlags.intersection(.deviceIndependentFlagsMask).contains(.command),
              event.keyCode == 36 || event.keyCode == 76
        else {
            return event
        }

        performPrimaryAction()
        return nil
    }

    private func performPrimaryAction() {
        let text = instructionField.stringValue
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if !text.isEmpty {
            submit()
        } else if hasResult {
            if isManualFallbackOnly {
                copyCurrentResult()
            } else {
                applyReplacement()
            }
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
        isManualFallbackOnly = false
        updateResultActions()

        layoutResultState(animate: true)
        panel.makeFirstResponder(instructionField)
    }

    private func applyReplacement() {
        guard let snapshot = currentSnapshot,
              let output = currentResult,
              !output.isEmpty else { return }

        ignoreResign = true
        panel.orderOut(nil)

        Task {
            let coordinator = ReplacementCoordinator()
            let outcome = await coordinator.apply(output, to: snapshot)

            switch outcome {
                case .appliedDirect, .appliedPaste:
                    Logger.info("replaced via \(outcome.rawValue)")
                    self.ignoreResign = false
                    self.dismiss()
                case .needsManualApply:
                    Logger.info("automatic apply unavailable, switching to manual fallback")
                    self.presentManualFallback(
                        from: snapshot,
                        result: output,
                        status: "Selection changed. Copy the result and apply it manually."
                    )
                case .failed:
                    Logger.info("automatic apply failed, switching to manual fallback")
                    self.presentManualFallback(
                        from: snapshot,
                        result: output,
                        status: "Automatic apply failed. Copy the result and apply it manually."
                    )
            }
        }
    }

    private func copyCurrentResult() {
        guard let output = currentResult, !output.isEmpty else { return }
        copyResultToClipboard(output)
        Logger.info("copied rewrite result to clipboard")
        dismiss()
    }

    @discardableResult
    private func copyResultToClipboard(_ text: String) -> Bool {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        return pasteboard.setString(text, forType: .string)
    }

    private func updateResultActions(status: String? = nil) {
        if let status {
            statusLabel.stringValue = status
            statusLabel.isHidden = false
        } else if isManualFallbackOnly {
            statusLabel.stringValue = "Automatic apply is unavailable for this selection. Copy the result and apply it manually."
            statusLabel.isHidden = false
        } else if currentWritebackCapability == .manualOnly {
            statusLabel.stringValue = "Mote will verify the current selection before applying."
            statusLabel.isHidden = false
        } else {
            statusLabel.stringValue = ""
            statusLabel.isHidden = true
        }

        updateButton.title = isManualFallbackOnly ? "Copy" : "Update"
    }

    private func presentManualFallback(
        from snapshot: AXSelectionSnapshot,
        result: String,
        status: String
    ) {
        let fallbackSnapshot = AXSelectionSnapshot(
            element: snapshot.element,
            context: snapshot.context,
            proof: .unproven,
            writebackCapability: .manualOnly,
            fieldText: snapshot.fieldText
        )

        currentSnapshot = fallbackSnapshot
        currentResult = result
        currentWritebackCapability = .manualOnly
        isManualFallbackOnly = true
        hasResult = true
        resultLabel.stringValue = result
        resultLabel.isHidden = false
        separator.isHidden = false
        cancelButton.isHidden = false
        updateButton.isHidden = false
        sendButton.isHidden = true
        spinner.isHidden = true
        instructionField.isEnabled = true
        instructionField.placeholderString = "Ask for another edit"
        let copied = copyResultToClipboard(result)
        let effectiveStatus = copied
            ? "\(status) The result was copied to the clipboard."
            : status
        updateResultActions(status: effectiveStatus)
        layoutResultState(animate: false)
        panel.makeKeyAndOrderFront(nil)
        panel.makeFirstResponder(instructionField)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            self?.ignoreResign = false
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
        statusLabel.preferredMaxLayoutWidth = textW
        let statusH = statusLabel.isHidden ? 0 : max(statusLabel.intrinsicContentSize.height, 16)

        let topPad: CGFloat = 16
        let statusGap: CGFloat = statusLabel.isHidden ? 0 : 8
        let sepGap: CGFloat = 12
        let totalH = topPad + resultH + statusGap + statusH + sepGap + barHeight

        resultLabel.frame = NSRect(
            x: hPad,
            y: barHeight + sepGap + statusGap + statusH,
            width: textW, height: resultH
        )

        statusLabel.frame = NSRect(
            x: hPad,
            y: barHeight + sepGap,
            width: textW,
            height: statusH
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

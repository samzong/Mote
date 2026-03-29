import AppKit
import MoteCore

@MainActor
final class ComposerPanel: NSObject, NSTextFieldDelegate {
    let panel: KeyablePanel
    let container: RoundedContainer
    let instructionField: NSTextField
    let sendButton: NSButton
    let spinner: NSProgressIndicator
    let resultLabel: NSTextField
    let statusLabel: NSTextField
    let cancelButton: NSButton
    let updateButton: NSButton
    let separator: NSView
    let manageSeparator: NSView
    let settingsButton: NSButton
    let quitButton: NSButton

    private nonisolated(unsafe) var localKeyMonitor: Any?
    var currentSnapshot: AXSelectionSnapshot?
    var currentResult: String?
    private var rewriteTask: Task<Void, Never>?
    var hasResult = false
    var ignoreResign = false
    var instructionWasEmpty = true
    var currentWritebackCapability: WritebackCapability = .manualOnly
    var isManualFallbackOnly = false
    var isManageMode = false
    var onDismiss: (() -> Void)?

    let suggestionsContainer: NSView
    var filteredCommands: [(name: String, prompt: String)] = []
    var selectedSuggestionIndex = -1

    let panelWidth: CGFloat = 420
    let barHeight: CGFloat = 48
    let hPad: CGFloat = 18
    let panelCornerRadius: CGFloat = 24

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

        manageSeparator = NSView()
        manageSeparator.wantsLayer = true
        manageSeparator.layer?.backgroundColor = NSColor.separatorColor.cgColor
        manageSeparator.isHidden = true

        settingsButton = NSButton(title: "Settings…", target: nil, action: nil)
        settingsButton.isBordered = false
        settingsButton.font = .systemFont(ofSize: 13)
        settingsButton.contentTintColor = .secondaryLabelColor
        settingsButton.isHidden = true

        quitButton = NSButton(title: "Quit Mote", target: nil, action: nil)
        quitButton.isBordered = false
        quitButton.font = .systemFont(ofSize: 13)
        quitButton.contentTintColor = .systemRed
        quitButton.isHidden = true

        suggestionsContainer = NSView()
        suggestionsContainer.wantsLayer = true
        suggestionsContainer.isHidden = true

        super.init()
        setUp()
    }

    deinit {
        if let localKeyMonitor {
            NSEvent.removeMonitor(localKeyMonitor)
        }
    }

    private func setUp() {
        panel.contentView?.wantsLayer = true
        panel.contentView?.addSubview(container)

        for v: NSView in [
            resultLabel, statusLabel, separator,
            instructionField, sendButton, spinner,
            cancelButton, updateButton,
            manageSeparator, settingsButton, quitButton,
        ] {
            container.addSubview(v)
        }
        container.addSubview(suggestionsContainer)

        instructionField.delegate = self
        sendButton.target = self
        sendButton.action = #selector(sendClicked)
        cancelButton.target = self
        cancelButton.action = #selector(cancelClicked)
        updateButton.target = self
        updateButton.action = #selector(updateClicked)
        settingsButton.target = self
        settingsButton.action = #selector(settingsClicked)
        quitButton.target = self
        quitButton.action = #selector(quitClicked)

        NotificationCenter.default.addObserver(
            self, selector: #selector(panelDidResignKey),
            name: NSWindow.didResignKeyNotification, object: panel
        )

        localKeyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self else { return event }
            return self.handleLocalKeyDown(event)
        }

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
        hideCommandSuggestions()

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

    func showManagement() {
        if panel.isVisible, isManageMode {
            dismiss()
            return
        }
        if panel.isVisible { dismiss() }

        isManageMode = true
        currentSnapshot = nil
        currentResult = nil
        hasResult = false

        instructionField.stringValue = ""
        instructionField.placeholderString = "Fn to rewrite selected text"
        instructionField.isEnabled = false
        resultLabel.isHidden = true
        statusLabel.isHidden = true
        separator.isHidden = true
        cancelButton.isHidden = true
        updateButton.isHidden = true
        sendButton.isHidden = true
        spinner.isHidden = true

        manageSeparator.isHidden = false
        settingsButton.isHidden = false
        quitButton.isHidden = false

        let manageRowH: CGFloat = 36
        let totalH = barHeight + manageRowH
        container.cornerRadius = panelCornerRadius
        layoutInputBar()
        layoutManageRow(totalH: totalH)
        panel.setFrame(
            NSRect(x: 0, y: 0, width: panelWidth, height: totalH),
            display: false
        )
        positionPanel(near: nil)

        ignoreResign = true
        panel.makeKeyAndOrderFront(nil)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            self?.ignoreResign = false
        }
    }

    func dismiss() {
        rewriteTask?.cancel()
        rewriteTask = nil
        hideCommandSuggestions()
        panel.orderOut(nil)
        currentSnapshot = nil
        currentResult = nil
        hasResult = false
        currentWritebackCapability = .manualOnly
        isManualFallbackOnly = false
        isManageMode = false
        statusLabel.stringValue = ""
        statusLabel.isHidden = true
        manageSeparator.isHidden = true
        settingsButton.isHidden = true
        quitButton.isHidden = true
        onDismiss?()
    }

    @objc private func settingsClicked() {
        NSWorkspace.shared.open(ConfigLoader.configURL())
        dismiss()
    }

    @objc private func quitClicked() {
        NSApp.terminate(nil)
    }

    func controlTextDidChange(_: Notification) {
        guard !hasResult else { return }
        let text = instructionField.stringValue
        updateCommandSuggestions(text: text)
        let empty = text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        guard empty != instructionWasEmpty else { return }
        instructionWasEmpty = empty
        sendButton.isHidden = empty
        layoutInputBar()
    }

    func control(
        _: NSControl, textView _: NSTextView, doCommandBy sel: Selector
    ) -> Bool {
        if handleSuggestionKeyDown(sel) {
            return true
        }
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
        if isManualFallbackOnly { copyCurrentResult() } else { applyReplacement() }
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
        guard panel.isVisible, panel.isKeyWindow,
              event.modifierFlags.intersection(.deviceIndependentFlagsMask).contains(.command),
              event.keyCode == 36 || event.keyCode == 76
        else { return event }
        performPrimaryAction()
        return nil
    }

    private func performPrimaryAction() {
        let text = instructionField.stringValue
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if !text.isEmpty {
            submit()
        } else if hasResult {
            if isManualFallbackOnly { copyCurrentResult() } else { applyReplacement() }
        }
    }

    func onResult(_ text: String) {
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
}

import AppKit
import MoteCore

@MainActor
final class ComposerPanelController: NSObject, NSWindowDelegate, NSTextFieldDelegate, NSSearchFieldDelegate {
    var onClose: (() -> Void)?

    private let replacementCoordinator: ReplacementCoordinator
    private let panel: ComposerPanel
    private let rootView = NSView()
    private let commandControl = NSSegmentedControl()
    private let inputSurface = NSVisualEffectView()
    private let inputField = NSSearchField()
    private let sendButton = SendButton()
    private let resultSurface = NSVisualEffectView()
    private let resultScrollView = NSScrollView()
    private let resultTextView = NSTextView()
    private let statusLabel = NSTextField(labelWithString: "")
    private let progressIndicator = NSProgressIndicator()
    private let cancelButton = NSButton(title: "Cancel", target: nil, action: nil)
    private let updateButton = NSButton(title: "Update", target: nil, action: nil)

    private var keyMonitor: Any?
    private var commands: [RewritePreset] = []
    private var visibleCommands: [RewritePreset] = []
    private var currentSnapshot: AXSelectionSnapshot?
    private var currentOutput: String?
    private var activeTask: Task<Void, Never>?

    init(replacementCoordinator: ReplacementCoordinator = ReplacementCoordinator()) {
        self.replacementCoordinator = replacementCoordinator
        panel = ComposerPanel(
            contentRect: CGRect(x: 0, y: 0, width: 520, height: 86),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )

        super.init()
        buildPanel()
    }

    var isVisible: Bool {
        panel.isVisible
    }

    func show(for snapshot: AXSelectionSnapshot) {
        currentSnapshot = snapshot
        currentOutput = nil
        resultTextView.string = ""
        inputField.stringValue = ""
        progressIndicator.stopAnimation(nil)

        do {
            commands = try CommandStore.load()
        } catch {
            commands = []
            setStatus(error.localizedDescription)
        }

        visibleCommands = Array(commands.prefix(CommandStore.defaultVisibleLimit))
        configureCommandControl()
        applyExpandedState(false)
        setStatus("")

        let frame = frameForPanel(from: snapshot.context.bounds, expanded: false)
        panel.setFrame(frame, display: true)
        panel.alphaValue = 0
        NSApp.activate(ignoringOtherApps: true)
        panel.orderFrontRegardless()
        panel.makeKey()
        panel.makeFirstResponder(inputField)
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.12
            panel.animator().alphaValue = 1
        }
        installKeyMonitor()
    }

    func close() {
        activeTask?.cancel()
        activeTask = nil
        removeKeyMonitor()
        panel.orderOut(nil)
        onClose?()
    }

    func windowWillClose(_ notification: Notification) {
        close()
    }

    func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
        if commandSelector == #selector(NSResponder.insertNewline(_:)) {
            generateRewrite()
            return true
        }

        if commandSelector == #selector(NSResponder.cancelOperation(_:)) {
            close()
            return true
        }

        return false
    }

    private var collapsedSize: CGSize {
        CGSize(width: 520, height: visibleCommands.isEmpty ? 78 : 106)
    }

    private var expandedSize: CGSize {
        CGSize(width: 520, height: visibleCommands.isEmpty ? 188 : 216)
    }

    private func buildPanel() {
        panel.delegate = self
        panel.isFloatingPanel = true
        panel.level = .floating
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.hidesOnDeactivate = false
        panel.contentView = rootView

        rootView.translatesAutoresizingMaskIntoConstraints = false
        rootView.wantsLayer = true
        rootView.layer?.backgroundColor = NSColor.clear.cgColor

        commandControl.segmentDistribution = .fillEqually
        commandControl.trackingMode = .selectOne
        commandControl.controlSize = .small
        commandControl.target = self
        commandControl.action = #selector(handleCommandSelection(_:))
        commandControl.translatesAutoresizingMaskIntoConstraints = false

        inputSurface.material = .popover
        inputSurface.blendingMode = .withinWindow
        inputSurface.state = .active
        inputSurface.wantsLayer = true
        inputSurface.layer?.cornerRadius = 22
        inputSurface.layer?.borderWidth = 1
        inputSurface.layer?.borderColor = NSColor.separatorColor.withAlphaComponent(0.35).cgColor
        inputSurface.translatesAutoresizingMaskIntoConstraints = false

        inputField.placeholderString = "Describe your change"
        inputField.delegate = self
        inputField.font = NSFont.systemFont(ofSize: 16, weight: .regular)
        inputField.focusRingType = .none
        inputField.maximumRecents = 0
        inputField.sendsWholeSearchString = true
        inputField.translatesAutoresizingMaskIntoConstraints = false

        sendButton.target = self
        sendButton.action = #selector(handleGenerate)
        sendButton.translatesAutoresizingMaskIntoConstraints = false

        inputSurface.addSubview(inputField)
        inputSurface.addSubview(sendButton)

        resultSurface.material = .popover
        resultSurface.blendingMode = .withinWindow
        resultSurface.state = .active
        resultSurface.wantsLayer = true
        resultSurface.layer?.cornerRadius = 18
        resultSurface.layer?.borderWidth = 1
        resultSurface.layer?.borderColor = NSColor.separatorColor.withAlphaComponent(0.30).cgColor
        resultSurface.translatesAutoresizingMaskIntoConstraints = false
        resultSurface.isHidden = true

        resultTextView.isEditable = false
        resultTextView.font = NSFont.systemFont(ofSize: 14)
        resultTextView.drawsBackground = false
        resultTextView.backgroundColor = .clear
        resultTextView.textContainerInset = NSSize(width: 8, height: 8)

        resultScrollView.drawsBackground = false
        resultScrollView.borderType = .noBorder
        resultScrollView.hasVerticalScroller = true
        resultScrollView.documentView = resultTextView
        resultScrollView.translatesAutoresizingMaskIntoConstraints = false
        resultSurface.addSubview(resultScrollView)

        statusLabel.font = NSFont.systemFont(ofSize: 12, weight: .medium)
        statusLabel.textColor = .secondaryLabelColor
        statusLabel.isHidden = true
        statusLabel.translatesAutoresizingMaskIntoConstraints = false

        progressIndicator.style = .spinning
        progressIndicator.controlSize = .small
        progressIndicator.isDisplayedWhenStopped = false
        progressIndicator.translatesAutoresizingMaskIntoConstraints = false

        cancelButton.bezelStyle = .rounded
        cancelButton.controlSize = .regular
        cancelButton.target = self
        cancelButton.action = #selector(handleCancel)
        cancelButton.translatesAutoresizingMaskIntoConstraints = false
        cancelButton.isHidden = true

        updateButton.bezelStyle = .rounded
        updateButton.controlSize = .regular
        updateButton.target = self
        updateButton.action = #selector(handleUpdate)
        updateButton.translatesAutoresizingMaskIntoConstraints = false
        updateButton.isHidden = true

        rootView.addSubview(commandControl)
        rootView.addSubview(inputSurface)
        rootView.addSubview(resultSurface)
        rootView.addSubview(statusLabel)
        rootView.addSubview(progressIndicator)
        rootView.addSubview(cancelButton)
        rootView.addSubview(updateButton)

        NSLayoutConstraint.activate([
            commandControl.leadingAnchor.constraint(equalTo: rootView.leadingAnchor, constant: 12),
            commandControl.trailingAnchor.constraint(equalTo: rootView.trailingAnchor, constant: -12),
            commandControl.topAnchor.constraint(equalTo: rootView.topAnchor, constant: 8),
            commandControl.heightAnchor.constraint(equalToConstant: 24),

            inputSurface.leadingAnchor.constraint(equalTo: rootView.leadingAnchor, constant: 12),
            inputSurface.trailingAnchor.constraint(equalTo: rootView.trailingAnchor, constant: -12),
            inputSurface.topAnchor.constraint(equalTo: commandControl.bottomAnchor, constant: 8),
            inputSurface.heightAnchor.constraint(equalToConstant: 44),

            inputField.leadingAnchor.constraint(equalTo: inputSurface.leadingAnchor, constant: 12),
            inputField.centerYAnchor.constraint(equalTo: inputSurface.centerYAnchor),
            sendButton.trailingAnchor.constraint(equalTo: inputSurface.trailingAnchor, constant: -8),
            sendButton.centerYAnchor.constraint(equalTo: inputSurface.centerYAnchor),
            sendButton.widthAnchor.constraint(equalToConstant: 28),
            sendButton.heightAnchor.constraint(equalToConstant: 28),
            inputField.trailingAnchor.constraint(equalTo: sendButton.leadingAnchor, constant: -8),

            resultSurface.leadingAnchor.constraint(equalTo: rootView.leadingAnchor, constant: 12),
            resultSurface.trailingAnchor.constraint(equalTo: rootView.trailingAnchor, constant: -12),
            resultSurface.topAnchor.constraint(equalTo: inputSurface.bottomAnchor, constant: 8),
            resultSurface.heightAnchor.constraint(equalToConstant: 84),

            resultScrollView.leadingAnchor.constraint(equalTo: resultSurface.leadingAnchor, constant: 8),
            resultScrollView.trailingAnchor.constraint(equalTo: resultSurface.trailingAnchor, constant: -8),
            resultScrollView.topAnchor.constraint(equalTo: resultSurface.topAnchor, constant: 8),
            resultScrollView.bottomAnchor.constraint(equalTo: resultSurface.bottomAnchor, constant: -8),

            statusLabel.leadingAnchor.constraint(equalTo: rootView.leadingAnchor, constant: 14),
            statusLabel.bottomAnchor.constraint(equalTo: rootView.bottomAnchor, constant: -10),

            progressIndicator.centerYAnchor.constraint(equalTo: statusLabel.centerYAnchor),
            progressIndicator.trailingAnchor.constraint(equalTo: cancelButton.leadingAnchor, constant: -8),

            cancelButton.bottomAnchor.constraint(equalTo: rootView.bottomAnchor, constant: -8),
            cancelButton.trailingAnchor.constraint(equalTo: updateButton.leadingAnchor, constant: -8),
            updateButton.bottomAnchor.constraint(equalTo: rootView.bottomAnchor, constant: -8),
            updateButton.trailingAnchor.constraint(equalTo: rootView.trailingAnchor, constant: -12),
        ])
    }

    private func configureCommandControl() {
        commandControl.segmentCount = visibleCommands.count
        for (index, command) in visibleCommands.enumerated() {
            commandControl.setLabel(command.name, forSegment: index)
            commandControl.setWidth(0, forSegment: index)
        }

        if visibleCommands.isEmpty {
            commandControl.isHidden = true
            commandControl.selectedSegment = -1
        } else {
            commandControl.isHidden = false
            commandControl.selectedSegment = 0
        }
    }

    private func currentCommand() -> RewritePreset? {
        guard commandControl.selectedSegment >= 0, commandControl.selectedSegment < visibleCommands.count else {
            return nil
        }

        return visibleCommands[commandControl.selectedSegment]
    }

    private func applyExpandedState(_ expanded: Bool) {
        resultSurface.isHidden = !expanded
        cancelButton.isHidden = !expanded
        updateButton.isHidden = !expanded
    }

    private func resolvedRequest() -> (RewritePreset, String)? {
        let trimmedInput = inputField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)

        if trimmedInput.hasPrefix("/") {
            let body = String(trimmedInput.dropFirst())
            let parts = body.split(maxSplits: 1, whereSeparator: \.isWhitespace)
            let commandID = parts.first.map(String.init)?.lowercased() ?? ""
            let customInstruction = parts.count > 1 ? String(parts[1]).trimmingCharacters(in: .whitespacesAndNewlines) : ""

            if let command = commands.first(where: { $0.id.lowercased() == commandID }) {
                return (command, customInstruction.isEmpty ? command.prompt : customInstruction)
            }
        }

        if trimmedInput.isEmpty, let command = currentCommand() {
            return (command, command.prompt)
        }

        if trimmedInput.isEmpty {
            return nil
        }

        return (
            currentCommand() ?? RewritePreset(id: "custom", name: "Custom", description: "", order: 0, prompt: ""),
            trimmedInput
        )
    }

    private func frameForPanel(from bounds: CGRect?, expanded: Bool) -> CGRect {
        let size = expanded ? expandedSize : collapsedSize

        guard let bounds else {
            let visibleFrame = NSScreen.main?.visibleFrame ?? CGRect(x: 0, y: 0, width: 1200, height: 800)
            return CGRect(
                x: visibleFrame.midX - size.width / 2,
                y: visibleFrame.midY - size.height / 2,
                width: size.width,
                height: size.height
            )
        }

        let rect = convertAccessibilityRect(bounds)
        let visibleFrame = NSScreen.main?.visibleFrame ?? rect.insetBy(dx: -300, dy: -300)
        let preferredX = rect.minX - 8
        let preferredY = rect.maxY + 16
        let x = min(max(preferredX, visibleFrame.minX + 10), visibleFrame.maxX - size.width - 10)
        let y = min(max(preferredY, visibleFrame.minY + 10), visibleFrame.maxY - size.height - 10)
        return CGRect(x: x, y: y, width: size.width, height: size.height)
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

    private func installKeyMonitor() {
        removeKeyMonitor()
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self, self.panel.isVisible, self.panel.isKeyWindow else {
                return event
            }

            if event.keyCode == 53 {
                self.close()
                return nil
            }

            return event
        }
    }

    private func removeKeyMonitor() {
        if let keyMonitor {
            NSEvent.removeMonitor(keyMonitor)
        }
        keyMonitor = nil
    }

    private func setStatus(_ text: String) {
        statusLabel.stringValue = text
        statusLabel.isHidden = text.isEmpty
    }

    private func setLoading(_ loading: Bool) {
        inputField.isEnabled = !loading
        sendButton.isEnabled = !loading
        commandControl.isEnabled = !loading
        updateButton.isEnabled = !loading
        cancelButton.isEnabled = !loading

        if loading {
            progressIndicator.startAnimation(nil)
            setStatus("")
        } else {
            progressIndicator.stopAnimation(nil)
        }
    }

    @objc
    private func handleCommandSelection(_ sender: NSSegmentedControl) {
        _ = sender
    }

    @objc
    private func handleGenerate() {
        generateRewrite()
    }

    @objc
    private func handleCancel() {
        close()
    }

    @objc
    private func handleUpdate() {
        applyUpdate()
    }

    private func generateRewrite() {
        guard let snapshot = currentSnapshot else {
            setStatus("No active selection.")
            return
        }

        guard let (command, instruction) = resolvedRequest() else {
            setStatus("Pick a command or type an instruction.")
            return
        }

        let config: AppConfig
        do {
            config = try ConfigLoader.loadConfig()
        } catch {
            setStatus(error.localizedDescription)
            return
        }

        let missingFields = config.missingRequiredFields
        guard missingFields.isEmpty else {
            setStatus("Config is incomplete: \(missingFields.joined(separator: ", "))")
            return
        }

        currentOutput = nil
        resultTextView.string = ""
        applyExpandedState(false)
        activeTask?.cancel()
        setLoading(true)

        let request = RewriteRequest(preset: command, instruction: instruction, selection: snapshot.context)
        activeTask = Task { [weak self] in
            guard let self else {
                return
            }

            do {
                let result = try await OpenAICompatibleClient().rewrite(request: request, config: config)
                await MainActor.run {
                    self.currentOutput = result.output
                    self.resultTextView.string = result.output
                    self.applyExpandedState(true)
                    self.setStatus("Review the rewrite, then update.")
                    self.panel.setFrame(self.frameForPanel(from: snapshot.context.bounds, expanded: true), display: true, animate: true)
                    self.setLoading(false)
                }
            } catch {
                await MainActor.run {
                    self.setStatus(error.localizedDescription)
                    self.setLoading(false)
                }
            }
        }
    }

    private func applyUpdate() {
        guard let snapshot = currentSnapshot, let currentOutput else {
            return
        }

        panel.orderOut(nil)
        setLoading(true)

        Task { [weak self] in
            guard let self else {
                return
            }

            do {
                let method = try await MainActor.run {
                    try replacementCoordinator.apply(currentOutput, to: snapshot)
                }
                await MainActor.run {
                    self.setLoading(false)
                    self.close()
                    Logger.info("replacement method=\(method.rawValue)")
                }
            } catch {
                await MainActor.run {
                    self.panel.makeKeyAndOrderFront(nil)
                    self.setStatus(error.localizedDescription)
                    self.setLoading(false)
                }
            }
        }
    }
}

private final class ComposerPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}

private final class SendButton: NSButton {
    init() {
        super.init(frame: .zero)
        bezelStyle = .texturedRounded
        isBordered = false
        image = NSImage(systemSymbolName: "arrow.up", accessibilityDescription: "Rewrite")
        contentTintColor = .white
        wantsLayer = true
    }

    required init?(coder: NSCoder) {
        nil
    }

    override var intrinsicContentSize: NSSize {
        NSSize(width: 28, height: 28)
    }

    override func layout() {
        super.layout()
        layer?.cornerRadius = bounds.width / 2
        layer?.backgroundColor = NSColor.black.cgColor
    }
}

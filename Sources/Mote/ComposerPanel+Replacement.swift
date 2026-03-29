import AppKit
import MoteCore

extension ComposerPanel {
    func applyReplacement() {
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
                        from: snapshot, result: output,
                        status: "Selection changed. Copy the result and apply it manually."
                    )
                case .failed:
                    Logger.info("automatic apply failed, switching to manual fallback")
                    self.presentManualFallback(
                        from: snapshot, result: output,
                        status: "Automatic apply failed. Copy the result and apply it manually."
                    )
            }
        }
    }

    func copyCurrentResult() {
        guard let output = currentResult, !output.isEmpty else { return }
        copyResultToClipboard(output)
        Logger.info("copied rewrite result to clipboard")
        dismiss()
    }

    @discardableResult
    func copyResultToClipboard(_ text: String) -> Bool {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        return pasteboard.setString(text, forType: .string)
    }

    func updateResultActions(status: String? = nil) {
        if let status {
            statusLabel.stringValue = status
            statusLabel.isHidden = false
        } else if isManualFallbackOnly {
            statusLabel.stringValue = "Automatic apply is unavailable for this selection. "
                + "Copy the result and apply it manually."
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

    func presentManualFallback(
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
}

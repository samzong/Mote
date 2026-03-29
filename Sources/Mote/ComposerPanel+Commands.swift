import AppKit
import MoteCore

private final class SuggestionRowView: NSView {
    var index = 0
}

extension ComposerPanel {
    private static let suggestionRowHeight: CGFloat = 30
    private static let maxVisibleSuggestions = 7
    private static let rowInset: CGFloat = 8

    var isSuggestionsVisible: Bool {
        !suggestionsContainer.isHidden
    }

    func updateCommandSuggestions(text: String) {
        guard text.hasPrefix("/"), !hasResult else {
            hideCommandSuggestions()
            return
        }

        let query = String(text.dropFirst()).lowercased()
        let all = CommandLoader.loadCommands()

        if query.isEmpty {
            filteredCommands = all.sorted { $0.key < $1.key }
                .map { (name: $0.key, prompt: $0.value) }
        } else {
            filteredCommands = all.filter { $0.key.lowercased().hasPrefix(query) }
                .sorted { $0.key < $1.key }
                .map { (name: $0.key, prompt: $0.value) }
        }

        guard !filteredCommands.isEmpty else {
            hideCommandSuggestions()
            return
        }

        showCommandSuggestions()
    }

    func hideCommandSuggestions() {
        guard isSuggestionsVisible else { return }
        suggestionsContainer.isHidden = true
        suggestionsContainer.subviews.forEach { $0.removeFromSuperview() }
        filteredCommands = []
        selectedSuggestionIndex = -1

        if !hasResult {
            var frame = panel.frame
            frame.size.height = barHeight
            panel.setFrame(frame, display: true)
        }
    }

    func handleSuggestionKeyDown(_ sel: Selector) -> Bool {
        guard isSuggestionsVisible else { return false }

        if sel == #selector(NSResponder.moveUp(_:)) {
            moveSuggestionSelection(by: -1)
            return true
        }
        if sel == #selector(NSResponder.moveDown(_:)) {
            moveSuggestionSelection(by: 1)
            return true
        }
        if sel == #selector(NSResponder.insertTab(_:)) ||
            sel == #selector(NSResponder.insertNewline(_:)) ||
            sel == #selector(NSResponder.insertNewlineIgnoringFieldEditor(_:))
        {
            acceptSelectedSuggestion()
            return true
        }
        if sel == #selector(NSResponder.cancelOperation(_:)) {
            hideCommandSuggestions()
            return true
        }
        return false
    }

    private func showCommandSuggestions() {
        suggestionsContainer.subviews.forEach { $0.removeFromSuperview() }

        let count = min(filteredCommands.count, Self.maxVisibleSuggestions)
        selectedSuggestionIndex = 0

        let separatorLine = NSView()
        separatorLine.wantsLayer = true
        separatorLine.layer?.backgroundColor = NSColor.separatorColor.cgColor
        suggestionsContainer.addSubview(separatorLine)

        for i in 0 ..< count {
            let row = makeSuggestionRow(index: i)
            suggestionsContainer.addSubview(row)
        }

        suggestionsContainer.isHidden = false
        layoutCommandSuggestions()
    }

    private func moveSuggestionSelection(by delta: Int) {
        let count = min(filteredCommands.count, Self.maxVisibleSuggestions)
        guard count > 0 else { return }
        selectedSuggestionIndex = ((selectedSuggestionIndex + delta) % count + count) % count
        updateSuggestionHighlight()
    }

    private func updateSuggestionHighlight() {
        for case let row as SuggestionRowView in suggestionsContainer.subviews {
            row.layer?.backgroundColor = row.index == selectedSuggestionIndex
                ? NSColor.controlAccentColor.withAlphaComponent(0.08).cgColor
                : nil
        }
    }

    func acceptSelectedSuggestion() {
        guard selectedSuggestionIndex >= 0,
              selectedSuggestionIndex < filteredCommands.count
        else { return }

        let name = filteredCommands[selectedSuggestionIndex].name
        instructionField.stringValue = "/\(name) "
        instructionField.currentEditor()?.selectedRange = NSRange(
            location: instructionField.stringValue.count, length: 0
        )
        hideCommandSuggestions()

        sendButton.isHidden = false
        instructionWasEmpty = false
        layoutInputBar()
    }

    private func makeSuggestionRow(index: Int) -> SuggestionRowView {
        let rowH = Self.suggestionRowHeight
        let row = SuggestionRowView(frame: .zero)
        row.wantsLayer = true
        row.layer?.cornerRadius = 5
        row.index = index

        let cmd = filteredCommands[index]

        let nameLabel = NSTextField(labelWithString: "/\(cmd.name)")
        nameLabel.font = .monospacedSystemFont(ofSize: 13, weight: .medium)
        nameLabel.textColor = .labelColor
        nameLabel.lineBreakMode = .byClipping

        let descLabel = NSTextField(labelWithString: cmd.prompt)
        descLabel.font = .systemFont(ofSize: 12)
        descLabel.textColor = .tertiaryLabelColor
        descLabel.lineBreakMode = .byTruncatingTail

        row.addSubview(nameLabel)
        row.addSubview(descLabel)

        let innerPad: CGFloat = 10
        let nameW: CGFloat = 90
        nameLabel.frame = NSRect(x: innerPad, y: (rowH - 16) / 2, width: nameW, height: 16)
        let descX = innerPad + nameW + 6
        descLabel.frame = NSRect(
            x: descX,
            y: (rowH - 16) / 2,
            width: panelWidth - Self.rowInset * 2 - descX,
            height: 16
        )

        if index == selectedSuggestionIndex {
            row.layer?.backgroundColor = NSColor.controlAccentColor.withAlphaComponent(0.08).cgColor
        }

        let click = NSClickGestureRecognizer(target: self, action: #selector(suggestionClicked(_:)))
        row.addGestureRecognizer(click)

        return row
    }

    @objc func suggestionClicked(_ gesture: NSClickGestureRecognizer) {
        guard let row = gesture.view as? SuggestionRowView else { return }
        selectedSuggestionIndex = row.index
        acceptSelectedSuggestion()
    }

    private func layoutCommandSuggestions() {
        let count = min(filteredCommands.count, Self.maxVisibleSuggestions)
        let rowH = Self.suggestionRowHeight
        let inset = Self.rowInset
        let padTop: CGFloat = 10
        let padBottom: CGFloat = 6
        let separatorH: CGFloat = 0.5
        let suggestionsH = CGFloat(count) * rowH + padTop + padBottom + separatorH

        suggestionsContainer.frame = NSRect(
            x: 0, y: barHeight,
            width: panelWidth, height: suggestionsH
        )

        for view in suggestionsContainer.subviews {
            if view is SuggestionRowView { continue }
            view.frame = NSRect(
                x: hPad, y: 0,
                width: panelWidth - hPad * 2, height: separatorH
            )
        }

        for case let row as SuggestionRowView in suggestionsContainer.subviews {
            row.frame = NSRect(
                x: inset,
                y: padBottom + separatorH + CGFloat(count - 1 - row.index) * rowH,
                width: panelWidth - inset * 2,
                height: rowH
            )
        }

        let totalH = barHeight + suggestionsH
        var frame = panel.frame
        frame.size.height = totalH
        panel.setFrame(frame, display: true)
    }
}

import AppKit

extension ComposerPanel {
    func layoutInputBar() {
        let h = barHeight
        let w = panelWidth
        let showSend = !sendButton.isHidden
        let showSpin = !spinner.isHidden
        let showQuit = !quitButton.isHidden

        let quitW = showQuit ? quitButton.intrinsicContentSize.width + 8 : 0
        let rightSize: CGFloat = showSend ? 24 : (showSpin ? 16 : quitW)
        let rightGap: CGFloat = rightSize > 0 ? 10 : 0
        let fieldW = w - hPad * 2 - rightSize - rightGap
        instructionField.frame = NSRect(x: hPad, y: (h - 22) / 2, width: fieldW, height: 22)

        sendButton.frame = NSRect(x: w - hPad - 24, y: (h - 24) / 2, width: 24, height: 24)
        spinner.frame = NSRect(x: w - hPad - 16, y: (h - 16) / 2, width: 16, height: 16)
        if showQuit {
            quitButton.frame = NSRect(x: w - hPad - quitW, y: (h - 28) / 2, width: quitW, height: 28)
        }
    }

    func layoutResultState(animate: Bool) {
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

    func positionPanel(near bounds: CGRect?) {
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

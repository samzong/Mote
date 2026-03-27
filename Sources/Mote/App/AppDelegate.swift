import AppKit
import MoteCore

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var selectionWatcher: SelectionWatcher?
    private var globalHotkeyMonitor: GlobalHotkeyMonitor?
    private var bubbleController: SelectionBubbleController?
    private var composerPanelController: ComposerPanelController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        let hotkey = (try? ConfigLoader.loadConfig().hotkey) ?? AppConfig.default.hotkey
        let selectionWatcher = SelectionWatcher()
        let globalHotkeyMonitor = GlobalHotkeyMonitor(hotkey: hotkey)
        let bubbleController = SelectionBubbleController()
        let composerPanelController = ComposerPanelController()

        selectionWatcher.onUpdate = { [weak self] snapshot in
            self?.handleSelectionUpdate(snapshot)
        }

        bubbleController.onActivate = { [weak self] in
            self?.openComposerFromBubble()
        }

        globalHotkeyMonitor.onTrigger = { [weak self] in
            self?.openComposer(forceRefresh: true)
        }

        composerPanelController.onClose = { [weak self] in
            self?.selectionWatcher?.resume()
            self?.selectionWatcher?.refreshNow()
        }

        self.selectionWatcher = selectionWatcher
        self.globalHotkeyMonitor = globalHotkeyMonitor
        self.bubbleController = bubbleController
        self.composerPanelController = composerPanelController

        selectionWatcher.start()
        globalHotkeyMonitor.start()
    }

    private func handleSelectionUpdate(_ snapshot: AXSelectionSnapshot?) {
        guard composerPanelController?.isVisible != true else {
            bubbleController?.hide()
            return
        }

        guard let snapshot, snapshot.context.isPlaceable else {
            bubbleController?.hide()
            return
        }

        bubbleController?.show(for: snapshot)
    }

    private func openComposer(forceRefresh: Bool = false) {
        if forceRefresh {
            _ = selectionWatcher?.captureCurrentSelection()
        }

        guard let snapshot = selectionWatcher?.currentSnapshot ?? selectionWatcher?.captureCurrentSelection() else {
            NSSound.beep()
            return
        }

        bubbleController?.hide()
        selectionWatcher?.suspend()
        composerPanelController?.show(for: snapshot)
    }

    private func openComposerFromBubble() {
        guard let snapshot = selectionWatcher?.currentSnapshot else {
            NSSound.beep()
            return
        }

        bubbleController?.hide()
        selectionWatcher?.suspend()
        composerPanelController?.show(for: snapshot)
    }
}

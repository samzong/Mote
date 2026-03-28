import AppKit
import MoteCore

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?
    private var hotkeyMonitor: GlobalHotkeyMonitor?
    private var composerPanel: ComposerPanel?
    private var selectionWatcher: SelectionWatcher?

    func applicationDidFinishLaunching(_: Notification) {
        Logger.debug("AppDelegate.applicationDidFinishLaunching")

        composerPanel = ComposerPanel()
        composerPanel?.onDismiss = { [weak self] in
            Logger.debug("composerPanel.onDismiss -> re-enable watcher")
            self?.selectionWatcher?.isEnabled = true
            self?.selectionWatcher?.recheckAfterDelay()
        }

        setupStatusItem()

        selectionWatcher = SelectionWatcher()
        selectionWatcher?.onActivate = { [weak self] snapshot in
            Logger.debug("selectionWatcher.onActivate text.count=\(snapshot.context.text.count)")
            self?.showPanel(for: snapshot)
        }
        selectionWatcher?.start()

        hotkeyMonitor = GlobalHotkeyMonitor { [weak self] in
            Task { @MainActor in
                Logger.debug("GlobalHotkeyMonitor triggered")
                self?.handleHotkey()
            }
        }
        hotkeyMonitor?.start()
        Logger.debug("AppDelegate init complete")
    }

    private func handleHotkey() {
        Logger.debug("handleHotkey() composerPanel=\(composerPanel != nil)")
        guard let composerPanel else { return }

        if composerPanel.isVisible {
            Logger.debug("handleHotkey() panel visible -> dismiss")
            composerPanel.dismiss()
            return
        }

        if let snapshot = selectionWatcher?.activeSnapshot {
            Logger.debug("handleHotkey() using watcher snapshot text.count=\(snapshot.context.text.count)")
            showPanel(for: snapshot)
            return
        }

        let trusted = AccessibilityPermission.isTrusted()
        Logger.debug("handleHotkey() accessibilityTrusted=\(trusted)")
        if !trusted {
            AccessibilityPermission.requestAccess()
            return
        }

        let reader = AXSelectionReader()
        guard let snapshot = reader.readFocusedSelection() else {
            Logger.debug("handleHotkey() no selection from reader")
            return
        }

        let b = String(describing: snapshot.context.bounds)
        Logger.debug("handleHotkey() text.count=\(snapshot.context.text.count) bounds=\(b)")
        showPanel(for: snapshot)
    }

    private func showPanel(for snapshot: AXSelectionSnapshot) {
        selectionWatcher?.hideDot()
        selectionWatcher?.isEnabled = false
        composerPanel?.show(for: snapshot)
    }

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = statusItem?.button {
            button.image = NSImage(
                systemSymbolName: "pencil.and.outline",
                accessibilityDescription: "Mote"
            )
        }

        let menu = NSMenu()
        menu.addItem(NSMenuItem(
            title: "Settings...",
            action: #selector(openSettings),
            keyEquivalent: ","
        ))
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(
            title: "Quit Mote",
            action: #selector(NSApplication.terminate(_:)),
            keyEquivalent: "q"
        ))
        statusItem?.menu = menu
    }

    @objc private func openSettings() {
        let url = ConfigLoader.configURL()
        if !FileManager.default.fileExists(atPath: url.path) {
            try? ConfigLoader.saveDefaultFilesIfNeeded()
        }
        NSWorkspace.shared.open(url)
    }
}

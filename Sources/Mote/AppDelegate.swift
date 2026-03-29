import AppKit
import MoteCore
import ServiceManagement

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var hotkeyMonitor: GlobalHotkeyMonitor?
    private var composerPanel: ComposerPanel?
    private var selectionWatcher: SelectionWatcher?
    private let clipboardReader = ClipboardSelectionReader()

    func applicationDidFinishLaunching(_: Notification) {
        Logger.debug("AppDelegate.applicationDidFinishLaunching")

        setupMainMenu()
        setupLoginItem()

        composerPanel = ComposerPanel()
        composerPanel?.onDismiss = { [weak self] in
            Logger.debug("composerPanel.onDismiss -> re-enable watcher")
            self?.selectionWatcher?.isEnabled = true
            self?.selectionWatcher?.recheckAfterDelay()
        }

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
        if let snapshot = reader.readFocusedSelection() {
            let b = String(describing: snapshot.context.bounds)
            Logger.debug("handleHotkey() AX text.count=\(snapshot.context.text.count) bounds=\(b)")
            showPanel(for: snapshot)
            return
        }

        Logger.debug("handleHotkey() AX failed, trying clipboard fallback")
        Task {
            guard let snapshot = await clipboardReader.readSelectedText() else {
                Logger.debug("handleHotkey() clipboard fallback failed")
                return
            }
            Logger.debug("handleHotkey() clipboard got text.count=\(snapshot.context.text.count)")
            self.showPanel(for: snapshot)
        }
    }

    private func showPanel(for snapshot: AXSelectionSnapshot) {
        selectionWatcher?.hideDot()
        selectionWatcher?.isEnabled = false
        composerPanel?.show(for: snapshot)
    }

    private func setupMainMenu() {
        let appMenu = NSMenu()
        appMenu.addItem(NSMenuItem(
            title: "Settings...",
            action: #selector(openSettings),
            keyEquivalent: ","
        ))
        appMenu.addItem(.separator())
        appMenu.addItem(NSMenuItem(
            title: "Quit Mote",
            action: #selector(NSApplication.terminate(_:)),
            keyEquivalent: "q"
        ))

        let appMenuItem = NSMenuItem()
        appMenuItem.submenu = appMenu

        let mainMenu = NSMenu()
        mainMenu.addItem(appMenuItem)
        NSApp.mainMenu = mainMenu
    }

    private func setupLoginItem() {
        let service = SMAppService.mainApp
        if service.status == .notRegistered {
            try? service.register()
            Logger.debug("login-item: registered")
        } else {
            Logger.debug("login-item: status=\(service.status.rawValue)")
        }
    }

    @objc private func openSettings() {
        let url = ConfigLoader.configURL()
        if !FileManager.default.fileExists(atPath: url.path) {
            try? ConfigLoader.saveDefaultFilesIfNeeded()
        }
        NSWorkspace.shared.open(url)
    }
}

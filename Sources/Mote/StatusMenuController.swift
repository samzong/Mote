import AppKit
import MoteCore

@MainActor
final class StatusMenuController: NSObject, NSMenuDelegate {
    struct Status {
        let accessibilityTrusted: Bool
        let hotkeyAvailable: Bool
    }

    var onRefreshStatus: (@MainActor () -> Status)?
    var onRequestAccessibility: (@MainActor () -> Void)?

    private enum DisplayState {
        case ready
        case accessibilityRequired
        case hotkeyUnavailable

        var title: String {
            switch self {
                case .ready:
                    "Mote: Ready"
                case .accessibilityRequired:
                    "Mote: Accessibility Permission Required"
                case .hotkeyUnavailable:
                    "Mote: Hotkey Monitor Unavailable"
            }
        }
    }

    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    private let statusImage = StatusMenuController.makeMenuBarImage()
    private let menu = NSMenu()
    private let statusMenuItem = NSMenuItem()
    private let requestAccessibilityItem = NSMenuItem()
    private let openConfigItem = NSMenuItem()
    private let quitItem = NSMenuItem()
    private var latestStatus = Status(accessibilityTrusted: false, hotkeyAvailable: false)

    override init() {
        super.init()
        setUpMenu()
        update(with: latestStatus)
    }

    func update(with status: Status) {
        latestStatus = status
        let displayState: DisplayState = if !status.accessibilityTrusted {
            .accessibilityRequired
        } else if !status.hotkeyAvailable {
            .hotkeyUnavailable
        } else {
            .ready
        }

        statusMenuItem.title = displayState.title
        requestAccessibilityItem.isHidden = status.accessibilityTrusted

        guard let button = statusItem.button else { return }
        button.image = statusImage
        button.title = ""
        button.imagePosition = .imageOnly
        button.imageScaling = .scaleProportionallyDown
        button.toolTip = displayState.title
        button.setAccessibilityLabel(displayState.title)
    }

    func refresh() {
        guard let status = onRefreshStatus?() else { return }
        update(with: status)
    }

    func menuWillOpen(_: NSMenu) {
        refresh()
    }

    private func setUpMenu() {
        menu.delegate = self
        menu.autoenablesItems = false

        statusMenuItem.isEnabled = false
        menu.addItem(statusMenuItem)
        menu.addItem(.separator())

        requestAccessibilityItem.title = "Request Accessibility Permission"
        requestAccessibilityItem.target = self
        requestAccessibilityItem.action = #selector(requestAccessibility)
        menu.addItem(requestAccessibilityItem)

        openConfigItem.title = "Open Config Folder"
        openConfigItem.target = self
        openConfigItem.action = #selector(openConfigFolder)
        menu.addItem(openConfigItem)

        menu.addItem(.separator())

        quitItem.title = "Quit Mote"
        quitItem.target = self
        quitItem.action = #selector(quit)
        quitItem.keyEquivalent = "q"
        menu.addItem(quitItem)

        statusItem.menu = menu
    }

    private static func makeMenuBarImage() -> NSImage {
        let image = NSImage(systemSymbolName: "note.text", accessibilityDescription: "Mote")?
            .withSymbolConfiguration(.init(pointSize: 17, weight: .medium)) ?? NSImage(
                systemSymbolName: "doc.text",
                accessibilityDescription: "Mote"
            ) ?? NSImage(size: NSSize(width: 17, height: 17))
        image.isTemplate = true
        return image
    }

    @objc private func requestAccessibility() {
        onRequestAccessibility?()
        refresh()
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 1_000_000_000)
            self.refresh()
        }
    }

    @objc private func openConfigFolder() {
        try? ConfigLoader.saveDefaultFilesIfNeeded()
        NSWorkspace.shared.open(ConfigLoader.configDirectory())
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }
}

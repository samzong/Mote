import AppKit
import MoteCore

@MainActor
final class SelectionWatcher {
    var onUpdate: ((AXSelectionSnapshot?) -> Void)?

    private let reader: AXSelectionReader
    private var eventMonitors: [Any] = []
    private var workspaceObserver: NSObjectProtocol?
    private var pollingTimer: Timer?
    private var pendingRefresh: DispatchWorkItem?
    private(set) var currentSnapshot: AXSelectionSnapshot?
    private var isSuspended = false

    init(reader: AXSelectionReader = AXSelectionReader()) {
        self.reader = reader
    }

    func start() {
        guard eventMonitors.isEmpty else {
            return
        }

        if let mouseMonitor = NSEvent.addGlobalMonitorForEvents(matching: .leftMouseUp, handler: { [weak self] _ in
            Task { @MainActor in
                self?.scheduleRefresh(after: 0.12)
            }
        }) {
            eventMonitors.append(mouseMonitor)
        }

        if let keyMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyUp, handler: { [weak self] event in
            Task { @MainActor in
                self?.handleKeyEvent(event)
            }
        }) {
            eventMonitors.append(keyMonitor)
        }

        workspaceObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.scheduleRefresh(after: 0.05)
            }
        }

        pollingTimer = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.refreshSelection()
            }
        }
        RunLoop.main.add(pollingTimer!, forMode: .common)

        scheduleRefresh(after: 0)
    }

    func stop() {
        pendingRefresh?.cancel()
        pendingRefresh = nil

        for monitor in eventMonitors {
            NSEvent.removeMonitor(monitor)
        }
        eventMonitors.removeAll()

        pollingTimer?.invalidate()
        pollingTimer = nil

        if let workspaceObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(workspaceObserver)
        }
        workspaceObserver = nil
    }

    func suspend() {
        isSuspended = true
        pendingRefresh?.cancel()
        pendingRefresh = nil
    }

    func resume() {
        isSuspended = false
        scheduleRefresh(after: 0.05)
    }

    func refreshNow() {
        scheduleRefresh(after: 0)
    }

    func captureCurrentSelection() -> AXSelectionSnapshot? {
        let snapshot = reader.readFocusedSelection()
        currentSnapshot = snapshot
        return snapshot
    }

    private func handleKeyEvent(_ event: NSEvent) {
        guard shouldRefreshSelection(for: event) else {
            return
        }

        scheduleRefresh(after: 0.12)
    }

    private func shouldRefreshSelection(for event: NSEvent) -> Bool {
        let characters = event.charactersIgnoringModifiers?.lowercased() ?? ""
        let flags = event.modifierFlags.intersection([.command, .shift, .option, .control])

        if event.keyCode == 123 || event.keyCode == 124 || event.keyCode == 125 || event.keyCode == 126 {
            return true
        }

        if flags.contains(.command), characters == "a" {
            return true
        }

        return flags.contains(.shift) || flags.contains(.command)
    }

    private func scheduleRefresh(after delay: TimeInterval) {
        pendingRefresh?.cancel()

        let workItem = DispatchWorkItem { [weak self] in
            guard let self else {
                return
            }

            self.refreshSelection()
        }

        pendingRefresh = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: workItem)
    }

    private func refreshSelection() {
        guard !isSuspended else {
            return
        }

        if NSWorkspace.shared.frontmostApplication?.bundleIdentifier == Bundle.main.bundleIdentifier {
            return
        }

        let snapshot = reader.readFocusedSelection()
        currentSnapshot = snapshot
        log(snapshot)
        onUpdate?(snapshot)
    }

    private func log(_ snapshot: AXSelectionSnapshot?) {
        guard let snapshot else {
            let bundleIdentifier = reader.frontmostBundleIdentifier() ?? "unknown"
            Logger.info("selection valid=false readable=false writable=false placeable=false app=\(bundleIdentifier)")
            return
        }

        Logger.info(
            "selection valid=\(snapshot.context.isValid) readable=true writable=\(snapshot.context.isWritable) placeable=\(snapshot.context.isPlaceable) app=\(snapshot.context.bundleIdentifier ?? "unknown") textLength=\(snapshot.context.text.count)"
        )
    }
}

import AppKit
import MoteCore

@MainActor
final class GlobalHotkeyMonitor {
    var onTrigger: (() -> Void)?

    private let hotkey: AppConfig.Hotkey
    private var globalMonitor: Any?
    private var localMonitor: Any?

    init(hotkey: AppConfig.Hotkey) {
        self.hotkey = hotkey
    }

    func start() {
        guard globalMonitor == nil, localMonitor == nil else {
            return
        }

        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self, self.matches(event: event) else {
                return
            }

            self.onTrigger?()
        }

        localMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self, self.matches(event: event) else {
                return event
            }

            self.onTrigger?()
            return nil
        }
    }

    func stop() {
        if let globalMonitor {
            NSEvent.removeMonitor(globalMonitor)
        }

        if let localMonitor {
            NSEvent.removeMonitor(localMonitor)
        }

        globalMonitor = nil
        localMonitor = nil
    }

    private func matches(event: NSEvent) -> Bool {
        guard let keyCode = keyCode(for: hotkey.key) else {
            return false
        }

        let flags = event.modifierFlags.intersection([.command, .shift, .option, .control])
        return event.keyCode == keyCode && flags == modifierFlags(from: hotkey.modifiers)
    }

    private func modifierFlags(from modifiers: [String]) -> NSEvent.ModifierFlags {
        modifiers.reduce(into: NSEvent.ModifierFlags()) { partialResult, modifier in
            switch modifier.lowercased() {
            case "command", "cmd":
                partialResult.insert(.command)
            case "shift":
                partialResult.insert(.shift)
            case "option", "alt":
                partialResult.insert(.option)
            case "control", "ctrl":
                partialResult.insert(.control)
            default:
                break
            }
        }
    }

    private func keyCode(for key: String) -> UInt16? {
        switch key.lowercased() {
        case "space":
            return 49
        case "return", "enter":
            return 36
        case "a":
            return 0
        case "b":
            return 11
        case "c":
            return 8
        case "d":
            return 2
        case "e":
            return 14
        case "f":
            return 3
        case "g":
            return 5
        case "h":
            return 4
        case "i":
            return 34
        case "j":
            return 38
        case "k":
            return 40
        case "l":
            return 37
        case "m":
            return 46
        case "n":
            return 45
        case "o":
            return 31
        case "p":
            return 35
        case "q":
            return 12
        case "r":
            return 15
        case "s":
            return 1
        case "t":
            return 17
        case "u":
            return 32
        case "v":
            return 9
        case "w":
            return 13
        case "x":
            return 7
        case "y":
            return 16
        case "z":
            return 6
        default:
            return nil
        }
    }
}

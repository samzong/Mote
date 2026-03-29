import CoreGraphics
import MoteCore

final class GlobalHotkeyMonitor: @unchecked Sendable {
    private static let fnFlag = CGEventFlags(rawValue: 0x0080_0000)

    private let onTrigger: @Sendable () -> Void
    private let onManageTrigger: @Sendable () -> Void
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var fnDown = false

    init(
        onTrigger: @escaping @Sendable () -> Void,
        onManageTrigger: @escaping @Sendable () -> Void
    ) {
        self.onTrigger = onTrigger
        self.onManageTrigger = onManageTrigger
    }

    func start() {
        Logger.debug("GlobalHotkeyMonitor.start()")
        let mask: CGEventMask =
            (1 << CGEventType.flagsChanged.rawValue) |
            (1 << CGEventType.keyDown.rawValue)

        let userInfo = Unmanaged.passUnretained(self).toOpaque()

        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .listenOnly,
            eventsOfInterest: mask,
            callback: { _, type, event, userInfo -> Unmanaged<CGEvent>? in
                guard let userInfo else { return Unmanaged.passRetained(event) }
                let monitor = Unmanaged<GlobalHotkeyMonitor>.fromOpaque(userInfo).takeUnretainedValue()
                monitor.handleEvent(type: type, event: event)
                return Unmanaged.passRetained(event)
            },
            userInfo: userInfo
        ) else {
            Logger.debug("GlobalHotkeyMonitor: CGEvent.tapCreate FAILED")
            return
        }

        Logger.debug("GlobalHotkeyMonitor: event tap created OK")
        eventTap = tap
        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        runLoopSource = source
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
    }

    func stop() {
        if let source = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes)
        }
        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
        }
        eventTap = nil
        runLoopSource = nil
    }

    private func handleEvent(type: CGEventType, event: CGEvent) {
        dispatchPrecondition(condition: .onQueue(.main))
        switch type {
            case .flagsChanged:
                let hasFn = event.flags.contains(Self.fnFlag)
                if hasFn, !fnDown {
                    fnDown = true
                } else if !hasFn, fnDown {
                    fnDown = false
                    let otherModifiers: CGEventFlags = [.maskShift, .maskControl, .maskAlternate, .maskCommand]
                    if event.flags.isDisjoint(with: otherModifiers) {
                        DispatchQueue.main.async { [onTrigger] in
                            onTrigger()
                        }
                    } else if event.flags.intersection(otherModifiers) == .maskAlternate {
                        DispatchQueue.main.async { [onManageTrigger] in
                            onManageTrigger()
                        }
                    }
                }
            case .keyDown:
                fnDown = false
            case .tapDisabledByTimeout, .tapDisabledByUserInput:
                fnDown = false
                if let tap = eventTap {
                    CGEvent.tapEnable(tap: tap, enable: true)
                }
            default:
                break
        }
    }
}

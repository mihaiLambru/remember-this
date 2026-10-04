import Carbon.HIToolbox
import Foundation

@MainActor
final class GlobalShortcutManager {
    private var hotKeyRef: EventHotKeyRef?
    private var handlerRef: EventHandlerRef?
    private var action: (() -> Void)?

    func start(action: @escaping () -> Void) -> OSStatus {
        guard hotKeyRef == nil else { return noErr }
        self.action = action

        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )
        let userData = Unmanaged.passUnretained(self).toOpaque()
        let handlerStatus = InstallEventHandler(
            GetApplicationEventTarget(),
            globalShortcutHandler,
            1,
            &eventType,
            userData,
            &handlerRef
        )
        guard handlerStatus == noErr else { return handlerStatus }

        let identifier = EventHotKeyID(signature: OSType(0x52544B59), id: 1) // RTKY
        let status = RegisterEventHotKey(
            UInt32(kVK_ANSI_V),
            UInt32(cmdKey | shiftKey),
            identifier,
            GetApplicationEventTarget(),
            0,
            &hotKeyRef
        )
        if status != noErr { stop() }
        return status
    }

    func stop() {
        if let hotKeyRef { UnregisterEventHotKey(hotKeyRef) }
        if let handlerRef { RemoveEventHandler(handlerRef) }
        hotKeyRef = nil
        handlerRef = nil
        action = nil
    }

    fileprivate func performAction() {
        action?()
    }
}

private let globalShortcutHandler: EventHandlerUPP = { _, _, userData in
    guard let userData else { return noErr }
    let manager = Unmanaged<GlobalShortcutManager>.fromOpaque(userData).takeUnretainedValue()
    Task { @MainActor in manager.performAction() }
    return noErr
}

// Globales Tastenkürzel über die Carbon-Hotkey-API. Funktioniert ohne
// Bedienungshilfen-Freigabe, anders als ein CGEventTap.
import AppKit
import Carbon

final class HotKey {
    private static var registry: [UInt32: HotKey] = [:]
    private static var nextID: UInt32 = 1
    private static var handlerInstalled = false

    private let id: UInt32
    private let callback: () -> Void
    private var hotKeyRef: EventHotKeyRef?

    /// - Parameters:
    ///   - keyCode: virtueller Keycode, z. B. `kVK_ANSI_Z`
    ///   - modifiers: Carbon-Modifier, z. B. `controlKey | optionKey`
    init(keyCode: Int, modifiers: Int, callback: @escaping () -> Void) {
        self.callback = callback
        id = HotKey.nextID
        HotKey.nextID += 1
        HotKey.registry[id] = self
        HotKey.installHandlerIfNeeded()

        let hotKeyID = EventHotKeyID(signature: OSType(0x5A54_544C) /* "ZTTL" */, id: id)
        let status = RegisterEventHotKey(UInt32(keyCode), UInt32(modifiers), hotKeyID,
                                         GetApplicationEventTarget(), 0, &hotKeyRef)
        if status != noErr {
            NSLog("Zettel: Tastenkürzel konnte nicht registriert werden (Status \(status))")
        }
    }

    deinit {
        if let hotKeyRef { UnregisterEventHotKey(hotKeyRef) }
        HotKey.registry[id] = nil
    }

    private static func installHandlerIfNeeded() {
        guard !handlerInstalled else { return }
        handlerInstalled = true
        var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard),
                                 eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(GetApplicationEventTarget(), { _, event, _ -> OSStatus in
            var hotKeyID = EventHotKeyID()
            GetEventParameter(event, EventParamName(kEventParamDirectObject),
                              EventParamType(typeEventHotKeyID), nil,
                              MemoryLayout<EventHotKeyID>.size, nil, &hotKeyID)
            HotKey.registry[hotKeyID.id]?.callback()
            return noErr
        }, 1, &spec, nil, nil)
    }
}

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

    /// Virtueller Keycode der Taste, die im aktuellen Tastaturlayout das
    /// Zeichen `character` erzeugt. Nötig, weil Keycodes physische Tasten
    /// bezeichnen: `kVK_ANSI_Z` ist auf einer deutschen Tastatur das Y.
    static func keyCode(for character: Character, fallback: Int) -> Int {
        guard let source = TISCopyCurrentKeyboardLayoutInputSource()?.takeRetainedValue(),
              let ptr = TISGetInputSourceProperty(source, kTISPropertyUnicodeKeyLayoutData) else {
            return fallback
        }
        let data = Unmanaged<CFData>.fromOpaque(ptr).takeUnretainedValue() as Data
        let wanted = String(character).lowercased()
        return data.withUnsafeBytes { raw -> Int in
            guard let layout = raw.bindMemory(to: UCKeyboardLayout.self).baseAddress else { return fallback }
            var deadKeys: UInt32 = 0
            var chars = [UniChar](repeating: 0, count: 4)
            var length = 0
            for code in 0..<128 {
                deadKeys = 0
                let status = UCKeyTranslate(layout, UInt16(code), UInt16(kUCKeyActionDown), 0,
                                            UInt32(LMGetKbdType()), UInt32(kUCKeyTranslateNoDeadKeysMask),
                                            &deadKeys, chars.count, &length, &chars)
                if status == noErr, length == 1, String(utf16CodeUnits: chars, count: 1).lowercased() == wanted {
                    return code
                }
            }
            return fallback
        }
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

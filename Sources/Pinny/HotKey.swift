import Carbon.HIToolbox

/// Atajos globales de teclado (Carbon). No requieren permisos especiales.
final class HotKeyCenter {
    private static var actions: [UInt32: () -> Void] = [:]

    private var refs: [UInt32: EventHotKeyRef] = [:]
    private var handlerRef: EventHandlerRef?
    private var handlerInstalled = false

    /// Registra (o reemplaza) el atajo con ese `id`. Devuelve false si macOS lo rechaza,
    /// por ejemplo porque otra app ya usa esa combinación.
    @discardableResult
    func register(id: UInt32, keyCode: Int, modifiers: Int, action: @escaping () -> Void) -> Bool {
        unregister(id: id)
        installHandlerIfNeeded()

        var ref: EventHotKeyRef?
        let hotKeyID = EventHotKeyID(signature: OSType(0x434C5050), id: id) // 'CLPP'
        let status = RegisterEventHotKey(
            UInt32(keyCode),
            UInt32(modifiers),
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &ref
        )
        guard status == noErr, let ref else { return false }

        refs[id] = ref
        HotKeyCenter.actions[id] = action
        return true
    }

    func unregister(id: UInt32) {
        if let ref = refs[id] {
            UnregisterEventHotKey(ref)
            refs[id] = nil
        }
        HotKeyCenter.actions[id] = nil
    }

    private func installHandlerIfNeeded() {
        guard !handlerInstalled else { return }
        handlerInstalled = true

        var spec = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )
        InstallEventHandler(
            GetApplicationEventTarget(),
            { _, event, _ in
                var hotKeyID = EventHotKeyID()
                GetEventParameter(
                    event,
                    EventParamName(kEventParamDirectObject),
                    EventParamType(typeEventHotKeyID),
                    nil,
                    MemoryLayout<EventHotKeyID>.size,
                    nil,
                    &hotKeyID
                )
                let id = hotKeyID.id
                DispatchQueue.main.async { HotKeyCenter.actions[id]?() }
                return noErr
            },
            1,
            &spec,
            nil,
            &handlerRef
        )
    }
}

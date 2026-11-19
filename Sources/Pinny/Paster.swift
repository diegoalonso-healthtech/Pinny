import AppKit
import ApplicationServices

/// Pega texto en la app que estaba activa.
/// Pegar requiere el permiso de Accesibilidad (se simula ⌘V). Con permiso, tras pegar se
/// restaura lo que tenías copiado. Sin permiso, el texto queda en el portapapeles para que
/// pulses ⌘V tú.
@MainActor
enum Paster {
    private typealias Snapshot = [[NSPasteboard.PasteboardType: Data]]

    private static var promptedForAccessibility = false

    /// Abre el panel con buscador y pega el elemento elegido.
    static func pickAndPaste(mode: PickerMode) {
        let previousApp = NSWorkspace.shared.frontmostApplication

        guard let text = PickerPanel.runModalPicker(mode: mode) else {
            previousApp?.activate(options: [])
            return
        }
        paste(text, into: previousApp)
    }

    /// Copia `text` al portapapeles, devuelve el foco a `app` y simula ⌘V.
    static func paste(_ text: String, into app: NSRunningApplication?) {
        let pasteboard = NSPasteboard.general

        // Si el destino es la propia Pinny (guía de bienvenida, buscador, Ajustes),
        // se pega directamente en el campo activo: no hace falta simular ⌘V ni permiso.
        if app == nil || app?.processIdentifier == ProcessInfo.processInfo.processIdentifier {
            let saved = snapshot(pasteboard)
            pasteboard.clearContents()
            pasteboard.setString(text, forType: .string)
            ClipboardMonitor.ownChangeCounts.insert(pasteboard.changeCount)
            NSApp.sendAction(#selector(NSText.paste(_:)), to: nil, from: nil)
            restore(saved, to: pasteboard)
            ClipboardMonitor.ownChangeCounts.insert(pasteboard.changeCount)
            return
        }

        let canAutoPaste = hasAccessibility()
        let saved = canAutoPaste ? snapshot(pasteboard) : nil

        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
        let pastedCount = pasteboard.changeCount

        app?.activate(options: [])

        // Sin permiso: el texto se queda en el portapapeles (y entra en el historial).
        guard canAutoPaste, let saved else { return }
        ClipboardMonitor.ownChangeCounts.insert(pastedCount)

        Task { @MainActor in
            // Pequeña espera para que la app anterior recupere el foco.
            try? await Task.sleep(for: .milliseconds(150))
            sendCommandV()

            // Restaura lo que tenías copiado, salvo que hayas copiado otra cosa entretanto.
            try? await Task.sleep(for: .milliseconds(500))
            guard pasteboard.changeCount == pastedCount else { return }
            restore(saved, to: pasteboard)
            ClipboardMonitor.ownChangeCounts.insert(pasteboard.changeCount)
        }
    }

    /// Solo pide el permiso una vez por sesión, para no molestar en cada uso.
    private static func hasAccessibility() -> Bool {
        if AXIsProcessTrusted() { return true }
        guard !promptedForAccessibility else { return false }
        promptedForAccessibility = true
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        return AXIsProcessTrustedWithOptions(options)
    }

    private static func snapshot(_ pasteboard: NSPasteboard) -> Snapshot {
        (pasteboard.pasteboardItems ?? []).map { item in
            var dict: [NSPasteboard.PasteboardType: Data] = [:]
            for type in item.types {
                if let data = item.data(forType: type) {
                    dict[type] = data
                }
            }
            return dict
        }
    }

    private static func restore(_ saved: Snapshot, to pasteboard: NSPasteboard) {
        pasteboard.clearContents()
        let items = saved.map { dict -> NSPasteboardItem in
            let item = NSPasteboardItem()
            for (type, data) in dict {
                item.setData(data, forType: type)
            }
            return item
        }
        if !items.isEmpty {
            pasteboard.writeObjects(items)
        }
    }

    private static func sendCommandV() {
        let source = CGEventSource(stateID: .combinedSessionState)
        let vKey: CGKeyCode = 9 // kVK_ANSI_V

        let down = CGEvent(keyboardEventSource: source, virtualKey: vKey, keyDown: true)
        down?.flags = .maskCommand
        let up = CGEvent(keyboardEventSource: source, virtualKey: vKey, keyDown: false)
        up?.flags = .maskCommand

        down?.post(tap: .cghidEventTap)
        up?.post(tap: .cghidEventTap)
    }
}

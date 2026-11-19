import AppKit
import SwiftUI

/// Muestra el selector en un panel modal y devuelve el texto elegido.
@MainActor
enum PickerPanel {
    static func runModalPicker(mode: PickerMode) -> String? {
        var result: String?

        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 440, height: 520),
            styleMask: [.titled],
            backing: .buffered,
            defer: false
        )
        panel.title = mode.title
        panel.level = .floating
        panel.isReleasedWhenClosed = false

        let view = PickerView(
            store: ClipStore.shared,
            mode: mode,
            onPick: { text in
                result = text
                NSApp.stopModal()
            },
            onCancel: {
                NSApp.stopModal()
            }
        )
        panel.contentView = NSHostingView(rootView: view)
        panel.center()

        NSApp.activate(ignoringOtherApps: true)
        panel.makeKeyAndOrderFront(nil)
        NSApp.runModal(for: panel)
        panel.orderOut(nil)

        return result
    }
}

/// Implementa los Servicios declarados en Info.plist (NSMessage).
/// Al devolver texto en el pasteboard del servicio, macOS lo inserta en la app origen.
@MainActor
final class ServiceProvider: NSObject {
    @objc func pickPinned(
        _ pboard: NSPasteboard,
        userData: String,
        error: AutoreleasingUnsafeMutablePointer<NSString>
    ) {
        run(.pinned, pboard)
    }

    @objc func pickRecent(
        _ pboard: NSPasteboard,
        userData: String,
        error: AutoreleasingUnsafeMutablePointer<NSString>
    ) {
        run(.recent, pboard)
    }

    @objc func pickAll(
        _ pboard: NSPasteboard,
        userData: String,
        error: AutoreleasingUnsafeMutablePointer<NSString>
    ) {
        run(.all, pboard)
    }

    /// Recibe el texto seleccionado (clic derecho → Servicios) y lo ancla.
    @objc func pinSelection(
        _ pboard: NSPasteboard,
        userData: String,
        error: AutoreleasingUnsafeMutablePointer<NSString>
    ) {
        Pinner.pin(pboard.string(forType: .string))
    }

    private func run(_ mode: PickerMode, _ pboard: NSPasteboard) {
        // Si cancelas, no se escribe nada y la app origen queda como estaba.
        guard let chosen = PickerPanel.runModalPicker(mode: mode) else { return }
        pboard.clearContents()
        pboard.setString(chosen, forType: .string)
    }
}

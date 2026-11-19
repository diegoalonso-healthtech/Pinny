import AppKit
import ApplicationServices

/// Acciones para guardar pines a voluntad: lo último copiado, el portapapeles,
/// el texto seleccionado o un texto escrito a mano.
@MainActor
enum Pinner {
    /// Ancla un texto y avisa con un mensaje breve junto al cursor.
    static func pin(_ text: String?, folderID: UUID? = nil) {
        guard let text else {
            Toast.show(L("Nothing to pin"))
            return
        }
        switch ClipStore.shared.pin(text, folderID: folderID) {
        case .pinned: Toast.show(L("Pinned 📌"))
        case .alreadyPinned: Toast.show(L("Already pinned 📌"))
        case .tooLong: Toast.show(L("Too long to pin"))
        case .empty: Toast.show(L("Nothing to pin"))
        }
    }

    /// Atajo «anclar portapapeles».
    static func pinClipboard() {
        pin(NSPasteboard.general.string(forType: .string))
    }

    /// Lo último copiado que aún no está anclado.
    static var lastCopied: ClipItem? {
        ClipStore.shared.recent.first
    }
}

/// Lee el texto seleccionado en la app activa (requiere el permiso de Accesibilidad).
/// Funciona en la mayoría de apps nativas; en algunas (p. ej. Electron) puede no haber dato.
@MainActor
enum SelectionReader {
    static func selectedText() -> String? {
        guard AXIsProcessTrusted() else { return nil }
        let system = AXUIElementCreateSystemWide()

        var focused: CFTypeRef?
        guard AXUIElementCopyAttributeValue(system, kAXFocusedUIElementAttribute as CFString, &focused) == .success,
              let focused, CFGetTypeID(focused) == AXUIElementGetTypeID() else { return nil }
        let element = focused as! AXUIElement

        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, kAXSelectedTextAttribute as CFString, &value) == .success,
              let text = value as? String,
              !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
        return text
    }
}

/// Diálogo «Nuevo pin»: escribes o pegas el texto y eliges carpeta.
@MainActor
enum PinEditor {
    static func newPin() {
        let alert = NSAlert()
        alert.messageText = L("New pin")
        alert.informativeText = L("Type or paste the text you want to keep.")
        alert.addButton(withTitle: L("Save"))
        alert.addButton(withTitle: L("Cancel"))

        let width: CGFloat = 340
        let container = NSView(frame: NSRect(x: 0, y: 0, width: width, height: 160))

        let scroll = NSScrollView(frame: NSRect(x: 0, y: 36, width: width, height: 124))
        scroll.hasVerticalScroller = true
        scroll.borderType = .bezelBorder
        let textView = NSTextView(frame: NSRect(x: 0, y: 0, width: width - 4, height: 124))
        textView.isRichText = false
        textView.font = .systemFont(ofSize: 13)
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.autoresizingMask = [.width]
        scroll.documentView = textView
        container.addSubview(scroll)

        let folderLabel = NSTextField(labelWithString: L("Folder:"))
        folderLabel.frame = NSRect(x: 0, y: 6, width: 70, height: 20)
        container.addSubview(folderLabel)

        let folders = ClipStore.shared.folders
        let popup = NSPopUpButton(frame: NSRect(x: 74, y: 2, width: width - 74, height: 26))
        popup.addItem(withTitle: L("No folder"))
        for folder in folders {
            popup.addItem(withTitle: "📁 \(folder.name)")
        }
        container.addSubview(popup)

        alert.accessoryView = container
        alert.window.initialFirstResponder = textView

        NSApp.activate(ignoringOtherApps: true)
        guard alert.runModal() == .alertFirstButtonReturn else { return }

        let index = popup.indexOfSelectedItem
        let folderID = index > 0 ? folders[index - 1].id : nil
        Pinner.pin(textView.string, folderID: folderID)
    }
}

/// Mensaje breve junto al cursor («Anclado 📌»), que desaparece solo.
@MainActor
enum Toast {
    private static var panel: NSPanel?

    static func show(_ message: String) {
        panel?.orderOut(nil)

        let label = NSTextField(labelWithString: message)
        label.font = .systemFont(ofSize: 14, weight: .semibold)
        label.textColor = .labelColor
        let size = label.fittingSize
        let width = size.width + 32
        let height: CGFloat = 36

        let newPanel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: width, height: height),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        newPanel.isOpaque = false
        newPanel.backgroundColor = .clear
        newPanel.level = .statusBar
        newPanel.ignoresMouseEvents = true
        newPanel.hasShadow = true

        let background = NSVisualEffectView(frame: NSRect(x: 0, y: 0, width: width, height: height))
        background.material = .popover
        background.state = .active
        background.wantsLayer = true
        background.layer?.cornerRadius = 10
        background.layer?.masksToBounds = true
        label.frame = NSRect(x: 16, y: (height - size.height) / 2, width: size.width, height: size.height)
        background.addSubview(label)
        newPanel.contentView = background

        let mouse = NSEvent.mouseLocation
        newPanel.setFrameOrigin(NSPoint(x: mouse.x + 14, y: mouse.y - height - 14))
        newPanel.orderFrontRegardless()
        panel = newPanel

        Task { @MainActor in
            try? await Task.sleep(for: .seconds(1.3))
            if panel === newPanel {
                newPanel.orderOut(nil)
                panel = nil
            }
        }
    }
}

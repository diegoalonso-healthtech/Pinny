import AppKit

/// Elemento de menú que ejecuta un cierre al elegirlo.
final class ActionMenuItem: NSMenuItem {
    private var handler: (() -> Void)?

    init(title: String, handler: @escaping () -> Void) {
        self.handler = handler
        super.init(title: title, action: #selector(fire), keyEquivalent: "")
        target = self
    }

    required init(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    @objc private func fire() {
        handler?()
    }
}

/// Menú nativo con submenús: Pines > (carpetas > textos), Recientes > últimos 10.
@MainActor
enum PopupMenu {
    /// Los dos elementos «Pines» y «Recientes», con sus submenús. `onSelect` recibe el texto elegido.
    static func items(onSelect: @escaping (String) -> Void) -> [NSMenuItem] {
        let store = ClipStore.shared

        // Pines
        let pinsMenu = makeMenu()
        for folder in store.folders {
            let sub = makeMenu()
            let folderPins = store.pinned(in: folder.id)
            for pin in folderPins {
                sub.addItem(entry(pin.text, onSelect))
            }
            if folderPins.isEmpty {
                sub.addItem(placeholder(L("(empty folder)")))
            }
            let folderItem = NSMenuItem(title: "📁 \(folder.name)", action: nil, keyEquivalent: "")
            folderItem.submenu = sub
            pinsMenu.addItem(folderItem)
        }
        for pin in store.pinned(in: nil) {
            pinsMenu.addItem(entry(pin.text, onSelect))
        }
        if pinsMenu.items.isEmpty {
            pinsMenu.addItem(placeholder(L("No pins")))
        }
        let pinsItem = NSMenuItem(title: L("Pins"), action: nil, keyEquivalent: "")
        pinsItem.submenu = pinsMenu

        // Recientes
        let recentMenu = makeMenu()
        let recents = Array(store.recent.prefix(10))
        for item in recents {
            recentMenu.addItem(entry(item.text, onSelect))
        }
        if recents.isEmpty {
            recentMenu.addItem(placeholder(L("History is empty")))
        }
        let recentItem = NSMenuItem(title: L("Recent"), action: nil, keyEquivalent: "")
        recentItem.submenu = recentMenu

        return [pinsItem, recentItem]
    }

    /// Muestra el menú en la posición del cursor y pega lo elegido en la app activa.
    static func show() {
        let previousApp = NSWorkspace.shared.frontmostApplication

        let menu = makeMenu()
        for item in items(onSelect: { text in
            Paster.paste(text, into: previousApp)
        }) {
            menu.addItem(item)
        }

        menu.addItem(.separator())
        menu.addItem(ActionMenuItem(title: L("Search everything…")) {
            Task { @MainActor in Paster.pickAndPaste(mode: .all) }
        })
        menu.addItem(ActionMenuItem(title: L("Settings…")) {
            Task { @MainActor in SettingsWindow.show() }
        })

        menu.popUp(positioning: nil, at: NSEvent.mouseLocation, in: nil)
    }

    // MARK: - Utilidades

    /// Etiqueta de una línea, máx. 50 caracteres. Solo procesa el principio del texto.
    static func label(_ text: String) -> String {
        let head = text.prefix(50)
        let oneLine = head
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "\t", with: " ")
        return head.endIndex < text.endIndex ? oneLine + "…" : oneLine
    }

    private static func makeMenu() -> NSMenu {
        let menu = NSMenu()
        menu.autoenablesItems = false
        return menu
    }

    private static func entry(_ text: String, _ onSelect: @escaping (String) -> Void) -> NSMenuItem {
        ActionMenuItem(title: label(text)) { onSelect(text) }
    }

    private static func placeholder(_ title: String) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        item.isEnabled = false
        return item
    }
}

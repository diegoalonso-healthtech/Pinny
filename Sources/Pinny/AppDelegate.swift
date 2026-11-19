import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private var statusItem: NSStatusItem!
    private let monitor = ClipboardMonitor()
    private let serviceProvider = ServiceProvider()
    private let hotKeys = HotKeyCenter()

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Menú «Edición»: sin él, ⌘C, ⌘V, ⌘X y ⌘A no funcionan en los campos de texto
        // de Pinny, porque es una app de barra de menús.
        NSApp.mainMenu = makeMainMenu()

        // Registra los Servicios y avisa al sistema.
        NSApp.servicesProvider = serviceProvider
        NSUpdateDynamicServices()

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        updateStatusIcon()
        let menu = NSMenu()
        menu.delegate = self
        statusItem.menu = menu

        registerHotKeys()
        NotificationCenter.default.addObserver(
            forName: .hotKeysChanged,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.registerHotKeys() }
        }

        monitor.start()
        RightClickMonitor.shared.update()

        // Si hubo que recuperar datos al arrancar, se avisa.
        if let message = ClipStore.shared.recoveryMessage {
            Task { @MainActor in
                Prompt.info(title: "Pinny ha recuperado tus datos", message: message)
            }
        }

        // Guía: primer arranque, guía nueva o permiso perdido (p. ej. tras reinstalar).
        WelcomeWindow.showIfNeeded()
    }

    func applicationWillTerminate(_ notification: Notification) {
        // Guarda lo pendiente antes de salir.
        ClipStore.shared.flush(waitUntilWritten: true)
    }

    /// Atajos elegidos en Ajustes: menú rápido y panel con buscador.
    private func registerHotKeys() {
        let settings = Settings.shared
        let menuKey = settings.menuHotKey
        let panelKey = settings.panelHotKey
        var problems: [String] = []

        let menuOK = hotKeys.register(id: 1, keyCode: menuKey.keyCode, modifiers: menuKey.modifiers) {
            Task { @MainActor in PopupMenu.show() }
        }
        if !menuOK {
            problems.append("No se pudo activar \(menuKey.name) (menú rápido). Puede que otra app lo esté usando.")
        }

        let panelOK = hotKeys.register(id: 2, keyCode: panelKey.keyCode, modifiers: panelKey.modifiers) {
            Task { @MainActor in Paster.pickAndPaste(mode: .all) }
        }
        if !panelOK {
            problems.append("No se pudo activar \(panelKey.name) (panel con buscador). Puede que otra app lo esté usando.")
        }

        settings.hotKeyProblems = problems
    }

    private func updateStatusIcon() {
        let paused = Settings.shared.capturePaused
        statusItem.button?.image = NSImage(
            systemSymbolName: paused ? "pin.slash" : "pin.circle",
            accessibilityDescription: paused ? "Pinny (captura en pausa)" : "Pinny"
        )
    }

    /// Menú principal mínimo (no se ve: Pinny no sale en el Dock), solo para los atajos de edición.
    private func makeMainMenu() -> NSMenu {
        let main = NSMenu()

        let appItem = NSMenuItem()
        let appMenu = NSMenu()
        appMenu.addItem(NSMenuItem(
            title: "Salir de Pinny",
            action: #selector(NSApplication.terminate(_:)),
            keyEquivalent: "q"
        ))
        appItem.submenu = appMenu
        main.addItem(appItem)

        let editItem = NSMenuItem()
        let edit = NSMenu(title: "Edición")
        edit.addItem(NSMenuItem(title: "Deshacer", action: Selector(("undo:")), keyEquivalent: "z"))
        let redo = NSMenuItem(title: "Rehacer", action: Selector(("redo:")), keyEquivalent: "z")
        redo.keyEquivalentModifierMask = [.command, .shift]
        edit.addItem(redo)
        edit.addItem(.separator())
        edit.addItem(NSMenuItem(title: "Cortar", action: #selector(NSText.cut(_:)), keyEquivalent: "x"))
        edit.addItem(NSMenuItem(title: "Copiar", action: #selector(NSText.copy(_:)), keyEquivalent: "c"))
        edit.addItem(NSMenuItem(title: "Pegar", action: #selector(NSText.paste(_:)), keyEquivalent: "v"))
        edit.addItem(NSMenuItem(title: "Seleccionar todo", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a"))
        editItem.submenu = edit
        main.addItem(editItem)

        return main
    }

    // MARK: - Menú de la barra

    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()
        let settings = Settings.shared

        // Avisos de atajos que no funcionan.
        for problem in settings.hotKeyProblems {
            let warning = NSMenuItem(title: "⚠️ \(problem)", action: nil, keyEquivalent: "")
            warning.isEnabled = false
            menu.addItem(warning)
        }
        if !settings.hotKeyProblems.isEmpty {
            menu.addItem(.separator())
        }

        // Pines y Recientes con submenús. Desde aquí, elegir un elemento solo lo copia.
        for item in PopupMenu.items(onSelect: { text in
            let pasteboard = NSPasteboard.general
            pasteboard.clearContents()
            pasteboard.setString(text, forType: .string)
        }) {
            menu.addItem(item)
        }

        menu.addItem(.separator())

        let panelName = settings.panelHotKey.name
        menu.addItem(ActionMenuItem(title: "Buscar en todo… (\(panelName))") {
            Task { @MainActor in Paster.pickAndPaste(mode: .all) }
        })
        menu.addItem(ActionMenuItem(title: "Ajustes…") {
            Task { @MainActor in SettingsWindow.show() }
        })
        menu.addItem(ActionMenuItem(title: "Guía de configuración…") {
            Task { @MainActor in WelcomeWindow.show() }
        })

        menu.addItem(.separator())

        menu.addItem(ActionMenuItem(
            title: settings.capturePaused ? "Reanudar captura" : "Pausar captura"
        ) { [weak self] in
            Task { @MainActor in
                Settings.shared.capturePaused.toggle()
                self?.updateStatusIcon()
            }
        })
        menu.addItem(ActionMenuItem(title: "Borrar recientes (conserva pines)") {
            Task { @MainActor in ClipStore.shared.clearUnpinned() }
        })

        menu.addItem(.separator())
        menu.addItem(ActionMenuItem(title: "Desinstalar Pinny…") {
            Task { @MainActor in Uninstaller.run() }
        })
        menu.addItem(NSMenuItem(
            title: "Salir de Pinny",
            action: #selector(NSApplication.terminate(_:)),
            keyEquivalent: "q"
        ))
    }
}

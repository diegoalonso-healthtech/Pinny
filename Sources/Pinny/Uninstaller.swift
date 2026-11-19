import AppKit
import ServiceManagement

/// Desinstala Pinny desde la propia app.
/// Una app no puede borrarse mientras se ejecuta, así que lanza un proceso `sh`
/// independiente que espera a que Pinny se cierre y entonces limpia.
@MainActor
enum Uninstaller {
    static func run() {
        let bundlePath = Bundle.main.bundlePath

        // Salvaguarda: solo se borra si se ejecuta desde un paquete Pinny.app.
        guard bundlePath.hasSuffix("/Pinny.app") else {
            let alert = NSAlert()
            alert.messageText = "No se puede desinstalar desde aquí"
            alert.informativeText = "Pinny no se está ejecutando desde un paquete Pinny.app. Usa scripts/uninstall.sh."
            alert.runModal()
            return
        }

        let alert = NSAlert()
        alert.messageText = "¿Desinstalar Pinny?"
        alert.informativeText = "Se cerrará la app y se eliminará de este Mac."
        alert.alertStyle = .warning
        let purgeCheckbox = NSButton(
            checkboxWithTitle: "Borrar también mi historial, pines y ajustes",
            target: nil,
            action: nil
        )
        purgeCheckbox.state = .off
        alert.accessoryView = purgeCheckbox
        alert.addButton(withTitle: "Desinstalar")
        alert.addButton(withTitle: "Cancelar")

        NSApp.activate(ignoringOtherApps: true)
        guard alert.runModal() == .alertFirstButtonReturn else { return }

        let purge = purgeCheckbox.state == .on
        let bundleID = Bundle.main.bundleIdentifier ?? "app.pinny.Pinny"

        // Quita el elemento de inicio de sesión, si estaba activado.
        try? SMAppService.mainApp.unregister()

        var script = "sleep 1; rm -rf \(shellQuote(bundlePath));"
        script += " /usr/bin/tccutil reset Accessibility \(shellQuote(bundleID)) >/dev/null 2>&1;"
        script += " /usr/bin/tccutil reset ListenEvent \(shellQuote(bundleID)) >/dev/null 2>&1;"
        // Siempre: que la guía vuelva a salir si se reinstala.
        script += " /usr/bin/defaults delete \(shellQuote(bundleID)) welcomeGuideVersionSeen >/dev/null 2>&1;"
        if purge {
            script += " rm -rf \"$HOME/Library/Application Support/Pinny\""
            script += " \"$HOME/Library/Caches/\"\(shellQuote(bundleID));"
            script += " /usr/bin/defaults delete \(shellQuote(bundleID)) >/dev/null 2>&1;"
        }
        script += " /System/Library/CoreServices/pbs -update >/dev/null 2>&1"

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/sh")
        process.arguments = ["-c", script]
        try? process.run()

        NSApp.terminate(nil)
    }

    private static func shellQuote(_ value: String) -> String {
        "'" + value.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }
}

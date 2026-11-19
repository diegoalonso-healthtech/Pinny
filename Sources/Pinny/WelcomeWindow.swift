import SwiftUI
import AppKit
import Combine
import ApplicationServices

/// Guía de configuración: se muestra en el primer arranque y desde el menú
/// («Guía de configuración…»). Vuelve sola al frente cuando sales de Ajustes del Sistema.
@MainActor
enum WelcomeWindow {
    private static var window: NSWindow?

    /// Versión de la guía. Súbela cuando la guía cambie y deba verse otra vez.
    private static let guideVersion = 2
    private static let seenKey = "welcomeGuideVersionSeen"

    private static var guideCompleted: Bool {
        UserDefaults.standard.integer(forKey: seenKey) >= guideVersion
    }

    /// Muestra la guía al arrancar si:
    /// - no se ha completado esta versión de la guía, o
    /// - falta el permiso (p. ej. tras reinstalar: el desinstalador lo quita).
    static func showIfNeeded() {
        recordPermissionIfGranted()
        guard !guideCompleted || !AXIsProcessTrusted() else { return }
        show()
    }

    // MARK: - Aviso tras actualizar

    /// Compilación con la que el permiso funcionaba por última vez.
    private static let permissionBuildKey = "permissionGrantedBuild"
    private static var currentBuild: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? ""
    }

    /// Guarda la compilación actual si el permiso está concedido.
    static func recordPermissionIfGranted() {
        guard AXIsProcessTrusted() else { return }
        UserDefaults.standard.set(currentBuild, forKey: permissionBuildKey)
    }

    /// Verdadero si el permiso funcionaba con una versión anterior y ahora falta.
    /// Pasa en cada actualización: con firma ad-hoc, macOS ata el permiso al binario
    /// exacto, así que una versión nueva (o una copia modificada) no lo hereda.
    static var permissionLostAfterUpdate: Bool {
        guard !AXIsProcessTrusted(),
              let previous = UserDefaults.standard.string(forKey: permissionBuildKey) else { return false }
        return previous != currentBuild
    }

    /// Más alta cuando muestra el aviso de actualización.
    fileprivate static var guideHeight: CGFloat { permissionLostAfterUpdate ? 830 : 720 }

    static func show() {
        if window == nil {
            let newWindow = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 560, height: guideHeight),
                styleMask: [.titled, .closable],
                backing: .buffered,
                defer: false
            )
            newWindow.title = L("Set up Pinny")
            newWindow.isReleasedWhenClosed = false
            newWindow.contentView = NSHostingView(rootView: WelcomeView {
                WelcomeWindow.finish()
            })
            newWindow.center()
            window = newWindow
        }
        refreshTitle()
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }

    /// Título en el idioma actual (al abrir y al cambiar de idioma).
    static func refreshTitle() {
        window?.title = L("Set up Pinny")
    }

    // MARK: - Abrir Ajustes del Sistema

    /// Muestra el diálogo del propio macOS para el permiso de Accesibilidad.
    /// Su botón «Abrir Ajustes del Sistema» lleva siempre al apartado correcto,
    /// también en macOS 27, donde ese permiso ha cambiado de nombre y de sitio.
    static func requestAccessibility() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        guard !AXIsProcessTrustedWithOptions(options) else { return }
        watchSystemSettings()
    }

    /// Borra el permiso guardado y lo vuelve a pedir. Arregla el caso típico de firma
    /// ad-hoc: tras recompilar, el interruptor sigue activado pero ya no vale.
    static func repairAccessibility() {
        let bundleID = Bundle.main.bundleIdentifier ?? "app.pinny.Pinny"
        for service in ["Accessibility", "ListenEvent"] {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/tccutil")
            process.arguments = ["reset", service, bundleID]
            try? process.run()
            process.waitUntilExit()
        }
        requestAccessibility()
    }

    /// Abre Ajustes del Sistema por su identificador de app (no depende de enlaces
    /// internos, que Apple cambia entre versiones y no son API oficial).
    static func openSystemSettings() {
        if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: systemSettingsID) {
            NSWorkspace.shared.openApplication(at: url, configuration: NSWorkspace.OpenConfiguration())
        }
        watchSystemSettings()
    }

    // MARK: - Volver a la guía al salir de Ajustes del Sistema

    private static let systemSettingsID = "com.apple.systempreferences"
    private static var observers: [NSObjectProtocol] = []
    private static var settingsWasActive = false

    /// Cuando dejas Ajustes del Sistema (cambias de app o lo cierras), la guía vuelve al frente.
    private static func watchSystemSettings() {
        guard observers.isEmpty else { return }
        settingsWasActive = false
        let center = NSWorkspace.shared.notificationCenter

        observers.append(center.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { note in
            let bundleID = (note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication)?.bundleIdentifier
            Task { @MainActor in WelcomeWindow.handleActivation(of: bundleID) }
        })

        observers.append(center.addObserver(
            forName: NSWorkspace.didTerminateApplicationNotification,
            object: nil,
            queue: .main
        ) { note in
            let bundleID = (note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication)?.bundleIdentifier
            Task { @MainActor in
                if bundleID == WelcomeWindow.systemSettingsID { WelcomeWindow.returnToGuide() }
            }
        })
    }

    private static func handleActivation(of bundleID: String?) {
        if bundleID == systemSettingsID {
            settingsWasActive = true
        } else if settingsWasActive {
            returnToGuide()
        }
    }

    private static func returnToGuide() {
        stopWatching()
        guard let window = WelcomeWindow.window, window.isVisible || !guideCompleted else { return }
        show()
    }

    private static func stopWatching() {
        let center = NSWorkspace.shared.notificationCenter
        observers.forEach { center.removeObserver($0) }
        observers = []
        settingsWasActive = false
    }

    /// Al pulsar «Hecho».
    fileprivate static func finish() {
        stopWatching()
        UserDefaults.standard.set(guideVersion, forKey: seenKey)
        window?.close()
    }
}

private struct WelcomeView: View {
    var onDone: () -> Void

    @ObservedObject private var settings = Settings.shared
    @State private var accessibilityGranted = AXIsProcessTrusted()
    @State private var updatedWithoutPermission = WelcomeWindow.permissionLostAfterUpdate
    /// Fija la altura al abrir, para que no salte al conceder el permiso.
    @State private var height = WelcomeWindow.guideHeight
    @State private var testText = ""
    @State private var testPassed = false
    @State private var showHelp = false

    /// Frase de prueba, en el idioma del sistema.
    private var testPhrase: String { L("No pins were harmed in the making of this text 📌") }
    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 12) {
                Image(nsImage: NSApp.applicationIconImage)
                    .resizable()
                    .frame(width: 56, height: 56)
                VStack(alignment: .leading, spacing: 4) {
                    Text(L("Welcome to Pinny"))
                        .font(.title2.bold())
                    Text(L("Three steps and you’re pasting."))
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Picker(L("Language"), selection: $settings.language) {
                    Text(L("Automatic")).tag("auto")
                    ForEach(Lang.available, id: \.code) { language in
                        Text(language.name).tag(language.code)
                    }
                }
                .labelsHidden()
                .fixedSize()
                .help(L("Language"))
                .onChange(of: settings.language) { _, _ in
                    WelcomeWindow.refreshTitle()
                }
            }

            if updatedWithoutPermission && !accessibilityGranted {
                updateNotice
            }

            step(
                number: 1,
                title: L("Let Pinny paste for you"),
                text: L("To paste into any app with %@ or right-click. Click the button, choose “Open System Settings” in the macOS prompt and turn Pinny on.", settings.menuHotKey.name),
                done: accessibilityGranted,
                buttonTitle: L("Grant permission…"),
                action: WelcomeWindow.requestAccessibility,
                links: [
                    (L("No prompt? Open System Settings"), WelcomeWindow.openSystemSettings),
                    (L("Turned on but not working? Repair permission"), WelcomeWindow.repairAccessibility)
                ]
            )

            rightClickStep

            testStep

            Spacer()

            Divider()

            HStack(alignment: .top) {
                Text(L("Pinny also appears in right-click → Services in compatible apps. You can reopen this guide from the menu bar icon."))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer()
                Button(L("Done"), action: onDone)
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(24)
        .frame(width: 560, height: height)
        .onReceive(timer) { _ in
            accessibilityGranted = AXIsProcessTrusted()
            if accessibilityGranted { WelcomeWindow.recordPermissionIfGranted() }
        }
    }

    /// Aviso tras una actualización: explica que volver a dar el permiso es lo esperado.
    private var updateNotice: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "arrow.triangle.2.circlepath")
                .font(.title3)
                .foregroundStyle(.blue)
            VStack(alignment: .leading, spacing: 6) {
                Text(L("Pinny was updated"))
                    .font(.headline)
                Text(L("macOS asks for the permission again after every Pinny update. It’s expected and only takes a moment: click “Repair permission” and turn Pinny on again."))
                    .font(.callout)
                    .fixedSize(horizontal: false, vertical: true)
                Button(L("Repair permission…"), action: WelcomeWindow.repairAccessibility)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.blue.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
    }

    /// Paso 2: pregunta si se quiere activar el menú con tecla + clic derecho.
    private var rightClickStep: some View {
        HStack(alignment: .top, spacing: 12) {
            badge(number: 2, done: settings.rightClickMenuEnabled && settings.rightClickProblem == nil)
            VStack(alignment: .leading, spacing: 6) {
                Text(L("Your pins on right-click (optional)"))
                    .font(.headline)
                Text(L("Hold the key and right-click to open Pinny (Pins › folders › texts, and Recent) in any app. Without the key, nothing changes."))
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                HStack {
                    Toggle(L("Turn on"), isOn: $settings.rightClickMenuEnabled)
                    Picker(L("with"), selection: $settings.rightClickModifier) {
                        ForEach(Settings.rightClickModifiers, id: \.id) { modifier in
                            Text(modifier.name).tag(modifier.id)
                        }
                    }
                    .fixedSize()
                    .disabled(!settings.rightClickMenuEnabled)
                    Text(L("+ right-click"))
                        .font(.callout)
                }
                if settings.rightClickMenuEnabled, let problem = settings.rightClickProblem {
                    Text(problem)
                        .font(.caption)
                        .foregroundStyle(.orange)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    /// Paso 3: prueba real. Se pone en verde solo cuando la frase llega pegada al cuadro.
    private var testStep: some View {
        HStack(alignment: .top, spacing: 12) {
            badge(number: 3, done: testPassed)
            VStack(alignment: .leading, spacing: 8) {
                Text(L("Try it"))
                    .font(.headline)
                Text(L("1. Copy the sentence.  2. Click the box.  3. Paste it with %@ → Recent.", howToPaste))
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                HStack {
                    Text(L("“%@”", testPhrase))
                        .font(.callout.italic())
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer()
                    Button(L("Copy sentence")) {
                        let pasteboard = NSPasteboard.general
                        pasteboard.clearContents()
                        pasteboard.setString(testPhrase, forType: .string)
                    }
                }

                TextField(L("Paste the sentence here…"), text: $testText)
                    .textFieldStyle(.roundedBorder)
                    .disabled(testPassed)
                    .onChange(of: testText) { _, newValue in
                        if newValue.contains(testPhrase) {
                            withAnimation { testPassed = true }
                        }
                    }

                if testPassed {
                    Text(L("It works! Pinny is ready 🎉"))
                        .font(.callout.bold())
                        .foregroundStyle(.green)
                } else {
                    Button(showHelp ? L("Hide help") : L("It doesn’t show up")) {
                        withAnimation { showHelp.toggle() }
                    }
                    .buttonStyle(.link)
                    .font(.caption)

                    if showHelp {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(L("• Check that step 1 is green. If the switch is on in System Settings but not here, click “Repair permission”."))
                            Text(L("• If you use modifier + right-click, try another key in step 2 or paste with %@.", settings.menuHotKey.name))
                            Text(L("• Still nothing? Paste with ⌘V: the sentence is already on your clipboard."))
                        }
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                        Button(L("Repair permission"), action: WelcomeWindow.repairAccessibility)
                            .font(.caption)
                    }
                }
            }
        }
    }

    private var howToPaste: String {
        settings.rightClickMenuEnabled
            ? L("%@ + right-click", settings.rightClickModifierSymbol)
            : settings.menuHotKey.name
    }

    private func badge(number: Int, done: Bool) -> some View {
        ZStack {
            Circle()
                .fill(done ? Color.green : Color.accentColor)
                .frame(width: 28, height: 28)
            if done {
                Image(systemName: "checkmark")
                    .foregroundStyle(.white)
                    .font(.system(size: 13, weight: .bold))
            } else {
                Text("\(number)")
                    .foregroundStyle(.white)
                    .font(.system(size: 14, weight: .bold))
            }
        }
    }

    /// `done`: true/false muestra el estado; nil si macOS no permite comprobarlo.
    private func step(
        number: Int,
        title: String,
        text: String,
        done: Bool?,
        buttonTitle: String,
        action: @escaping () -> Void,
        links: [(title: String, action: () -> Void)] = []
    ) -> some View {
        HStack(alignment: .top, spacing: 12) {
            badge(number: number, done: done == true)
            VStack(alignment: .leading, spacing: 6) {
                Text(title).font(.headline)
                Text(text)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                if done == true {
                    Text(L("On"))
                        .font(.callout.bold())
                        .foregroundStyle(.green)
                } else {
                    Button(buttonTitle, action: action)
                    ForEach(Array(links.enumerated()), id: \.offset) { _, link in
                        Button(link.title, action: link.action)
                            .buttonStyle(.link)
                            .font(.caption)
                    }
                }
            }
        }
    }
}

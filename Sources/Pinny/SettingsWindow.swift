import SwiftUI
import AppKit
import ServiceManagement

@MainActor
enum SettingsWindow {
    private static var window: NSWindow?

    static func show() {
        if window == nil {
            let newWindow = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 480, height: 600),
                styleMask: [.titled, .closable],
                backing: .buffered,
                defer: false
            )
            newWindow.title = "Ajustes de Pinny"
            newWindow.isReleasedWhenClosed = false
            newWindow.contentView = NSHostingView(rootView: SettingsView())
            newWindow.center()
            window = newWindow
        }
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }
}

struct SettingsView: View {
    @ObservedObject private var settings = Settings.shared
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled
    @State private var loginError: String?

    var body: some View {
        Form {
            Section("Historial") {
                Stepper(
                    "Recientes a conservar: \(settings.historyLimit)",
                    value: $settings.historyLimit,
                    in: 10...2000,
                    step: 10
                )
                Stepper(
                    "Tamaño máximo por elemento: \(settings.maxItemKB) KB",
                    value: $settings.maxItemKB,
                    in: 10...10_000,
                    step: 10
                )
                Text("Los pines nunca se borran solos. Lo que supere el tamaño máximo no se guarda.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Atajos globales") {
                Picker("Menú rápido (pines y recientes)", selection: $settings.menuHotKeyID) {
                    ForEach(HotKeyPreset.all) { preset in
                        Text(preset.name).tag(preset.id)
                    }
                }
                Picker("Panel con buscador", selection: $settings.panelHotKeyID) {
                    ForEach(HotKeyPreset.all) { preset in
                        Text(preset.name).tag(preset.id)
                    }
                }
                if settings.menuHotKeyID == settings.panelHotKeyID {
                    Text("Los dos atajos son iguales: el segundo no funcionará.")
                        .font(.caption)
                        .foregroundStyle(.red)
                }
                ForEach(settings.hotKeyProblems, id: \.self) { problem in
                    Text("⚠️ \(problem)")
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }

            Section("Tecla + clic derecho (experimental)") {
                Toggle("Abrir el menú de Pinny con tecla + clic derecho", isOn: $settings.rightClickMenuEnabled)
                Picker("Tecla", selection: $settings.rightClickModifier) {
                    ForEach(Settings.rightClickModifiers, id: \.id) { modifier in
                        Text(modifier.name).tag(modifier.id)
                    }
                }
                .disabled(!settings.rightClickMenuEnabled)
                Text("Con la tecla pulsada, el clic derecho muestra Pines › carpetas › textos y Recientes en cualquier app. Sin la tecla, el clic derecho funciona como siempre.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if let problem = settings.rightClickProblem {
                    Text("⚠️ \(problem)")
                        .font(.caption)
                        .foregroundStyle(.red)
                    Button("Reparar permiso") {
                        WelcomeWindow.repairAccessibility()
                    }
                }
            }

            Section("Privacidad") {
                Text("Apps cuyo contenido copiado no se guarda (un identificador por línea):")
                    .font(.caption)
                TextEditor(text: $settings.ignoredApps)
                    .font(.system(.body, design: .monospaced))
                    .frame(height: 100)
                Text("Para ver el identificador de una app: osascript -e 'id of app \"Nombre\"'")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Sistema") {
                Toggle("Abrir Pinny al iniciar sesión", isOn: Binding(
                    get: { launchAtLogin },
                    set: { setLaunchAtLogin($0) }
                ))
                if let loginError {
                    Text(loginError)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
                Button("Desinstalar Pinny…", role: .destructive) {
                    Task { @MainActor in Uninstaller.run() }
                }
            }

            Section("Sincronización") {
                Text("Disponible en la próxima versión.")
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .frame(width: 480, height: 600)
    }

    private func setLaunchAtLogin(_ enable: Bool) {
        do {
            if enable {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
            loginError = nil
        } catch {
            loginError = "No se pudo cambiar: \(error.localizedDescription)"
        }
        launchAtLogin = SMAppService.mainApp.status == .enabled
    }
}

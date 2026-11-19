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
            newWindow.title = L("Pinny Settings")
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
            Section(L("History")) {
                Stepper(
                    L("Recent items to keep: %ld", settings.historyLimit),
                    value: $settings.historyLimit,
                    in: 10...2000,
                    step: 10
                )
                Stepper(
                    L("Max size per item: %ld KB", settings.maxItemKB),
                    value: $settings.maxItemKB,
                    in: 10...10_000,
                    step: 10
                )
                Text(L("Pins are never deleted automatically. Items larger than the max size aren’t saved."))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section(L("Global shortcuts")) {
                Picker(L("Quick menu (pins and recent)"), selection: $settings.menuHotKeyID) {
                    ForEach(HotKeyPreset.all) { preset in
                        Text(preset.name).tag(preset.id)
                    }
                }
                Picker(L("Search panel"), selection: $settings.panelHotKeyID) {
                    ForEach(HotKeyPreset.all) { preset in
                        Text(preset.name).tag(preset.id)
                    }
                }
                if settings.menuHotKeyID == settings.panelHotKeyID {
                    Text(L("Both shortcuts are the same: the second one won’t work."))
                        .font(.caption)
                        .foregroundStyle(.red)
                }
                ForEach(settings.hotKeyProblems, id: \.self) { problem in
                    Text("⚠️ \(problem)")
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }

            Section(L("Modifier + right-click (experimental)")) {
                Toggle(L("Open Pinny’s menu with modifier + right-click"), isOn: $settings.rightClickMenuEnabled)
                Picker(L("Key"), selection: $settings.rightClickModifier) {
                    ForEach(Settings.rightClickModifiers, id: \.id) { modifier in
                        Text(modifier.name).tag(modifier.id)
                    }
                }
                .disabled(!settings.rightClickMenuEnabled)
                Text(L("Hold the key and right-click to see Pins › folders › texts and Recent in any app. Without the key, right-click works as usual."))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if let problem = settings.rightClickProblem {
                    Text("⚠️ \(problem)")
                        .font(.caption)
                        .foregroundStyle(.red)
                    Button(L("Repair permission")) {
                        WelcomeWindow.repairAccessibility()
                    }
                }
            }

            Section(L("Privacy")) {
                Text(L("Apps whose copied content isn’t saved (one bundle ID per line):"))
                    .font(.caption)
                TextEditor(text: $settings.ignoredApps)
                    .font(.system(.body, design: .monospaced))
                    .frame(height: 100)
                Text(L("To find an app’s bundle ID: osascript -e 'id of app \"Name\"'"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section(L("System")) {
                Toggle(L("Open Pinny at login"), isOn: Binding(
                    get: { launchAtLogin },
                    set: { setLaunchAtLogin($0) }
                ))
                if let loginError {
                    Text(loginError)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
                Button(L("Uninstall Pinny…"), role: .destructive) {
                    Task { @MainActor in Uninstaller.run() }
                }
            }

            Section(L("Sync")) {
                Text(L("Coming in a future version."))
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
            loginError = L("Couldn’t change it: %@", error.localizedDescription)
        }
        launchAtLogin = SMAppService.mainApp.status == .enabled
    }
}

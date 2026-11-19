import Foundation
import CoreGraphics
import Carbon.HIToolbox

extension Notification.Name {
    static let hotKeysChanged = Notification.Name("PinnyHotKeysChanged")
}

/// Combinaciones de teclas disponibles para los atajos globales.
struct HotKeyPreset: Identifiable, Hashable {
    let id: String
    let name: String
    let keyCode: Int
    let modifiers: Int

    static let all: [HotKeyPreset] = [
        HotKeyPreset(id: "ctrl-opt-v", name: "⌃⌥V", keyCode: kVK_ANSI_V, modifiers: controlKey | optionKey),
        HotKeyPreset(id: "ctrl-opt-shift-v", name: "⌃⌥⇧V", keyCode: kVK_ANSI_V, modifiers: controlKey | optionKey | shiftKey),
        HotKeyPreset(id: "ctrl-opt-c", name: "⌃⌥C", keyCode: kVK_ANSI_C, modifiers: controlKey | optionKey),
        HotKeyPreset(id: "ctrl-cmd-v", name: "⌃⌘V", keyCode: kVK_ANSI_V, modifiers: controlKey | cmdKey),
        HotKeyPreset(id: "ctrl-opt-space", name: "⌃⌥Espacio", keyCode: kVK_Space, modifiers: controlKey | optionKey)
    ]
}

/// Preferencias del usuario, guardadas en UserDefaults.
@MainActor
final class Settings: ObservableObject {
    static let shared = Settings()

    /// Identificadores de apps cuyo contenido copiado no se guarda. Editable en Ajustes.
    /// Son los que creo correctos; compruébalos con `osascript -e 'id of app "NombreApp"'`.
    static let defaultIgnoredApps = """
    com.1password.1password
    com.agilebits.onepassword7
    com.bitwarden.desktop
    org.keepassxc.keepassxc
    com.apple.keychainaccess
    """

    @Published var historyLimit: Int {
        didSet {
            UserDefaults.standard.set(historyLimit, forKey: "historyLimit")
            ClipStore.shared.applyHistoryLimit()
        }
    }
    /// Se conserva entre reinicios.
    @Published var capturePaused: Bool {
        didSet { UserDefaults.standard.set(capturePaused, forKey: "capturePaused") }
    }
    /// Avisos de atajos que macOS no ha aceptado (no se guardan).
    @Published var hotKeyProblems: [String] = []

    /// Menú de Pinny con tecla + clic derecho (experimental, desactivado por defecto).
    @Published var rightClickMenuEnabled: Bool {
        didSet {
            UserDefaults.standard.set(rightClickMenuEnabled, forKey: "rightClickMenuEnabled")
            RightClickMonitor.shared.update()
        }
    }
    /// "cmd", "opt" o "shift".
    @Published var rightClickModifier: String {
        didSet {
            UserDefaults.standard.set(rightClickModifier, forKey: "rightClickModifier")
            RightClickMonitor.shared.update()
        }
    }
    /// Aviso si el menú con clic derecho no se ha podido activar (no se guarda).
    @Published var rightClickProblem: String?

    static let rightClickModifiers: [(id: String, name: String)] = [
        ("cmd", "⌘ Comando"),
        ("opt", "⌥ Opción"),
        ("shift", "⇧ Mayúsculas")
    ]

    var rightClickFlags: CGEventFlags {
        switch rightClickModifier {
        case "opt": return .maskAlternate
        case "shift": return .maskShift
        default: return .maskCommand
        }
    }

    var rightClickModifierSymbol: String {
        switch rightClickModifier {
        case "opt": return "⌥"
        case "shift": return "⇧"
        default: return "⌘"
        }
    }
    @Published var maxItemKB: Int {
        didSet { UserDefaults.standard.set(maxItemKB, forKey: "maxItemKB") }
    }
    @Published var ignoredApps: String {
        didSet { UserDefaults.standard.set(ignoredApps, forKey: "ignoredApps") }
    }
    @Published var menuHotKeyID: String {
        didSet {
            UserDefaults.standard.set(menuHotKeyID, forKey: "menuHotKeyID")
            NotificationCenter.default.post(name: .hotKeysChanged, object: nil)
        }
    }
    @Published var panelHotKeyID: String {
        didSet {
            UserDefaults.standard.set(panelHotKeyID, forKey: "panelHotKeyID")
            NotificationCenter.default.post(name: .hotKeysChanged, object: nil)
        }
    }

    private init() {
        let d = UserDefaults.standard
        historyLimit = d.object(forKey: "historyLimit") as? Int ?? 20
        maxItemKB = d.object(forKey: "maxItemKB") as? Int ?? 100
        capturePaused = d.bool(forKey: "capturePaused")
        rightClickMenuEnabled = d.bool(forKey: "rightClickMenuEnabled")
        rightClickModifier = d.string(forKey: "rightClickModifier") ?? "cmd"
        ignoredApps = d.string(forKey: "ignoredApps") ?? Settings.defaultIgnoredApps
        menuHotKeyID = d.string(forKey: "menuHotKeyID") ?? "ctrl-opt-v"
        panelHotKeyID = d.string(forKey: "panelHotKeyID") ?? "ctrl-opt-shift-v"
    }

    var maxItemBytes: Int { maxItemKB * 1024 }

    var menuHotKey: HotKeyPreset {
        HotKeyPreset.all.first { $0.id == menuHotKeyID } ?? HotKeyPreset.all[0]
    }

    var panelHotKey: HotKeyPreset {
        HotKeyPreset.all.first { $0.id == panelHotKeyID } ?? HotKeyPreset.all[1]
    }

    var ignoredBundleIDs: Set<String> {
        Set(
            ignoredApps
                .split(whereSeparator: \.isNewline)
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { !$0.isEmpty }
        )
    }
}

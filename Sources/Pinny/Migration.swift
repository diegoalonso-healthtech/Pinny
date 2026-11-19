import Foundation

/// Trae los datos de ClipPin (nombre anterior de Pinny) la primera vez que se abre Pinny:
/// historial, pines, carpetas y ajustes. No borra nada de ClipPin.
enum Migration {
    private static let oldBundleID = "org.clippin.ClipPin"
    private static let doneKey = "migratedFromClipPin"

    static func runIfNeeded() {
        let defaults = UserDefaults.standard
        guard !defaults.bool(forKey: doneKey) else { return }
        defer { defaults.set(true, forKey: doneKey) }

        migrateStore()
        migrateSettings(into: defaults)
    }

    private static func migrateStore() {
        let fm = FileManager.default
        let support = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let oldStore = support.appendingPathComponent("ClipPin/store.json")
        let newDir = support.appendingPathComponent("Pinny", isDirectory: true)
        let newStore = newDir.appendingPathComponent("store.json")

        guard fm.fileExists(atPath: oldStore.path), !fm.fileExists(atPath: newStore.path) else { return }
        try? fm.createDirectory(at: newDir, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
        try? fm.copyItem(at: oldStore, to: newStore)
        try? fm.setAttributes([.posixPermissions: 0o600], ofItemAtPath: newStore.path)
    }

    private static func migrateSettings(into defaults: UserDefaults) {
        guard let old = UserDefaults(suiteName: oldBundleID) else { return }
        let keys = [
            "historyLimit", "maxItemKB", "ignoredApps", "menuHotKeyID", "panelHotKeyID",
            "capturePaused", "rightClickMenuEnabled", "rightClickModifier"
        ]
        for key in keys where defaults.object(forKey: key) == nil {
            if let value = old.object(forKey: key) {
                defaults.set(value, forKey: key)
            }
        }
    }
}

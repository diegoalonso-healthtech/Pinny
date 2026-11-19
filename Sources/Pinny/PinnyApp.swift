import AppKit

@main
struct PinnyApp {
    @MainActor
    static func main() {
        Lang.apply(UserDefaults.standard.string(forKey: "language") ?? "auto")
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        app.setActivationPolicy(.accessory) // sin icono en el Dock
        app.run()
    }
}

import AppKit

@main
struct PinnyApp {
    @MainActor
    static func main() {
        Migration.runIfNeeded() // datos de ClipPin, nombre anterior
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        app.setActivationPolicy(.accessory) // sin icono en el Dock
        app.run()
    }
}

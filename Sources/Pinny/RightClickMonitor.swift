import AppKit
import CoreGraphics

/// Estado que comparte el callback C del event tap (no aislado al hilo principal).
enum RightClickTapState {
    static var tap: CFMachPort?
    static var requiredFlags: CGEventFlags = .maskCommand
    static var swallowNextUp = false
}

/// Callback del event tap: si haces clic derecho con la tecla elegida, se anula ese clic
/// (la app no abre su menú) y Pinny muestra el suyo en el cursor.
private let rightClickCallback: CGEventTapCallBack = { _, type, event, _ in
    // macOS desactiva el tap si tarda o si el usuario lo interrumpe: se reactiva.
    if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
        if let tap = RightClickTapState.tap {
            CGEvent.tapEnable(tap: tap, enable: true)
        }
        return Unmanaged.passUnretained(event)
    }

    if type == .rightMouseDown {
        let modifiers = event.flags.intersection([.maskCommand, .maskAlternate, .maskShift, .maskControl])
        if modifiers == RightClickTapState.requiredFlags {
            RightClickTapState.swallowNextUp = true
            Task { @MainActor in PopupMenu.show() }
            return nil
        }
    } else if type == .rightMouseUp, RightClickTapState.swallowNextUp {
        RightClickTapState.swallowNextUp = false
        return nil
    }
    return Unmanaged.passUnretained(event)
}

/// Menú de Pinny con tecla + clic derecho, en cualquier app (experimental).
/// Necesita el permiso de Accesibilidad; si macOS lo exige, también Monitorización de entrada.
@MainActor
final class RightClickMonitor {
    static let shared = RightClickMonitor()

    private var source: CFRunLoopSource?
    private var retryTimer: Timer?

    private init() {}

    /// Aplica los ajustes actuales: arranca, para o cambia la tecla.
    func update() {
        let settings = Settings.shared
        RightClickTapState.requiredFlags = settings.rightClickFlags

        guard settings.rightClickMenuEnabled else {
            stop()
            settings.rightClickProblem = nil
            return
        }
        guard RightClickTapState.tap == nil else { return }

        if start() {
            settings.rightClickProblem = nil
            retryTimer?.invalidate()
            retryTimer = nil
        } else {
            settings.rightClickProblem = "Pendiente de permiso: concede Accesibilidad a Pinny (y Monitorización de entrada si macOS lo pide). Se activará solo."
            scheduleRetry()
        }
    }

    private func start() -> Bool {
        let mask = CGEventMask(1 << CGEventType.rightMouseDown.rawValue)
            | CGEventMask(1 << CGEventType.rightMouseUp.rawValue)

        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: mask,
            callback: rightClickCallback,
            userInfo: nil
        ) else {
            return false
        }

        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)

        RightClickTapState.tap = tap
        self.source = source
        return true
    }

    private func stop() {
        retryTimer?.invalidate()
        retryTimer = nil
        if let tap = RightClickTapState.tap {
            CGEvent.tapEnable(tap: tap, enable: false)
            CFMachPortInvalidate(tap)
        }
        if let source {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes)
        }
        RightClickTapState.tap = nil
        RightClickTapState.swallowNextUp = false
        source = nil
    }

    /// Reintenta cada 3 s, para que se active solo en cuanto concedas el permiso.
    private func scheduleRetry() {
        guard retryTimer == nil else { return }
        let timer = Timer(timeInterval: 3, repeats: true) { _ in
            Task { @MainActor in RightClickMonitor.shared.update() }
        }
        RunLoop.main.add(timer, forMode: .common)
        retryTimer = timer
    }
}

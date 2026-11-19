import Foundation

/// Una carpeta de pines (un solo nivel).
struct Folder: Identifiable, Codable, Equatable {
    var id = UUID()
    var name: String
}

/// Un elemento del historial. Los anclados (`pinned`) nunca se eliminan solos.
struct ClipItem: Identifiable, Codable, Equatable {
    var id = UUID()
    var text: String
    var date = Date()
    var pinned = false
    /// Solo tiene sentido si `pinned` es true. nil = pin sin carpeta.
    var folderID: UUID?

    /// Vista previa de una línea, recortada: evita procesar textos enormes al dibujar.
    var preview: String {
        let head = text.prefix(300)
        let oneLine = head
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "\t", with: " ")
        return head.endIndex < text.endIndex ? oneLine + "…" : oneLine
    }
}

private struct StoreFile: Codable {
    var items: [ClipItem]
    var folders: [Folder]
}

/// Almacén local en JSON: ~/Library/Application Support/Pinny/store.json
/// - Carpeta con permisos 700 y archivo con 600.
/// - Guardado agrupado (1 s) y escrito en segundo plano.
/// - Copia de seguridad del último estado bueno en cada arranque (store.backup.json).
/// - Si el archivo está dañado, se aparta (store.corrupt-<fecha>.json) en vez de sobrescribirlo.
@MainActor
final class ClipStore: ObservableObject {
    static let shared = ClipStore()

    @Published private(set) var items: [ClipItem] = []
    @Published private(set) var folders: [Folder] = []

    /// Aviso para el usuario si hubo que recuperar datos al arrancar.
    private(set) var recoveryMessage: String?

    private let directory: URL
    private let fileURL: URL
    private let backupURL: URL
    private let saveQueue = DispatchQueue(label: "app.pinny.save", qos: .utility)
    private var saveTask: Task<Void, Never>?

    private init() {
        let fm = FileManager.default
        directory = fm
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Pinny", isDirectory: true)
        try? fm.createDirectory(
            at: directory,
            withIntermediateDirectories: true,
            attributes: [.posixPermissions: 0o700]
        )
        // Por si la carpeta ya existía de una versión anterior con otros permisos.
        try? fm.setAttributes([.posixPermissions: 0o700], ofItemAtPath: directory.path)

        fileURL = directory.appendingPathComponent("store.json")
        backupURL = directory.appendingPathComponent("store.backup.json")
        load()
    }

    // MARK: - Consultas

    var pinned: [ClipItem] { items.filter { $0.pinned } }
    var recent: [ClipItem] { items.filter { !$0.pinned } }

    /// Pines de una carpeta (o los pines sueltos si `folderID` es nil), en su orden.
    func pinned(in folderID: UUID?) -> [ClipItem] {
        items.filter { $0.pinned && $0.folderID == folderID }
    }

    // MARK: - Historial

    func add(_ text: String) {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        // Evita guardar volcados enormes (límite configurable en Ajustes).
        guard text.utf8.count <= Settings.shared.maxItemBytes else { return }

        if let index = items.firstIndex(where: { $0.text == text }) {
            // Si ya está anclado, no se mueve. Si no, sube al principio.
            guard !items[index].pinned else { return }
            var item = items.remove(at: index)
            item.date = Date()
            items.insert(item, at: 0)
        } else {
            items.insert(ClipItem(text: text), at: 0)
        }
        trim()
        scheduleSave()
    }

    func delete(_ id: UUID) {
        items.removeAll { $0.id == id }
        scheduleSave()
    }

    func clearUnpinned() {
        items.removeAll { !$0.pinned }
        scheduleSave()
    }

    /// Aplica de inmediato un nuevo límite de historial (al cambiarlo en Ajustes).
    func applyHistoryLimit() {
        trim()
        scheduleSave()
    }

    // MARK: - Pines

    func togglePin(_ id: UUID) {
        guard let index = items.firstIndex(where: { $0.id == id }) else { return }
        var item = items.remove(at: index)
        item.pinned.toggle()
        item.folderID = nil
        items.insert(item, at: 0)
        trim()
        scheduleSave()
    }

    enum PinResult { case pinned, alreadyPinned, tooLong, empty }

    /// Ancla un texto (de la selección, el portapapeles o escrito a mano).
    /// Si ya estaba en Recientes, pasa a Pines; si ya estaba anclado, no se duplica.
    @discardableResult
    func pin(_ text: String, folderID: UUID? = nil) -> PinResult {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return .empty }
        guard text.utf8.count <= Settings.shared.maxItemBytes else { return .tooLong }

        if let index = items.firstIndex(where: { $0.text == text }) {
            if items[index].pinned {
                if let folderID {
                    items[index].folderID = folderID
                    scheduleSave()
                }
                return .alreadyPinned
            }
            var item = items.remove(at: index)
            item.pinned = true
            item.folderID = folderID
            items.insert(item, at: 0)
        } else {
            items.insert(ClipItem(text: text, pinned: true, folderID: folderID), at: 0)
        }
        scheduleSave()
        return .pinned
    }

    /// Sube o baja un pin dentro de su grupo (su carpeta, o los sueltos).
    func movePin(_ id: UUID, up: Bool) {
        guard let item = items.first(where: { $0.id == id }), item.pinned else { return }
        let group = items.indices.filter {
            items[$0].pinned && items[$0].folderID == item.folderID
        }
        guard let position = group.firstIndex(where: { items[$0].id == id }) else { return }
        let target = up ? position - 1 : position + 1
        guard group.indices.contains(target) else { return }
        items.swapAt(group[position], group[target])
        scheduleSave()
    }

    // MARK: - Carpetas

    @discardableResult
    func addFolder(_ name: String) -> UUID {
        let folder = Folder(name: name)
        folders.append(folder)
        scheduleSave()
        return folder.id
    }

    func renameFolder(_ id: UUID, to name: String) {
        guard let index = folders.firstIndex(where: { $0.id == id }) else { return }
        folders[index].name = name
        scheduleSave()
    }

    /// Al borrar una carpeta, sus pines pasan a estar sueltos (no se pierden).
    func deleteFolder(_ id: UUID) {
        for index in items.indices where items[index].folderID == id {
            items[index].folderID = nil
        }
        folders.removeAll { $0.id == id }
        scheduleSave()
    }

    func setFolder(_ itemID: UUID, _ folderID: UUID?) {
        guard let index = items.firstIndex(where: { $0.id == itemID }), items[index].pinned else { return }
        items[index].folderID = folderID
        scheduleSave()
    }

    // MARK: - Persistencia

    private func trim() {
        let limit = Settings.shared.historyLimit
        var count = 0
        items = items.filter { item in
            if item.pinned { return true }
            count += 1
            return count <= limit
        }
    }

    private func load() {
        let fm = FileManager.default
        guard fm.fileExists(atPath: fileURL.path) else { return }

        if let data = try? Data(contentsOf: fileURL), let file = Self.decode(data) {
            items = file.items
            folders = file.folders
            // Copia de seguridad del último estado bueno.
            try? fm.removeItem(at: backupURL)
            try? fm.copyItem(at: fileURL, to: backupURL)
            return
        }

        // Archivo ilegible: se aparta para no sobrescribirlo y perder los pines.
        let stamp = ISO8601DateFormatter().string(from: Date())
            .replacingOccurrences(of: ":", with: "-")
        let corruptURL = directory.appendingPathComponent("store.corrupt-\(stamp).json")
        try? fm.moveItem(at: fileURL, to: corruptURL)

        if let data = try? Data(contentsOf: backupURL), let file = Self.decode(data) {
            items = file.items
            folders = file.folders
            recoveryMessage = L("Your data file couldn’t be read, so the latest backup was restored.\nThe damaged file was kept at:\n%@", corruptURL.path)
            flush()
        } else {
            recoveryMessage = L("Your data file couldn’t be read and there’s no valid backup, so Pinny starts empty.\nThe damaged file was kept at:\n%@", corruptURL.path)
        }
    }

    private static func decode(_ data: Data) -> StoreFile? {
        let decoder = JSONDecoder()
        if let file = try? decoder.decode(StoreFile.self, from: data) {
            return file
        }
        if let legacy = try? decoder.decode([ClipItem].self, from: data) {
            // Formato de v0.1/v0.2: solo una lista de elementos.
            return StoreFile(items: legacy, folders: [])
        }
        return nil
    }

    /// Agrupa los cambios: guarda como mucho una vez por segundo.
    private func scheduleSave() {
        saveTask?.cancel()
        saveTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(1))
            guard !Task.isCancelled else { return }
            self?.flush()
        }
    }

    /// Escribe el estado actual en disco (en segundo plano, en orden).
    /// Con `waitUntilWritten` espera a que termine: se usa al salir de la app.
    func flush(waitUntilWritten: Bool = false) {
        saveTask?.cancel()
        saveTask = nil

        let file = StoreFile(items: items, folders: folders)
        let url = fileURL
        let write = {
            guard let data = try? JSONEncoder().encode(file) else { return }
            try? data.write(to: url, options: .atomic)
            try? FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: url.path)
        }
        if waitUntilWritten {
            saveQueue.sync(execute: write)
        } else {
            saveQueue.async(execute: write)
        }
    }
}

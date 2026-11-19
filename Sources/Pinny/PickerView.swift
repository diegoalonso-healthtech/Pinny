import SwiftUI
import AppKit

/// Qué muestra el selector.
enum PickerMode {
    case all, pinned, recent

    var title: String {
        switch self {
        case .all: return "Pinny"
        case .pinned: return "Pinny · Pines"
        case .recent: return "Pinny · Recientes"
        }
    }
}

private struct PickerGroup: Identifiable {
    let id: String
    let title: String
    let folder: Folder?
    let items: [ClipItem]
}

/// Panel con buscador, carpetas de pines y recientes. Teclado: ↑ ↓ Intro, ⌘1…⌘9, Esc.
struct PickerView: View {
    @ObservedObject var store: ClipStore
    var mode: PickerMode
    var onPick: (String) -> Void
    var onCancel: () -> Void

    @State private var query = ""
    @State private var selection: UUID?
    @FocusState private var searchFocused: Bool

    // MARK: - Datos (se calculan una vez por dibujado)

    private func makeGroups() -> [PickerGroup] {
        let q = query
        func matches(_ item: ClipItem) -> Bool {
            q.isEmpty || item.text.localizedCaseInsensitiveContains(q)
        }

        var result: [PickerGroup] = []

        if mode != .recent {
            for folder in store.folders {
                let items = store.pinned(in: folder.id).filter(matches)
                // Las carpetas vacías solo se ven sin búsqueda, para poder gestionarlas.
                if !items.isEmpty || q.isEmpty {
                    result.append(PickerGroup(id: folder.id.uuidString, title: "📁 \(folder.name)", folder: folder, items: items))
                }
            }
            let loose = store.pinned(in: nil).filter(matches)
            if !loose.isEmpty {
                result.append(PickerGroup(id: "pins", title: "Pines", folder: nil, items: loose))
            }
        }

        if mode != .pinned {
            let recent = store.recent.filter(matches)
            if !recent.isEmpty {
                result.append(PickerGroup(id: "recent", title: "Recientes", folder: nil, items: recent))
            }
        }
        return result
    }

    var body: some View {
        let groups = makeGroups()
        let flat = groups.flatMap { $0.items }
        let shortcuts = Dictionary(
            uniqueKeysWithValues: flat.prefix(9).enumerated().map { ($1.id, $0 + 1) }
        )

        VStack(spacing: 0) {
            TextField("Buscar…", text: $query)
                .textFieldStyle(.roundedBorder)
                .padding(8)
                .focused($searchFocused)
                .onSubmit { pickSelected() }
                .onKeyPress(.downArrow) { move(1); return .handled }
                .onKeyPress(.upArrow) { move(-1); return .handled }

            if groups.isEmpty {
                Spacer()
                Text("No hay elementos")
                    .foregroundStyle(.secondary)
                Spacer()
            } else {
                ScrollViewReader { proxy in
                    List(selection: $selection) {
                        ForEach(groups) { group in
                            Section {
                                ForEach(group.items) { item in
                                    row(item, shortcut: shortcuts[item.id])
                                }
                            } header: {
                                header(group)
                            }
                        }
                    }
                    .onChange(of: selection) { _, newValue in
                        if let newValue { proxy.scrollTo(newValue) }
                    }
                }
            }

            HStack {
                Button("Nueva carpeta…") {
                    if let name = Prompt.text(title: "Nueva carpeta", message: "Nombre de la carpeta:") {
                        store.addFolder(name)
                    }
                }
                Spacer()
                Button("Cancelar", action: onCancel)
                    .keyboardShortcut(.cancelAction)
            }
            .padding(8)
        }
        .frame(width: 440, height: 520)
        .background(shortcutButtons(Array(flat.prefix(9))))
        .onAppear {
            searchFocused = true
            selection = flat.first?.id
        }
        .onChange(of: query) { _, _ in
            selection = makeGroups().first(where: { !$0.items.isEmpty })?.items.first?.id
        }
    }

    // MARK: - Teclado

    private func move(_ delta: Int) {
        let items = makeGroups().flatMap { $0.items }
        guard !items.isEmpty else { return }
        let current = items.firstIndex { $0.id == selection } ?? (delta > 0 ? -1 : items.count)
        let next = max(0, min(items.count - 1, current + delta))
        selection = items[next].id
    }

    private func pickSelected() {
        let items = makeGroups().flatMap { $0.items }
        if let item = items.first(where: { $0.id == selection }) ?? items.first {
            onPick(item.text)
        }
    }

    /// Botones invisibles con ⌘1…⌘9 para elegir directamente los 9 primeros.
    private func shortcutButtons(_ firstNine: [ClipItem]) -> some View {
        ZStack {
            ForEach(Array(firstNine.enumerated()), id: \.offset) { index, item in
                Button("") { onPick(item.text) }
                    .keyboardShortcut(KeyEquivalent(Character(String(index + 1))), modifiers: .command)
            }
        }
        .opacity(0)
        .allowsHitTesting(false)
    }

    // MARK: - Filas

    @ViewBuilder
    private func header(_ group: PickerGroup) -> some View {
        HStack {
            Text(group.title)
            if let folder = group.folder {
                Spacer()
                Menu {
                    Button("Renombrar…") {
                        if let name = Prompt.text(title: "Renombrar carpeta", message: "Nuevo nombre:", initial: folder.name) {
                            store.renameFolder(folder.id, to: name)
                        }
                    }
                    Button("Eliminar carpeta (los pines se conservan)", role: .destructive) {
                        store.deleteFolder(folder.id)
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
                .menuStyle(.borderlessButton)
                .fixedSize()
            }
        }
    }

    private func row(_ item: ClipItem, shortcut: Int?) -> some View {
        HStack {
            Text(shortcut.map { "⌘\($0)" } ?? "")
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 28, alignment: .leading)

            Button {
                onPick(item.text)
            } label: {
                Text(item.preview)
                    .lineLimit(2)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Button {
                store.togglePin(item.id)
            } label: {
                Image(systemName: item.pinned ? "pin.fill" : "pin")
            }
            .buttonStyle(.borderless)
            .help(item.pinned ? "Desanclar" : "Anclar")

            Menu {
                if item.pinned {
                    Button("Subir") { store.movePin(item.id, up: true) }
                    Button("Bajar") { store.movePin(item.id, up: false) }
                    Menu("Mover a carpeta") {
                        Button("Sin carpeta") { store.setFolder(item.id, nil) }
                        ForEach(store.folders) { folder in
                            Button(folder.name) { store.setFolder(item.id, folder.id) }
                        }
                        Divider()
                        Button("Nueva carpeta…") {
                            if let name = Prompt.text(title: "Nueva carpeta", message: "Nombre de la carpeta:") {
                                let id = store.addFolder(name)
                                store.setFolder(item.id, id)
                            }
                        }
                    }
                    Divider()
                }
                Button("Eliminar", role: .destructive) {
                    // Los pines piden confirmación: son los datos que quieres conservar.
                    if !item.pinned || Prompt.confirm(
                        title: "¿Eliminar este pin?",
                        message: PopupMenu.label(item.text),
                        action: "Eliminar"
                    ) {
                        store.delete(item.id)
                    }
                }
            } label: {
                Image(systemName: "ellipsis.circle")
            }
            .menuStyle(.borderlessButton)
            .fixedSize()
        }
        .tag(item.id)
    }
}

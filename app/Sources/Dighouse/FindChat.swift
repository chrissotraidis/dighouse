import SwiftUI

/// Search every Dighouse chat by its words, and bring back archived ones.
struct FindChatSheet: View {
    @EnvironmentObject var app: AppState
    @EnvironmentObject var chat: ChatModel
    @EnvironmentObject var store: ProjectStore
    @Environment(\.dismiss) private var dismiss
    @State private var term = ""
    @State private var results: [ChatModel.Found] = []
    @State private var archive: [ChatModel.Found] = []
    @State private var searching = false
    @State private var showArchive = false
    @State private var pending: Task<Void, Never>?
    @FocusState private var focused: Bool

    private var folders: Set<String> { Set(store.projects.map(\.path) + [Paths.general.path]) }

    var body: some View {
        // The same frame as the ⌘K palette: a bare field on top, the list, and a foot with the hint and Close.
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass").foregroundStyle(Theme.faint)
                TextField("Find a chat by what was said in it", text: $term).textFieldStyle(.plain).font(.system(size: 16 * Theme.scale))
                    .focused($focused)
                if searching { DigIndicator() }
            }
            .padding(.horizontal, 16).frame(height: 52)
            Hairline()
            ScrollView {
                VStack(alignment: .leading, spacing: 2) {
                    let rows = showArchive ? archive : results
                    if rows.isEmpty {
                        if !searching || term.isEmpty || showArchive {
                            EmptyLine(icon: "dig.sieve", text: showArchive ? "No archived chats." : term.isEmpty ? "Type to search chats in every project." : "No chat says that.")
                                .padding(.horizontal, 10)
                        }
                    }
                    ForEach(rows) { row in
                        HStack(alignment: .top, spacing: 10) {
                            Button { open(row) } label: {
                                VStack(alignment: .leading, spacing: 3) {
                                    HStack(spacing: 6) {
                                        Text(row.thread.title).font(.system(size: 13.5 * Theme.scale, weight: .medium)).lineLimit(1)
                                        Text(place(row)).font(.system(size: 12 * Theme.scale)).foregroundStyle(Theme.faint).lineLimit(1)
                                    }
                                    if !row.snippet.isEmpty {
                                        Text(row.snippet).font(.system(size: 12.5 * Theme.scale)).foregroundStyle(Theme.dim).lineLimit(2)
                                    }
                                }
                                .frame(maxWidth: .infinity, alignment: .leading).contentShape(Rectangle())
                            }
                            .buttonStyle(.plain).disabled(showArchive)
                            if showArchive {
                                Button("Restore") {
                                    Task {
                                        if await chat.unarchive(row) { archive.removeAll { $0.id == row.id } }
                                    }
                                }
                                .buttonStyle(SecondaryButton())
                            }
                        }
                        .padding(.horizontal, 10).padding(.vertical, 8)
                        .background(RoundedRectangle(cornerRadius: 8).fill(Theme.ink.opacity(0.03)))
                    }
                }
                .padding(6)
            }
            Hairline()
            HStack(spacing: 8) {
                Text(showArchive ? "Archived chats, newest first" : "Chats in every project").font(.system(size: 11.5 * Theme.scale)).foregroundStyle(Theme.faint)
                Spacer()
                Button(showArchive ? "Back to search" : "Archived chats") {
                    showArchive.toggle()
                    if showArchive { Task { archive = await chat.archived(folders: folders) } }
                }
                .buttonStyle(SecondaryButton())
                Button("Close") { dismiss() }.buttonStyle(SecondaryButton()).keyboardShortcut(.cancelAction)
            }
            .padding(.horizontal, 14).padding(.vertical, 8)
        }
        .frame(width: min(620, app.windowSize.width - 40), height: min(440, app.windowSize.height - 40))
        .background(Theme.bg).foregroundStyle(Theme.text)
        .onAppear { focused = true }
        .onChange(of: term) { _, value in
            pending?.cancel()
            showArchive = false
            pending = Task {
                try? await Task.sleep(nanoseconds: 300_000_000)
                guard !Task.isCancelled else { return }
                searching = true
                let found = await chat.search(value, folders: folders)
                guard !Task.isCancelled else { return }
                results = found
                searching = false
            }
        }
    }

    private func place(_ row: ChatModel.Found) -> String {
        store.projects.first { $0.path == row.folder }?.name ?? "General chat"
    }

    private func open(_ row: ChatModel.Found) {
        dismiss()
        app.openChat(row.thread, in: store.projects.first { $0.path == row.folder })
    }
}


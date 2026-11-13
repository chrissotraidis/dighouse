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
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass").foregroundStyle(Theme.faint)
                TextField("Find a chat by what was said in it", text: $term).textFieldStyle(.plain).font(.system(size: 15))
                    .focused($focused)
                if searching { ProgressView().controlSize(.small) }
            }
            .padding(.horizontal, 12).frame(height: 40)
            .background(RoundedRectangle(cornerRadius: 10).fill(Theme.ink.opacity(0.06)))

            HStack {
                Button(showArchive ? "Search" : "Archived chats") {
                    showArchive.toggle()
                    if showArchive { Task { archive = await chat.archived(folders: folders) } }
                }
                .buttonStyle(SecondaryButton())
                Spacer()
                Button("Close") { dismiss() }.buttonStyle(SecondaryButton()).keyboardShortcut(.cancelAction)
            }

            ScrollView {
                VStack(alignment: .leading, spacing: 2) {
                    let rows = showArchive ? archive : results
                    if rows.isEmpty {
                        Text(showArchive ? "No archived chats." : term.isEmpty ? "Type to search chats in every project." : searching ? "" : "No chat says that.")
                            .font(.system(size: 13)).foregroundStyle(Theme.faint).padding(.vertical, 20)
                    }
                    ForEach(rows) { row in
                        HStack(alignment: .top, spacing: 10) {
                            Button { open(row) } label: {
                                VStack(alignment: .leading, spacing: 3) {
                                    HStack(spacing: 6) {
                                        Text(row.thread.title).font(.system(size: 13.5, weight: .medium)).lineLimit(1)
                                        Text(place(row)).font(.system(size: 12)).foregroundStyle(Theme.faint).lineLimit(1)
                                    }
                                    if !row.snippet.isEmpty {
                                        Text(row.snippet).font(.system(size: 12.5)).foregroundStyle(Theme.dim).lineLimit(2)
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
            }
            .frame(minHeight: 280)
        }
        .padding(18).frame(width: 600, height: 480)
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


import SwiftUI

/// ⌘K: jump to any project, chat, candidate, page or command by typing a few letters.
struct CommandPalette: View {
    @EnvironmentObject var app: AppState
    @EnvironmentObject var store: ProjectStore
    @EnvironmentObject var chat: ChatModel
    @Environment(\.dismiss) private var dismiss
    @State private var term = ""
    @State private var picked = 0
    /// Every find in every project, with the lowercased words each is found by: a sweep leaves thousands, and lowercasing
    /// 27,000 finds on each key press stalled the window for up to half a second.
    @State private var records: [Find] = []
    /// What the typed words match, worked out when the words change rather than on every redraw.
    @State private var rows: [Item] = []
    @FocusState private var focused: Bool

    /// A find as plain words, made in the background. Rows are made only for the few that match: a row for each of
    /// 27,000 finds took a third of a second to make on opening and as long to free on closing.
    struct Find: Sendable {
        let path: String, id: String, title: String, detail: String, hay: String
    }

    struct Item: Identifiable {
        enum Kind: String { case page = "Go to", project = "Project", candidate = "Candidate", chat = "Chat", command = "Command" }
        let id: String
        let kind: Kind
        let title: String
        var detail = ""
        var icon: String
        var blocked: String? = nil
        let action: @MainActor () -> Void
    }

    private var pages: [Item] {
        var out: [Item] = [
            Item(id: "home", kind: .page, title: "Home", icon: "house") { app.goHome() },
            Item(id: "newchat", kind: .page, title: "New chat", detail: "⌘N", icon: "square.and.pencil") { app.newChat() },
            Item(id: "newproject", kind: .page, title: "New project", detail: "⇧⌘N", icon: "plus.square") { app.startProject() },
            Item(id: "toolbox", kind: .page, title: "Toolbox", detail: "⌘T", icon: "wrench.and.screwdriver") { app.show(.toolbox) },
            Item(id: "find", kind: .page, title: "Find a chat by its words", detail: "⇧⌘F", icon: "magnifyingglass") { app.findingChat = true },
            Item(id: "tutorial", kind: .page, title: "First project tutorial", detail: "Six steps at Serpent Mound", icon: "dig.trowel") { app.startTutorial() },
        ]
        out += SettingsSection.allCases.map { section in
            Item(id: "settings-" + section.rawValue, kind: .page, title: "Settings: " + section.rawValue, icon: "gearshape") {
                app.settingsSection = section; app.show(.settings)
            }
        }
        if store.current != nil {
            out += WorkTab.allCases.map { tab in
                Item(id: "tab-" + tab.rawValue, kind: .page, title: "\(store.current?.name ?? ""): \(tab.rawValue)", icon: "rectangle.split.2x1") {
                    app.tab = tab; app.route = .chat; if app.layout == .chat { app.layout = .split }
                }
            }
        }
        return out
    }

    private var projects: [Item] {
        store.projects.map { p in Item(id: "p-" + p.path, kind: .project, title: p.name, icon: "folder") { app.open(p) } }
    }

    private var chats: [Item] {
        chat.allChats.map { folder, thread in
            let project = store.projects.first { $0.path == folder }
            return Item(id: "c-" + thread.id, kind: .chat, title: thread.label, detail: project?.name ?? "General chat", icon: "bubble.left") {
                app.openChat(thread, in: project)
            }
        }
    }

    private var commands: [Item] {
        SlashCommands.all.map { c in
            Item(id: "s-" + c.id, kind: .command, title: c.name, detail: c.summary, icon: "chevron.right.2", blocked: app.unavailable(c)) {
                if c.workflow != nil || ["review", "status", "help", "goal"].contains(c.id) { app.route = .chat }
                app.perform(c, argument: "")
            }
        }
    }

    nonisolated private static func hay(_ title: String, _ detail: String, _ kind: Item.Kind) -> String {
        (title + " " + detail + " " + kind.rawValue).lowercased()
    }

    private func match() -> [Item] {
        let words = term.lowercased().split(separator: " ").map(String.init)
        guard !words.isEmpty else { return Array((pages.prefix(5) + projects.prefix(6) + chats.prefix(6)).prefix(20)) }
        let order: [Item.Kind: Int] = [.project: 0, .candidate: 1, .page: 2, .chat: 3, .command: 2]
        func score(_ title: String, _ hay: String, _ kind: Item.Kind, blocked: Bool) -> Int? {
            guard words.allSatisfy({ hay.contains($0) }) else { return nil }
            let title = title.lowercased()
            return (title.hasPrefix(words[0]) ? 0 : title.contains(words[0]) ? 1 : 2) * 100 + (blocked ? 50 : 0) + (order[kind] ?? 4)
        }
        // In the order pages, projects, finds, chats, commands, which breaks ties.
        let before = pages + projects, after = chats + commands
        var ranked: [(item: Item, score: Int, n: Int)] = []
        for (n, it) in before.enumerated() {
            if let sc = score(it.title, Self.hay(it.title, it.detail, it.kind), it.kind, blocked: it.blocked != nil) { ranked.append((it, sc, n)) }
        }
        let finds = records.indices.compactMap { i in score(records[i].title, records[i].hay, .candidate, blocked: false).map { ($0, i) } }
        for (sc, i) in finds.sorted(by: <).prefix(40) { ranked.append((item(records[i]), sc, before.count + i)) }
        for (n, it) in after.enumerated() {
            if let sc = score(it.title, Self.hay(it.title, it.detail, it.kind), it.kind, blocked: it.blocked != nil) {
                ranked.append((it, sc, before.count + records.count + n))
            }
        }
        return ranked.sorted { ($0.score, $0.n) < ($1.score, $1.n) }.prefix(40).map(\.item)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass").foregroundStyle(Theme.faint)
                TextField("Jump to a project, chat, find, page or command", text: $term)
                    .textFieldStyle(.plain).font(.system(size: 16 * Theme.scale)).focused($focused)
                    .onSubmit { run(rows) }
                    .onKeyPress(.downArrow) { picked = min(picked + 1, max(rows.count - 1, 0)); return .handled }
                    .onKeyPress(.upArrow) { picked = max(picked - 1, 0); return .handled }
            }
            .padding(.horizontal, 16).frame(height: 52)
            Hairline()
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 1) {
                        if rows.isEmpty {
                            EmptyLine(icon: "dig.sieve", text: "Nothing matches. Try a project name, a find such as C-001, or a command such as look.")
                                .padding(.horizontal, 10)
                        }
                        ForEach(Array(rows.enumerated()), id: \.element.id) { index, item in
                            Button { picked = index; run(rows) } label: { row(item, selected: index == picked) }
                                .buttonStyle(.plain).id(index)
                        }
                    }
                    .padding(6)
                }
                .onChange(of: picked) { _, value in proxy.scrollTo(value) }
            }
            Hairline()
            HStack(spacing: 14) {
                Text("↑↓ to move · Return to open · Esc to close").font(.system(size: 11.5 * Theme.scale)).foregroundStyle(Theme.faint)
                Spacer()
                Button("Close") { dismiss() }.buttonStyle(SecondaryButton()).keyboardShortcut(.cancelAction)
            }
            .padding(.horizontal, 14).padding(.vertical, 8)
        }
        .frame(width: min(620, max(420, app.windowSize.width - 40)), height: min(440, max(300, app.windowSize.height - 40)))
        .background(Theme.bg).foregroundStyle(Theme.text)
        .closesOnOutsideClick { dismiss() }
        .onAppear { focused = true; rows = match() }
        .onChange(of: term) { _, _ in picked = 0; rows = match() }
        .task {
            records = await Self.candidates(in: store.projects, app: app)
            if !term.isEmpty { rows = match() }
        }
    }

    private func row(_ item: Item, selected: Bool) -> some View {
        HStack(spacing: 10) {
            Glyph(name: item.icon, size: 12.5 * Theme.scale).foregroundStyle(Theme.tan).frame(width: 20)
            Text(item.title).font(.system(size: 13.5 * Theme.scale, weight: .medium)).lineLimit(1)
            Text(item.blocked ?? item.detail).font(.system(size: 12 * Theme.scale)).foregroundStyle(item.blocked == nil ? Theme.dim : Theme.amber).lineLimit(1)
            Spacer(minLength: 8)
            Text(item.kind.rawValue).font(.system(size: 11 * Theme.scale)).foregroundStyle(Theme.faint)
        }
        .padding(.horizontal, 10).frame(height: 34)
        .background(RoundedRectangle(cornerRadius: 8).fill(selected ? Theme.ink.opacity(0.08) : .clear))
        .opacity(item.blocked == nil ? 1 : 0.6)
        .contentShape(Rectangle())
    }

    private func run(_ rows: [Item]) {
        guard rows.indices.contains(picked) else { return }
        let item = rows[picked]
        guard item.blocked == nil else { return }
        dismiss()
        item.action()
    }

    /// Every candidate in every project, read from the records' front matter.
    /// The row for a find, made when it matches.
    private func item(_ find: Find) -> Item {
        Item(id: "r-\(find.path)-\(find.id)", kind: .candidate, title: find.title, detail: find.detail, icon: "mappin") { [app] in
            guard let project = app.store.projects.first(where: { $0.path == find.path }) else { return }
            if app.store.current?.path != project.path { app.open(project) }
            app.showRecords(find.id)
        }
    }

    private static func candidates(in projects: [ProjectRef], app: AppState) async -> [Find] {
        await Task.detached {
            var out: [Find] = []
            for p in projects {
                let dir = p.path + "/candidates"
                for file in ((try? FileManager.default.contentsOfDirectory(atPath: dir)) ?? []).sorted() where file.hasSuffix(".md") {
                    guard let text = try? String(contentsOfFile: dir + "/" + file, encoding: .utf8) else { continue }
                    let head = text.components(separatedBy: "---\n").dropFirst().first ?? ""
                    var meta: [String: String] = [:]
                    for line in head.split(separator: "\n") {
                        guard let split = line.range(of: ": ") else { continue }
                        let key = String(line[..<split.lowerBound]), raw = String(line[split.upperBound...])
                        guard ["id", "name", "status"].contains(key) else { continue }
                        meta[key] = (try? JSONSerialization.jsonObject(with: Data(raw.utf8), options: .fragmentsAllowed)) as? String ?? raw
                    }
                    if let id = meta["id"] {
                        let status = meta["status"] ?? ""
                        let title = "\(id) \(meta["name"] ?? "")", detail = "\(p.name) · \(Candidate.labels[status] ?? status)"
                        out.append(Find(path: p.path, id: id, title: title, detail: detail, hay: hay(title, detail, .candidate)))
                    }
                }
            }
            return out
        }.value
    }
}


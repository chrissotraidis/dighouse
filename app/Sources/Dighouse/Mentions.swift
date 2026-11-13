import Foundation

/// Something in the project a message can point at with "@": a candidate, a tile, a source, a file or another project.
struct Mention: Identifiable, Hashable {
    enum Kind: String { case candidate = "Candidate", tile = "Tile", source = "Source", file = "File", project = "Project" }
    let kind: Kind
    /// What follows "@" in the message.
    let label: String
    /// A second line in the list, to tell similar items apart.
    let detail: String
    /// What the agent is told the mention refers to.
    let reference: String
    var id: String { kind.rawValue + ":" + label }

    var icon: String {
        switch kind {
        case .candidate: return "mappin.circle"
        case .tile: return "square.grid.3x3"
        case .source: return "book"
        case .file: return "doc.text"
        case .project: return "folder"
        }
    }
}

enum Mentions {
    /// The line that starts the references added to a sent message. Everything after it is for the agent, not shown in the chat.
    static let marker = "References for the @ mentions above:"

    /// The text of a message as the person wrote it, without the references added for the agent.
    static func visible(_ text: String) -> String {
        guard let range = text.range(of: "\n\n" + marker) else { return text }
        return String(text[..<range.lowerBound])
    }

    /// The word being typed after "@", or nil when the cursor is not in a mention.
    static func query(_ draft: String) -> String? {
        guard !draft.hasPrefix("/") else { return nil }
        let word = draft.split(separator: " ", omittingEmptySubsequences: false).last.map(String.init) ?? ""
        guard word.hasPrefix("@"), !word.contains("\n") else { return nil }
        return String(word.dropFirst()).lowercased()
    }

    /// The draft with the mention being typed replaced by the one picked.
    static func insert(_ m: Mention, into draft: String) -> String {
        var words = draft.split(separator: " ", omittingEmptySubsequences: false).map(String.init)
        if !words.isEmpty { words.removeLast() }
        words.append("@" + m.label)
        return words.joined(separator: " ") + " "
    }

    /// The message to send: the draft, then what each mention still in it refers to.
    static func expand(_ draft: String, with picked: [Mention]) -> String {
        let used = picked.filter { draft.contains("@" + $0.label) }
        guard !used.isEmpty else { return draft }
        return draft + "\n\n" + marker + "\n" + used.map { "- @\($0.label): \($0.reference)" }.joined(separator: "\n")
    }

    /// Everything the open project offers, and the other projects.
    @MainActor
    static func pool(store: ProjectStore) -> [Mention] {
        var out: [Mention] = []
        if let root = store.current?.path {
            for c in store.candidates {
                out.append(Mention(kind: .candidate, label: c.id, detail: c.name,
                                   reference: "candidate \(c.id) (\(c.name)); its record is candidates/\(c.id).md in this project"))
            }
            let shorts = Dictionary(grouping: store.tiles, by: \.short)
            for t in store.tiles {
                let label = (shorts[t.short]?.count ?? 0) > 1 ? t.id : t.short
                out.append(Mention(kind: .tile, label: label, detail: t.verdict.map { "Verdict: \($0)" } ?? "Not screened yet",
                                   reference: "tile \(t.id) of terrain \(t.terrain)"))
            }
            var seen = Set<String>()
            for c in store.candidates {
                for s in c.sources where seen.insert(s.title).inserted {
                    let label = String(s.title.prefix(48)).trimmingCharacters(in: .whitespaces)
                    out.append(Mention(kind: .source, label: label, detail: s.status.replacingOccurrences(of: "_", with: " ").capitalized,
                                       reference: "the source \"\(s.title)\" (logged as \(s.status))" + (s.link.isEmpty ? "" : ", \(s.link)")))
                }
            }
            for path in files(in: root) {
                out.append(Mention(kind: .file, label: path, detail: "In this project", reference: "the file \(root)/\(path)"))
            }
        }
        for p in store.projects where p != store.current {
            out.append(Mention(kind: .project, label: p.name.replacingOccurrences(of: " ", with: "-"), detail: "Project",
                               reference: "the Dighouse project \"\(p.name)\", a folder at \(p.path)"))
        }
        return out
    }

    /// The project's own files. Downloaded data and the private folder are left out: one is huge, the other holds locations.
    static func files(in root: String) -> [String] {
        let fm = FileManager.default
        guard let walker = fm.enumerator(atPath: root) else { return [] }
        var out: [String] = []
        while let path = walker.nextObject() as? String {
            let top = path.split(separator: "/").first.map(String.init) ?? path
            if ["data", "private", ".git"].contains(top) || path.hasPrefix(".") { walker.skipDescendants(); continue }
            var isDir: ObjCBool = false
            if fm.fileExists(atPath: root + "/" + path, isDirectory: &isDir), !isDir.boolValue { out.append(path) }
            if out.count >= 400 { break }
        }
        return out.sorted()
    }

    /// The items that fit what has been typed after "@", best first.
    static func matches(_ query: String, in pool: [Mention]) -> [Mention] {
        guard !query.isEmpty else { return Array(pool.prefix(12)) }
        let starts = pool.filter { $0.label.lowercased().hasPrefix(query) }
        let contains = pool.filter { m in !starts.contains(m) && (m.label.lowercased().contains(query) || m.detail.lowercased().contains(query)) }
        return Array((starts + contains).prefix(12))
    }
}


import AppKit
import AVFoundation
import Foundation

struct ChatThread: Identifiable, Hashable, Codable {
    let id: String
    var title: String
    /// Whether the chat has a name of its own, rather than the start of its first message.
    var named: Bool? = nil
}

struct Approval {
    let id: Any
    let message: String
}

enum Media {
    /// Sample a few frames from a video so a model that reads images can see it.
    static func frames(from path: String, count: Int = 6) async -> [String] {
        let asset = AVURLAsset(url: URL(fileURLWithPath: path))
        guard let duration = try? await asset.load(.duration), duration.seconds > 0 else { return [] }
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = CGSize(width: 1280, height: 1280)
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("dighouse-frames-\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        var out: [String] = []
        for i in 0..<count {
            let time = CMTime(seconds: duration.seconds * (Double(i) + 0.5) / Double(count), preferredTimescale: 600)
            guard let frame = try? await generator.image(at: time).image,
                  let data = NSBitmapImageRep(cgImage: frame).representation(using: .jpeg, properties: [.compressionFactor: 0.8])
            else { continue }
            let file = folder.appendingPathComponent("frame-\(i + 1).jpg")
            if (try? data.write(to: file)) != nil { out.append(file.path) }
        }
        return out
    }
}

/// The conversations of the open scope (a project, or the general chat) and the live state of the one on screen.
@MainActor
final class ChatModel: ObservableObject {
    @Published var threads: [ChatThread] = []
    @Published var generalThreads: [ChatThread] = []
    @Published var active: String?
    @Published var items: [ChatItem] = []
    @Published var running = false
    @Published var preparing = false
    @Published var loading = false
    @Published var approval: Approval?
    @Published var draft = ""
    @Published var attachments: [Attachment] = []
    /// The chats with a run in progress, and the turn each is on.
    @Published private(set) var live: [String: String] = [:]
    /// How much of each chat's context the model has used, from the engine's reports.
    @Published private(set) var usage: [String: (used: Int, window: Int?)] = [:]
    /// Chats whose goal is still being worked on.
    @Published private(set) var goals: Set<String> = []
    /// The last Dighouse tool each chat's agent called, so a run can say which stage it is on.
    @Published private(set) var lastTool: [String: String] = [:]
    /// The share of the account's usage left, as the engine last reported it.
    @Published var usageLeft: Int?

    var engine: Engine?
    var instructions: () -> String = { "" }
    var model: () -> ModelInfo? = { nil }
    var modelID: () -> String? = { nil }
    var effort: () -> String? = { nil }
    /// Called for a chat that has no name yet, with the text it began with.
    var onUntitled: ((String, String) -> Void)?
    var onToolFinished: ((String, JSON) -> Void)?
    /// Called when a run in a project ends, with the project's folder and whether the person stopped it.
    var onRunEnded: ((String, String, Bool) -> Void)?
    /// Called when a chat's goal stops being worked on, with the chat and how it ended: complete, paused, blocked,
    /// usageLimited or budgetLimited.
    var onGoalEnded: ((String, String) -> Void)?

    private(set) var project: String?
    private var turn: String?
    private var resumed: Set<String> = []
    /// Chats started since launch. The engine can take a while to list a new chat, so these are kept until it does.
    private var startedHere: Set<String> = []

    var scope: String { project ?? Paths.general.path }
    var title: String { (threads + generalThreads).first { $0.id == active }?.title ?? "New chat" }

    /// The chats of each folder, kept between launches. The engine needs several seconds to list one folder's chats
    /// when there are thousands of Codex sessions on the Mac, so the lists show from here and are refreshed behind.
    private var known: [String: [ChatThread]] = UserDefaults.standard.data(forKey: "chatLists")
        .flatMap { try? JSONDecoder().decode([String: [ChatThread]].self, from: $0) } ?? [:]

    /// Every chat Dighouse has listed, with its folder, for the ⌘K palette.
    var allChats: [(String, ChatThread)] {
        var lists = known
        lists[Paths.general.path] = generalThreads
        if let project { lists[project] = threads }
        return lists.sorted { $0.key < $1.key }.flatMap { folder, list in list.map { (folder, $0) } }
    }

    func open(project path: String?) async {
        project = path
        newChat()
        generalThreads = known[Paths.general.path] ?? []
        threads = path.flatMap { known[$0] } ?? []
        Task { @MainActor in await refreshThreads() }
    }

    func refreshThreads() async {
        guard let engine, engine.ready else { return }
        let scope = project
        async let general = list(Paths.general.path)
        async let own = list(scope)
        let (fresh, mine) = await (general, own)
        // A chat that was just started may not be in the engine's list yet, so keep it.
        if let fresh { generalThreads = keepingNew(fresh, from: generalThreads) }
        if let mine, let scope {
            // The person may have moved on while the engine was listing; the answer is still worth keeping.
            if scope == project { threads = keepingNew(mine, from: threads) } else { known[scope] = keepingNew(mine, from: known[scope] ?? []) }
        }
        remember()
    }

    private func remember() {
        known[Paths.general.path] = generalThreads
        if let project { known[project] = threads }
        UserDefaults.standard.set(try? JSONEncoder().encode(known), forKey: "chatLists")
    }

    private func keepingNew(_ fresh: [ChatThread], from old: [ChatThread]) -> [ChatThread] {
        let missing = old.filter { t in (t.id == active || startedHere.contains(t.id)) && !fresh.contains { $0.id == t.id } }
        return missing + fresh
    }

    /// The chats stored for a folder, or nil when there is no folder or the engine did not answer.
    private func list(_ cwd: String?) async -> [ChatThread]? {
        guard let cwd, let listed = try? await engine?.request("thread/list", ["cwd": cwd, "limit": 40]) else { return nil }
        return (listed["data"] as? [JSON] ?? []).compactMap { t in
            guard let id = t["id"] as? String else { return nil }
            let name = (t["name"] as? String) ?? ""
            let title = name.isEmpty ? (t["preview"] as? String) ?? "" : name
            let thread = ChatThread(id: id, title: title.isEmpty ? "New chat" : String(title.prefix(80)), named: !name.isEmpty)
            if name.isEmpty, !title.isEmpty { onUntitled?(id, title) }
            return thread
        }
    }

    /// Give a chat a name by its id, wherever it is listed.
    func setTitle(_ id: String, _ name: String) async {
        guard let engine, !name.isEmpty else { return }
        _ = try? await engine.request("thread/name/set", ["threadId": id, "name": name])
        if let i = threads.firstIndex(where: { $0.id == id }) { threads[i].title = name; threads[i].named = true }
        if let i = generalThreads.firstIndex(where: { $0.id == id }) { generalThreads[i].title = name; generalThreads[i].named = true }
        remember()
    }

    func newChat() {
        active = nil
        items = []
        running = false
        loading = false
        attachments = []
    }

    func select(_ thread: ChatThread) async {
        guard let engine else { return }
        active = thread.id
        items = []
        running = live[thread.id] != nil
        turn = live[thread.id]
        loading = true
        defer { if active == thread.id { loading = false } }
        do {
            let turns = try await readTurns(thread.id, engine)
            guard active == thread.id else { return }
            items = Self.items(of: turns) { self.item(from: $0, finished: true) }
            // A goal starts its turns without a message from the person, so show it at the top.
            if let goal = (try? await engine.request("thread/goal/get", ["threadId": thread.id]))?["goal"] as? JSON,
               let objective = goal["objective"] as? String, active == thread.id {
                items.insert(ChatItem(id: "goal-" + thread.id, kind: .note, text: Self.goalNote(objective)), at: 0)
                if goal["status"] as? String == "active" { goals.insert(thread.id) }
            }
            loading = false
        } catch {
            items = [problem(error.localizedDescription)]
            return
        }
        do {
            try await resume(thread.id)
        } catch where error.localizedDescription.contains("active writer") {
            note("This chat is open in another app, such as Codex, so it can be read here but not continued. Close it there, then open it again here.")
        } catch {
            items.append(problem(error.localizedDescription))
        }
    }

    /// Older chats come back whole from `thread/read`. Newer ones are stored page by page,
    /// and the engine refuses to return their turns that way, so read those a page at a time.
    private func readTurns(_ id: String, _ engine: Engine) async throws -> [JSON] {
        do {
            let read = try await engine.request("thread/read", ["threadId": id, "includeTurns": true])
            return (read["thread"] as? JSON)?["turns"] as? [JSON] ?? []
        } catch where error.localizedDescription.contains("paginated") {
            var turns: [JSON] = []
            var cursor: String?
            repeat {
                var params: JSON = ["threadId": id, "itemsView": "full", "sortDirection": "asc", "limit": 100]
                if let cursor { params["cursor"] = cursor }
                let page = try await engine.request("thread/turns/list", params)
                turns += page["data"] as? [JSON] ?? []
                cursor = page["nextCursor"] as? String
            } while cursor != nil
            return turns
        }
    }

    /// The engine has to load a stored chat before it can take another message.
    private func resume(_ id: String) async throws {
        guard let engine, !resumed.contains(id) else { return }
        _ = try await engine.request("thread/resume", threadSettings(["threadId": id]))
        resumed.insert(id)
    }

    func rename(_ thread: ChatThread, to name: String) async {
        let name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let engine, !name.isEmpty else { return }
        _ = try? await engine.request("thread/name/set", ["threadId": thread.id, "name": name])
        if let i = threads.firstIndex(of: thread) { threads[i].title = name }
        if let i = generalThreads.firstIndex(of: thread) { generalThreads[i].title = name }
        remember()
    }

    /// A line from Dighouse itself in the chat, such as the command list. It is not sent to the model.
    func note(_ text: String) {
        items.append(ChatItem(id: UUID().uuidString, kind: .note, text: text))
    }

    /// The usage left in the tighter of the account's two windows.
    static func left(_ limits: JSON) -> Int? {
        let used = ["primary", "secondary"].compactMap { (limits[$0] as? JSON)?["usedPercent"] as? Int }
        return used.max().map { max(0, 100 - $0) }
    }

    /// Every item of the turns read from the engine, each marked with its turn.
    static func items(of turns: [JSON], _ make: (JSON) -> ChatItem?) -> [ChatItem] {
        turns.flatMap { turn -> [ChatItem] in
            let id = turn["id"] as? String
            return (turn["items"] as? [JSON] ?? []).compactMap { raw in
                var item = make(raw)
                item?.turn = id
                return item
            }
        }
    }

    /// Copy the open chat into a new one and open it, whole or up to and including one turn.
    func fork(through turn: String? = nil) async {
        guard let engine, let active else { return }
        do {
            var params: JSON = ["threadId": active]
            if let turn { params["lastTurnId"] = turn }
            let forked = try await engine.request("thread/fork", threadSettings(params))
            guard let id = (forked["thread"] as? JSON)?["id"] as? String else { throw EngineError(message: "No copy was made.") }
            let title = "Copy of " + ((threads + generalThreads).first { $0.id == active }?.title ?? "chat")
            let copy = ChatThread(id: id, title: String(title.prefix(80)), named: true)
            startedHere.insert(id)
            resumed.insert(id)
            if project == nil { generalThreads.insert(copy, at: 0) } else { threads.insert(copy, at: 0) }
            remember()
            _ = try? await engine.request("thread/name/set", ["threadId": id, "name": copy.title])
            await select(copy)
            note(turn == nil ? "This is a copy of the chat. What you do here leaves the original as it was."
                             : "This is a copy of the chat up to that message. What you do here leaves the original as it was.")
        } catch {
            note("Could not copy the chat: \(error.localizedDescription)")
        }
    }

    /// Take back the last message and send it again, edited or as it was.
    /// The failure the chat ended on, if the last thing in it is one.
    var lastProblem: ChatItem? {
        guard !running, let last = items.last, last.kind == .step, last.state == .failed, last.icon == "exclamationmark.triangle" else { return nil }
        return last
    }

    /// Send the last message again after a failure. When there is no answer to take back, the failure is cleared and the message sent again.
    func retry() async {
        guard let question = items.last(where: { $0.kind == .user }) else { return }
        let text = question.result ?? question.text
        if await undo() == nil {
            if let problem = lastProblem { items.removeAll { $0.id == problem.id } }
            items.removeAll { $0.id == question.id }
        }
        await send(text)
    }

    func resend(_ text: String) async {
        guard await undo() != nil else { return }
        await send(text)
    }

    /// Take back the last message and its answer. Returns the message, so it can be edited and sent again.
    func undo() async -> String? {
        guard let engine, let active, !running else { return nil }
        let lastMessage = items.last { $0.kind == .user }
        let last = lastMessage.map { $0.result ?? $0.text }
        do {
            try await resume(active)
            // Roll back to just before the last message the person sent. Turns after it without a message of their own,
            // such as a summary made by /compact, go with it.
            let before = try await readTurns(active, engine)
            let mine = before.lastIndex { turn in (turn["items"] as? [JSON] ?? []).contains { $0["type"] as? String == "userMessage" } }
            let count = mine.map { before.count - $0 } ?? 1
            _ = try await engine.request("thread/rollback", ["threadId": active, "numTurns": max(1, count)])
            let turns = try await readTurns(active, engine)
            items = Self.items(of: turns) { self.item(from: $0, finished: true) }
            return last
        } catch {
            note("Could not take the message back: \(error.localizedDescription)")
            return nil
        }
    }

    /// Ask the engine to summarise the chat so far, so a long run has room to keep going.
    func compact() async {
        guard let engine, let active else { return }
        do {
            try await resume(active)
            _ = try await engine.request("thread/compact/start", ["threadId": active])
            note("Shortening this chat. The model keeps a summary of what came before and carries on from there.")
        } catch {
            note("Could not shorten the chat: \(error.localizedDescription)")
        }
    }

    /// Give the chat a goal. The engine keeps taking turns until the goal is met or it needs the person.
    /// A workflow sets its name as the title, so the chat and its note show the name rather than the instructions.
    func setGoal(_ objective: String, title: String? = nil) async {
        let objective = objective.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let engine, !objective.isEmpty else { return }
        let title = title.map(fresh)
        do {
            if active == nil {
                let started = try await engine.request("thread/start", threadSettings([:]))
                guard let id = (started["thread"] as? JSON)?["id"] as? String else { throw EngineError(message: "No chat was created.") }
                active = id
                resumed.insert(id)
                startedHere.insert(id)
                let new = ChatThread(id: id, title: String((title ?? objective).prefix(80)), named: title != nil)
                if project == nil { generalThreads.insert(new, at: 0) } else { threads.insert(new, at: 0) }
                remember()
                if let title { _ = try? await engine.request("thread/name/set", ["threadId": id, "name": title]) }
                else { onUntitled?(id, objective) }
            } else if let active {
                try await resume(active)
            }
            guard let active else { return }
            note(Self.goalNote(objective))
            running = true
            _ = try await engine.request("thread/goal/set", ["threadId": active, "objective": objective, "status": "active"])
        } catch {
            running = false
            note("Could not set the goal: \(error.localizedDescription)")
        }
    }

    static func goalNote(_ objective: String) -> String {
        let name = ToolGuide.workflow(sentAs: objective)?.title ?? objective
        return "**Goal:** \(name)\n\nThe agent keeps working, turn after turn, until this is done or it needs you. Stop ends it."
    }

    /// A workflow names its chat, so a second chat from the same workflow gets a number and the two can be told apart.
    private func fresh(_ title: String) -> String {
        let taken = Set((project == nil ? generalThreads : threads).map(\.title))
        guard taken.contains(title) else { return title }
        var n = 2
        while taken.contains("\(title) \(n)") { n += 1 }
        return "\(title) \(n)"
    }

    /// A chat found by search or in the archive, with the folder it belongs to.
    struct Found: Identifiable {
        let thread: ChatThread
        let folder: String
        let snippet: String
        var id: String { thread.id }
    }

    /// Every Dighouse chat with the file the engine keeps it in, listed once and kept for the next search.
    private var library: [(found: Found, path: String)] = []

    /// Dighouse's chats whose messages contain every word typed. The engine's own search reads every Codex chat on the Mac
    /// and took over a minute here, so this lists Dighouse's folders and reads only their chat files.
    func search(_ term: String, folders: Set<String>) async -> [Found] {
        let words = term.lowercased().split(separator: " ").map(String.init).filter { !$0.isEmpty }
        guard let engine, !words.isEmpty else { return [] }
        if library.isEmpty {
            library = await withTaskGroup(of: [(found: Found, path: String)].self) { group in
                for folder in folders {
                    group.addTask { @MainActor in
                        guard let listed = try? await engine.request("thread/list", ["cwd": folder, "limit": 100]) else { return [] }
                        return (listed["data"] as? [JSON] ?? []).compactMap { t in
                            guard let path = t["path"] as? String, let f = self.makeFound(t, snippet: "", folders: folders) else { return nil }
                            return (f, path)
                        }
                    }
                }
                var all: [(found: Found, path: String)] = []
                for await part in group { all += part }
                return all
            }
        }
        let shelf = library
        return await Task.detached {
            shelf.compactMap { entry -> Found? in
                guard let snippet = Self.match(words, in: entry.path) else { return nil }
                return Found(thread: entry.found.thread, folder: entry.found.folder, snippet: snippet)
            }
        }.value
    }

    /// The first message in a chat file that holds every word, cut down to a line around the first word, or nil.
    nonisolated static func match(_ words: [String], in path: String) -> String? {
        guard let text = try? String(contentsOfFile: path, encoding: .utf8) else { return nil }
        var messages: [String] = []
        // Chats are written in two formats: newer ones log user_message and agent_message events, older ones item_completed events.
        for line in text.split(separator: "\n")
        where line.contains("\"user_message\"") || line.contains("\"agent_message\"") || line.contains("\"UserMessage\"") || line.contains("\"AgentMessage\"") {
            guard let data = line.data(using: .utf8), let o = try? JSONSerialization.jsonObject(with: data) as? JSON,
                  let payload = o["payload"] as? JSON else { continue }
            if let message = payload["message"] as? String, ["user_message", "agent_message"].contains(payload["type"] as? String ?? "") {
                messages.append(Mentions.visible(message))
            } else if let item = payload["item"] as? JSON, ["UserMessage", "AgentMessage"].contains(item["type"] as? String ?? "") {
                let parts = (item["content"] as? [JSON] ?? []).compactMap { $0["text"] as? String }
                if !parts.isEmpty { messages.append(Mentions.visible(parts.joined(separator: "\n"))) }
            }
        }
        let all = messages.joined(separator: "\n").lowercased()
        guard words.allSatisfy({ all.contains($0) }) else { return nil }
        let hit = messages.first { m in words.contains { m.lowercased().contains($0) } } ?? ""
        guard let r = hit.lowercased().range(of: words[0]) else { return String(hit.prefix(160)) }
        let start = hit.index(r.lowerBound, offsetBy: -60, limitedBy: hit.startIndex) ?? hit.startIndex
        let end = hit.index(r.upperBound, offsetBy: 100, limitedBy: hit.endIndex) ?? hit.endIndex
        return (start > hit.startIndex ? "…" : "") + hit[start..<end].replacingOccurrences(of: "\n", with: " ") + (end < hit.endIndex ? "…" : "")
    }

    /// Dighouse's archived chats, newest first.
    func archived(folders: Set<String>) async -> [Found] {
        guard let engine else { return [] }
        var out: [Found] = []
        for folder in folders {
            guard let listed = try? await engine.request("thread/list", ["cwd": folder, "archived": true, "limit": 40]) else { continue }
            out += (listed["data"] as? [JSON] ?? []).compactMap { makeFound($0, snippet: "", folders: folders) }
        }
        return out
    }

    private func makeFound(_ t: JSON, snippet: String, folders: Set<String>) -> Found? {
        guard let id = t["id"] as? String, let cwd = t["cwd"] as? String, folders.contains(cwd) else { return nil }
        let name = (t["name"] as? String) ?? ""
        let title = name.isEmpty ? Mentions.visible((t["preview"] as? String) ?? "Chat") : name
        let shown = ToolGuide.workflow(sentAs: title)?.title ?? title
        return Found(thread: ChatThread(id: id, title: String(shown.prefix(80)), named: !name.isEmpty), folder: cwd,
                     snippet: snippet.trimmingCharacters(in: .whitespacesAndNewlines))
    }

    /// Bring an archived chat back to the sidebar.
    func unarchive(_ found: Found) async -> Bool {
        guard let engine, (try? await engine.request("thread/unarchive", ["threadId": found.thread.id])) != nil else { return false }
        if found.folder == scope {
            if project == nil { generalThreads.insert(found.thread, at: 0) } else { threads.insert(found.thread, at: 0) }
        } else {
            known[found.folder, default: []].insert(found.thread, at: 0)
        }
        remember()
        return true
    }

    func archive(_ thread: ChatThread) async {
        guard let engine else { return }
        _ = try? await engine.request("thread/archive", ["threadId": thread.id])
        threads.removeAll { $0.id == thread.id }
        generalThreads.removeAll { $0.id == thread.id }
        remember()
        if active == thread.id { newChat() }
    }

    func attach(_ path: String) {
        guard FileManager.default.fileExists(atPath: path), !attachments.contains(where: { $0.path == path }) else { return }
        attachments.append(Attachment(path: path))
    }

    /// Send a message. A title names the chat when this message starts one.
    func send(_ text: String, title: String? = nil) async {
        let text = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let engine, !text.isEmpty || !attachments.isEmpty else { return }
        let title = active == nil ? title.map(fresh) : title
        let sending = attachments
        attachments = []
        var shown = ChatItem(id: UUID().uuidString, kind: .user, text: Mentions.visible(text))
        if let flow = ToolGuide.workflow(sentAs: text) { shown.text = flow.title; shown.result = text }
        shown.images = sending.filter { $0.kind == .image }.map(\.path)
        shown.files = sending.filter { $0.kind != .image }.map(\.name)
        items.append(shown)

        var input: [JSON] = []
        var notes: [String] = []
        preparing = true
        for file in sending {
            switch file.kind {
            case .image:
                input.append(["type": "localImage", "path": file.path])
            case .audio:
                if model()?.hearsAudio == true { input.append(["type": "localAudio", "path": file.path]) }
                else { notes.append("Attached audio file, which this model cannot hear directly: \(file.path)") }
            case .video:
                let frames = await Media.frames(from: file.path)
                frames.forEach { input.append(["type": "localImage", "path": $0]) }
                notes.append(frames.isEmpty ? "Attached video file: \(file.path)"
                             : "The \(frames.count) images above are frames sampled evenly through the video \(file.name) (\(file.path)).")
            case .file:
                notes.append("Attached file: \(file.path)")
            }
        }
        preparing = false
        let full = ([text] + notes).filter { !$0.isEmpty }.joined(separator: "\n\n")
        if !full.isEmpty { input.append(["type": "text", "text": full]) }

        do {
            if let active { try await resume(active) }
            if running, let turn, let active {
                _ = try await engine.request("turn/steer", ["threadId": active, "expectedTurnId": turn, "input": input])
                return
            }
            if active == nil {
                let started = try await engine.request("thread/start", threadSettings([:]))
                guard let id = (started["thread"] as? JSON)?["id"] as? String else { throw EngineError(message: "No chat was created.") }
                active = id
                resumed.insert(id)
                startedHere.insert(id)
                let new = ChatThread(id: id, title: title ?? String((text.isEmpty ? sending.first?.name ?? "Chat" : text).prefix(80)), named: title != nil)
                if project == nil { generalThreads.insert(new, at: 0) } else { threads.insert(new, at: 0) }
                remember()
                if let title { _ = try? await engine.request("thread/name/set", ["threadId": id, "name": title]) }
                else if !text.isEmpty { onUntitled?(id, Mentions.visible(text)) }
            }
            running = true
            var params: JSON = ["threadId": active ?? "", "input": input]
            if let model = modelID() { params["model"] = model }
            if let effort = effort() { params["effort"] = effort }
            _ = try await engine.request("turn/start", params)
        } catch {
            running = false
            items.append(problem(error.localizedDescription))
        }
    }

    func stop() async {
        guard let engine, let active, let turn else { return }
        // A chat with a goal would start its next turn on its own, so pause the goal first.
        if goals.contains(active) { _ = try? await engine.request("thread/goal/set", ["threadId": active, "status": "paused"]) }
        _ = try? await engine.request("turn/interrupt", ["threadId": active, "turnId": turn])
    }

    /// Stop the run in one chat, whichever chat is on screen.
    func stop(chat thread: String) async {
        guard let engine, let turn = live[thread] else { return }
        if goals.contains(thread) { _ = try? await engine.request("thread/goal/set", ["threadId": thread, "status": "paused"]) }
        if !turn.isEmpty { _ = try? await engine.request("turn/interrupt", ["threadId": thread, "turnId": turn]) }
    }

    /// Stop every run, in whichever chat it is, such as a download started from another chat.
    func stopAll() async {
        guard let engine else { return }
        for (thread, turn) in live where !turn.isEmpty {
            if goals.contains(thread) { _ = try? await engine.request("thread/goal/set", ["threadId": thread, "status": "paused"]) }
            _ = try? await engine.request("turn/interrupt", ["threadId": thread, "turnId": turn])
        }
    }

    func answer(_ allow: Bool) {
        guard let approval else { return }
        engine?.respond(to: approval.id, result: ["action": allow ? "accept" : "decline", "content": [:] as JSON])
        self.approval = nil
    }

    private func threadSettings(_ extra: JSON) -> JSON {
        var settings: JSON = [
            "cwd": scope,
            "approvalPolicy": "never",
            "sandbox": "workspace-write",
            "serviceName": "Dighouse",
            "developerInstructions": instructions(),
        ]
        if let model = modelID() { settings["model"] = model }
        return settings.merging(extra) { _, new in new }
    }

    private func problem(_ text: String) -> ChatItem {
        ChatItem(id: UUID().uuidString, kind: .step, text: EngineError.plain(text), icon: "exclamationmark.triangle", state: .failed)
    }

    // MARK: what the engine tells us

    func handle(_ method: String, _ params: JSON) {
        if method == "account/rateLimits/updated", let limits = params["rateLimits"] as? JSON {
            usageLeft = Self.left(limits)
        }
        guard let thread = params["threadId"] as? String else { return }
        // Runs carry on while another chat is on screen, so keep track of every chat's turn.
        if method == "turn/started" { live[thread] = (params["turn"] as? JSON)?["id"] as? String ?? "" }
        if method == "turn/completed" {
            live[thread] = nil
            // The chat on screen belongs to the open project; a run elsewhere is found by the list its chat is in.
            let folder = thread == active ? project : known.first { $0.value.contains { $0.id == thread } }?.key
            if let folder, folder != Paths.general.path {
                onRunEnded?(thread, folder, ((params["turn"] as? JSON)?["status"] as? String) == "interrupted")
            }
        }
        if method == "item/started", let item = params["item"] as? JSON, item["type"] as? String == "mcpToolCall",
           item["server"] as? String == "dighouse", let tool = item["tool"] as? String {
            lastTool[thread] = tool
        }
        if method == "thread/tokenUsage/updated", let use = params["tokenUsage"] as? JSON {
            let used = (use["last"] as? JSON)?["totalTokens"] as? Int ?? (use["total"] as? JSON)?["totalTokens"] as? Int ?? 0
            usage[thread] = (used, use["modelContextWindow"] as? Int)
        }
        if method == "thread/goal/updated" {
            let status = (params["goal"] as? JSON)?["status"] as? String ?? ""
            if status == "active" { goals.insert(thread) } else {
                goals.remove(thread)
                onGoalEnded?(thread, status)
            }
        }
        if method == "thread/goal/cleared" { goals.remove(thread) }
        guard thread == active else { return }
        switch method {
        case "turn/started":
            running = true
            turn = (params["turn"] as? JSON)?["id"] as? String
        case "turn/plan/updated":
            var card = ChatItem(id: "plan-" + (params["turnId"] as? String ?? ""), kind: .plan, text: params["explanation"] as? String ?? "")
            card.plan = (params["plan"] as? [JSON] ?? []).map { PlanStep(text: $0["step"] as? String ?? "", status: $0["status"] as? String ?? "") }
            if let i = items.firstIndex(where: { $0.id == card.id }) { items[i] = card } else { items.append(card) }
        case "item/started":
            guard let raw = params["item"] as? JSON, raw["type"] as? String != "userMessage",
                  var new = item(from: raw, finished: false) else { return }
            new.turn = params["turnId"] as? String
            items.append(new)
        case "item/agentMessage/delta":
            guard let id = params["itemId"] as? String, let i = items.firstIndex(where: { $0.id == id }) else { return }
            items[i].text += params["delta"] as? String ?? ""
        case "item/completed":
            guard let raw = params["item"] as? JSON, raw["type"] as? String != "userMessage" else { return }
            guard var done = item(from: raw, finished: true) else {
                items.removeAll { $0.id == raw["id"] as? String }
                return
            }
            done.turn = params["turnId"] as? String
            if let i = items.firstIndex(where: { $0.id == done.id }) { items[i] = done } else { items.append(done) }
            if raw["type"] as? String == "mcpToolCall", raw["server"] as? String == "dighouse", done.state != .failed {
                onToolFinished?(raw["tool"] as? String ?? "", raw["arguments"] as? JSON ?? [:])
            }
        case "turn/completed":
            running = false
            turn = nil
            // A step still open when the turn ends will not finish: say so if the person stopped it, otherwise just close it.
            let stopped = ((params["turn"] as? JSON)?["status"] as? String) == "interrupted"
            for i in items.indices where items[i].state == .running {
                items[i].state = stopped ? .failed : .done
                if stopped { items[i].text += " (stopped)" }
            }
            if let failure = ((params["turn"] as? JSON)?["error"] as? JSON)?["message"] as? String {
                items.append(problem(failure))
            }
            Task { @MainActor in await refreshThreads() }
        default:
            break
        }
    }

    func handleRequest(_ id: Any, _ method: String, _ params: JSON) {
        guard method == "mcpServer/elicitation/request" else {
            engine?.refuse(id, "Dighouse does not grant this kind of request yet.")
            return
        }
        if params["serverName"] as? String == "dighouse" {
            engine?.respond(to: id, result: ["action": "accept", "content": [:] as JSON])  // the app's own tools
        } else {
            approval = Approval(id: id, message: params["message"] as? String ?? "A tool is asking for permission.")
        }
    }

    /// Where the picture a tool made was saved, so the chat can show the file.
    private func pictures(_ tool: String, _ args: JSON) -> [String] {
        guard let root = project else { return [] }
        let tile = args["tile"] as? String ?? "", style = args["style"] as? String ?? "composite"
        switch tool {
        case "view_tile": return ["\(root)/data/tiles/\(tile)-\(style).png"]
        case "view_terrain": return ["\(root)/data/tiles/\(args["terrain"] as? String ?? "")-overview-\(style).png"]
        case "cut_section":
            if let candidate = args["candidate"] as? String, !candidate.isEmpty { return ["\(root)/candidates/img/\(candidate)-section.png"] }
            return ["\(root)/data/tiles/\(tile)-section.png"]
        default: return []
        }
    }


    /// A plain name for a shell command the agent ran, from its first program and the files it names.
    static func describe(command: String) -> String {
        let words = command.split(whereSeparator: { $0.isWhitespace }).map(String.init)
        guard let program = words.first.map({ URL(fileURLWithPath: $0).lastPathComponent }) else { return "Ran a command" }
        let files = words.dropFirst().filter { !$0.hasPrefix("-") && ($0.contains(".") || $0.contains("/")) && !$0.contains("'") }
            .map { URL(fileURLWithPath: $0.trimmingCharacters(in: CharacterSet(charactersIn: ";|&)\"'"))).lastPathComponent }
        let named = files.prefix(2).joined(separator: ", ")
        switch program {
        case "cat", "sed", "head", "tail", "less", "nl": return named.isEmpty ? "Read a file" : "Read \(named)"
        case "ls", "find", "tree": return "Looked through the project folder"
        case "rg", "grep": return named.isEmpty ? "Searched the files" : "Searched \(named)"
        case "wc": return named.isEmpty ? "Counted lines" : "Counted lines in \(named)"
        case "python", "python3", "uv": return "Ran a Python script"
        case "curl", "wget": return "Fetched a web address"
        default: return "Ran a command"
        }
    }

    private func item(from raw: JSON, finished: Bool) -> ChatItem? {
        guard let id = raw["id"] as? String, let type = raw["type"] as? String else { return nil }
        let status = raw["status"] as? String ?? ""
        let failed = status == "failed" || raw["error"] is JSON || (raw["exitCode"] as? Int ?? 0) != 0
        let state: ChatItem.State = failed ? .failed : (finished ? .done : .running)
        func step(_ icon: String, _ text: String, tool: String? = nil) -> ChatItem {
            var s = ChatItem(id: id, kind: .step, text: text, icon: icon, state: state)
            s.tool = tool
            return s
        }
        switch type {
        case "userMessage":
            let content = raw["content"] as? [JSON] ?? []
            var shown = ChatItem(id: id, kind: .user, text: Mentions.visible(content.compactMap { $0["text"] as? String }.joined(separator: "\n")))
            if let flow = ToolGuide.workflow(sentAs: shown.text) { shown.result = shown.text; shown.text = flow.title }
            shown.images = content.compactMap { $0["path"] as? String }
            return shown
        case "agentMessage":
            return ChatItem(id: id, kind: .agent, text: raw["text"] as? String ?? "")
        case "reasoning":
            let summary = (raw["summary"] as? [String] ?? []).joined(separator: "\n\n").trimmingCharacters(in: .whitespacesAndNewlines)
            guard finished, !summary.isEmpty else { return nil }
            var s = step("brain", "Thought it through", tool: "thinking")
            s.result = summary
            return s
        case "mcpToolCall":
            let tool = raw["tool"] as? String ?? "", args = raw["arguments"] as? JSON ?? [:]
            let ours = raw["server"] as? String == "dighouse"
            let (icon, text) = ours ? ToolGuide.describe(tool, args) : ("puzzlepiece.extension", "\(raw["server"] as? String ?? "tool"): \(tool)")
            var s = step(icon, text, tool: tool)
            s.details = args.filter { $0.key != "project" }.sorted { $0.key < $1.key }.map { "\($0.key): \($0.value)" }
            let content = (raw["result"] as? JSON)?["content"] as? [JSON] ?? []
            s.result = content.compactMap { $0["text"] as? String }.joined(separator: "\n")
            if let failure = (raw["error"] as? JSON)?["message"] as? String { s.result = failure }
            if ours, finished, !failed {
                s.images = pictures(tool, args)
                s.showsImage = tool == "cut_section"
                if tool == "init_project" { s.projectPath = args["project"] as? String }
            }
            return s
        case "commandExecution":
            var command = raw["command"] as? String ?? "a command"
            if let wrapped = command.range(of: " -lc ") {
                command = String(command[wrapped.upperBound...]).trimmingCharacters(in: CharacterSet(charactersIn: "'\""))
            }
            var s = step("terminal", Self.describe(command: command), tool: "shell")
            s.details = [command]
            s.result = raw["aggregatedOutput"] as? String
            return s
        case "fileChange":
            let changes = raw["changes"] as? [JSON] ?? []
            var s = step("doc.text", "Edited \(max(changes.count, 1)) file\(changes.count > 1 ? "s" : "")", tool: "edit")
            s.details = changes.compactMap { $0["path"] as? String }.map { URL(fileURLWithPath: $0).lastPathComponent }
            return s
        case "webSearch":
            return step("globe", "Searched the web: \(raw["query"] as? String ?? "")", tool: "web")
        case "imageView":
            var s = step("photo", "Looked at an image", tool: "image")
            if let path = raw["path"] as? String { s.images = [path] }
            return s
        case "collabAgentToolCall":
            let states = raw["agentsStates"] as? [String: JSON] ?? [:]
            switch raw["tool"] as? String ?? "" {
            case "spawnAgent":
                var s = step("person.badge.plus", "Started a helper agent", tool: "sub-agent")
                s.details = [raw["model"] as? String ?? "", raw["prompt"] as? String ?? ""].filter { !$0.isEmpty }
                return s
            case "wait":
                var s = step("person.2", "Waited for \(max(states.count, 1)) helper agent\(states.count > 1 ? "s" : "")", tool: "sub-agent")
                s.result = states.values.compactMap { $0["message"] as? String }.joined(separator: "\n\n")
                return s
            default:
                return step("person.2", "Worked with helper agents", tool: "sub-agent")
            }
        case "contextCompaction":
            return step("arrow.triangle.2.circlepath", "Summarized the conversation so far")
        default:
            return nil
        }
    }
}

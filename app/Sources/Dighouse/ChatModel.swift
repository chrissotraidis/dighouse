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

    var engine: Engine?
    var instructions: () -> String = { "" }
    var model: () -> ModelInfo? = { nil }
    var modelID: () -> String? = { nil }
    var effort: () -> String? = { nil }
    /// Called for a chat that has no name yet, with the text it began with.
    var onUntitled: ((String, String) -> Void)?
    var onToolFinished: ((String, JSON) -> Void)?

    private(set) var project: String?
    private var turn: String?
    private var resumed: Set<String> = []

    var scope: String { project ?? Paths.general.path }
    var title: String { (threads + generalThreads).first { $0.id == active }?.title ?? "New chat" }

    /// The chats of each folder, kept between launches. The engine needs several seconds to list one folder's chats
    /// when there are thousands of Codex sessions on the Mac, so the lists show from here and are refreshed behind.
    private var known: [String: [ChatThread]] = UserDefaults.standard.data(forKey: "chatLists")
        .flatMap { try? JSONDecoder().decode([String: [ChatThread]].self, from: $0) } ?? [:]

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
        // A chat that was just started may not be in the engine's list yet, so keep the open one.
        if let fresh { generalThreads = keepingOpen(fresh, from: generalThreads) }
        if let mine, let scope {
            // The person may have moved on while the engine was listing; the answer is still worth keeping.
            if scope == project { threads = keepingOpen(mine, from: threads) } else { known[scope] = mine }
        }
        remember()
    }

    private func remember() {
        known[Paths.general.path] = generalThreads
        if let project { known[project] = threads }
        UserDefaults.standard.set(try? JSONEncoder().encode(known), forKey: "chatLists")
    }

    private func keepingOpen(_ fresh: [ChatThread], from old: [ChatThread]) -> [ChatThread] {
        guard let open = old.first(where: { $0.id == active }), !fresh.contains(where: { $0.id == open.id }) else { return fresh }
        return [open] + fresh
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
            items = turns.flatMap { $0["items"] as? [JSON] ?? [] }.compactMap { item(from: $0, finished: true) }
            loading = false
            try await resume(thread.id)
        } catch {
            items = [problem(error.localizedDescription)]
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
        let sending = attachments
        attachments = []
        var shown = ChatItem(id: UUID().uuidString, kind: .user, text: text)
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
                let new = ChatThread(id: id, title: title ?? String((text.isEmpty ? sending.first?.name ?? "Chat" : text).prefix(80)), named: title != nil)
                if project == nil { generalThreads.insert(new, at: 0) } else { threads.insert(new, at: 0) }
                remember()
                if let title { _ = try? await engine.request("thread/name/set", ["threadId": id, "name": title]) }
                else if !text.isEmpty { onUntitled?(id, text) }
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
        _ = try? await engine.request("turn/interrupt", ["threadId": active, "turnId": turn])
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
        guard let thread = params["threadId"] as? String else { return }
        // Runs carry on while another chat is on screen, so keep track of every chat's turn.
        if method == "turn/started" { live[thread] = (params["turn"] as? JSON)?["id"] as? String ?? "" }
        if method == "turn/completed" { live[thread] = nil }
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
                  let new = item(from: raw, finished: false) else { return }
            items.append(new)
        case "item/agentMessage/delta":
            guard let id = params["itemId"] as? String, let i = items.firstIndex(where: { $0.id == id }) else { return }
            items[i].text += params["delta"] as? String ?? ""
        case "item/completed":
            guard let raw = params["item"] as? JSON, raw["type"] as? String != "userMessage" else { return }
            guard let done = item(from: raw, finished: true) else {
                items.removeAll { $0.id == raw["id"] as? String }
                return
            }
            if let i = items.firstIndex(where: { $0.id == done.id }) { items[i] = done } else { items.append(done) }
            if raw["type"] as? String == "mcpToolCall", raw["server"] as? String == "dighouse", done.state != .failed {
                onToolFinished?(raw["tool"] as? String ?? "", raw["arguments"] as? JSON ?? [:])
            }
        case "turn/completed":
            running = false
            turn = nil
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
            var shown = ChatItem(id: id, kind: .user, text: content.compactMap { $0["text"] as? String }.joined(separator: "\n"))
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
            var s = step("terminal", "Ran a command", tool: "shell")
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

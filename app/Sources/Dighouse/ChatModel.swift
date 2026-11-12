import AppKit
import Foundation

struct ChatThread: Identifiable, Hashable {
    let id: String
    var title: String
}

struct Approval {
    let id: Any
    let message: String
}

/// The conversations of the open project, and the live state of the one on screen.
@MainActor
final class ChatModel: ObservableObject {
    @Published var threads: [ChatThread] = []
    @Published var active: String?
    @Published var items: [ChatItem] = []
    @Published var running = false
    @Published var approval: Approval?
    @Published var draft = ""
    @Published var attachments: [String] = []

    var engine: Engine?
    var instructions: () -> String = { "" }
    var model: () -> String? = { nil }
    var effort: () -> String? = { nil }
    var onToolFinished: ((String, JSON) -> Void)?

    private var project: String?
    private var turn: String?
    private var resumed: Set<String> = []

    var title: String { threads.first { $0.id == active }?.title ?? "New chat" }

    func open(project path: String?) async {
        project = path
        newChat()
        await refreshThreads()
    }

    func refreshThreads() async {
        guard let engine, let project else { threads = []; return }
        let listed = try? await engine.request("thread/list", ["cwd": project, "limit": 40])
        let open = threads.first { $0.id == active }
        var fresh: [ChatThread] = (listed?["data"] as? [JSON] ?? []).compactMap { t in
            guard let id = t["id"] as? String else { return nil }
            let title = (t["name"] as? String) ?? (t["preview"] as? String) ?? ""
            return ChatThread(id: id, title: title.isEmpty ? "New chat" : String(title.prefix(80)))
        }
        if let open, !fresh.contains(where: { $0.id == open.id }) { fresh.insert(open, at: 0) }
        threads = fresh
    }

    func newChat() {
        active = nil
        items = []
        running = false
        attachments = []
    }

    func select(_ thread: ChatThread) async {
        guard let engine else { return }
        active = thread.id
        items = []
        running = false
        do {
            if !resumed.contains(thread.id) {
                _ = try await engine.request("thread/resume", threadSettings(["threadId": thread.id]))
                resumed.insert(thread.id)
            }
            let read = try await engine.request("thread/read", ["threadId": thread.id, "includeTurns": true])
            let turns = (read["thread"] as? JSON)?["turns"] as? [JSON] ?? []
            guard active == thread.id else { return }
            items = turns.flatMap { $0["items"] as? [JSON] ?? [] }.compactMap { item(from: $0, finished: true) }
        } catch {
            items = [problem(error.localizedDescription)]
        }
    }

    func rename(_ thread: ChatThread, to name: String) async {
        let name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let engine, !name.isEmpty else { return }
        _ = try? await engine.request("thread/name/set", ["threadId": thread.id, "name": name])
        if let i = threads.firstIndex(of: thread) { threads[i].title = name }
    }

    func archive(_ thread: ChatThread) async {
        guard let engine else { return }
        _ = try? await engine.request("thread/archive", ["threadId": thread.id])
        threads.removeAll { $0.id == thread.id }
        if active == thread.id { newChat() }
    }

    func send(_ text: String) async {
        let text = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let engine, !text.isEmpty || !attachments.isEmpty else { return }
        var input: [JSON] = attachments.map { ["type": "localImage", "path": $0] }
        if !text.isEmpty { input.append(["type": "text", "text": text]) }
        var shown = ChatItem(id: UUID().uuidString, kind: .user, text: text)
        shown.images = attachments.compactMap { Images.load($0) }
        items.append(shown)
        attachments = []
        do {
            if running, let turn, let active {
                _ = try await engine.request("turn/steer", ["threadId": active, "expectedTurnId": turn, "input": input])
                return
            }
            if active == nil {
                let started = try await engine.request("thread/start", threadSettings([:]))
                guard let id = (started["thread"] as? JSON)?["id"] as? String else { throw EngineError(message: "No chat was created.") }
                active = id
                resumed.insert(id)
                threads.insert(ChatThread(id: id, title: String((text.isEmpty ? "Image" : text).prefix(80))), at: 0)
            }
            running = true
            var params: JSON = ["threadId": active ?? "", "input": input]
            if let model = model() { params["model"] = model }
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
            "cwd": project ?? Paths.support.path,
            "approvalPolicy": "never",
            "sandbox": "workspace-write",
            "serviceName": "Dighouse",
            "developerInstructions": instructions(),
        ]
        if let model = model() { settings["model"] = model }
        return settings.merging(extra) { _, new in new }
    }

    private func problem(_ text: String) -> ChatItem {
        ChatItem(id: UUID().uuidString, kind: .step, text: text, icon: "exclamationmark.triangle", state: .failed)
    }

    // MARK: what the engine tells us

    func handle(_ method: String, _ params: JSON) {
        guard params["threadId"] as? String == active, active != nil else { return }
        switch method {
        case "turn/started":
            running = true
            turn = (params["turn"] as? JSON)?["id"] as? String
        case "item/started":
            guard let raw = params["item"] as? JSON, raw["type"] as? String != "userMessage",
                  let new = item(from: raw, finished: false) else { return }
            items.append(new)
        case "item/agentMessage/delta":
            guard let id = params["itemId"] as? String, let i = items.firstIndex(where: { $0.id == id }) else { return }
            items[i].text += params["delta"] as? String ?? ""
        case "item/completed":
            guard let raw = params["item"] as? JSON, raw["type"] as? String != "userMessage",
                  let done = item(from: raw, finished: true) else { return }
            if let i = items.firstIndex(where: { $0.id == done.id }) { items[i] = done } else { items.append(done) }
            if raw["type"] as? String == "mcpToolCall", raw["server"] as? String == "dighouse" {
                onToolFinished?(raw["tool"] as? String ?? "", raw["arguments"] as? JSON ?? [:])
            }
        case "turn/completed":
            running = false
            turn = nil
            if let failure = ((params["turn"] as? JSON)?["error"] as? JSON)?["message"] as? String {
                items.append(problem(EngineError.plain(failure)))
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
            shown.images = content.compactMap { $0["path"] as? String }.compactMap { Images.load($0) }
            return shown
        case "agentMessage":
            return ChatItem(id: id, kind: .agent, text: raw["text"] as? String ?? "")
        case "mcpToolCall":
            let tool = raw["tool"] as? String ?? "", args = raw["arguments"] as? JSON ?? [:]
            let ours = raw["server"] as? String == "dighouse"
            let (icon, text) = ours ? ToolGuide.describe(tool, args) : ("puzzlepiece.extension", "\(raw["server"] as? String ?? "tool"): \(tool)")
            var s = step(icon, text, tool: tool)
            s.details = args.filter { $0.key != "project" }.sorted { $0.key < $1.key }.map { "\($0.key): \($0.value)" }
            let content = (raw["result"] as? JSON)?["content"] as? [JSON] ?? []
            s.result = content.compactMap { $0["text"] as? String }.joined(separator: "\n")
            if let failure = (raw["error"] as? JSON)?["message"] as? String { s.result = failure }
            s.images = content.compactMap { $0["data"] as? String }
                .compactMap { Data(base64Encoded: $0) }.compactMap { NSImage(data: $0) }
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
            if let path = raw["path"] as? String, let image = Images.load(path) { s.images = [image] }
            return s
        case "collabAgentToolCall":
            return step("person.2", "Worked with another agent", tool: "agent")
        case "contextCompaction":
            return step("arrow.triangle.2.circlepath", "Summarized the conversation so far")
        default:
            return nil
        }
    }
}

import Foundation

enum PickerRequest { case model, effort }

/// A command typed after "/" in the message box.
struct SlashCommand: Identifiable, Equatable {
    enum Group: String { case search = "Search", chat = "Chat" }
    let id: String
    let summary: String
    let group: Group
    /// What to type after the name, for a command that takes text.
    var argument: String? = nil
    /// The workflow this command starts, if it is one.
    var workflow: String? = nil
    /// Whether the command needs its text before it can run.
    var needsArgument = false

    var name: String { "/" + id }
}

enum SlashCommands {
    static let all: [SlashCommand] = [
        SlashCommand(id: "research", summary: "Find where a search is worth doing, and get three proposals", group: .search, workflow: "research"),
        SlashCommand(id: "new-project", summary: "Start a project on a place", group: .search),
        SlashCommand(id: "run", summary: "Run the whole search, stopping for you at the second look and decisions", group: .search, workflow: "full"),
        SlashCommand(id: "terrain", summary: "Find open lidar for the project and build the bare ground", group: .search, workflow: "terrain"),
        SlashCommand(id: "screen", summary: "Look at every tile nobody has screened yet", group: .search, workflow: "screen"),
        SlashCommand(id: "check", summary: "Cut a section and look for modern features on each flag", group: .search, workflow: "check"),
        SlashCommand(id: "second-look", summary: "Ask your second-look model about each flag", group: .search, workflow: "second"),
        SlashCommand(id: "sources", summary: "Search what is published and log every source", group: .search, workflow: "prior"),
        SlashCommand(id: "decide", summary: "Have the agent suggest a decision on each find, ready for your review", group: .search, workflow: "decide"),
        SlashCommand(id: "review", summary: "Go through the finds one at a time and decide each", group: .search),
        SlashCommand(id: "report", summary: "Draft a report for the heritage authority", group: .search, workflow: "report"),
        SlashCommand(id: "new", summary: "Start a new chat", group: .chat),
        SlashCommand(id: "model", summary: "Choose the model", group: .chat),
        SlashCommand(id: "effort", summary: "Choose how hard the model thinks", group: .chat),
        SlashCommand(id: "rename", summary: "Rename this chat", group: .chat, argument: "name"),
        SlashCommand(id: "fork", summary: "Copy this chat into a new one, to try something else", group: .chat),
        SlashCommand(id: "undo", summary: "Take back your last message and its answer", group: .chat),
        SlashCommand(id: "compact", summary: "Shorten this chat so the model has room to keep going", group: .chat),
        SlashCommand(id: "goal", summary: "Keep working, turn after turn, until this is done", group: .chat, argument: "what to finish", needsArgument: true),
        SlashCommand(id: "status", summary: "Show the model, how full the chat is, and your usage left", group: .chat),
        SlashCommand(id: "archive", summary: "Archive this chat", group: .chat),
        SlashCommand(id: "help", summary: "List every command", group: .chat),
    ]

    /// The command name being typed and the text after it, or nil when the draft is not a command.
    static func parse(_ draft: String) -> (name: String, argument: String)? {
        guard draft.hasPrefix("/"), !draft.contains("\n") else { return nil }
        let body = draft.dropFirst()
        let name = body.prefix { !$0.isWhitespace }
        let argument = body.dropFirst(name.count).trimmingCharacters(in: .whitespaces)
        return (String(name).lowercased(), argument)
    }

    /// Commands that fit what has been typed: names that start with it first, then names or descriptions that contain it.
    static func matches(_ draft: String) -> [SlashCommand] {
        guard let (name, _) = parse(draft) else { return [] }
        if draft.dropFirst().contains(where: \.isWhitespace) { return all.filter { $0.id == name } }
        guard !name.isEmpty else { return all }
        // An exact name comes first, so "/new" and Return starts a new chat rather than a new project.
        let starts = all.filter { $0.id.hasPrefix(name) }.sorted { ($0.id == name ? 0 : 1) < ($1.id == name ? 0 : 1) }
        // Descriptions only count once a few letters are typed; one letter would match nearly everything.
        let contains = all.filter { c in !starts.contains(c) && (c.id.contains(name) || (name.count >= 3 && c.summary.lowercased().contains(name))) }
        return starts + contains
    }

    static var help: String {
        var lines = ["**Commands.** Type / in the message box, then a few letters. Return runs the highlighted one; Escape closes the list."]
        for group in [SlashCommand.Group.search, .chat] {
            lines.append("")
            lines.append("**\(group.rawValue)**")
            for c in all where c.group == group {
                lines.append("- `\(c.name)\(c.argument.map { " " + $0 } ?? "")` \(c.summary)")
            }
        }
        return lines.joined(separator: "\n")
    }
}

extension AppState {
    /// Why a command cannot run here, or nil when it can.
    func unavailable(_ c: SlashCommand) -> String? {
        if let id = c.workflow, let flow = ToolGuide.workflows.first(where: { $0.id == id }) {
            let s = state(of: flow)
            if s.ready { return nil }
            return s.note == "Done" ? "Nothing left to do" : (s.note.isEmpty ? "Not ready yet" : s.note)
        }
        let hasChat = chat.active != nil
        switch c.id {
        case "rename", "archive": return hasChat ? nil : "Start a chat first"
        case "fork", "compact":
            if !hasChat { return "Start a chat first" }
            return chat.running ? "Wait for the run to finish" : nil
        case "undo":
            if chat.running { return "Stop the run first" }
            return chat.items.contains { $0.kind == .user } ? nil : "Nothing to take back"
        case "goal": return chat.running ? "Wait for the run to finish" : nil
        case "review": return store.candidates.isEmpty ? "Needs candidates" : nil
        default: return nil
        }
    }

    /// Run a command with the text typed after it.
    func perform(_ c: SlashCommand, argument: String) {
        if let id = c.workflow, let flow = ToolGuide.workflows.first(where: { $0.id == id }) {
            if argument.isEmpty || flow.id == "second" { run(flow) } else { ask(flow.prompt + "\n\n" + argument, title: flow.title) }
            return
        }
        let thread = (chat.threads + chat.generalThreads).first { $0.id == chat.active }
        switch c.id {
        case "new-project": startProject()
        case "review": reviewing = true
        case "new": newChat()
        case "model": pickerRequest = .model
        case "effort": pickerRequest = .effort
        case "rename":
            guard let thread else { return }
            if argument.isEmpty { renameRequest = thread } else { Task { @MainActor in await chat.rename(thread, to: argument) } }
        case "fork": Task { @MainActor in await chat.fork() }
        case "undo": Task { @MainActor in if let text = await chat.undo() { chat.draft = text } }
        case "compact": Task { @MainActor in await chat.compact() }
        case "goal": route = .chat; Task { @MainActor in await chat.setGoal(argument) }
        case "status": Task { @MainActor in await showStatus() }
        case "archive": if let thread { Task { @MainActor in await chat.archive(thread) } }
        case "help": route = .chat; chat.note(SlashCommands.help)
        default: break
        }
    }

    /// What the chat runs on and how much is left, written into the chat.
    func showStatus() async {
        route = .chat
        var lines = ["**Status**", "- Model: \(modelName)\(activeEffort.map { ", thinking " + Effort.label($0).lowercased() } ?? "")"]
        lines.append("- Project: \(store.current?.name ?? "none (a general chat)")")
        if let id = chat.active, let use = chat.usage[id] {
            if let window = use.window, window > 0 {
                lines.append("- This chat: \(use.used.formatted()) of \(window.formatted()) tokens of context used (\(Int((Double(use.used) / Double(window) * 100).rounded()))%)")
            } else {
                lines.append("- This chat: \(use.used.formatted()) tokens of context used")
            }
        } else {
            lines.append(chat.items.contains { $0.kind == .user } ? "- This chat: the engine reports this after the next message" : "- This chat: nothing sent yet")
        }
        lines.append(contentsOf: await usageLines())
        chat.note(lines.joined(separator: "\n"))
    }

    /// The account's usage left, as the engine reports it.
    func usageLines() async -> [String] {
        guard let read = try? await engine.request("account/rateLimits/read"), let limits = read["rateLimits"] as? JSON else {
            return ["- Usage left: the engine did not say"]
        }
        func line(_ key: String) -> String? {
            guard let window = limits[key] as? JSON, let used = window["usedPercent"] as? Int else { return nil }
            let minutes = window["windowDurationMins"] as? Int ?? 0
            let label = minutes >= 10_080 ? "this week" : minutes >= 1_440 ? "the next \(minutes / 1_440) days" : minutes > 0 ? "the next \(max(1, minutes / 60)) hours" : "this period"
            var text = "- Usage for \(label): \(max(0, 100 - used))% left"
            if let resets = window["resetsAt"] as? Int {
                let date = Date(timeIntervalSince1970: TimeInterval(resets))
                text += ", resets \(date.formatted(date: .abbreviated, time: .shortened))"
            }
            return text
        }
        let out = [line("primary"), line("secondary")].compactMap { $0 }
        return out.isEmpty ? ["- Usage left: not reported for this account"] : out
    }
}


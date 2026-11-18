import SwiftUI

/// The one thing the window is showing.
enum Route: Equatable {
    case home, chat, newProject, toolbox, settings
}

enum PaneLayout: String, CaseIterable {
    case chat, split, workspace

    static let names: [PaneLayout: String] = [.chat: "Chat only", .split: "Chat and workspace", .workspace: "Workspace only"]
    var icon: String { self == .chat ? "bubble.left" : self == .split ? "rectangle.split.2x1" : "map" }
}

enum WorkTab: String, CaseIterable {
    case map = "Map", records = "Records", notes = "Notes", sources = "Sources", data = "Data"
}

enum SettingsSection: String, CaseIterable {
    case general = "General", look = "Personalize", models = "Models", engine = "How it runs", tools = "Tools", privacy = "Data and privacy", about = "About"
}

@MainActor
final class AppState: ObservableObject {
    let setup = Setup()
    let engine = Engine()
    let store = ProjectStore()
    let chat = ChatModel()

    @Published var route = Route.home
    @Published var onboarded = UserDefaults.standard.bool(forKey: "onboarded")
    @Published var showWelcome = false
    @Published var textSize = UserDefaults.standard.string(forKey: "textSize") ?? "standard" {
        didSet { UserDefaults.standard.set(textSize, forKey: "textSize") }
    }
    /// The text size just chosen from the keyboard, shown for a moment at the top of the window.
    @Published var sizeNote: String?
    /// A slash command asking the message box to open the model list or the effort slider.
    @Published var pickerRequest: PickerRequest?
    /// A slash command asking the sidebar to rename a chat.
    @Published var renameRequest: ChatThread?
    /// Publishing a project: its folder and the step it is on, shown on that project's overview.
    @Published var publishing: (path: String, step: PublishStep)?
    /// Whether the "Find a chat" sheet is open.
    @Published var findingChat = false
    @Published var jumping = false
    /// Whole searches under way ("Find and report back"): the chat each runs in, and its project's folder.
    @Published var investigating: [String: String] = [:]
    /// The search report on show, as a file, or nil.
    @Published var reportShown: String?
    /// The list of known sites for a blind test is open.
    @Published var testPicking = false
    /// A place typed on Home that is being looked up for a whole search, and what went wrong if it could not be found.
    @Published var placeBusy: String?
    @Published var placeProblem: String?
    /// The project whose report waits for its second looks to come back. The strip says so while it waits.
    @Published private(set) var reportAfterLooks: String?
    /// The first-project tutorial: whether its bar is showing, the project it made, how far past the automatic steps
    /// the person has got (4, 5 or 6), and whether it has been finished. Kept between launches.
    @Published var tutorialOn = UserDefaults.standard.bool(forKey: "tutorialOn") {
        didSet { UserDefaults.standard.set(tutorialOn, forKey: "tutorialOn") }
    }
    @Published var tutorialProject = UserDefaults.standard.string(forKey: "tutorialProject") {
        didSet { UserDefaults.standard.set(tutorialProject, forKey: "tutorialProject") }
    }
    @Published var tutorialReached = UserDefaults.standard.integer(forKey: "tutorialReached") {
        didSet { UserDefaults.standard.set(tutorialReached, forKey: "tutorialReached") }
    }
    @Published var tutorialDone = UserDefaults.standard.bool(forKey: "tutorialDone") {
        didSet { UserDefaults.standard.set(tutorialDone, forKey: "tutorialDone") }
    }
    /// Which part of the Notes tab is showing: record, runs, method or log.
    @Published var notesPart = "record"
    /// A file to show first in the Notes tab, such as PROJECT.md from the project's folder list.
    @Published var notesFile: String?
    /// The window's size, so sheets fit inside it.
    @Published var windowSize = CGSize(width: 1380, height: 880)
    /// Whether the one-at-a-time review of candidates is open.
    @Published var reviewing = false
    @Published var starting = true
    @Published var sidebarVisible = true
    @Published var sidebarPeek = false
    @Published var tab = WorkTab.map
    @Published var settingsSection = SettingsSection.general
    @Published var draftProject = StartingPoints.own
    @Published var surveys: [Survey] = []
    @Published var surveysLoading = false
    @Published var surveysProblem: String?
    @Published var secondLookBusy: String?
    @Published var secondLookProblem: [String: String] = [:]
    @Published var layout = PaneLayout(rawValue: UserDefaults.standard.string(forKey: "layout") ?? "") ?? .split {
        didSet { UserDefaults.standard.set(layout.rawValue, forKey: "layout") }
    }
    @Published var chatWidth = UserDefaults.standard.object(forKey: "chatWidth") as? Double ?? 440 {
        didSet { UserDefaults.standard.set(chatWidth, forKey: "chatWidth") }
    }
    @Published var look = Look(rawValue: UserDefaults.standard.string(forKey: "look") ?? "") ?? .earth {
        didSet {
            UserDefaults.standard.set(look.rawValue, forKey: "look")
            Theme.palette = look.palette
        }
    }
    /// The page shown in a project's Sources tab. It follows what the agent opens.
    @Published var browserURL: URL?
    @Published var sidebarWidth = UserDefaults.standard.object(forKey: "sidebarWidth") as? Double ?? 256 {
        didSet { UserDefaults.standard.set(sidebarWidth, forKey: "sidebarWidth") }
    }
    @Published var modelID: String? = UserDefaults.standard.string(forKey: "model") {
        didSet {
            UserDefaults.standard.set(modelID, forKey: "model")
            if let modelID { recentModels = Array(([modelID] + recentModels.filter { $0 != modelID }).prefix(5)) }
        }
    }
    /// The last models picked, newest first, so switching back to a cheaper one is one click.
    @Published var recentModels: [String] = UserDefaults.standard.stringArray(forKey: "recentModels") ?? [] {
        didSet { UserDefaults.standard.set(recentModels, forKey: "recentModels") }
    }
    @Published var secondModelID: String? = UserDefaults.standard.string(forKey: "secondModel") {
        didSet {
            UserDefaults.standard.set(secondModelID, forKey: "secondModel")
            if secondModelID != oldValue { secondModelRefusal = nil }
        }
    }
    /// The second model's provider refused the last request (an account or access problem, not a passing one): the model
    /// and the reason, so Home, the project and Settings can say so instead of offering a step that will fail again.
    @Published var secondModelRefusal: [String: String]? = UserDefaults.standard.dictionary(forKey: "secondModelRefused") as? [String: String] {
        didSet { UserDefaults.standard.set(secondModelRefusal, forKey: "secondModelRefused") }
    }
    /// The refusal, when it is for the second model chosen now.
    var refusedSecondModel: String? {
        guard let r = secondModelRefusal, r["model"] == secondModelID else { return nil }
        return r["reason"]
    }
    @Published var effort: String? = UserDefaults.standard.string(forKey: "effort") {
        didSet { UserDefaults.standard.set(effort, forKey: "effort") }
    }
    @Published var userName = UserDefaults.standard.string(forKey: "userName") ?? NSFullUserName() {
        didSet { UserDefaults.standard.set(userName, forKey: "userName") }
    }
    /// The name to greet the person by: the first word of their name, or nothing.
    var firstName: String { userName.split(separator: " ").first.map(String.init) ?? "" }
    @Published var toolServers: [ToolServer] = (UserDefaults.standard.data(forKey: "toolServers"))
        .flatMap { try? JSONDecoder().decode([ToolServer].self, from: $0) } ?? [] {
        didSet { UserDefaults.standard.set(try? JSONEncoder().encode(toolServers), forKey: "toolServers") }
    }

    private var titleQueue: [(chat: String, text: String)] = []
    private var titleJobs: [String: String] = [:]
    private var titleReplies: [String: String] = [:]
    private var titled: Set<String> = []

    private var secondLooks: [String: String] = [:]
    private var secondLookQueue: [String] = []

    var model: ModelInfo? {
        let id = modelID ?? engine.defaultModel
        return engine.models.first { $0.id == id }
    }
    var modelName: String { model?.name ?? modelID ?? engine.defaultModel ?? "Default model" }
    var secondModelName: String { engine.models.first { $0.id == secondModelID }?.name ?? "Choose a model" }
    var activeEffort: String? {
        guard let model, !model.efforts.isEmpty else { return nil }
        if let effort, model.efforts.contains(effort) { return effort }
        return model.defaultEffort ?? model.efforts.first
    }

    init() {
        route = store.current == nil ? .home : .chat
        chat.engine = engine
        chat.model = { [weak self] in self?.model }
        chat.modelID = { [weak self] in self?.modelID }
        chat.onUntitled = { [weak self] chat, text in self?.nameLater(chat, text) }
        // A run that ends, however it ends, leaves the research record up to date. No model is used.
        // When the person stopped it, the record also says which stage it was on.
        chat.onRunEnded = { [weak self] thread, folder, stopped in
            guard let self else { return }
            let stage = stopped ? self.stage(of: thread).title : nil
            Task { @MainActor in await self.updateRecord(of: folder, stoppedDuring: stage) }
        }
        chat.onGoalEnded = { [weak self] thread, status in
            Task { @MainActor in await self?.searchEnded(thread, status) }
        }
        chat.effort = { [weak self] in
            guard let self, let effort = self.effort, self.model?.efforts.contains(effort) == true else { return nil }
            return effort
        }
        chat.instructions = { [weak self] in
            guard let self else { return "" }
            let shared = "Keep replies short and plain. Keep a plan for anything with more than two stages."
            if let project = self.store.current {
                return self.setup.skill + "\n\nYou are running inside the Dighouse app. The open project folder is \(project.path). "
                    + "Pass that path as the project argument to every dighouse tool. "
                + "Write the search report (write_report) only in a whole search, when asked to report back; after a single step, "
                + "end with write_summary. "
                    + "The person sees the map, the tiles and the records beside this chat, so do not paste images or file contents. "
                    + "Do not record a second opinion yourself: the person asks a different model for it from the record. " + shared
            }
            return self.setup.skill + "\n\nYou are running inside the Dighouse app and no project is open. Help the person choose "
                + "where to look, or answer their question. Once the chat has settled a place and a question, call suggest_project, "
                + "with what the chat read and the places it ruled out and why: "
                + "the person gets a Make this a project card, and pressing it makes the project and moves this chat into it. "
                + "Projects go in \(Paths.projectsHome.path). Only if the person says they want to work out of their GitHub folder, "
                + "set work_in_github and tell them the folder the reply names; never choose it yourself. "
                + "If the person asked you to search a place or find things there, set search_now, so one press makes the project "
                + "and runs the whole search; size the place up first (survey_area) so the box has open data. "
                + "Call init_project yourself only when the person asks you to create the project; pass a new folder name and it "
                + "goes inside \(Paths.projectsHome.path), then tell the person to open it from the card in the chat. " + shared
        }
        chat.onToolFinished = { [weak self] tool, args in
            guard let self else { return }
            if tool == "init_project", let path = args["project"] as? String { self.store.register(path: path) }
            self.store.reloadIfChanged()
            if ["view_tile", "cut_section", "flag_candidate", "record_verdict"].contains(tool), let tile = args["tile"] as? String {
                self.store.selectedTile = tile
            }
            if let candidate = args["candidate"] as? String, !candidate.contains(","), candidate != "all" { self.store.selectedCandidate = candidate }
            // Follow the agent to web pages it reads. A page the person saved is a file name, so it stays put.
            if tool == "read_source", let url = (args["url"] as? String).flatMap(URL.init),
               ["http", "https"].contains(url.scheme?.lowercased() ?? "") { self.browserURL = url }
        }
        engine.onNotification = { [weak self] method, params in
            guard let self else { return }
            if let thread = params["threadId"] as? String, let chat = self.titleJobs[thread] {
                if method == "item/completed", let item = params["item"] as? JSON, item["type"] as? String == "agentMessage" {
                    self.titleReplies[thread] = item["text"] as? String
                } else if method == "turn/completed" {
                    self.titleJobs[thread] = nil
                    let name = Self.cleanTitle(self.titleReplies.removeValue(forKey: thread) ?? "")
                    Task { @MainActor in
                        if !name.isEmpty { await self.chat.setTitle(chat, name) }
                        self.nextTitle()
                    }
                }
                return
            }
            if method == "turn/completed", let thread = params["threadId"] as? String,
               let candidate = self.secondLooks.removeValue(forKey: thread) {
                self.secondLookBusy = nil
                if let failure = ((params["turn"] as? JSON)?["error"] as? JSON)?["message"] as? String {
                    self.secondLookProblem[candidate] = EngineError.plain(failure)
                    self.secondLookQueue = []
                    self.recordSecondLookFailure(candidate, EngineError.plain(failure))
                } else {
                    self.secondModelRefusal = nil   // it answered, so whatever stopped it before is over
                }
                self.store.reloadIfChanged()
                if let path = self.store.current?.path { Task { @MainActor in await self.updateRecord(of: path) } }
                self.nextSecondLook()
                self.afterSecondLooks()
            }
            self.chat.handle(method, params)
        }
        engine.onServerRequest = { [weak self] id, method, params in
            guard let self else { return }
            if let thread = params["threadId"] as? String, self.secondLooks[thread] != nil {
                self.engine.respond(to: id, result: ["action": "accept", "content": [:] as JSON])
            } else {
                self.chat.handleRequest(id, method, params)
            }
        }
        store.fetchStatus = { [weak self] path in
            guard let self, self.engine.ready, let text = try? await self.engine.callTool("run_status", ["project": path]) else { return nil }
            return ProjectStore.status(from: text)
        }
        Task { await boot() }
    }

    /// Find the engine and the tools, then start the engine if everything is in place.
    func boot() async {
        starting = true
        let quick = setup.restore()
        if !quick { await setup.detect() }
        // After an update the tools may need new parts. Fetch them without asking, since nothing else works until then.
        if onboarded, !setup.toolsReady, setup.uv != nil, setup.toolsSource != nil { await setup.prepareTools() }
        if let codex = setup.codex, setup.toolsReady {
            await engine.start(codex: codex, toolsBinary: setup.toolsBinary, path: setup.path, extraServers: toolServers)
            if engine.ready {
                if let read = try? await engine.request("account/rateLimits/read"), let limits = read["rateLimits"] as? JSON {
                    chat.usageLeft = ChatModel.left(limits)
                }
                // After a restart, come back to the chat that was open.
                let open = (chat.threads + chat.generalThreads).first { $0.id == chat.active }
                await chat.open(project: store.current?.path)
                if let project = store.current { store.open(project) }
                if let open { await chat.select(open) }
            }
        }
        starting = false
        // Started from what the last check found: check again now, for the next start and for Settings.
        if quick { await setup.detect() }
    }

    // MARK: moving around

    func goHome() {
        sidebarPeek = false
        store.close()
        route = .home
        Task { @MainActor in await chat.open(project: nil) }
    }

    /// Open a project, and with a chat given, show that chat once the project's chat list is open.
    func open(_ project: ProjectRef, showing thread: ChatThread? = nil) {
        sidebarPeek = false
        if route == .home { chat.draft = "" }   // what was typed on Home was for Home, not for this project's chat
        store.open(project)
        route = .chat
        tab = .map
        Task { @MainActor in
            await chat.open(project: project.path)
            if let thread { await chat.select(thread) }
        }
        // Bring the research record up to date (and give an older project its method and history). No model is used.
        Task { @MainActor in await updateRecord(of: project.path) }
    }

    /// Rebuild a project's research record through the tools. It also says whether the project was handed over
    /// without its downloads, which the overview needs to know.
    func updateRecord(of path: String, stoppedDuring stage: String? = nil) async {
        var arguments: JSON = ["project": path]
        if let stage { arguments["stopped_during"] = stage }
        guard engine.ready, let reply = try? await engine.callTool("document_project", arguments),
              let info = (try? JSONSerialization.jsonObject(with: Data(reply.utf8))) as? JSON else { return }
        if store.current?.path == path {
            store.screenedBefore = info["handed_over"] as? Bool == true ? info["screened_before"] as? Int ?? 0 : nil
        }
    }

    func showNotes(_ part: String, file: String? = nil) {
        notesPart = part
        notesFile = file
        tab = .notes
        route = .chat
        if layout == .chat { layout = .split }
    }

    func openChat(_ thread: ChatThread, in project: ProjectRef?) {
        sidebarPeek = false
        if layout == .workspace { layout = .split }
        route = .chat
        // Coming back to the chat that is already open keeps what is on screen, including a run in progress.
        if thread.id == chat.active, project?.path == store.current?.path { return }
        Task { @MainActor in
            if project?.path != store.current?.path {
                if let project { store.open(project) } else { store.close() }
                await chat.open(project: project?.path)
            }
            await chat.select(thread)
        }
    }

    func newChat() {
        sidebarPeek = false
        if layout == .workspace { layout = .split }
        if route != .chat, store.current != nil {
            // From Home, Toolbox or Settings, New chat means a general chat, not one inside whichever project was last open.
            store.close()
            Task { @MainActor in await chat.open(project: nil) }
        } else {
            chat.newChat()
        }
        route = .chat
    }

    func show(_ page: Route) {
        sidebarPeek = false
        route = page
    }

    func showRecords(_ candidate: String? = nil) {
        if let candidate { store.selectedCandidate = candidate }
        tab = .records
        route = .chat
        if layout == .chat { layout = .split }
    }

    func finishOnboarding() {
        onboarded = true
        showWelcome = false
        UserDefaults.standard.set(true, forKey: "onboarded")
    }

    // MARK: projects

    func startProject(from point: StartingPoint = StartingPoints.own) {
        sidebarPeek = false
        draftProject = point
        route = .newProject
    }

    func startProject(from survey: Survey) {
        // Catalog titles run long: "Perry Mesa, AZ: Ancient Agricultural Features…" becomes "Perry Mesa, AZ".
        let short = survey.title.split(separator: ":").first.map(String.init) ?? survey.title
        startProject(from: StartingPoint(
            id: survey.id, kind: .search, title: survey.title, place: "", about: survey.why, source: "OpenTopography",
            name: short.trimmingCharacters(in: .whitespaces),
            question: "Which built features show in this survey, and which of them are already published?",
            box: survey.start.map { String($0) }, dataset: survey.id))
    }

    /// Create a project folder through the tools, so its layout always matches what they expect.
    /// Create the project and, unless told not to, start getting its terrain straight away, so a new project is never left empty.
    /// Made from a general chat, the chat moves into the project and stays on screen, and the person goes on from there.
    func createProject(name: String, question: String, box: [Double], fetch: Bool = true, from start: StartingPoint? = nil,
                       inGitHub: Bool = false) async throws {
        if inGitHub, let problem = Paths.githubProblem { throw EngineError(message: problem) }
        let path = Self.folder(for: name, inGitHub: inGitHub)
        _ = try await engine.callTool("init_project", [
            "project": path, "name": name, "question": question,
            "west": box[0], "south": box[1], "east": box[2], "north": box[3],
        ])
        store.register(path: path)
        if let start, let source = start.chat {
            // What the chat settled becomes the project's first records, committed before the chat moves in.
            _ = try? await engine.callTool("start_from_chat", [
                "project": path, "chat_title": start.title, "why_here": start.whyHere ?? "",
                "sources": start.sources, "ruled_out": start.ruledOut, "conversation": start.conversation ?? "",
            ])
            // The chat stays on screen, and the project starts on its ground in that chat, as any new project does.
            let next = start.searchNow ? "full" : "terrain"
            if await carry(source, into: path), fetch, let flow = ToolGuide.workflows.first(where: { $0.id == next }) { run(flow) }
            return
        }
        if let project = store.projects.first(where: { $0.path == path }) { open(project) }
        if fetch, let flow = ToolGuide.workflows.first(where: { $0.id == "terrain" }) {
            try? await Task.sleep(for: .milliseconds(400))   // let the project's chat list open first
            run(flow)
        }
    }

    /// The folder a new project of this name would get: in ~/Dighouse, or in the GitHub folder when the person asked,
    /// with a number added if the name is taken. A folder already there is never reused.
    static func folder(for name: String, inGitHub: Bool) -> String {
        let base = inGitHub ? Paths.githubHome : Paths.projectsHome
        let slug = name.lowercased().map { $0.isLetter || $0.isNumber ? String($0) : "-" }.joined()
            .split(separator: "-").joined(separator: "-")
        let stem = slug.isEmpty ? "project" : slug
        var path = base.appendingPathComponent(stem).path
        var n = 2
        while FileManager.default.fileExists(atPath: path) {
            path = base.appendingPathComponent("\(stem)-\(n)").path
            n += 1
        }
        return path
    }

    /// Move a general chat into a project and open the project with the chat on screen. Returns whether it moved.
    @discardableResult
    func carry(_ source: String, into path: String) async -> Bool {
        store.register(path: path)
        var moved: ChatThread?
        var problem: String?
        let name = store.projects.first { $0.path == path }?.name
        do { moved = try await chat.move(source, into: path, projectName: name) } catch { problem = error.localizedDescription }
        if let project = store.projects.first(where: { $0.path == path }) {
            sidebarPeek = false
            store.open(project)
            route = .chat
            tab = .map
            await chat.open(project: path)
            if let moved { await chat.select(moved) }
            Task { @MainActor in await updateRecord(of: path) }
        }
        if let problem {
            chat.note("The project is ready, but the chat could not be moved into it: \(problem). It is still under Chats.")
        }
        return moved != nil
    }

    /// Bring the general chat on screen into a project it made (the agent's init_project), with the chat as its first record.
    func bringChat(into path: String) {
        guard store.current == nil, let id = chat.active else {
            store.register(path: path)
            if let project = store.projects.first(where: { $0.path == path }) { open(project) }
            return
        }
        let title = chat.generalThreads.first { $0.id == id }?.title ?? "Chat"
        let conversation = ProjectOffer.conversation(chat.items)
        Task { @MainActor in
            _ = try? await engine.callTool("start_from_chat", ["project": path, "chat_title": title, "conversation": conversation])
            await carry(id, into: path)
        }
    }

    /// Start a project at a place typed by name: the New project page opens with the place looked up and the area set.
    func startProject(at place: String) {
        let name = place.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }
        startProject(from: StartingPoint(
            id: "typed-" + name, kind: .own, title: name, place: "", about: "", source: "",
            name: name, question: "What built features show in the ground at \(name), and which of them are already published?",
            box: ["", "", "", ""], search: name))
    }

    /// Make a project from the general chat on screen. With the agent's offer, the New project page opens filled in
    /// from it, and the chat moves into the project once the person makes it. Without one, the agent is asked for an
    /// offer, which shows as a card in the chat. An empty chat just opens New project.
    func makeProject(_ offer: ProjectOffer? = nil) {
        guard store.current == nil else { return }
        guard let id = chat.active, chat.items.contains(where: { $0.kind == .user }) else { startProject(); return }
        let title = chat.generalThreads.first { $0.id == id }?.title ?? "Chat"
        // A chat that already made a project (the agent's init_project) moves into that one rather than making another.
        if offer == nil, let made = chat.items.last(where: { $0.projectPath != nil })?.projectPath,
           FileManager.default.fileExists(atPath: made + "/PROJECT.md") {
            bringChat(into: made)
            return
        }
        guard let offer = offer
            ?? chat.items.last(where: { $0.tool == "suggest_project" && $0.state == .done }).flatMap({ ProjectOffer(reply: $0.result) }) else {
            ask("Offer this chat as a project: call suggest_project with a name, the question, why this area, and a box under "
                + "6 square km, from what we have settled. If the place or the question is not settled yet, ask me for what is missing.")
            return
        }
        startProject(from: StartingPoint(
            id: "chat-\(id)-\(UUID().uuidString)", kind: .chat, title: title, place: offer.place, about: "", source: "",
            name: offer.name, question: offer.question,
            box: offer.box.map { $0.map { String(format: "%.5f", $0) } } ?? ["", "", "", ""],
            search: offer.box == nil && !offer.place.isEmpty ? offer.place : nil, chat: id, whyHere: offer.whyHere,
            sources: offer.sources, ruledOut: offer.ruledOut, conversation: ProjectOffer.conversation(chat.items),
            inGitHub: offer.inGitHub, searchNow: offer.searchNow))
    }

    /// The next part of the search for the open project, or nil when nothing is ready or a run is going.
    var nextStep: ToolGuide.Workflow? {
        guard store.current != nil, chat.live.isEmpty, secondLookBusy == nil else { return nil }
        let order = store.status.tiles == 0 ? ["terrain"] : ["screen", "check", "second", "prior", "decide"]
        // Once every find has been decided, the search is done; nothing is next.
        if !store.candidates.isEmpty, store.candidates.allSatisfy({ $0.status != "flagged" && $0.status != "ground_confirmed" }) { return nil }
        return order.compactMap { id in ToolGuide.workflows.first { $0.id == id } }.first { state(of: $0).ready }
    }

    func chooseProjectFolder() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.message = "Choose a Dighouse project folder (one that contains PROJECT.md)."
        if panel.runModal() == .OK, let url = panel.url {
            store.register(path: url.path)
            if let project = store.projects.first(where: { $0.path == url.path }) { open(project) }
        }
    }

    /// Save a project as a zip to hand to someone else: its records, notes, sources, reports and history, without the
    /// downloaded data or anything under private/. The research record is brought up to date first.
    /// Returns what happened in plain words, or nil when the person cancelled. Unless quiet, a failure is shown in an alert.
    @discardableResult
    func exportProject(_ project: ProjectRef? = nil, quiet: Bool = false) async -> String? {
        guard let project = project ?? store.current else { return nil }
        let folder = URL(fileURLWithPath: project.path)
        let name = folder.lastPathComponent
        let panel = NSSavePanel()
        panel.nameFieldStringValue = name + ".zip"
        panel.allowedContentTypes = [.zip]
        panel.message = "The records, notes, sources and reports, without downloaded data or locations."
        guard panel.runModal() == .OK, let out = panel.url else { return nil }
        if engine.ready { _ = try? await engine.callTool("document_project", ["project": project.path]) }
        try? FileManager.default.removeItem(at: out)
        let zip = await Shell.run("/usr/bin/zip", ["-r", "-q", out.path, name, "-x", "\(name)/private/*", "\(name)/data/*", "*.DS_Store"],
                                  in: folder.deletingLastPathComponent().path)
        if zip.code == 0 {
            NSWorkspace.shared.selectFile(out.path, inFileViewerRootedAtPath: "")
            return "Saved \(out.lastPathComponent): records, notes, sources and reports, with no downloaded data and nothing from private/."
        }
        let problem = "Could not make the zip. \(zip.out.trimmingCharacters(in: .whitespacesAndNewlines))"
        if !quiet {
            let alert = NSAlert()
            alert.messageText = "The project was not exported"
            alert.informativeText = problem
            alert.runModal()
        }
        return problem
    }

    /// Where publishing the open project stands. It shows as a panel on the project's overview, one step at a time.
    enum PublishStep: Equatable {
        case checking, blocked([String]), confirm(name: String), working(String), done(String), failed(String)
    }

    /// Publish the open project to a private GitHub repository, only ever on the person's press. This checks that no
    /// location would leave this Mac and then asks, in the overview's panel. A project already published just pushes.
    func beginPublish() async {
        guard let project = store.current else { return }
        let path = project.path
        publishing = (path, .checking)
        func set(_ step: PublishStep) { if publishing?.path == path { publishing = (path, step) } }
        guard engine.ready, (try? await engine.callTool("document_project", ["project": path])) != nil,
              let reply = try? await engine.callTool("check_before_publishing", ["project": path]),
              let info = (try? JSONSerialization.jsonObject(with: Data(reply.utf8))) as? JSON else {
            return set(.failed("Dighouse could not check the project first. Try again once the engine is running."))
        }
        let problems = info["problems"] as? [String] ?? []
        guard problems.isEmpty else { return set(.blocked(problems)) }
        if let remote = info["remote"] as? String, !remote.isEmpty {
            set(.working("Sending the new history to GitHub"))
            let push = await Shell.run("/usr/bin/git", ["push", "-q", "origin", "HEAD"], env: publishEnv, in: path)
            return set(push.code == 0 ? .done("The new history is on GitHub. private/ and data/ stayed on this Mac.")
                                      : .failed(push.out.trimmingCharacters(in: .whitespacesAndNewlines)))
        }
        guard let gh = githubTool else {
            return set(.failed("Publishing needs GitHub's command-line tool, gh. Install it from cli.github.com, then run "
                               + "\"gh auth login\" in Terminal once."))
        }
        // Signed in, and a name not already used on the account, so the confirmation names the repository it will make.
        let user = await Shell.run(gh, ["api", "user", "--jq", ".login"], env: publishEnv)
        let login = user.out.trimmingCharacters(in: .whitespacesAndNewlines)
        guard user.code == 0, !login.isEmpty, !login.contains(" ") else {
            return set(.failed("gh is not signed in to GitHub on this Mac. Run \"gh auth login\" in Terminal once, then press Publish again."))
        }
        let base = URL(fileURLWithPath: path).lastPathComponent
        var name = base, n = 2
        while n < 50, await Shell.run(gh, ["repo", "view", "\(login)/\(name)", "--json", "name"], env: publishEnv).code == 0 {
            name = "\(base)-\(n)"
            n += 1
        }
        set(.confirm(name: name))
    }

    /// Open the project's overview, where publishing shows its panel, and start: from /publish or the sidebar.
    func showPublishing() {
        guard store.current != nil else { return }
        route = .chat
        if layout == .workspace { layout = .split }
        if chat.active != nil { chat.newChat() }
        Task { @MainActor in await beginPublish() }
    }

    /// The person pressed Publish privately in the panel.
    func confirmPublish() async {
        guard let (path, step) = publishing, case .confirm(let name) = step, let gh = githubTool else { return }
        publishing = (path, .working("Making the private repository"))
        let made = await Shell.run(gh, ["repo", "create", name, "--private", "--source", path, "--remote", "origin", "--push"],
                                   env: publishEnv, in: path)
        guard publishing?.path == path else { return }
        publishing = (path, made.code == 0 ? .done("Published privately. Only you can see it until you change that on GitHub.")
                                           : .failed(made.out.trimmingCharacters(in: .whitespacesAndNewlines)))
    }

    private var githubTool: String? {
        ["/opt/homebrew/bin/gh", "/usr/local/bin/gh", NSHomeDirectory() + "/.local/bin/gh"].first { FileManager.default.isExecutableFile(atPath: $0) }
    }

    private var publishEnv: [String: String] { ProcessInfo.processInfo.environment.merging(["PATH": setup.path]) { _, new in new } }

    func loadSurveys() async {
        guard engine.ready, !surveysLoading, surveys.isEmpty else { return }
        surveysLoading = true
        surveysProblem = nil
        do {
            let text = try await engine.callTool("open_surveys", [:])
            surveys = Engine.rows(text).compactMap { row in
                guard let title = row["title"] as? String, let w = row["west"] as? Double, let s = row["south"] as? Double,
                      let e = row["east"] as? Double, let n = row["north"] as? Double, let id = row["id"] as? String,
                      let start = row["checked_start"] as? [Double], start.count == 4 else { return nil }
                return Survey(id: id, title: title, collected: row["collected"] as? String ?? "", why: row["why"] as? String ?? "",
                              url: row["landing_page"] as? String ?? "", box: [w, s, e, n], start: start)
            }
        } catch {
            surveysProblem = error.localizedDescription
        }
        surveysLoading = false
    }

    // MARK: workflows

    /// Whether a workflow can run now, and a short note on where it stands.
    func state(of flow: ToolGuide.Workflow) -> (ready: Bool, note: String) {
        guard flow.scope == .project else { return (true, "") }
        guard store.current != nil else { return (false, "Needs a project") }
        if flow.id == "full", runningSearch != nil { return (false, "Running now") }
        let s = store.status, all = store.candidates
        let open = all.filter { $0.status == "flagged" || $0.status == "ground_confirmed" }
        func count(_ n: Int, _ noun: String) -> String { n == 0 ? "Done" : "\(n) \(noun)" }
        switch flow.id {
        case "terrain": return (true, s.tiles > 0 ? "Done" : "")
        case "screen": return (s.unscreened > 0, s.tiles == 0 ? "Needs the ground" : count(s.unscreened, "tiles left"))
        case "check":
            let n = open.filter { $0.checks["section"] == nil || $0.checks["modern"] == nil }.count
            return (n > 0, all.isEmpty ? "Needs finds" : count(n, "to check"))
        case "second":
            let n = open.filter { $0.checks["second_look"] == nil }.count
            if n > 0, refusedSecondModel != nil { return (false, "Second model refused") }
            return (n > 0 && secondModelID != nil, all.isEmpty ? "Needs finds" : secondModelID == nil ? "Choose a second model" : count(n, "to ask"))
        case "prior":
            let n = open.filter { $0.sources.isEmpty }.count
            return (n > 0, all.isEmpty ? "Needs finds" : count(n, "to search"))
        case "decide":
            let unprepared = open.filter { $0.suggestion == nil }.count
            return (unprepared > 0, all.isEmpty ? "Needs finds" : open.isEmpty ? "All decided" : unprepared == 0 ? "Prepared" : "\(unprepared) to prepare")
        case "report":
            let n = all.filter { $0.status == "no_match_in_sources_read" }.count
            return (n > 0, n == 0 ? "Needs a decided find" : "\(n) ready")
        default: return (true, "")
        }
    }

    func run(_ flow: ToolGuide.Workflow) {
        guard state(of: flow).ready else { return }
        if flow.scope == .general, store.current != nil { store.close() }
        if flow.id == "second" {
            secondLookQueue = store.candidates
                .filter { ($0.status == "flagged" || $0.status == "ground_confirmed") && $0.checks["second_look"] == nil }.map(\.id)
            showRecords(secondLookQueue.first)
            nextSecondLook()
        } else if flow.scope == .general, chat.project != nil || route != .chat {
            // From a project, or from Home, the Toolbox or Settings, a workflow that needs no project starts a chat of its own.
            route = .chat
            Task { @MainActor in
                await chat.open(project: nil)
                await chat.send(flow.prompt, title: flow.title)
            }
        } else if flow.id == "full" {
            // A whole search runs as a goal, so the engine keeps taking turns until the report is written.
            route = .chat
            if layout == .workspace { layout = .split }
            chat.newChat()
            let path = store.current?.path
            Task { @MainActor in
                await chat.setGoal(flow.prompt, title: flow.title)
                if let id = chat.active, let path, chat.running { investigating[id] = path }
            }
        } else {
            ask(flow.prompt, title: flow.title)
        }
    }

    // MARK: find and report back

    /// The whole search running in the open project, if there is one: the chat it runs in.
    var runningSearch: String? {
        guard let path = store.current?.path else { return nil }
        // A goal takes turn after turn, so it counts as running between turns too.
        return investigating.first { $0.value == path && (chat.goals.contains($0.key) || chat.live[$0.key] != nil) }?.key
    }

    /// The stage a run is on: from the last tool its agent called, or else from what the project still lacks.
    func stage(of thread: String) -> (number: Int, title: String, icon: String) {
        // Until every tile has been looked at, the project's own state says the stage: the agent often reads a source
        // while the ground downloads, and that is not the search being on stage 4. After that, the stage only moves forward,
        // so going back to cut another slice does not step it back.
        var index = store.tiles.isEmpty ? 0 : store.tiles.contains { $0.status == "unscreened" } ? 1 : 2
        if index == 2, let reached = chat.furthest[thread] { index = max(index, reached) }
        return (index + 1, ToolGuide.stages[index].title, ToolGuide.stages[index].icon)
    }

    /// The newest search report in the open project.
    var latestReport: String? {
        guard let root = store.current?.path else { return nil }
        let files = ((try? FileManager.default.contentsOfDirectory(atPath: root + "/reports")) ?? []).filter { $0.hasSuffix("-search-report.md") }
        return files.sorted().last.map { root + "/reports/" + $0 }
    }

    /// Find and report back from a place typed by name: look it up, make a project around it, and start the whole search.
    func investigate(at place: String) {
        let name = place.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty, placeBusy == nil, let flow = ToolGuide.workflows.first(where: { $0.id == "full" }) else { return }
        placeBusy = name
        placeProblem = nil
        Task { @MainActor in
            defer { placeBusy = nil }
            do {
                let found = Engine.rows(try await engine.callTool("find_place", ["query": name]))
                guard let first = found.first, let lat = first["lat"] as? Double, let lon = first["lon"] as? Double else {
                    placeProblem = "No place called \(name) was found. Add the region or country, or pick the area on the map."
                    return
                }
                // A square 600 m across around the place: nine tiles or so, which a first search finishes in minutes.
                let north = 300 / 110_540.0, east = 300 / (111_320.0 * max(cos(lat * .pi / 180), 0.2))
                let box = [lon - east, lat - north, lon + east, lat + north]
                // Make sure open data covers the place before a project is made and the model spends time on it.
                let data = Engine.rows(try await engine.callTool("find_data", ["west": box[0], "south": box[1], "east": box[2], "north": box[3]]))
                let usable = data.filter { $0["id"] != nil && $0["needs_token"] as? Bool != true }
                if usable.isEmpty {
                    let place = (first["name"] as? String).map { String($0.split(separator: ",").prefix(2).joined(separator: ",")) } ?? name
                    if let errors = data.compactMap({ $0["errors"] as? [String] }).first, !errors.isEmpty {
                        placeProblem = "The open catalogs did not all answer, so Dighouse could not tell what covers \(place). Try again in a minute."
                    } else if data.contains(where: { $0["needs_token"] as? Bool == true }) {
                        placeProblem = "\(place) is covered only by data that needs a free token. Paste it in Settings, Data and privacy, then try again."
                    } else {
                        placeProblem = "No open lidar or sonar Dighouse reads covers \(place). How it works, on Home, shows where it can look; you can also give the agent your own ground model."
                    }
                    return
                }
                try await createProject(name: name, question: "What built features show in the ground at \(name), and which of them are already published?",
                                        box: box, fetch: false)
                chat.draft = ""
                try? await Task.sleep(for: .milliseconds(400))   // let the project's chat list open first
                run(flow)
            } catch {
                placeProblem = error.localizedDescription
            }
        }
    }

    /// A whole search's goal has stopped being worked on. Unless the person stopped it, report what there is.
    private func searchEnded(_ thread: String, _ status: String) async {
        guard let path = investigating.removeValue(forKey: thread), status != "paused" else { return }
        if status != "complete", chat.active == thread {
            let why = ["usageLimited": "the account's usage ran out", "budgetLimited": "it reached its limit"][status] ?? "the agent could not go on"
            chat.note("The search stopped before it finished: \(why). The report covers what was done up to here.")
        }
        store.reloadIfChanged()
        // The second look has to come from a different model, so Dighouse asks for it itself, then writes the report.
        if store.current?.path == path, secondModelID != nil, refusedSecondModel == nil, let flow = ToolGuide.workflows.first(where: { $0.id == "second" }), state(of: flow).ready {
            reportAfterLooks = path
            run(flow)
        } else {
            await writeReport(path)
        }
    }

    /// When the last second look is back, write the report that was waiting for it.
    private func afterSecondLooks() {
        guard secondLookBusy == nil, secondLookQueue.isEmpty, let path = reportAfterLooks else { return }
        reportAfterLooks = nil
        Task { @MainActor in await writeReport(path) }
    }

    /// Rebuild the search report from the project's records and show it, when its project is the one open.
    /// The agent's own advice in it is kept.
    func writeReport(_ path: String) async {
        guard engine.ready, let reply = try? await engine.callTool("write_report", ["project": path]),
              let info = (try? JSONSerialization.jsonObject(with: Data(reply.utf8))) as? JSON, let file = info["written"] as? String else { return }
        store.reloadIfChanged()
        if store.current?.path == path {
            tab = .map
            reportShown = path + "/" + file
        }
    }

    /// Put a request in the message box of a new chat, for the person to change or send.
    /// The chat belongs to the open project when there is one, since most requests are about it.
    func draft(_ text: String) {
        sidebarPeek = false
        route = .chat
        if layout == .workspace { layout = .split }
        Task { @MainActor in
            if store.current == nil { await chat.open(project: nil) } else { chat.newChat() }
            chat.draft = text
        }
    }

    /// Ask a question that belongs to no project, in a new general chat.
    func askGeneral(_ text: String) {
        sidebarPeek = false
        route = .chat
        Task { @MainActor in
            if store.current != nil { store.close() }
            await chat.open(project: nil)
            await chat.send(text)
        }
    }

    /// Send a message to the agent, making sure the chat is on screen.
    func ask(_ text: String, title: String? = nil) {
        sidebarPeek = false
        route = .chat
        if layout == .workspace { layout = .split }
        Task { @MainActor in await chat.send(text, title: title) }
    }

    /// Record the person's own decision on a candidate.
    func decide(_ c: Candidate, status: String, reason: String) async throws {
        guard let project = store.current else { return }
        _ = try await engine.callTool("set_status", [
            "project": project.path, "candidate": c.id, "status": status, "decided_by": userName, "reason": reason,
        ])
        store.reloadIfChanged()
    }

    private func nextSecondLook() {
        guard secondLookBusy == nil, !secondLookQueue.isEmpty else { return }
        let id = secondLookQueue.removeFirst()
        if let candidate = store.candidates.first(where: { $0.id == id }) { secondLook(candidate) }
    }

    /// Queue a chat for a short name, written by the agent model from the message it began with.
    func nameLater(_ chat: String, _ text: String) {
        guard !titled.contains(chat) else { return }
        titled.insert(chat)
        titleQueue.append((chat, text))
        if titleJobs.isEmpty { nextTitle() }
    }

    /// Name one chat at a time, so a list of old chats does not send a burst of requests.
    private func nextTitle() {
        guard titleJobs.isEmpty, !titleQueue.isEmpty else { return }
        let job = titleQueue.removeFirst()
        Task { @MainActor in
            for _ in 0..<60 where !engine.ready { try? await Task.sleep(for: .seconds(1)) }
            guard let model = self.model else { return }
            do {
                let started = try await engine.request("thread/start", [
                    "cwd": Paths.support.path, "ephemeral": true, "approvalPolicy": "never", "sandbox": "read-only", "model": model.id,
                ])
                guard let id = (started["thread"] as? JSON)?["id"] as? String else { throw EngineError(message: "No chat was created.") }
                titleJobs[id] = job.chat
                let prompt = "Write a title of two to five words for a chat that begins with the message below. Use plain words "
                    + "in sentence case (a capital only for the first word and for names), with lidar in lowercase, no quotes, no full stop and no coordinates. Reply with the title only and use no tools.\n\nMessage:\n"
                    + String(job.text.prefix(600))
                var params: JSON = ["threadId": id, "model": model.id, "input": [["type": "text", "text": prompt]]]
                if let low = ["minimal", "low"].first(where: model.efforts.contains) { params["effort"] = low }
                _ = try await engine.request("turn/start", params)
            } catch {
                nextTitle()
            }
        }
    }

    /// The first line of a model's reply, without quotes or a full stop, at most six words.
    static func cleanTitle(_ reply: String) -> String {
        let line = reply.split(whereSeparator: \.isNewline).first.map(String.init) ?? ""
        let bare = line.trimmingCharacters(in: CharacterSet(charactersIn: " \"'*#.`“”‘’"))
        return bare.split(separator: " ").prefix(6).joined(separator: " ")
    }

    /// Ask a different model for an independent opinion on a candidate, in its own short conversation.
    /// A second opinion that could not be had goes on the project's record, so the report says it was asked for.
    private func recordSecondLookFailure(_ candidate: String, _ reason: String) {
        // A refusal by the provider will happen again on the next find, so remember it until the person chooses another model.
        let lower = reason.lowercased()
        if let id = secondModelID, ["403", "401", "permission", "disabled", "forbidden", "not found", "unauthorized", "access denied"].contains(where: lower.contains) {
            secondModelRefusal = ["model": id, "reason": String(reason.prefix(300))]
        }
        guard let path = store.current?.path else { return }
        let model = secondModelName
        Task { @MainActor in
            _ = try? await engine.callTool("second_look_failed", ["project": path, "candidate": candidate, "model": model, "reason": reason])
            store.reloadIfChanged()
        }
    }

    func secondLook(_ c: Candidate) {
        guard let project = store.current, let model = secondModelID, secondLookBusy == nil else { return }
        secondLookBusy = c.id
        secondLookProblem[c.id] = nil
        let prompt = """
        You are giving an independent second opinion on a possible archaeological feature. Do not read the candidate's \
        record, the notes, or any other file. Call view_tile for tile \(c.tile) of project \(project.path) in the \
        composite style, then again in the local_relief style. The feature sits about \(Int(c.x * 100)) percent across \
        and \(Int(c.y * 100)) percent down the tile. Decide whether what is there looks built by people. Then call \
        second_look with candidate \(c.id), your verdict as agrees, model "\(secondModelName)", and a one-sentence note. \
        Do nothing else.
        """
        Task { @MainActor in
            do {
                let started = try await engine.request("thread/start", [
                    "cwd": project.path, "ephemeral": true, "approvalPolicy": "never", "sandbox": "read-only", "model": model,
                ])
                guard let id = (started["thread"] as? JSON)?["id"] as? String else { throw EngineError(message: "No chat was created.") }
                secondLooks[id] = c.id
                _ = try await engine.request("turn/start", ["threadId": id, "model": model, "input": [["type": "text", "text": prompt]]])
            } catch {
                secondLookBusy = nil
                secondLookQueue = []
                secondLookProblem[c.id] = error.localizedDescription
                recordSecondLookFailure(c.id, error.localizedDescription)
                afterSecondLooks()
            }
        }
    }
}

extension View {
    func withApp(_ app: AppState) -> some View {
        self.environmentObject(app)
            .environmentObject(app.setup)
            .environmentObject(app.engine)
            .environmentObject(app.store)
            .environmentObject(app.chat)
            .preferredColorScheme(.dark)
    }
}

/// Receives files dropped on the Dock icon or opened with Dighouse, however many arrive at once.
final class AppDelegate: NSObject, NSApplicationDelegate {
    var openFiles: (([URL]) -> Void)?

    func application(_ application: NSApplication, open urls: [URL]) { openFiles?(urls.filter(\.isFileURL)) }
}

@main
struct DighouseApp: App {
    @StateObject private var app = AppState()
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate

    /// A file dropped on the Dock icon, or opened with Dighouse, is attached to the message being written.
    private func attach(_ files: [URL]) {
        files.filter(\.isFileURL).forEach { app.chat.attach($0.path) }
        if app.route != .home, app.route != .chat { app.route = .chat }
    }

    var body: some Scene {
        Window("Dighouse", id: "main") {
            RootView()
                .withApp(app)
                .frame(minWidth: 560, maxWidth: .infinity, minHeight: 520, maxHeight: .infinity)
                .onOpenURL { attach([$0]) }
                .onAppear { delegate.openFiles = attach }
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentMinSize)
        .defaultSize(width: 1380, height: 880)
        .commands {
            CommandGroup(replacing: .appSettings) {
                Button("Settings…") { app.show(.settings) }.keyboardShortcut(",")
            }
            CommandGroup(replacing: .newItem) {
                Button("New Chat") { app.newChat() }.keyboardShortcut("n")
                Button("New Project…") { app.startProject() }.keyboardShortcut("n", modifiers: [.command, .shift])
                Divider()
                Button("Open Project Folder…") { app.chooseProjectFolder() }.keyboardShortcut("o")
                FileMenuExport(app: app, store: app.store)
            }
            CommandGroup(after: .sidebar) { ViewMenu(app: app) }
            CommandMenu("Project") { ProjectMenu(app: app, store: app.store, chat: app.chat) }
            CommandGroup(replacing: .help) {
                Button("Welcome Guide") { app.showWelcome = true }
                Button("First Project Tutorial") { app.startTutorial() }
                Button("Commands and Shortcuts") { app.route = .chat; app.chat.note(SlashCommands.help) }.keyboardShortcut("/")
                Button("How a Search Works") { UserDefaults.standard.set(ToolboxView.Tab.how.rawValue, forKey: "toolboxTab"); app.show(.toolbox) }
                Divider()
                Link("Dighouse on GitHub", destination: URL(string: "https://github.com/chrissotraidis/dighouse")!)
            }
        }
    }
}

// MARK: - The menu bar

/// File › Export Project. A view of its own so it follows the open project.
private struct FileMenuExport: View {
    @ObservedObject var app: AppState
    @ObservedObject var store: ProjectStore

    var body: some View {
        Button { Task { await app.exportProject() } } label: {
            Text("Export Project…")
            if store.current == nil { Text("Open a project first") }
        }
        .keyboardShortcut("e", modifiers: [.command, .shift]).disabled(store.current == nil)
    }
}

/// View: the three layouts, the sidebar, the two ways to find things, the two pages, and text size.
private struct ViewMenu: View {
    @ObservedObject var app: AppState

    var body: some View {
        ForEach(Array(PaneLayout.allCases.enumerated()), id: \.element) { index, layout in
            Toggle((PaneLayout.names[layout] ?? "").titleCased, isOn: Binding(get: { app.layout == layout }, set: { _ in app.layout = layout }))
                .keyboardShortcut(KeyEquivalent(Character("\(index + 1)")))
        }
        Divider()
        Button(app.sidebarVisible ? "Hide Sidebar" : "Show Sidebar") { app.sidebarVisible.toggle() }
            .keyboardShortcut("s", modifiers: [.command, .control])
        Divider()
        Button("Jump To…") { app.jumping = true }.keyboardShortcut("k")
        Button("Find a Chat…") { app.findingChat = true }.keyboardShortcut("f", modifiers: [.command, .shift])
        Divider()
        Button("Home") { app.goHome() }.keyboardShortcut("0")
        Button("Toolbox") { app.show(.toolbox) }.keyboardShortcut("t")
        Divider()
        Button("Bigger Text") { step(1) }.keyboardShortcut("+").disabled(app.textSize == TextSize.all.last?.id)
        Button("Smaller Text") { step(-1) }.keyboardShortcut("-").disabled(app.textSize == TextSize.all.first?.id)
        Picker("Text Size", selection: $app.textSize) {
            ForEach(TextSize.all, id: \.id) { size in Text(size.name).tag(size.id) }
        }
        Divider()
    }

    private func step(_ by: Int) {
        let i = (TextSize.all.firstIndex { $0.id == app.textSize } ?? 1) + by
        guard TextSize.all.indices.contains(i) else { return }
        app.textSize = TextSize.all[i].id
        // Say which size it is, briefly, since the change itself can be small.
        let note = "Text size: \(TextSize.all[i].name)"
        app.sizeNote = note
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(1.4))
            if app.sizeNote == note { app.sizeNote = nil }
        }
    }
}

/// Project: each part of a search, the review, the research record, and the folder. An item that cannot run says why.
private struct ProjectMenu: View {
    @ObservedObject var app: AppState
    @ObservedObject var store: ProjectStore
    @ObservedObject var chat: ChatModel

    var body: some View {
        let none = store.current == nil
        ForEach(ToolGuide.workflows.filter { $0.scope == .project }) { flow in
            let state = app.state(of: flow)
            Button { app.run(flow) } label: {
                Text(flow.title.titleCased)
                if !state.ready { Text(state.note == "Done" ? "Nothing left to do" : state.note.isEmpty ? "Not ready yet" : state.note) }
            }
            .disabled(!state.ready)
        }
        Divider()
        Button { app.reviewing = true } label: {
            Text("Review the Finds…")
            if store.candidates.isEmpty { Text(none ? "Needs a project" : "Needs finds") }
        }
        .keyboardShortcut("r").disabled(store.candidates.isEmpty)
        Button { app.showNotes("record") } label: {
            Text("Research Record")
            if none { Text("Needs a project") }
        }
        .keyboardShortcut("r", modifiers: [.command, .shift]).disabled(none)
        Button { app.reportShown = app.latestReport } label: {
            Text("Search Report")
            if app.latestReport == nil { Text(none ? "Needs a project" : "No report yet") }
        }
        .disabled(app.latestReport == nil)
        Divider()
        Button { if let path = store.current?.path { NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: path) } } label: {
            Text("Show in Finder")
            if none { Text("Needs a project") }
        }
        .disabled(none)
        Divider()
        Button { Task { await chat.stop() } } label: {
            Text("Stop the Run")
            if !chat.running { Text("Nothing is running") }
        }
        .keyboardShortcut(".").disabled(!chat.running)
    }
}

extension String {
    /// Menu-bar capitals: "Run the whole search" becomes "Run the Whole Search".
    var titleCased: String {
        let small: Set<String> = ["a", "an", "the", "and", "or", "of", "to", "in", "on", "for", "by", "at"]
        let words = split(separator: " ").map(String.init)
        return words.enumerated().map { i, word in
            i > 0 && i < words.count - 1 && small.contains(word) ? word : word.prefix(1).uppercased() + word.dropFirst()
        }.joined(separator: " ")
    }
}

struct RootView: View {
    @EnvironmentObject var app: AppState

    var body: some View {
        ZStack {
            Theme.bg.ignoresSafeArea()
            if !app.onboarded || app.showWelcome {
                WelcomeView()
            } else {
                MainView()
            }
        }
        .foregroundStyle(Theme.text)
        .tint(Theme.accent)
        .id("\(app.look.rawValue)-\(app.textSize)")   // colours and sizes are read when a view is built, so a change rebuilds the window
        .overlay(alignment: .top) {
            if let note = app.sizeNote {
                Text(note).font(.system(size: 12.5, weight: .medium)).foregroundStyle(Theme.text)
                    .padding(.horizontal, 14).frame(height: 30)
                    .background(Capsule().fill(Theme.pop).shadow(color: .black.opacity(0.35), radius: 10, y: 3))
                    .overlay(Capsule().strokeBorder(Theme.line))
                    .padding(.top, 58)
                    .transition(.opacity.combined(with: .offset(y: -6)))
                    .accessibilityAddTraits(.updatesFrequently)
            }
        }
        .animation(Motion.ease(0.18), value: app.sizeNote)
    }
}

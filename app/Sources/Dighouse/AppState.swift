import SwiftUI

/// The one thing the window is showing.
enum Route: Equatable {
    case home, chat, newProject, toolbox, settings
}

enum PaneLayout: String {
    case chat, split, workspace
}

enum WorkTab: String, CaseIterable {
    case map = "Map", records = "Records", notes = "Notes"
}

enum SettingsSection: String, CaseIterable {
    case general = "General", models = "Models", engine = "How it runs", privacy = "Data and privacy", about = "About"
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
    @Published var sidebarWidth = UserDefaults.standard.object(forKey: "sidebarWidth") as? Double ?? 256 {
        didSet { UserDefaults.standard.set(sidebarWidth, forKey: "sidebarWidth") }
    }
    @Published var modelID: String? = UserDefaults.standard.string(forKey: "model") {
        didSet { UserDefaults.standard.set(modelID, forKey: "model") }
    }
    @Published var secondModelID: String? = UserDefaults.standard.string(forKey: "secondModel") {
        didSet { UserDefaults.standard.set(secondModelID, forKey: "secondModel") }
    }
    @Published var effort: String? = UserDefaults.standard.string(forKey: "effort") {
        didSet { UserDefaults.standard.set(effort, forKey: "effort") }
    }
    @Published var userName = UserDefaults.standard.string(forKey: "userName") ?? NSFullUserName() {
        didSet { UserDefaults.standard.set(userName, forKey: "userName") }
    }
    @Published var toolServers: [ToolServer] = (UserDefaults.standard.data(forKey: "toolServers"))
        .flatMap { try? JSONDecoder().decode([ToolServer].self, from: $0) } ?? [] {
        didSet { UserDefaults.standard.set(try? JSONEncoder().encode(toolServers), forKey: "toolServers") }
    }

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
                    + "The person sees the map, the tiles and the records beside this chat, so do not paste images or file contents. "
                    + "Do not record a second look yourself: the person asks a different model for it from the record. " + shared
            }
            return self.setup.skill + "\n\nYou are running inside the Dighouse app and no project is open. Help the person choose "
                + "where to look, or answer their question. New projects go inside \(Paths.projectsHome.path): pass a new folder "
                + "there as the project argument to init_project. After creating one, tell the person to open it from the card "
                + "in the chat. " + shared
        }
        chat.onToolFinished = { [weak self] tool, args in
            guard let self else { return }
            if tool == "init_project", let path = args["project"] as? String { self.store.register(path: path) }
            self.store.reloadIfChanged()
            if ["view_tile", "cut_section", "flag_candidate", "record_verdict"].contains(tool), let tile = args["tile"] as? String {
                self.store.selectedTile = tile
            }
            if let candidate = args["candidate"] as? String { self.store.selectedCandidate = candidate }
        }
        engine.onNotification = { [weak self] method, params in
            guard let self else { return }
            if method == "turn/completed", let thread = params["threadId"] as? String,
               let candidate = self.secondLooks.removeValue(forKey: thread) {
                self.secondLookBusy = nil
                if let failure = ((params["turn"] as? JSON)?["error"] as? JSON)?["message"] as? String {
                    self.secondLookProblem[candidate] = EngineError.plain(failure)
                    self.secondLookQueue = []
                }
                self.store.reloadIfChanged()
                self.nextSecondLook()
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
        await setup.detect()
        // After an update the tools may need new parts. Fetch them without asking, since nothing else works until then.
        if onboarded, !setup.toolsReady, setup.uv != nil, setup.toolsSource != nil { await setup.prepareTools() }
        if let codex = setup.codex, setup.toolsReady {
            await engine.start(codex: codex, toolsBinary: setup.toolsBinary, path: setup.path, extraServers: toolServers)
            if engine.ready {
                await chat.open(project: store.current?.path)
                if let project = store.current { store.open(project) }
            }
        }
        starting = false
    }

    // MARK: moving around

    func goHome() {
        sidebarPeek = false
        store.close()
        route = .home
        Task { @MainActor in await chat.open(project: nil) }
    }

    func open(_ project: ProjectRef) {
        sidebarPeek = false
        store.open(project)
        route = .chat
        tab = .map
        Task { @MainActor in await chat.open(project: project.path) }
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
    func createProject(name: String, question: String, box: [Double]) async throws {
        let slug = name.lowercased().map { $0.isLetter || $0.isNumber ? String($0) : "-" }.joined()
            .split(separator: "-").joined(separator: "-")
        var path = Paths.projectsHome.appendingPathComponent(slug.isEmpty ? "project" : slug).path
        var n = 2
        while FileManager.default.fileExists(atPath: path) {
            path = Paths.projectsHome.appendingPathComponent("\(slug)-\(n)").path
            n += 1
        }
        _ = try await engine.callTool("init_project", [
            "project": path, "name": name, "question": question,
            "west": box[0], "south": box[1], "east": box[2], "north": box[3],
        ])
        store.register(path: path)
        if let project = store.projects.first(where: { $0.path == path }) { open(project) }
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
        let s = store.status, all = store.candidates
        let open = all.filter { $0.status == "flagged" || $0.status == "ground_confirmed" }
        func count(_ n: Int, _ noun: String) -> String { n == 0 ? "Done" : "\(n) \(noun)" }
        switch flow.id {
        case "terrain": return (true, s.tiles > 0 ? "Done" : "")
        case "screen": return (s.unscreened > 0, s.tiles == 0 ? "Needs terrain" : count(s.unscreened, "tiles left"))
        case "check":
            let n = open.filter { $0.checks["section"] == nil || $0.checks["modern"] == nil }.count
            return (n > 0, all.isEmpty ? "Needs candidates" : count(n, "to check"))
        case "second":
            let n = open.filter { $0.checks["second_look"] == nil }.count
            return (n > 0 && secondModelID != nil, all.isEmpty ? "Needs candidates" : secondModelID == nil ? "Choose a second model" : count(n, "to ask"))
        case "prior":
            let n = open.filter { $0.sources.isEmpty }.count
            return (n > 0, all.isEmpty ? "Needs candidates" : count(n, "to search"))
        case "decide": return (!all.isEmpty, all.isEmpty ? "Needs candidates" : "\(open.count) open")
        case "report":
            let n = all.filter { $0.status == "no_match_in_sources_read" }.count
            return (n > 0, n == 0 ? "Needs a decided candidate" : "\(n) ready")
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
        } else if flow.scope == .general, chat.project != nil {
            route = .chat
            Task { @MainActor in
                await chat.open(project: nil)
                await chat.send(flow.prompt, title: flow.title)
            }
        } else {
            ask(flow.prompt, title: flow.title)
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

    /// Ask a different model for an independent opinion on a candidate, in its own short conversation.
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
            }
            CommandGroup(after: .sidebar) {
                Button("Home") { app.goHome() }.keyboardShortcut("0")
                Button("Toolbox") { app.show(.toolbox) }.keyboardShortcut("t")
                Divider()
                Button(app.sidebarVisible ? "Hide Sidebar" : "Show Sidebar") { app.sidebarVisible.toggle() }
                    .keyboardShortcut("s", modifiers: [.command, .control])
                Button("Chat Only") { app.layout = .chat }.keyboardShortcut("1")
                Button("Chat and Workspace") { app.layout = .split }.keyboardShortcut("2")
                Button("Workspace Only") { app.layout = .workspace }.keyboardShortcut("3")
                Divider()
            }
            CommandMenu("Run") {
                ForEach(ToolGuide.workflows.filter { $0.scope == .project }) { flow in
                    Button(flow.title) { app.run(flow) }.disabled(!app.state(of: flow).ready)
                }
                Divider()
                Button("Stop") { Task { await app.chat.stop() } }
                    .keyboardShortcut(".").disabled(!app.chat.running)
            }
            CommandGroup(replacing: .help) {
                Button("Welcome Guide") { app.showWelcome = true }
                Button("Toolbox: Tools and Workflows") { app.show(.toolbox) }
                Divider()
                Link("Dighouse on GitHub", destination: URL(string: "https://github.com/chrissotraidis/dighouse")!)
            }
        }
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
    }
}

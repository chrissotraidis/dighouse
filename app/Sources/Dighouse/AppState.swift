import SwiftUI

enum PaneLayout: String {
    case chat, split, workspace
}

enum WorkTab: String, CaseIterable {
    case map = "Map", records = "Records", tools = "Tools"
}

@MainActor
final class AppState: ObservableObject {
    let setup = Setup()
    let engine = Engine()
    let store = ProjectStore()
    let chat = ChatModel()

    @Published var onboarded = UserDefaults.standard.bool(forKey: "onboarded")
    @Published var showWelcome = false
    @Published var exploring = false
    @Published var starting = true
    @Published var sidebarVisible = true
    @Published var sidebarPeek = false
    @Published var tab = WorkTab.map
    @Published var newProject: StartingPoint?
    @Published var secondLookBusy: String?
    @Published var secondLookProblem: [String: String] = [:]
    @Published var layout = PaneLayout(rawValue: UserDefaults.standard.string(forKey: "layout") ?? "") ?? .split {
        didSet { UserDefaults.standard.set(layout.rawValue, forKey: "layout") }
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

    private var secondLooks: [String: String] = [:]

    /// True when the Explore page is showing instead of a project.
    var onStart: Bool { exploring || store.current == nil }

    var model: ModelInfo? {
        let id = modelID ?? engine.defaultModel
        return engine.models.first { $0.id == id }
    }
    var modelName: String { model?.name ?? modelID ?? engine.defaultModel ?? "Default model" }
    var secondModelName: String { engine.models.first { $0.id == secondModelID }?.name ?? "Choose a model" }
    var activeEffort: String? {
        guard let model, !model.efforts.isEmpty else { return nil }
        if let effort, model.efforts.contains(effort) { return effort }
        return model.defaultEffort
    }

    init() {
        chat.engine = engine
        chat.model = { [weak self] in self?.modelID }
        chat.effort = { [weak self] in
            guard let self, let effort = self.effort, self.model?.efforts.contains(effort) == true else { return nil }
            return effort
        }
        chat.instructions = { [weak self] in
            guard let self, let project = self.store.current else { return "" }
            return self.setup.skill + "\n\nYou are running inside the Dighouse app. The open project folder is \(project.path). "
                + "Pass that path as the project argument to every dighouse tool. Keep replies short and plain. "
                + "The person sees the map, the tiles and the records beside this chat, so do not paste images or file contents. "
                + "Do not record a second look yourself: the person asks a different model for it from the record."
        }
        chat.onToolFinished = { [weak self] tool, args in
            guard let self else { return }
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
                }
                self.store.reloadIfChanged()
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
        if let codex = setup.codex, setup.toolsReady {
            await engine.start(codex: codex, toolsBinary: setup.toolsBinary, path: setup.path)
            if engine.ready {
                await chat.open(project: store.current?.path)
                if let project = store.current { store.open(project) }
            }
        }
        starting = false
    }

    func open(_ project: ProjectRef) {
        exploring = false
        sidebarPeek = false
        store.open(project)
        Task { await chat.open(project: project.path) }
    }

    func openChat(_ thread: ChatThread) {
        exploring = false
        sidebarPeek = false
        if layout == .workspace { layout = .split }
        Task { await chat.select(thread) }
    }

    func newChat() {
        guard store.current != nil else { exploring = true; return }
        exploring = false
        sidebarPeek = false
        if layout == .workspace { layout = .split }
        chat.newChat()
    }

    func show(_ tab: WorkTab) {
        exploring = false
        self.tab = tab
        if layout == .chat { layout = .split }
    }

    func finishOnboarding() {
        onboarded = true
        showWelcome = false
        UserDefaults.standard.set(true, forKey: "onboarded")
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
        store.add(path: path)
        exploring = false
        await chat.open(project: path)
    }

    func chooseProjectFolder() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.message = "Choose a Dighouse project folder (one that contains PROJECT.md)."
        if panel.runModal() == .OK, let url = panel.url {
            store.add(path: url.path)
            if let project = store.current, project.path == url.path { open(project) }
        }
    }

    /// Send a message to the agent, making sure the chat is on screen.
    func ask(_ text: String) {
        exploring = false
        if layout == .workspace { layout = .split }
        Task { @MainActor in await chat.send(text) }
    }

    /// Record the person's own decision on a candidate.
    func decide(_ c: Candidate, status: String, reason: String) async throws {
        guard let project = store.current else { return }
        _ = try await engine.callTool("set_status", [
            "project": project.path, "candidate": c.id, "status": status, "decided_by": userName, "reason": reason,
        ])
        store.reloadIfChanged()
    }

    /// Ask a different model for an independent opinion on a candidate, in its own short conversation.
    func secondLook(_ c: Candidate) {
        guard let project = store.current, let model = secondModelID else { return }
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

@main
struct DighouseApp: App {
    @StateObject private var app = AppState()

    var body: some Scene {
        Window("Dighouse", id: "main") {
            RootView()
                .withApp(app)
                .frame(minWidth: 560, maxWidth: .infinity, minHeight: 520, maxHeight: .infinity)
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentMinSize)
        .defaultSize(width: 1380, height: 880)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("New Chat") { app.newChat() }.keyboardShortcut("n")
                Button("New Project…") { app.newProject = StartingPoints.own }.keyboardShortcut("n", modifiers: [.command, .shift])
                Divider()
                Button("Open Project Folder…") { app.chooseProjectFolder() }.keyboardShortcut("o")
                Button("Explore Starting Points") { app.exploring = true }.keyboardShortcut("e", modifiers: [.command, .shift])
            }
            CommandGroup(after: .sidebar) {
                Button(app.sidebarVisible ? "Hide Sidebar" : "Show Sidebar") { app.sidebarVisible.toggle() }
                    .keyboardShortcut("s", modifiers: [.command, .control])
                Divider()
                Button("Chat Only") { app.layout = .chat }.keyboardShortcut("1")
                Button("Chat and Workspace") { app.layout = .split }.keyboardShortcut("2")
                Button("Workspace Only") { app.layout = .workspace }.keyboardShortcut("3")
                Divider()
                Button("Map") { app.show(.map) }.keyboardShortcut("4")
                Button("Records") { app.show(.records) }.keyboardShortcut("5")
                Button("Tools") { app.show(.tools) }.keyboardShortcut("6")
                Divider()
            }
            CommandMenu("Run") {
                ForEach(ToolGuide.stages) { stage in
                    Button(stage.title) { app.ask(stage.prompt) }.disabled(app.store.current == nil)
                }
                Divider()
                Button("Stop") { Task { await app.chat.stop() } }
                    .keyboardShortcut(".").disabled(!app.chat.running)
            }
            CommandGroup(replacing: .help) {
                Button("Welcome Guide") { app.showWelcome = true }
                Button("Tools and How a Search Works") { app.show(.tools) }
                Divider()
                Link("Dighouse on GitHub", destination: URL(string: "https://github.com/chrissotraidis/dighouse")!)
            }
        }

        Settings {
            SettingsView().withApp(app)
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
        .sheet(item: $app.newProject) { point in
            NewProjectSheet(point: point).withApp(app)
        }
    }
}

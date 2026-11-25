import SwiftUI

/// The window: sidebar, top bar, and one page at a time.
struct MainView: View {
    @EnvironmentObject var app: AppState
    @EnvironmentObject var engine: Engine
    @EnvironmentObject var store: ProjectStore
    @EnvironmentObject var setup: Setup
    @EnvironmentObject var chat: ChatModel

    var body: some View {
        GeometryReader { geo in
            let narrow = geo.size.width < 860
            let sidebar = app.sidebarVisible && !narrow
            let side = min(max(app.sidebarWidth, 200), 420)
            let width = geo.size.width - (sidebar ? side + 1 : 0)
            HStack(spacing: 0) {
                if sidebar {
                    Sidebar().frame(width: side)
                    SplitHandle(width: $app.sidebarWidth, range: 200...min(420, max(Double(geo.size.width) - 520, 200)),
                                help: "Drag to resize the sidebar")
                }
                VStack(spacing: 0) {
                    TopBar(inset: !sidebar, narrow: narrow, width: width)
                    CoachBar()
                    page(width: width)
                }
            }
            .overlay(alignment: .leading) {
                if narrow && app.sidebarPeek {
                    ZStack(alignment: .leading) {
                        Color.black.opacity(0.45).onTapGesture { app.sidebarPeek = false }
                        Sidebar().frame(width: 256).shadow(color: .black.opacity(0.5), radius: 24)
                    }
                }
            }
        }
        .ignoresSafeArea(edges: .top)
        // A page from one project's sources does not follow the person into another project.
        .onChange(of: store.current?.path) { app.browserURL = nil }
        .background(GeometryReader { geo in
            Color.clear.onAppear { app.windowSize = geo.size }.onChange(of: geo.size) { _, size in app.windowSize = size }
        })
        .sheet(isPresented: $app.choosingDuration) { ResearchDurationSheet().environmentObject(app) }
        .sheet(isPresented: $app.reviewing) { DecideView().withApp(app) }
        .sheet(isPresented: $app.testPicking) { TestPicker().withApp(app) }
        // On the window, not the sidebar, so they open when the sidebar is hidden too.
        .sheet(isPresented: $app.findingChat) { FindChatSheet().withApp(app) }
        .sheet(isPresented: $app.jumping) { CommandPalette().withApp(app) }
        .sheet(isPresented: Binding(get: { app.reportShown != nil }, set: { if !$0 { app.reportShown = nil } })) {
            if let file = app.reportShown { ReportSheet(file: file).withApp(app) }
        }
        .modifier(RenameChat())
        // The tutorial moves on when the project or the page changes in the way its step asked for.
        .onChange(of: "\(app.tab.rawValue) \(store.tiles.count) \(store.tiles.filter { $0.status == "unscreened" }.count) \(store.candidates.count) \(store.candidates.filter { !$0.decisions.isEmpty }.count) \(chat.running) \(store.current?.path ?? "")") { _, _ in
            app.advanceTutorial()
        }
    }

    @ViewBuilder private func page(width: CGFloat) -> some View {
        if !engine.ready {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    let stopped = !app.starting && setup.codex != nil && setup.toolsReady && engine.problem != nil
                    Text(app.starting ? "Starting Dighouse" : stopped ? "The Codex engine stopped" : "Dighouse needs a few things")
                        .font(.system(size: 22 * Theme.scale, weight: .semibold))
                    if stopped {
                        Text("Dighouse runs every chat through the Codex engine, and it is not running now. Your projects, records and chats are safe on this Mac. Restart it to carry on; a run that was going will need to be started again.")
                            .font(.system(size: 14 * Theme.scale)).foregroundStyle(Theme.dim).lineSpacing(3).fixedSize(horizontal: false, vertical: true)
                        if let problem = engine.problem, problem != "The Codex engine stopped." {
                            Text(problem).font(.system(size: 12.5 * Theme.scale)).foregroundStyle(Theme.faint).fixedSize(horizontal: false, vertical: true)
                        }
                        Button { Task { await app.boot() } } label: { Label("Restart the engine", systemImage: "arrow.clockwise") }
                            .buttonStyle(PrimaryButton())
                    } else if app.starting {
                        DigIndicator()
                        if setup.toolsBusy {
                            Text("Preparing the archaeology tools. This takes about a minute the first time and after an update.")
                                .font(.system(size: 13 * Theme.scale)).foregroundStyle(Theme.dim).fixedSize(horizontal: false, vertical: true)
                        }
                    } else { SetupChecklist() }
                }
                .padding(28).frame(maxWidth: 640, alignment: .leading).frame(maxWidth: .infinity)
            }
        } else {
            switch app.route {
            case .home: HomeView()
            case .newProject: NewProjectView(point: app.draftProject).id(app.draftProject.id)
            case .toolbox: ToolboxView()
            case .settings:
                SettingsPage()
                    // Escape goes back where Settings was opened from, wherever the focus is.
                    .background(Button("") { app.closeSettings() }.keyboardShortcut(.escape, modifiers: [])
                        .opacity(0).frame(width: 0, height: 0).accessibilityHidden(true))
            case .chat:
                if store.current == nil { ChatView() } else { split(width: width) }
            }
        }
    }

    private func split(width: CGFloat) -> some View {
        let mode: PaneLayout = app.layout == .split && width < 720 ? .chat : app.layout
        let most = max(Double(width) - 300, 320)
        return HStack(spacing: 0) {
            if mode != .workspace {
                ChatView()
                    .frame(width: mode == .split ? min(max(app.chatWidth, 320), most) : nil)
                    .frame(maxWidth: mode == .chat ? .infinity : nil)
            }
            if mode == .split { SplitHandle(width: $app.chatWidth, range: 320...most, help: "Drag to resize the chat") }
            if mode != .chat { WorkspaceView() }
        }
    }
}

/// Always on screen: where you are and, in a project, where its run stands.
struct TopBar: View {
    let inset: Bool
    let narrow: Bool
    let width: CGFloat
    @EnvironmentObject var app: AppState
    @EnvironmentObject var store: ProjectStore
    @EnvironmentObject var chat: ChatModel
    @EnvironmentObject var engine: Engine

    private var inProject: Bool { app.route == .chat && store.current != nil }
    @AppStorage("toolboxTab") private var toolboxTab = ToolboxView.Tab.how.rawValue

    private var title: String {
        switch app.route {
        case .home: return "Home"
        case .newProject: return "New project"
        case .toolbox:
            // Where you are in the Toolbox: its tab, and the source open in it.
            return (["Toolbox", toolboxTab] + [app.toolboxDetail].compactMap { $0 }).joined(separator: "  ›  ")
        case .settings: return "Settings"
        case .chat: return store.current?.name ?? chat.title
        }
    }

    var body: some View {
        let s = store.status
        HStack(spacing: 8) {
            Button {
                if narrow { app.sidebarPeek.toggle() } else { app.sidebarVisible.toggle() }
            } label: { Image(systemName: "sidebar.left") }
                .buttonStyle(IconButton()).help("Show or hide the sidebar")
            Text(title).font(.system(size: 14 * Theme.scale, weight: .semibold)).lineLimit(1)
            if inProject, width > 640 { stats(s) }
            Spacer(minLength: 8)
            if let problem = engine.problem {
                Button { app.settingsSection = .engine; app.show(.settings) } label: { Badge(text: problem, color: Theme.amber) }
                    .buttonStyle(.plain)
            } else if inProject {
                // A whole search shows the trowel in the strip, beside its stage.
                if chat.running, app.runningSearch == nil || width <= 640 { DigIndicator().padding(.trailing, 2) }
                // The same count the overview and Decide show.
                if !store.decideWords.isEmpty {
                    Button { app.openDecide() } label: { Badge(text: store.decideWords, color: Theme.accent) }
                        .buttonStyle(.plain).help("Open Decide")
                }
                LayoutSwitch()
            }
        }
        .padding(.leading, inset ? 84 : 10).padding(.trailing, 12)
        .frame(height: 48)
        .background(WindowDragArea())
        .overlay(alignment: .bottomLeading) {
            GeometryReader { geo in
                ZStack(alignment: .bottomLeading) {
                    Hairline().frame(maxHeight: .infinity, alignment: .bottom)
                    if inProject, s.progress > 0 {
                        Rectangle().fill(Theme.accent).frame(width: geo.size.width * s.progress, height: 2)
                    }
                }
            }
            .allowsHitTesting(false)
        }
    }

    @ViewBuilder private func stats(_ s: RunStatus) -> some View {
        HStack(spacing: 8) {
            if let search = app.runningSearch {
                // A whole search: the stage it is on, and a way to stop it.
                let stage = app.stage(of: search)
                Text("·").foregroundStyle(Theme.faint)
                DigIndicator(size: 13)
                Text("Stage \(stage.number) of \(ToolGuide.stages.count): \(stage.title)").foregroundStyle(Theme.text).fontWeight(.medium)
                    .accessibilityLabel("The search is on stage \(stage.number) of \(ToolGuide.stages.count): \(stage.title)")
                Button("Stop") { Task { await chat.stop(chat: search) } }
                    .buttonStyle(.plain).font(.system(size: 12.5 * Theme.scale, weight: .medium)).foregroundStyle(Theme.accent)
                    .help("Stop the search. What it has done is kept, and the research record says where it stopped.")
            } else if app.reportAfterLooks != nil, app.reportAfterLooks == store.current?.path {
                // The agent is done; a second model is being asked about each find before the report is shown.
                Text("·").foregroundStyle(Theme.faint)
                DigIndicator(size: 13)
                Text("Asking a second model, then the report").foregroundStyle(Theme.text).fontWeight(.medium)
            }
            if let d = store.download {
                let name = d.dataset.split(separator: ":").last.map(String.init) ?? d.dataset
                piece(d.total > 0 ? "Downloading \(name): \(d.done) of \(d.total) parts" + (d.left.map { ", \($0)" } ?? "") : "Downloading \(name)")
                Button("Cancel") {
                    // The tools check for this file between parts, since stopping the agent does not stop a tool already running.
                    if let root = store.current?.path {
                        FileManager.default.createFile(atPath: root + "/private/state/stop-download", contents: Data())
                    }
                    Task { await chat.stopAll() }
                }
                    .buttonStyle(.plain).font(.system(size: 12.5 * Theme.scale, weight: .medium)).foregroundStyle(Theme.accent)
                    .help("Stop the download and the agent. Nothing half-downloaded is added to the project.")
            } else if s.tiles == 0 {
                piece(store.terrains.isEmpty ? (store.screenedBefore.map { "Shared with you, \($0) tile\($0 == 1 ? "" : "s") looked at before" } ?? "No ground yet")
                      : "Ground ready, not cut into tiles")
            } else {
                piece("\(s.screened) of \(s.readable) tiles looked at")
                if s.unreadable > 0, width > 900 { piece("\(s.unreadable) unreadable") }
                if s.controls > 0, width > 900 { piece("\(s.controlsFound) of \(s.controls) known sites found again") }
            }
            piece("\(s.candidates) find\(s.candidates == 1 ? "" : "s")")
            if let next = app.nextStep, store.download == nil {
                Button { app.run(next) } label: {
                    HStack(spacing: 6) {
                        Glyph(name: next.icon, size: 12.5 * Theme.scale, weight: .medium)
                        Text("Next: \(next.title)").font(.system(size: 12.5 * Theme.scale, weight: .medium))
                    }
                }
                .buttonStyle(.plain).foregroundStyle(Theme.accent).padding(.leading, 6)
                .help(next.summary)
                .coach(next.id == "screen" ? .screen : nil, radius: 8)
            }
        }
        .font(.system(size: 12.5 * Theme.scale)).lineLimit(1)
    }

    private func piece(_ text: String) -> some View {
        HStack(spacing: 8) {
            Text("·").foregroundStyle(Theme.faint)
            Text(text).foregroundStyle(Theme.dim)
        }
    }
}

/// Chat only, chat beside the workspace, or the workspace only.
struct LayoutSwitch: View {
    @EnvironmentObject var app: AppState

    var body: some View {
        HStack(spacing: 2) {
            ForEach(PaneLayout.allCases, id: \.self) { layout in
                Button { app.layout = layout } label: { Image(systemName: layout.icon) }
                    .buttonStyle(IconButton(size: 28, active: app.layout == layout)).help(PaneLayout.names[layout] ?? "")
            }
        }
        .padding(2)
        .background(RoundedRectangle(cornerRadius: 10).fill(Theme.ink.opacity(0.05)))
    }
}

struct Sidebar: View {
    @EnvironmentObject var app: AppState
    @EnvironmentObject var store: ProjectStore
    @EnvironmentObject var chat: ChatModel
    @EnvironmentObject var engine: Engine
    /// Projects whose fold the person flipped: the open project is unfolded unless flipped, any other folded unless flipped.
    @State private var flipped: Set<String> = []
    @AppStorage("sidebarTestsOpen") private var testsOpen = false
    /// The row under the pointer and the row whose menu is open. A right-click opens the menu of the row it lands on.
    @State private var hovered: String?
    @State private var menuFor: String?
    @State private var clicks: Any?
    @State private var frames = RowFrames.Box()

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Color.clear.frame(height: 40).background(WindowDragArea())
            HStack(spacing: 9) {
                // The mark and the name are the way home, as a logo is on a website.
                Button { app.goHome() } label: {
                    HStack(spacing: 9) {
                        MoundMark(working: !chat.live.isEmpty || app.secondLookBusy != nil || app.starting, lively: true).frame(width: 34, height: 15)
                        Text("Dighouse").font(.system(size: 15 * Theme.scale, weight: .bold))
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help(chat.live.isEmpty && app.secondLookBusy == nil ? "Go to Home" : "The agent is working. Go to Home")
                .accessibilityLabel("Dighouse, go to Home")
                Spacer()
            }
            .padding(.horizontal, 10).padding(.bottom, 8)
            nav("square.and.pencil", "New chat", selected: app.route == .chat && store.current == nil && chat.active == nil) { app.newChat() }
            nav("house", "Home", selected: app.route == .home) { app.goHome() }
            nav("wrench.and.screwdriver", "Toolbox", selected: app.route == .toolbox) { app.show(.toolbox) }
            nav("magnifyingglass", "Find a chat", selected: false) { app.findingChat = true }

            ScrollView {
                VStack(alignment: .leading, spacing: 2) {
                    // Projects first: a project is where work lives, with its chats folded under it.
                    HStack {
                        header("Projects")
                        Spacer()
                        Button { app.startProject() } label: { Image(systemName: "plus") }
                            .buttonStyle(IconButton(size: 24, active: app.route == .newProject)).help("New project")
                    }
                    ForEach(store.projects.filter { !store.blindTests.contains($0.path) }) { project in projectRows(project) }
                    if store.projects.isEmpty {
                        EmptyLine(icon: "dig.grid", text: "No projects yet. Start one from Home.").padding(.horizontal, 10)
                    }
                    if !chat.generalThreads.isEmpty {
                        header("Chats")
                        ForEach(chat.generalThreads) { thread in chatRow(thread, in: nil, indent: 0) }
                    }
                    blindTestRows
                }
            }
            .padding(.top, 6)
            // A fold is remembered only while the project keeps its place: opening another project resets both rows.
            .onChange(of: store.current?.path) { old, new in
                if let old { flipped.remove(old) }
                if let new { flipped.remove(new) }
            }

            Hairline().padding(.vertical, 6)
            if !engine.ready {
                Button { app.settingsSection = .engine; app.show(.settings) } label: {
                    Label("Engine not running", systemImage: "exclamationmark.triangle").font(.system(size: 13 * Theme.scale)).foregroundStyle(Theme.amber)
                }
                .buttonStyle(RowButton())
            }
            // Work going on in the background, from every page: one quiet line with a count.
            if app.secondOpinionsLeft > 0 {
                HStack(spacing: 8) {
                    if app.opinionsWaiting == nil { DigIndicator() } else { Image(systemName: "pause.circle").foregroundStyle(Theme.amber) }
                    Text("Second opinions: \(app.secondOpinionsLeft) left").font(.system(size: 12 * Theme.scale)).foregroundStyle(Theme.faint)
                }
                .padding(.horizontal, 12).padding(.bottom, 4)
                .help(app.opinionsWaiting ?? "A second model is looking at each open find on its own. The records fill in as the answers come back.")
            }
            nav("gearshape", "Settings", selected: app.route == .settings) { app.toggleSettings() }
        }
        .padding(.horizontal, 8).padding(.bottom, 10)
        .frame(maxHeight: .infinity, alignment: .top)
        .background(Theme.side)
        .onPreferenceChange(RowFrames.self) { frames.value = $0 }
        .onAppear {
            // A right-click, or a click with Control held, opens the same menu as a row's "…" button.
            clicks = NSEvent.addLocalMonitorForEvents(matching: [.rightMouseDown, .leftMouseDown]) { event in
                guard event.type == .rightMouseDown || event.modifierFlags.contains(.control),
                      let window = event.window, window === NSApp.mainWindow, let content = window.contentView else { return event }
                let at = CGPoint(x: event.locationInWindow.x, y: content.bounds.height - event.locationInWindow.y)
                guard let id = frames.value.first(where: { $0.value.contains(at) })?.key else { return event }
                menuFor = id
                return nil
            }
        }
        .onDisappear {
            if let clicks { NSEvent.removeMonitor(clicks) }
            clicks = nil
        }
    }

    /// Gives a row its menu: a "…" button while the pointer is over it, and the same menu on a right-click.
    private func rowMenu(_ id: String, _ what: String, entries: @escaping () -> [MenuEntry]) -> some View {
        Group {
            if hovered == id || menuFor == id {
                Button { menuFor = id } label: { Image(systemName: "ellipsis") }
                    .buttonStyle(IconButton(size: 24)).help("More").accessibilityLabel("More for \(what)")
                    .popover(isPresented: Binding(get: { menuFor == id }, set: { if !$0, menuFor == id { menuFor = nil } }), arrowEdge: .trailing) {
                        MenuPanel(entries: entries(), width: 220) { menuFor = nil }.popoverSurface()
                    }
                    .padding(.trailing, 4)
            }
        }
    }

    private func hover(_ id: String, _ inside: Bool) {
        if inside { hovered = id } else if hovered == id { hovered = nil }
    }

    /// Reports where a row sits in the window, so a right-click can find the row under it.
    private func place(_ id: String) -> some View {
        GeometryReader { geo in Color.clear.preference(key: RowFrames.self, value: [id: geo.frame(in: .global)]) }
    }

    private func header(_ title: String) -> some View {
        Text(title).font(.system(size: 12 * Theme.scale, weight: .medium)).foregroundStyle(Theme.faint)
            .padding(.leading, 10).padding(.top, 12).padding(.bottom, 2)
    }

    private func nav(_ icon: String, _ title: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            // The icons differ in width, so each sits in a column of its own and the words line up.
            HStack(spacing: 9) {
                Glyph(name: icon, size: 13.5 * Theme.scale).frame(width: 20)
                Text(title).font(.system(size: 13.5 * Theme.scale))
            }
        }
        .buttonStyle(RowButton(selected: selected))
    }

    private func chatRow(_ thread: ChatThread, in project: ProjectRef?, indent: CGFloat) -> some View {
        let selected = app.route == .chat && chat.active == thread.id
        let menu = hovered == thread.id || menuFor == thread.id
        return Button { app.openChat(thread, in: project) } label: {
            HStack(spacing: 6) {
                Text(thread.label).font(.system(size: 13 * Theme.scale)).lineLimit(1).foregroundStyle(selected ? Theme.text : Theme.dim)
                Spacer(minLength: 0)
                if chat.live[thread.id] != nil { DigIndicator(size: 13) }
            }
            .padding(.trailing, menu ? 24 : 0)
        }
        .buttonStyle(RowButton(selected: selected))
        .overlay(alignment: .trailing) {
            rowMenu(thread.id, thread.title) {
                [MenuEntry(title: "Rename…", icon: "pencil") { app.renameRequest = thread },
                 .divider,
                 MenuEntry(title: "Archive", icon: "archivebox") { Task { await chat.archive(thread) } }]
            }
        }
        .onHover { hover(thread.id, $0) }
        .background(place(thread.id))
        .padding(.leading, indent)
    }

    /// Blind tests, folded into one group under the chats: each is a known site scored against its key.
    @ViewBuilder private var blindTestRows: some View {
        let tests = store.projects.filter { store.blindTests.contains($0.path) }
        if !tests.isEmpty {
            let open = testsOpen || tests.contains { $0 == store.current }
            Button { testsOpen.toggle() } label: {
                HStack(spacing: 6) {
                    Text("Blind tests").font(.system(size: 12 * Theme.scale, weight: .medium)).foregroundStyle(Theme.faint)
                    Text("\(tests.count)").font(.system(size: 12 * Theme.scale)).foregroundStyle(Theme.faint.opacity(0.7))
                    Image(systemName: "chevron.right").font(.system(size: 8 * Theme.scale, weight: .bold)).foregroundStyle(Theme.faint)
                        .rotationEffect(.degrees(open ? 90 : 0))
                    Spacer()
                }
                .padding(.leading, 10).padding(.top, 12).padding(.bottom, 2).contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help(open ? "Hide the blind tests" : "Show the blind tests: known sites the method was scored on")
            if open {
                ForEach(tests) { project in projectRows(project) }
            }
        }
    }

    @ViewBuilder private func projectRows(_ project: ProjectRef) -> some View {
        let current = project == store.current
        let open = current != flipped.contains(project.path)
        let threads = chat.chats(in: project.path)
        let working = threads.contains { chat.live[$0.id] != nil || chat.goals.contains($0.id) }
        // The name opens the project's overview; only the arrow folds its chats away.
        Button {
            if current { app.newChat(inProject: true) } else { app.open(project) }
        } label: {
            HStack(spacing: 8) {
                Color.clear.frame(width: 16, height: 20)   // room for the fold button laid over the row
                Text(project.name).font(.system(size: 13.5 * Theme.scale)).lineLimit(1)
                Spacer(minLength: 0)
                if working { DigIndicator(size: 13).help("One of its chats is working") }
                else if !open, !threads.isEmpty {
                    Text("\(threads.count)").font(.system(size: 11.5 * Theme.scale)).foregroundStyle(Theme.faint)
                        .help("\(threads.count) chat\(threads.count == 1 ? "" : "s")")
                }
            }
            .padding(.trailing, hovered == project.path || menuFor == project.path ? 24 : 0)
        }
        .buttonStyle(RowButton(selected: current && app.route == .chat && chat.active == nil))
        // A button of its own, so the keyboard and VoiceOver can fold a project as well as a pointer can.
        .overlay(alignment: .leading) {
            Button {
                if flipped.contains(project.path) { flipped.remove(project.path) } else { flipped.insert(project.path) }
                if !current, !open { Task { await chat.listChats(in: project.path) } }
            } label: {
                Image(systemName: "chevron.right").font(.system(size: 9 * Theme.scale, weight: .bold)).foregroundStyle(Theme.faint)
                    .rotationEffect(.degrees(open ? 90 : 0)).frame(width: 16, height: 20).contentShape(Rectangle())
            }
            .buttonStyle(.plain).padding(.leading, 10)
            .help(open ? "Hide this project's chats" : "Show this project's chats")
            .accessibilityLabel((open ? "Fold " : "Unfold ") + project.name)
        }
        .overlay(alignment: .trailing) {
            rowMenu(project.path, project.name) {
                [MenuEntry(title: "Research record", icon: "book.closed") {
                    if !current { app.open(project) }
                    app.showNotes("record")
                 },
                 MenuEntry(title: "Show in Finder", icon: "folder") { NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: project.path) },
                 MenuEntry(title: "Export project…", icon: "square.and.arrow.up") { Task { await app.exportProject(project) } },
                 MenuEntry(title: "Publish to GitHub…", icon: "arrow.up.circle") {
                    if !current { app.open(project) }
                    app.showPublishing()
                 },
                 .divider,
                 MenuEntry(title: "Remove from list", icon: "minus.circle", detail: nil) {
                    if current { app.goHome() }
                    store.remove(project)
                 }]
            }
        }
        .onHover { hover(project.path, $0) }
        .background(place(project.path))
        if open {
            ForEach(threads) { thread in chatRow(thread, in: project, indent: 18) }
        }
    }
}


/// The rename box for a chat, asked for by /rename or a chat's menu in the sidebar.
private struct RowFrames: PreferenceKey {
    /// Kept outside the view's state, so scrolling the sidebar does not redraw it.
    final class Box { var value: [String: CGRect] = [:] }
    static var defaultValue: [String: CGRect] = [:]
    static func reduce(value: inout [String: CGRect], nextValue: () -> [String: CGRect]) { value.merge(nextValue()) { $1 } }
}

private struct RenameChat: ViewModifier {
    @EnvironmentObject var app: AppState
    @EnvironmentObject var chat: ChatModel
    @State private var renaming: ChatThread?
    @State private var newName = ""

    func body(content: Content) -> some View {
        content
            .onChange(of: app.renameRequest) { _, thread in
                guard let thread else { return }
                newName = thread.title
                renaming = thread
                app.renameRequest = nil
            }
            .alert("Rename chat", isPresented: Binding(get: { renaming != nil }, set: { if !$0 { renaming = nil } })) {
                TextField("Name", text: $newName)
                Button("Rename") {
                    if let thread = renaming { Task { await chat.rename(thread, to: newName) } }
                }
                Button("Cancel", role: .cancel) {}
            }
    }
}

private struct ResearchDurationSheet: View {
    @EnvironmentObject var app: AppState
    @State private var minutes = 60
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Find something").font(.system(size: 18 * Theme.scale, weight: .semibold))
            Text("The agent picks a region with open lidar and little on record, where it can check finds against a site register if one is open, then searches it area by area and checks every find until the time is up. A second model gives its opinion on each area as it is finished. You decide what reaches you. You can stop it at any point.")
                .font(.system(size: 12.5 * Theme.scale)).foregroundStyle(Theme.dim).fixedSize(horizontal: false, vertical: true)
            Picker("How long", selection: $minutes) {
                // Under half an hour a session ends before its first sweep is looked at.
                ForEach([30, 60, 120, 240, 300, 480], id: \.self) { value in
                    Text(value < 60 ? "\(value) minutes" : value == 60 ? "1 hour" : "\(value / 60) hours").tag(value)
                }
            }
            .font(.system(size: 13 * Theme.scale))
            HStack(spacing: 8) {
                Spacer()
                Button("Cancel") { app.choosingDuration = false }.buttonStyle(SecondaryButton()).keyboardShortcut(.cancelAction)
                Button("Start") { app.startTimedResearch(minutes: minutes) }.buttonStyle(PrimaryButton()).keyboardShortcut(.defaultAction)
            }
        }
        .padding(24).frame(width: 420)
        .background(Theme.bg).foregroundStyle(Theme.text)
        .closesOnOutsideClick { app.choosingDuration = false }
    }
}

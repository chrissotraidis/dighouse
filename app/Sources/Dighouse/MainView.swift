import SwiftUI

/// The window: sidebar, top bar, and one page at a time.
struct MainView: View {
    @EnvironmentObject var app: AppState
    @EnvironmentObject var engine: Engine
    @EnvironmentObject var store: ProjectStore
    @EnvironmentObject var setup: Setup

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
    }

    @ViewBuilder private func page(width: CGFloat) -> some View {
        if !engine.ready {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Text(app.starting ? "Starting Dighouse" : "Dighouse needs a few things").font(.system(size: 22, weight: .semibold))
                    if app.starting {
                        ProgressView().controlSize(.small)
                        if setup.toolsBusy {
                            Text("Preparing the archaeology tools. This takes about a minute the first time and after an update.")
                                .font(.system(size: 13)).foregroundStyle(Theme.dim).fixedSize(horizontal: false, vertical: true)
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
            case .settings: SettingsPage()
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

    private var title: String {
        switch app.route {
        case .home: return "Home"
        case .newProject: return "New project"
        case .toolbox: return "Toolbox"
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
            Text(title).font(.system(size: 14, weight: .semibold)).lineLimit(1)
            if inProject, width > 640 { stats(s) }
            Spacer(minLength: 8)
            if let problem = engine.problem {
                Button { app.settingsSection = .engine; app.show(.settings) } label: { Badge(text: problem, color: Theme.amber) }
                    .buttonStyle(.plain)
            } else if inProject {
                if chat.running { ProgressView().controlSize(.small).padding(.trailing, 2) }
                if !s.needsPerson.isEmpty {
                    Button { app.showRecords(s.needsPerson.first) } label: {
                        Badge(text: "\(s.needsPerson.count) need\(s.needsPerson.count == 1 ? "s" : "") you", color: Theme.accent)
                    }
                    .buttonStyle(.plain).help("Candidates waiting for your decision")
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
            if s.tiles == 0 {
                piece("No terrain yet")
            } else {
                piece("Screened \(s.screened) of \(s.readable) tiles")
                if s.unreadable > 0, width > 900 { piece("\(s.unreadable) unreadable") }
                if s.controls > 0, width > 900 { piece("\(s.controlsFound) of \(s.controls) known sites found again") }
            }
            piece("\(s.candidates) candidate\(s.candidates == 1 ? "" : "s")")
        }
        .font(.system(size: 12.5)).lineLimit(1)
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
            option(.chat, "bubble.left", "Chat only")
            option(.split, "rectangle.split.2x1", "Chat and workspace")
            option(.workspace, "map", "Workspace only")
        }
        .padding(2)
        .background(RoundedRectangle(cornerRadius: 10).fill(Theme.ink.opacity(0.05)))
    }

    private func option(_ layout: PaneLayout, _ icon: String, _ help: String) -> some View {
        Button { app.layout = layout } label: { Image(systemName: icon) }
            .buttonStyle(IconButton(size: 28, active: app.layout == layout)).help(help)
    }
}

struct Sidebar: View {
    @EnvironmentObject var app: AppState
    @EnvironmentObject var store: ProjectStore
    @EnvironmentObject var chat: ChatModel
    @EnvironmentObject var engine: Engine
    @State private var collapsed: Set<String> = []
    @State private var renaming: ChatThread?
    @State private var newName = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Color.clear.frame(height: 40).background(WindowDragArea())
            HStack(spacing: 9) {
                MoundMark(working: !chat.live.isEmpty || app.secondLookBusy != nil || app.starting, lively: true).frame(width: 34, height: 15)
                    .help(chat.live.isEmpty && app.secondLookBusy == nil ? "Dighouse" : "The agent is working")
                Text("Dighouse").font(.system(size: 15, weight: .bold))
                Spacer()
            }
            .padding(.horizontal, 10).padding(.bottom, 8)
            nav("square.and.pencil", "New chat", selected: app.route == .chat && store.current == nil && chat.active == nil) { app.newChat() }
            nav("house", "Home", selected: app.route == .home) { app.goHome() }
            nav("wrench.and.screwdriver", "Toolbox", selected: app.route == .toolbox) { app.show(.toolbox) }

            ScrollView {
                VStack(alignment: .leading, spacing: 2) {
                    if !chat.generalThreads.isEmpty {
                        header("Chats")
                        ForEach(chat.generalThreads) { thread in chatRow(thread, in: nil, indent: 0) }
                    }
                    HStack {
                        header("Projects")
                        Spacer()
                        Button { app.startProject() } label: { Image(systemName: "plus") }
                            .buttonStyle(IconButton(size: 24, active: app.route == .newProject)).help("New project")
                    }
                    ForEach(store.projects) { project in projectRows(project) }
                    if store.projects.isEmpty {
                        Text("No projects yet. Start one from Home.")
                            .font(.system(size: 12.5)).foregroundStyle(Theme.faint).padding(.horizontal, 10).padding(.vertical, 6)
                    }
                }
            }
            .padding(.top, 6)

            Hairline().padding(.vertical, 6)
            if !engine.ready {
                Button { app.settingsSection = .engine; app.show(.settings) } label: {
                    Label("Engine not running", systemImage: "exclamationmark.triangle").font(.system(size: 13)).foregroundStyle(Theme.amber)
                }
                .buttonStyle(RowButton())
            }
            nav("gearshape", "Settings", selected: app.route == .settings) { app.show(.settings) }
        }
        .padding(.horizontal, 8).padding(.bottom, 10)
        .frame(maxHeight: .infinity, alignment: .top)
        .background(Theme.side)
        .alert("Rename chat", isPresented: Binding(get: { renaming != nil }, set: { if !$0 { renaming = nil } })) {
            TextField("Name", text: $newName)
            Button("Rename") {
                if let thread = renaming { Task { await chat.rename(thread, to: newName) } }
            }
            Button("Cancel", role: .cancel) {}
        }
    }

    private func header(_ title: String) -> some View {
        Text(title).font(.system(size: 12, weight: .medium)).foregroundStyle(Theme.faint)
            .padding(.leading, 10).padding(.top, 12).padding(.bottom, 2)
    }

    private func nav(_ icon: String, _ title: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: icon).font(.system(size: 13.5))
        }
        .buttonStyle(RowButton(selected: selected))
    }

    private func chatRow(_ thread: ChatThread, in project: ProjectRef?, indent: CGFloat) -> some View {
        let selected = app.route == .chat && chat.active == thread.id
        return Button { app.openChat(thread, in: project) } label: {
            HStack(spacing: 6) {
                Text(thread.title).font(.system(size: 13)).lineLimit(1).foregroundStyle(selected ? Theme.text : Theme.dim)
                Spacer(minLength: 0)
                if chat.live[thread.id] != nil { ProgressView().controlSize(.mini) }
            }
        }
        .buttonStyle(RowButton(selected: selected))
        .padding(.leading, indent)
        .contextMenu {
            Button("Rename…") {
                newName = thread.title
                renaming = thread
            }
            Button("Archive") { Task { await chat.archive(thread) } }
        }
    }

    @ViewBuilder private func projectRows(_ project: ProjectRef) -> some View {
        let current = project == store.current
        let open = current && !collapsed.contains(project.path)
        Button {
            if current && app.route == .chat && chat.active == nil {
                if open { collapsed.insert(project.path) } else { collapsed.remove(project.path) }
            } else {
                collapsed.remove(project.path)
                if current { app.newChat() } else { app.open(project) }
            }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "chevron.right").font(.system(size: 9, weight: .bold)).foregroundStyle(Theme.faint)
                    .rotationEffect(.degrees(open ? 90 : 0)).frame(width: 10)
                Text(project.name).font(.system(size: 13.5)).lineLimit(1)
            }
        }
        .buttonStyle(RowButton(selected: current && app.route == .chat && chat.active == nil))
        .contextMenu {
            Button("Show in Finder") { NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: project.path) }
            Button("Remove from List") {
                if current { app.goHome() }
                store.remove(project)
            }
        }
        if open {
            ForEach(chat.threads) { thread in chatRow(thread, in: project, indent: 18) }
        }
    }
}

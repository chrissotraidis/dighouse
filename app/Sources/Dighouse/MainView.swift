import SwiftUI

/// The window: sidebar, top bar, and the chat and workspace panes, arranged to fit the width available.
struct MainView: View {
    @EnvironmentObject var app: AppState
    @EnvironmentObject var engine: Engine

    var body: some View {
        GeometryReader { geo in
            let narrow = geo.size.width < 900
            let sidebar = app.sidebarVisible && !narrow
            let width = geo.size.width - (sidebar ? 261 : 0)
            HStack(spacing: 0) {
                if sidebar {
                    Sidebar().frame(width: 260)
                    Hairline(vertical: true)
                }
                VStack(spacing: 0) {
                    TopBar(inset: !sidebar, narrow: narrow, width: width)
                    content(width: width)
                }
            }
            .overlay(alignment: .leading) {
                if narrow && app.sidebarPeek {
                    ZStack(alignment: .leading) {
                        Color.black.opacity(0.45).onTapGesture { app.sidebarPeek = false }
                        Sidebar().frame(width: 260).shadow(color: .black.opacity(0.5), radius: 24)
                    }
                }
            }
        }
        .ignoresSafeArea(edges: .top)
    }

    @ViewBuilder private func content(width: CGFloat) -> some View {
        if !engine.ready {
            VStack(spacing: 18) {
                Text(app.starting ? "Starting Dighouse" : "Dighouse needs a few things").font(.system(size: 22, weight: .semibold))
                if app.starting { ProgressView().controlSize(.small) } else { SetupChecklist().frame(maxWidth: 600) }
            }
            .padding(24).frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if app.onStart {
            StartView()
        } else {
            let mode: PaneLayout = app.layout == .split && width < 760 ? .chat : app.layout
            HStack(spacing: 0) {
                if mode != .workspace {
                    ChatView()
                        .frame(width: mode == .split ? min(max(width * 0.36, 340), 480) : nil)
                        .frame(maxWidth: mode == .chat ? .infinity : nil)
                }
                if mode == .split { Hairline(vertical: true) }
                if mode != .chat { WorkspaceView() }
            }
        }
    }
}

/// Always on screen: the project, where its run stands, and how the panes are arranged.
struct TopBar: View {
    let inset: Bool
    let narrow: Bool
    let width: CGFloat
    @EnvironmentObject var app: AppState
    @EnvironmentObject var store: ProjectStore
    @EnvironmentObject var chat: ChatModel
    @EnvironmentObject var engine: Engine

    var body: some View {
        let s = store.status
        HStack(spacing: 8) {
            Button {
                if narrow { app.sidebarPeek.toggle() } else { app.sidebarVisible.toggle() }
            } label: { Image(systemName: "sidebar.left") }
                .buttonStyle(IconButton()).help("Show or hide the sidebar")

            if app.onStart {
                Text("Explore").font(.system(size: 14, weight: .semibold))
            } else {
                Text(store.current?.name ?? "").font(.system(size: 14, weight: .semibold)).lineLimit(1)
                if width > 640 { stats(s) }
            }
            Spacer(minLength: 8)
            if let problem = engine.problem {
                Badge(text: problem, color: Theme.amber)
            } else if !app.onStart {
                if chat.running { ProgressView().controlSize(.small).padding(.trailing, 2) }
                if !s.needsPerson.isEmpty {
                    Button {
                        store.selectedCandidate = s.needsPerson.first
                        app.show(.records)
                    } label: {
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
                    if !app.onStart, s.progress > 0 {
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
        .background(RoundedRectangle(cornerRadius: 10).fill(Color.white.opacity(0.05)))
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
            Color.clear.frame(height: 46).background(WindowDragArea())
            nav("square.and.pencil", "New chat", selected: false) { app.newChat() }
            nav("binoculars", "Explore", selected: app.onStart) {
                app.exploring = true
                app.sidebarPeek = false
            }
            nav("wrench.and.screwdriver", "Tools", selected: !app.onStart && app.tab == .tools && app.layout != .chat) {
                app.show(.tools)
                app.sidebarPeek = false
            }

            HStack {
                Text("Projects").font(.system(size: 12, weight: .medium)).foregroundStyle(Theme.faint)
                Spacer()
                Button { app.newProject = StartingPoints.own } label: { Image(systemName: "plus") }
                    .buttonStyle(IconButton(size: 24)).help("New project")
            }
            .padding(.leading, 10).padding(.trailing, 2).padding(.top, 14)

            ScrollView {
                VStack(alignment: .leading, spacing: 2) {
                    ForEach(store.projects) { project in projectRows(project) }
                    if store.projects.isEmpty {
                        Text("No projects yet. Pick a starting point in Explore.")
                            .font(.system(size: 12.5)).foregroundStyle(Theme.faint).padding(10)
                    }
                }
            }

            Hairline().padding(.vertical, 6)
            SettingsLink {
                Label("Settings", systemImage: "gearshape").font(.system(size: 13.5))
            }
            .buttonStyle(RowButton())
            HStack(spacing: 8) {
                Circle().fill(engine.ready ? Theme.green : Theme.amber).frame(width: 7, height: 7)
                Text(engine.ready ? (engine.account ?? "Engine running") : "Engine not running")
                    .font(.system(size: 12)).foregroundStyle(Theme.faint).lineLimit(1)
            }
            .padding(.horizontal, 12).padding(.top, 4).padding(.bottom, 2)
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

    private func nav(_ icon: String, _ title: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: icon).font(.system(size: 13.5))
        }
        .buttonStyle(RowButton(selected: selected))
    }

    @ViewBuilder private func projectRows(_ project: ProjectRef) -> some View {
        let current = project == store.current
        let open = current && !collapsed.contains(project.path)
        Button {
            if current && !app.onStart {
                if open { collapsed.insert(project.path) } else { collapsed.remove(project.path) }
            } else {
                collapsed.remove(project.path)
                app.open(project)
            }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "chevron.right").font(.system(size: 9, weight: .bold)).foregroundStyle(Theme.faint)
                    .rotationEffect(.degrees(open ? 90 : 0)).frame(width: 10)
                Text(project.name).font(.system(size: 13.5, weight: current ? .medium : .regular)).lineLimit(1)
            }
        }
        .buttonStyle(RowButton())
        .contextMenu {
            Button("Show in Finder") { NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: project.path) }
            Button("Remove from List") { store.remove(project) }
        }
        if open {
            ForEach(chat.threads) { thread in
                Button { app.openChat(thread) } label: {
                    Text(thread.title).font(.system(size: 13)).lineLimit(1)
                        .foregroundStyle(chat.active == thread.id ? Theme.text : Theme.dim)
                }
                .buttonStyle(RowButton(selected: chat.active == thread.id && !app.onStart))
                .padding(.leading, 18)
                .contextMenu {
                    Button("Rename…") {
                        newName = thread.title
                        renaming = thread
                    }
                    Button("Archive") { Task { await chat.archive(thread) } }
                }
            }
            if chat.threads.isEmpty {
                Text("No chats yet").font(.system(size: 12.5)).foregroundStyle(Theme.faint)
                    .padding(.leading, 28).padding(.vertical, 6)
            }
        }
    }
}

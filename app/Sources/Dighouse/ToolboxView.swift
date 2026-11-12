import SwiftUI

/// The Toolbox: what Dighouse adds to the agent. Workflows, the archaeology tools, the open data they read, and other connections.
struct ToolboxView: View {
    enum Tab: String, CaseIterable {
        case workflows = "Workflows", tools = "Tools", data = "Data sources", connections = "Connections"
    }

    @EnvironmentObject var app: AppState
    @EnvironmentObject var engine: Engine
    @AppStorage("toolboxTab") private var tab = Tab.workflows

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 26) {
                VStack(alignment: .leading, spacing: 14) {
                    VStack(alignment: .leading, spacing: 5) {
                        Text("Toolbox").font(.system(size: 26, weight: .bold))
                        Text("What Dighouse adds to the agent: archaeology tools, the open data they read, and workflows that pass work between models and you.")
                            .font(.system(size: 14)).foregroundStyle(Theme.dim).fixedSize(horizontal: false, vertical: true)
                    }
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 4) {
                            ForEach(Tab.allCases, id: \.self) { item in
                                Button { tab = item } label: {
                                    Text(item.rawValue).font(.system(size: 13, weight: .medium))
                                        .foregroundStyle(tab == item ? Theme.text : Theme.dim)
                                        .padding(.horizontal, 12).frame(height: 30)
                                        .background(Capsule().fill(tab == item ? Color.white.opacity(0.1) : .clear))
                                        .contentShape(Capsule())
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    Hairline()
                }
                switch tab {
                case .workflows: WorkflowsTab()
                case .tools: ToolsTab()
                case .data: DataTab()
                case .connections: ConnectionsTab()
                }
            }
            .padding(.horizontal, 32).padding(.top, 26).padding(.bottom, 32)
            .frame(maxWidth: 860, alignment: .leading).frame(maxWidth: .infinity)
        }
        .background(Theme.bg)
        .task(id: engine.ready) { await engine.loadConnections() }
    }
}

// MARK: - Workflows

private struct WorkflowsTab: View {
    @EnvironmentObject var app: AppState
    @EnvironmentObject var store: ProjectStore

    private let roles: [(String, String, String)] = [
        ("cpu", "Agent", "The model you chose runs the search, calls the tools and keeps the plan."),
        ("person.2", "Helper agents", "On long screening runs it hands batches of tiles to helpers and collects their verdicts."),
        ("eye", "Second model", "A different model gives its own opinion on each flag, without seeing the first."),
        ("person", "You", "You decide what each candidate is, and you send any report."),
    ]

    var body: some View {
        PageSection(title: "Who does what",
                    caption: "A workflow is a request the agent already knows how to carry out. Each one shows where the work passes from one model to another, and where it stops for you.") {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 170), spacing: 10, alignment: .top)], alignment: .leading, spacing: 10) {
                ForEach(roles, id: \.1) { role in
                    VStack(alignment: .leading, spacing: 6) {
                        Label(role.1, systemImage: role.0).font(.system(size: 13, weight: .semibold))
                        Text(role.2).font(.system(size: 12.5)).foregroundStyle(Theme.dim).lineSpacing(2)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .frame(maxWidth: .infinity, minHeight: 92, alignment: .topLeading)
                    .panel(padding: 12, radius: 12)
                }
            }
        }
        PageSection(title: "Before there is a project", caption: "These run in a general chat and help decide where to look.") {
            ForEach(ToolGuide.workflows.filter { $0.scope == .general }) { WorkflowCard(flow: $0) }
        }
        PageSection(title: "In a project",
                    caption: store.current.map { "These run on \($0.name), the open project." }
                        ?? "Open a project to run these. Each one picks up from where the project stands.") {
            ForEach(ToolGuide.workflows.filter { $0.scope == .project }) { WorkflowCard(flow: $0) }
        }
    }
}

private struct WorkflowCard: View {
    let flow: ToolGuide.Workflow
    @EnvironmentObject var app: AppState

    var body: some View {
        let state = app.state(of: flow)
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                IconTile(name: flow.icon)
                VStack(alignment: .leading, spacing: 3) {
                    Text(flow.title).font(.system(size: 14, weight: .semibold))
                    Text(flow.summary).font(.system(size: 12.5)).foregroundStyle(Theme.dim).lineSpacing(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 8)
                if !state.note.isEmpty { Badge(text: state.note, color: state.note == "Done" ? Theme.green : Theme.dim) }
                Button("Run") { app.run(flow) }.buttonStyle(SecondaryButton()).disabled(!state.ready)
            }
            Flow(spacing: 6) {
                ForEach(Array(flow.steps.enumerated()), id: \.offset) { index, step in
                    HStack(spacing: 6) {
                        if index > 0 { Image(systemName: "arrow.right").font(.system(size: 9, weight: .bold)).foregroundStyle(Theme.faint) }
                        HStack(spacing: 5) {
                            Text(step.who).fontWeight(.semibold).foregroundStyle(step.who == "You" ? Theme.accent : Theme.text)
                            Text(step.does).foregroundStyle(Theme.dim)
                        }
                        .font(.system(size: 11.5)).lineLimit(1)
                        .padding(.horizontal, 9).frame(height: 24)
                        .background(Capsule().fill(Color.white.opacity(0.05)))
                    }
                }
            }
            .padding(.leading, 46)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .panel(padding: 14)
    }
}

// MARK: - Tools

private struct ToolsTab: View {
    @EnvironmentObject var app: AppState
    @EnvironmentObject var setup: Setup
    @EnvironmentObject var engine: Engine

    var body: some View {
        if setup.toolsReady {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "checkmark.circle.fill").font(.system(size: 18)).foregroundStyle(Theme.green)
                VStack(alignment: .leading, spacing: 3) {
                    Text("The archaeology tools are installed").font(.system(size: 14, weight: .semibold))
                    Text("\(engine.toolCount > 0 ? "\(engine.toolCount) tools" : "The tools") run on this Mac, inside the app, and are available to the agent in every chat. They read public data and need no account.")
                        .font(.system(size: 12.5)).foregroundStyle(Theme.dim).fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
            }
            .panel(padding: 14)
        } else {
            SetupChecklist()
        }

        ForEach(ToolGuide.packs) { pack in
            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .top, spacing: 12) {
                    IconTile(name: pack.icon)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(pack.title).font(.system(size: 14, weight: .semibold))
                        Text(pack.summary).font(.system(size: 12.5)).foregroundStyle(Theme.dim).lineSpacing(2)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer(minLength: 8)
                    Button("Ask how to use these") {
                        app.ask("Explain the \(pack.title) tools (\(pack.tools.map(\.name).joined(separator: ", "))) in plain words: what each one tells me, when to use it, and one example request I could make.")
                    }
                    .buttonStyle(SecondaryButton())
                }
                .padding(14)
                ForEach(pack.tools) { tool in
                    Hairline()
                    HStack(alignment: .firstTextBaseline, spacing: 12) {
                        name(tool).frame(width: 140, alignment: .leading)
                        does(tool)
                        Spacer(minLength: 0)
                    }
                    .padding(.horizontal, 14).padding(.vertical, 9)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .panel()
        }

        PageSection(title: "Rules the tools enforce", caption: "These are checked by the tools themselves, whichever model is running.") {
            VStack(alignment: .leading, spacing: 9) {
                ForEach(ToolGuide.rules, id: \.self) { rule in
                    HStack(alignment: .firstTextBaseline, spacing: 9) {
                        Image(systemName: "lock").font(.system(size: 11)).foregroundStyle(Theme.faint)
                        Text(rule).font(.system(size: 13)).foregroundStyle(Theme.dim).fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading).panel(padding: 14)
        }
    }

    private func name(_ tool: ToolGuide.Tool) -> some View {
        Text(tool.name).font(.system(size: 12, design: .monospaced)).foregroundStyle(Theme.green)
    }

    private func does(_ tool: ToolGuide.Tool) -> some View {
        Text(tool.does).font(.system(size: 12.5)).foregroundStyle(Theme.dim).fixedSize(horizontal: false, vertical: true)
    }
}

// MARK: - Data sources

private struct DataTab: View {
    @State private var answers: [String: Bool] = [:]

    var body: some View {
        PageSection(title: "Open data the tools read",
                    caption: "Public services, checked just now from this Mac. Dighouse uses the parts of each that need no account.") {
            VStack(spacing: 0) {
                ForEach(Array(ToolGuide.sources.enumerated()), id: \.element.id) { index, source in
                    if index > 0 { Hairline() }
                    HStack(alignment: .top, spacing: 12) {
                        Circle().fill(answers[source.name] == true ? Theme.green : answers[source.name] == false ? Theme.amber : Theme.faint)
                            .frame(width: 8, height: 8).padding(.top, 5)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(source.name).font(.system(size: 14, weight: .semibold))
                            Text(source.use).font(.system(size: 12.5)).foregroundStyle(Theme.dim).lineSpacing(2)
                                .fixedSize(horizontal: false, vertical: true)
                            if let url = URL(string: source.url) {
                                Link(url.host ?? source.url, destination: url).font(.system(size: 12)).foregroundStyle(Theme.accent)
                            }
                        }
                        Spacer(minLength: 8)
                        Text(answers[source.name] == true ? "Answering" : answers[source.name] == false ? "Not answering" : "Checking")
                            .font(.system(size: 12)).foregroundStyle(answers[source.name] == false ? Theme.amber : Theme.faint)
                    }
                    .padding(14)
                }
            }
            .panel()
            Button("Check again") { Task { await probe() } }.buttonStyle(SecondaryButton())
        }
        .task { await probe() }
    }

    private func probe() async {
        answers = [:]
        await withTaskGroup(of: (String, Bool).self) { group in
            for source in ToolGuide.sources {
                group.addTask {
                    guard let url = URL(string: source.probe) else { return (source.name, false) }
                    var request = URLRequest(url: url)
                    request.timeoutInterval = 12
                    request.setValue("dighouse/0.2 (https://github.com/chrissotraidis/dighouse)", forHTTPHeaderField: "User-Agent")
                    let code = ((try? await URLSession.shared.data(for: request))?.1 as? HTTPURLResponse)?.statusCode ?? 0
                    return (source.name, (200..<400).contains(code))
                }
            }
            for await (name, ok) in group { answers[name] = ok }
        }
    }
}

// MARK: - Connections

private struct ConnectionsTab: View {
    @EnvironmentObject var app: AppState
    @EnvironmentObject var engine: Engine
    @State private var name = ""
    @State private var command = ""

    var body: some View {
        PageSection(title: "From your Codex setup",
                    caption: "Dighouse runs the Codex engine with your own Codex configuration. Tool servers and plugins you set up there are available to the agent in every chat.") {
            if engine.connections.isEmpty && engine.plugins.isEmpty {
                Text("No other tool servers or plugins were found.").font(.system(size: 13)).foregroundStyle(Theme.faint)
            }
            if !engine.connections.isEmpty {
                VStack(spacing: 0) {
                    ForEach(Array(engine.connections.enumerated()), id: \.element.id) { index, server in
                        if index > 0 { Hairline() }
                        HStack(spacing: 12) {
                            Image(systemName: "puzzlepiece.extension").foregroundStyle(Theme.tan).frame(width: 20)
                            Text(server.name).font(.system(size: 13, design: .monospaced))
                            Spacer()
                            Text(server.tools == 0 ? "No tools listed" : "\(server.tools) tools").font(.system(size: 12.5)).foregroundStyle(Theme.dim)
                        }
                        .padding(.horizontal, 14).padding(.vertical, 10)
                    }
                }
                .panel()
            }
            if !engine.plugins.isEmpty {
                Text("Plugins").font(.system(size: 12.5, weight: .semibold)).padding(.top, 4)
                Flow(spacing: 6) { ForEach(engine.plugins, id: \.self) { Badge(text: $0) } }
            }
        }

        PageSection(title: "Add a tool server",
                    caption: "Any MCP tool server can be added to Dighouse alone: a GIS package, a database of sites, a document reader. Enter a name and the command that starts it. The engine restarts to load it.") {
            ForEach(app.toolServers) { server in
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(server.name).font(.system(size: 13, weight: .medium))
                        Text(server.command).font(.system(size: 12, design: .monospaced)).foregroundStyle(Theme.dim).lineLimit(1)
                    }
                    Spacer()
                    Button("Remove") {
                        app.toolServers.removeAll { $0 == server }
                        Task { await app.boot() }
                    }
                    .buttonStyle(SecondaryButton())
                }
                .panel(padding: 12, radius: 12)
            }
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 8) { fields }
                VStack(alignment: .leading, spacing: 8) { fields }
            }
            .font(.system(size: 13))
        }
    }

    @ViewBuilder private var fields: some View {
        TextField("Name", text: $name).field().frame(minWidth: 120, maxWidth: 170)
        TextField("Command, for example: uvx my-gis-server (quote a path that has spaces)", text: $command).field().frame(minWidth: 260)
        Button("Add") {
            app.toolServers.append(ToolServer(name: name.trimmingCharacters(in: .whitespaces), command: command.trimmingCharacters(in: .whitespaces)))
            name = ""
            command = ""
            Task { await app.boot() }
        }
        .buttonStyle(PrimaryButton())
        .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty || command.trimmingCharacters(in: .whitespaces).isEmpty
                  || app.toolServers.contains { $0.name == name.trimmingCharacters(in: .whitespaces) })
    }
}


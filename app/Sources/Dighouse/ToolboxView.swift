import SwiftUI

/// The Toolbox: what Dighouse gives the agent that a chat app does not. How a search works, the workflows that run it,
/// where the data comes from, and other tools the agent can use.
struct ToolboxView: View {
    enum Tab: String, CaseIterable {
        case how = "How a search works", workflows = "Workflows", data = "Open data", more = "More tools"
    }

    @EnvironmentObject var app: AppState
    @EnvironmentObject var engine: Engine
    @AppStorage("toolboxTab") private var tab = Tab.how

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 26) {
                VStack(alignment: .leading, spacing: 14) {
                    VStack(alignment: .leading, spacing: 5) {
                        Text("Toolbox").font(.system(size: 26, weight: .bold))
                        Text("A chat app can only talk about archaeology. Dighouse gives the AI \(ToolGuide.toolCount) tools to do it: fetch the data, look at the ground, check its own finds, and keep the record. This page shows what they do and how to run them.")
                            .font(.system(size: 14)).foregroundStyle(Theme.dim).lineSpacing(2).fixedSize(horizontal: false, vertical: true)
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
                case .how: HowTab()
                case .workflows: WorkflowsTab()
                case .data: DataTab()
                case .more: MoreTab()
                }
            }
            .padding(.horizontal, 32).padding(.top, 26).padding(.bottom, 32)
            .frame(maxWidth: 900, alignment: .leading).frame(maxWidth: .infinity)
        }
        .background(Theme.bg)
        .task(id: engine.ready) { await engine.loadConnections() }
    }
}

// MARK: - How a search works

private struct HowTab: View {
    @EnvironmentObject var setup: Setup

    var body: some View {
        if !setup.toolsReady { SetupChecklist() }
        Text("A search runs through six stages. Each one has its own tools, shown under it by the name the agent calls them. You never need to type a tool's name: ask in plain words, or press Run.")
            .font(.system(size: 13.5)).foregroundStyle(Theme.dim).lineSpacing(3).fixedSize(horizontal: false, vertical: true)
        ForEach(Array(ToolGuide.packs.enumerated()), id: \.element.id) { index, pack in
            StageCard(number: index + 1, pack: pack)
        }
        PageSection(title: "Rules the tools enforce", caption: "These are built into the tools, so they hold whichever model is running.") {
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
}

private struct StageCard: View {
    let number: Int
    let pack: ToolGuide.Pack
    @EnvironmentObject var app: AppState
    @State private var showTools = false

    var body: some View {
        let flow = ToolGuide.workflows.first { $0.id == pack.flow }
        let state = flow.map { app.state(of: $0) }
        VStack(alignment: .leading, spacing: 0) {
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .top, spacing: 18) {
                    words.frame(minWidth: 380, idealWidth: 380, maxWidth: .infinity, alignment: .leading)
                    picture.frame(width: 250)
                }
                VStack(alignment: .leading, spacing: 14) {
                    words
                    picture.frame(maxWidth: 420)
                }
            }
            .padding(16)

            Hairline()
            HStack(spacing: 10) {
                Button { showTools.toggle() } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "chevron.right").font(.system(size: 8.5, weight: .bold)).rotationEffect(.degrees(showTools ? 90 : 0))
                        Text("\(pack.tools.count) tools").font(.system(size: 12.5, weight: .medium))
                        if !showTools {
                            Text(pack.tools.map(\.title).joined(separator: " · ")).font(.system(size: 12.5)).foregroundStyle(Theme.faint).lineLimit(1)
                        }
                    }
                    .foregroundStyle(Theme.dim).contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                Spacer(minLength: 8)
                if let note = state?.note, !note.isEmpty { Badge(text: note, color: note == "Done" ? Theme.green : Theme.dim) }
                if let flow {
                    Button("Run this stage") { app.run(flow) }.buttonStyle(SecondaryButton()).disabled(state?.ready != true)
                        .help(flow.summary)
                }
            }
            .padding(.horizontal, 16).padding(.vertical, 10)

            if showTools {
                ForEach(pack.tools) { tool in
                    Hairline()
                    HStack(alignment: .firstTextBaseline, spacing: 12) {
                        Text(tool.title).font(.system(size: 13, weight: .medium)).frame(width: 170, alignment: .leading)
                        Text(tool.does).font(.system(size: 12.5)).foregroundStyle(Theme.dim).fixedSize(horizontal: false, vertical: true)
                        Spacer(minLength: 8)
                        Text(tool.name).font(.system(size: 11, design: .monospaced)).foregroundStyle(Theme.faint)
                            .help("The name the agent calls this tool by")
                    }
                    .padding(.horizontal, 16).padding(.vertical, 9)
                }
            }
        }
        .panel()
    }

    private var words: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                Text("\(number)").font(.system(size: 13, weight: .bold)).foregroundStyle(.black)
                    .frame(width: 24, height: 24).background(Circle().fill(Theme.tan))
                Text(pack.title).font(.system(size: 17, weight: .semibold))
            }
            Text(pack.summary).font(.system(size: 13.5)).foregroundStyle(Theme.text.opacity(0.86)).lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
            HStack(alignment: .firstTextBaseline, spacing: 7) {
                Image(systemName: "lightbulb").font(.system(size: 11)).foregroundStyle(Theme.tan)
                Text(pack.why).font(.system(size: 12.5)).foregroundStyle(Theme.dim).lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    @ViewBuilder private var picture: some View {
        if pack.image == "reveal" {
            VStack(alignment: .leading, spacing: 5) {
                ForestReveal(animateIn: false)
                Text("Drag the handle. Serpent Mound, Ohio.").font(.system(size: 11)).foregroundStyle(Theme.faint)
            }
        } else if let name = pack.image, let image = Tour.image(name) {
            Image(nsImage: image).resizable().aspectRatio(contentMode: .fit)
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(Theme.line))
        } else {
            RoundedRectangle(cornerRadius: 10).fill(Color.white.opacity(0.04)).frame(height: 120)
                .overlay(Image(systemName: pack.icon).font(.system(size: 38, weight: .light)).foregroundStyle(Theme.tan.opacity(0.8)))
        }
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
                    caption: "A workflow is a ready-made request: press Run and the agent carries it out with the tools. Each one shows where the work passes from one model to another, and where it stops for you.") {
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
                    caption: store.current.map { "These run on \($0.name), the open project. Each one picks up from where the project stands." }
                        ?? "Open a project from the sidebar to run these. Each one picks up from where the project stands.") {
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

// MARK: - Open data

private struct DataTab: View {
    @State private var online: [String: Bool] = [:]
    @State private var checked: Date?

    var body: some View {
        Text("Everything Dighouse searches is public. It reads from five open services, and none of them needs an account or a key. The dot beside each name shows whether this Mac can reach it right now.")
            .font(.system(size: 13.5)).foregroundStyle(Theme.dim).lineSpacing(3).fixedSize(horizontal: false, vertical: true)
        ForEach(ToolGuide.sources) { source in
            let state = online[source.name]
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 10) {
                    Text(source.name).font(.system(size: 15, weight: .semibold))
                    Spacer()
                    HStack(spacing: 6) {
                        Circle().fill(state == true ? Theme.green : state == false ? Theme.amber : Theme.faint).frame(width: 7, height: 7)
                        Text(state == true ? "Online" : state == false ? "Cannot be reached" : "Checking")
                            .font(.system(size: 12)).foregroundStyle(state == false ? Theme.amber : Theme.dim)
                    }
                    .help(state == false ? "This service did not reply. Tools that use it will fail until it is back, or until this Mac is online."
                          : "This service replied to a test request from this Mac.")
                }
                line("What it is", source.what)
                line("What Dighouse takes", source.gives)
                line("Used for", source.usedFor)
                if let url = URL(string: source.url) {
                    Link(url.host ?? source.url, destination: url).font(.system(size: 12.5)).foregroundStyle(Theme.accent)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .panel(padding: 16)
        }
        HStack(spacing: 10) {
            Button("Check again") { Task { await probe() } }.buttonStyle(SecondaryButton())
            if let checked {
                Text("Checked at \(checked.formatted(date: .omitted, time: .shortened)).").font(.system(size: 12.5)).foregroundStyle(Theme.faint)
            }
        }
        .task { await probe() }
    }

    private func line(_ label: String, _ text: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text(label).font(.system(size: 12.5)).foregroundStyle(Theme.faint).frame(width: 138, alignment: .leading)
            Text(text).font(.system(size: 13)).foregroundStyle(Theme.dim).lineSpacing(2).fixedSize(horizontal: false, vertical: true)
        }
    }

    private func probe() async {
        online = [:]
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
            for await (name, ok) in group { online[name] = ok }
        }
        checked = Date()
    }
}

// MARK: - More tools

private struct MoreTab: View {
    @EnvironmentObject var app: AppState
    @EnvironmentObject var engine: Engine
    @State private var name = ""
    @State private var command = ""
    @State private var showServers = false

    private var known: [(String, ToolGuide.Addon)] {
        engine.plugins.compactMap { id in ToolGuide.addons[id].map { (id, $0) } }
    }
    private var others: [String] { engine.plugins.filter { ToolGuide.addons[$0] == nil } }

    var body: some View {
        Text("The archaeology tools are built in. The agent can also use other tools, in two ways: the ones your Codex app already has, and ones you add here.")
            .font(.system(size: 13.5)).foregroundStyle(Theme.dim).lineSpacing(3).fixedSize(horizontal: false, vertical: true)

        PageSection(title: "Already on this Mac",
                    caption: "Dighouse runs on the same engine as the Codex app, so whatever you connected there works here too. Ask for it in plain words, for example \"copy these records into Notion\". These come from your Codex setup, and Dighouse has not tested each one.") {
            if engine.plugins.isEmpty && engine.connections.isEmpty {
                Text("Nothing else is connected in Codex on this Mac.").font(.system(size: 13)).foregroundStyle(Theme.faint)
            }
            if !known.isEmpty {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 250), spacing: 10, alignment: .top)], alignment: .leading, spacing: 10) {
                    ForEach(known, id: \.0) { _, addon in
                        HStack(alignment: .top, spacing: 12) {
                            IconTile(name: addon.icon, size: 32)
                            VStack(alignment: .leading, spacing: 3) {
                                Text(addon.title).font(.system(size: 13.5, weight: .semibold))
                                Text(addon.use).font(.system(size: 12.5)).foregroundStyle(Theme.dim).lineSpacing(2)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            Spacer(minLength: 0)
                        }
                        .frame(maxWidth: .infinity, minHeight: 64, alignment: .topLeading)
                        .panel(padding: 12, radius: 12)
                    }
                }
            }
            if !others.isEmpty {
                Text("Also connected").font(.system(size: 12.5, weight: .semibold)).padding(.top, 4)
                Flow(spacing: 6) { ForEach(others, id: \.self) { Badge(text: $0) } }
            }
            if !engine.connections.isEmpty {
                Button { showServers.toggle() } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "chevron.right").font(.system(size: 8.5, weight: .bold)).rotationEffect(.degrees(showServers ? 90 : 0))
                        Text("Technical details: \(engine.connections.count) tool servers").font(.system(size: 12.5))
                    }
                    .foregroundStyle(Theme.dim).contentShape(Rectangle())
                }
                .buttonStyle(.plain).padding(.top, 4)
                if showServers {
                    VStack(spacing: 0) {
                        ForEach(Array(engine.connections.enumerated()), id: \.element.id) { index, server in
                            if index > 0 { Hairline() }
                            HStack(spacing: 12) {
                                Text(server.name).font(.system(size: 12.5, design: .monospaced))
                                Spacer()
                                Text(server.tools == 0 ? "Starts when used" : "\(server.tools) tools").font(.system(size: 12.5)).foregroundStyle(Theme.dim)
                            }
                            .padding(.horizontal, 14).padding(.vertical, 9)
                        }
                    }
                    .panel(radius: 10)
                }
            }
        }

        PageSection(title: "Add your own",
                    caption: "A tool server is a small program that gives the agent a new ability, such as a mapping package, a museum's site database, or a reader for a file type. It speaks an open standard called MCP, and many are free to download. Give it a name and the command that starts it. The engine restarts to load it, which stops any running work.") {
            ForEach(app.toolServers) { server in
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(server.name).font(.system(size: 13, weight: .medium))
                        Text(server.command).font(.system(size: 12, design: .monospaced)).foregroundStyle(Theme.dim).lineLimit(1)
                    }
                    Spacer()
                    if let found = engine.connections.first(where: { $0.name == server.key }) {
                        Badge(text: found.tools == 0 ? "No tools found" : "\(found.tools) tools", color: found.tools == 0 ? Theme.amber : Theme.green)
                    }
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

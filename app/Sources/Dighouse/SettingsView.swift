import SwiftUI

/// Settings, shown as a page in the main window.
struct SettingsPage: View {
    @EnvironmentObject var app: AppState

    var body: some View {
        GeometryReader { geo in
            let wide = geo.size.width >= 720
            HStack(alignment: .top, spacing: 0) {
                if wide {
                    VStack(spacing: 2) {
                        ForEach(SettingsSection.allCases, id: \.self) { section in
                            Button { app.settingsSection = section } label: {
                                Label(section.rawValue, systemImage: icon(section)).font(.system(size: 13.5))
                            }
                            .buttonStyle(RowButton(selected: app.settingsSection == section))
                        }
                        Spacer()
                    }
                    .padding(12).frame(width: 210)
                    Hairline(vertical: true)
                }
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        if !wide {
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 4) {
                                    ForEach(SettingsSection.allCases, id: \.self) { section in
                                        Button { app.settingsSection = section } label: {
                                            Text(section.rawValue).font(.system(size: 13, weight: .medium))
                                                .foregroundStyle(app.settingsSection == section ? Theme.text : Theme.dim)
                                                .padding(.horizontal, 12).frame(height: 30)
                                                .background(Capsule().fill(app.settingsSection == section ? Color.white.opacity(0.1) : .clear))
                                                .contentShape(Capsule())
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                            }
                        }
                        Text(app.settingsSection.rawValue).font(.system(size: 24, weight: .bold))
                        switch app.settingsSection {
                        case .general: GeneralSettings()
                        case .models: ModelSettings()
                        case .engine: EngineSettings()
                        case .privacy: PrivacySettings()
                        case .about: AboutSettings()
                        }
                    }
                    .padding(.horizontal, 32).padding(.vertical, 26)
                    .frame(maxWidth: 720, alignment: .leading).frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
        .background(Theme.bg)
    }

    private func icon(_ section: SettingsSection) -> String {
        switch section {
        case .general: return "gearshape"
        case .models: return "cpu"
        case .engine: return "gearshape.2"
        case .privacy: return "lock"
        case .about: return "info.circle"
        }
    }
}

private struct SettingRow<Content: View>: View {
    let title: String
    var note = ""
    @ViewBuilder let content: () -> Content

    var body: some View {
        HStack(alignment: .center, spacing: 16) {
            label.frame(maxWidth: .infinity, alignment: .leading)
            content().fixedSize()
        }
        .padding(14).frame(maxWidth: .infinity, alignment: .leading)
    }

    private var label: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title).font(.system(size: 13.5, weight: .medium))
            if !note.isEmpty {
                Text(note).font(.system(size: 12.5)).foregroundStyle(Theme.dim).lineSpacing(2).fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

private struct GeneralSettings: View {
    @EnvironmentObject var app: AppState
    @AppStorage("projectsHome") private var projectsHome = ""

    var body: some View {
        VStack(spacing: 0) {
            SettingRow(title: "Your name", note: "Written into a record when you make a decision on a candidate.") {
                TextField("Name", text: $app.userName).field().font(.system(size: 13)).frame(width: 220)
            }
            Hairline()
            SettingRow(title: "Projects folder", note: "New projects are created in \(projectsHome.isEmpty ? Paths.projectsHome.path : projectsHome).") {
                HStack(spacing: 8) {
                    Button("Show") { NSWorkspace.shared.open(Paths.projectsHome) }.buttonStyle(SecondaryButton())
                    Button("Choose…") {
                        let panel = NSOpenPanel()
                        panel.canChooseDirectories = true
                        panel.canChooseFiles = false
                        panel.canCreateDirectories = true
                        if panel.runModal() == .OK, let url = panel.url { projectsHome = url.path }
                    }
                    .buttonStyle(SecondaryButton())
                }
            }
            Hairline()
            SettingRow(title: "A project opens as", note: "You can change this at any time from the top right of a project.") {
                PillMenu(title: ["chat": "Chat only", "split": "Chat and workspace", "workspace": "Workspace only"][app.layout.rawValue] ?? "") {
                    Button("Chat only") { app.layout = .chat }
                    Button("Chat and workspace") { app.layout = .split }
                    Button("Workspace only") { app.layout = .workspace }
                }
            }
            Hairline()
            SettingRow(title: "Welcome guide", note: "What Dighouse is, how a search works, and setting up.") {
                Button("Open") { app.showWelcome = true }.buttonStyle(SecondaryButton())
            }
        }
        .panel()
    }
}

private struct ModelSettings: View {
    @EnvironmentObject var app: AppState
    @EnvironmentObject var engine: Engine
    @EnvironmentObject var setup: Setup

    var body: some View {
        VStack(spacing: 0) {
            SettingRow(title: "Agent model", note: "Runs the search. Screening tiles needs a model that reads images.") {
                ModelPicker(title: app.modelName, models: engine.models, current: app.model?.id) { app.modelID = $0.id }
            }
            Hairline()
            effortRow
            Hairline()
            SettingRow(title: "Second-look model",
                       note: "Gives the independent second opinion on a candidate. Choose one from a different maker than the agent's model.") {
                ModelPicker(title: app.secondModelName, models: engine.models.filter { $0.readsImages },
                            current: app.secondModelID) { app.secondModelID = $0.id }
            }
        }
        .panel()
        Text(setup.ocxRunning
             ? "\(engine.models.count) models are listed. The OpenCodex router is running on this Mac, so the list holds every model in its roster, and the start of each name says which provider or account it runs through."
             : "\(engine.models.count) models are listed, from the Codex sign-in on this Mac. Running the OpenCodex router adds models from other providers.")
            .font(.system(size: 12.5)).foregroundStyle(Theme.dim).lineSpacing(2).fixedSize(horizontal: false, vertical: true)
        Text("The same choices are in the message box of every chat.")
            .font(.system(size: 12.5)).foregroundStyle(Theme.faint)
    }

    /// How long the model thinks. The steps on offer belong to the model, so they change when the model does.
    @ViewBuilder private var effortRow: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Thinking effort").font(.system(size: 13.5, weight: .medium))
            if let model = app.model, let effort = app.activeEffort {
                Text("\(Effort.label(effort)). \(Effort.note(effort))")
                    .font(.system(size: 12.5)).foregroundStyle(Theme.dim).fixedSize(horizontal: false, vertical: true)
                StepSlider(steps: model.efforts, value: Binding(get: { effort }, set: { app.effort = $0 }), showLabels: true)
                    .frame(maxWidth: 420)
                Text("Each model offers its own steps. \(model.name) has \(model.efforts.count): \(model.efforts.map(Effort.label).joined(separator: ", ")).")
                    .font(.system(size: 12)).foregroundStyle(Theme.faint).fixedSize(horizontal: false, vertical: true)
            } else {
                Text("\(app.modelName) has no effort setting. It always thinks the same amount.")
                    .font(.system(size: 12.5)).foregroundStyle(Theme.dim).fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(14).frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// One of the parts Dighouse is made of, in plain words, with whether it is working.
private struct PartCard<Action: View>: View {
    let icon: String, title: String, role: String, text: String
    let ok: Bool?
    let status: String
    @ViewBuilder let action: () -> Action

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            IconTile(name: icon, size: 40)
            VStack(alignment: .leading, spacing: 6) {
                Text(title).font(.system(size: 15, weight: .semibold))
                Text(role).font(.system(size: 13, weight: .medium)).foregroundStyle(Theme.tan)
                Text(text).font(.system(size: 13)).foregroundStyle(Theme.dim).lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
                HStack(spacing: 7) {
                    Circle().fill(ok == true ? Theme.green : ok == false ? Theme.amber : Theme.faint).frame(width: 7, height: 7)
                    Text(status).font(.system(size: 12.5)).foregroundStyle(ok == false ? Theme.amber : Theme.text)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.top, 2)
                action()
            }
            Spacer(minLength: 0)
        }
        .padding(16).frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct EngineSettings: View {
    @EnvironmentObject var app: AppState
    @EnvironmentObject var engine: Engine
    @EnvironmentObject var setup: Setup

    var body: some View {
        Text("Dighouse is three parts working together: a model that thinks, an engine that lets it act, and tools that do the archaeology. All three run from this Mac. Dighouse has no account and no server of its own.")
            .font(.system(size: 13.5)).foregroundStyle(Theme.dim).lineSpacing(3).fixedSize(horizontal: false, vertical: true)

        VStack(spacing: 0) {
            PartCard(icon: "cpu", title: "1. The AI model", role: "Does the thinking and the looking.",
                     text: "A large AI model, like the ones behind ChatGPT and Claude. It reads your request, decides what to do next, and looks at the terrain pictures. You choose which one.",
                     ok: engine.ready ? true : nil,
                     status: engine.ready ? "\(app.modelName) is selected, out of \(engine.models.count) on this Mac."
                        : app.starting ? "Starting" : "Models appear once the engine is running.") {
                if engine.ready {
                    ModelPicker(title: app.modelName, models: engine.models, current: app.model?.id) { app.modelID = $0.id }
                }
            }
            Hairline()
            PartCard(icon: "bolt", title: "2. The agent engine", role: "Lets the model act instead of only talk.",
                     text: "On its own a model can only write text. The engine is the program in between: when the model asks for a tool, the engine runs it and hands back the result, again and again, until the job is done. It also keeps the plan, starts helper agents, and saves each chat. Dighouse uses Codex, a free open-source engine made by OpenAI. It is the same one inside the Codex app, so it uses the Codex sign-in already on this Mac.",
                     ok: setup.codex == nil ? false : engine.ready,
                     status: setup.codex == nil ? "Codex was not found on this Mac."
                        : engine.ready
                          ? setup.codexVersion + (engine.account.map { ", signed in as \($0)" + (engine.plan.map { " (\($0) plan)" } ?? "") } ?? ", not signed in")
                          : app.starting ? "Starting" : (engine.problem ?? "Not running")) {
                HStack(spacing: 8) {
                    if setup.codex == nil, let url = URL(string: "https://github.com/openai/codex") {
                        Link("Get Codex", destination: url).font(.system(size: 13)).foregroundStyle(Theme.accent)
                    }
                    Button("Restart the engine") { Task { await app.boot() } }.buttonStyle(SecondaryButton()).disabled(app.starting)
                        .help("Use this after signing in to Codex or changing its settings. Running work stops.")
                    if app.starting { ProgressView().controlSize(.small) }
                }
            }
            Hairline()
            PartCard(icon: "wrench.and.screwdriver", title: "3. The archaeology tools", role: "What makes this more than a chat app.",
                     text: "\(ToolGuide.toolCount) small programs that come with Dighouse and run on this Mac. They do what a model cannot do alone: download lidar, build the bare ground, cut slices through the raw laser points, check open maps, find and open the literature, and keep the records.",
                     ok: setup.toolsReady ? true : setup.toolsBusy ? nil : false,
                     status: setup.toolsReady ? "Installed and ready. They read public data and need no account."
                        : setup.toolsBusy ? "Preparing. This takes about a minute."
                        : setup.uv == nil ? "Needs uv, a small program that runs the tools." : (setup.toolsProblem ?? "Not prepared yet.")) {
                VStack(alignment: .leading, spacing: 10) {
                    Flow(spacing: 6) {
                        ForEach(ToolGuide.packs) { pack in Badge(text: "\(pack.title) · \(pack.tools.count)") }
                    }
                    HStack(spacing: 8) {
                        Button("See what each tool does") { app.show(.toolbox) }.buttonStyle(SecondaryButton())
                        if !setup.toolsReady, !setup.toolsBusy, setup.uv != nil {
                            Button("Prepare tools") { Task { await setup.prepareTools(); await app.boot() } }.buttonStyle(PrimaryButton())
                        }
                        if setup.uv == nil, let url = URL(string: "https://docs.astral.sh/uv/getting-started/installation/") {
                            Link("Get uv", destination: url).font(.system(size: 13)).foregroundStyle(Theme.accent)
                        }
                    }
                }
            }
        }
        .panel()

        VStack(spacing: 0) {
            PartCard(icon: "arrow.triangle.branch", title: "Model router", role: "Optional. Adds models from other companies.",
                     text: "Codex alone offers the models from its own sign-in. OpenCodex is a separate free program that sits beside it and adds models from other providers, each with its own key or sign-in. That is how a different maker's model can give the second opinion.",
                     ok: setup.ocxRunning ? true : nil,
                     status: setup.ocxRunning ? "OpenCodex is running on this Mac." : "OpenCodex is not running. Dighouse works without it.") { EmptyView() }
        }
        .panel()
    }
}

private struct PrivacySettings: View {
    private let rows: [(String, String)] = [
        ("Messages and images", "What you type, and the terrain tiles the agent looks at, go to the provider of the model you chose, through the Codex engine. Dighouse adds no service in between."),
        ("Locations", "A project's search area and the position of each candidate are kept in its private folder on this Mac. Records, notes and reports carry no coordinates, so they can be shared."),
        ("Open data services", "The tools ask OpenTopography, USGS, Wikidata, OpenStreetMap and OpenAlex for data. Each sees the area or the search words in the request."),
        ("The map", "The New project page uses Apple Maps, which sees the part of the map you look at."),
        ("Reports", "Dighouse sends nothing to anyone. A report to a heritage authority is a draft in the project until you send it yourself."),
    ]

    var body: some View {
        VStack(spacing: 0) {
            ForEach(Array(rows.enumerated()), id: \.offset) { index, row in
                if index > 0 { Hairline() }
                SettingRow(title: row.0, note: row.1) { EmptyView() }
            }
        }
        .panel()
        VStack(spacing: 0) {
            SettingRow(title: "Projects", note: Paths.projectsHome.path) {
                Button("Show") { NSWorkspace.shared.open(Paths.projectsHome) }.buttonStyle(SecondaryButton())
            }
            Hairline()
            SettingRow(title: "General chats, downloaded catalogs and the tools", note: Paths.support.path) {
                Button("Show") { NSWorkspace.shared.open(Paths.support) }.buttonStyle(SecondaryButton())
            }
        }
        .panel()
    }
}

private struct AboutSettings: View {
    @EnvironmentObject var app: AppState

    var body: some View {
        HStack(spacing: 16) {
            Image(nsImage: NSApp.applicationIconImage).resizable().frame(width: 72, height: 72)
            VStack(alignment: .leading, spacing: 4) {
                Text("Dighouse").font(.system(size: 20, weight: .bold))
                Text("Version \(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "")")
                    .font(.system(size: 13)).foregroundStyle(Theme.dim)
            }
        }
        Text("An agent harness with archaeology tools built in. It runs the Codex engine with any model you have, and adds tools that find, fetch and read open lidar, records that carry their own evidence, and workflows that stop for your decision.")
            .font(.system(size: 13.5)).foregroundStyle(Theme.dim).lineSpacing(3).fixedSize(horizontal: false, vertical: true)
        VStack(spacing: 0) {
            SettingRow(title: "About the word lidar",
                       note: "Lidar maps the ground with laser pulses from an aircraft. The word began as a blend of light and radar, and Dighouse writes it in lowercase, as the US Geological Survey and NOAA do.") { EmptyView() }
            Hairline()
            SettingRow(title: "Source code", note: "Open source under the Apache 2.0 licence.") {
                if let url = URL(string: "https://github.com/chrissotraidis/dighouse") {
                    Link("GitHub", destination: url).font(.system(size: 13)).foregroundStyle(Theme.accent)
                }
            }
            Hairline()
            SettingRow(title: "Welcome guide", note: "What Dighouse is and how a search works.") {
                Button("Open") { app.showWelcome = true }.buttonStyle(SecondaryButton())
            }
        }
        .panel()
    }
}


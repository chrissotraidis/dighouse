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
                                                .background(Capsule().fill(app.settingsSection == section ? Theme.ink.opacity(0.1) : .clear))
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
                        case .look: LookSettings()
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
        case .look: return "paintpalette"
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

/// Choose the colours of the app.
private struct LookSettings: View {
    @EnvironmentObject var app: AppState

    var body: some View {
        Text("Dighouse wears the colours of its icon: dark soil, the tan line of the ground, and the green of the canopy above it. Pick another look if you prefer.")
            .font(.system(size: 13.5)).foregroundStyle(Theme.dim).lineSpacing(3).fixedSize(horizontal: false, vertical: true)
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 190), spacing: 12, alignment: .top)], alignment: .leading, spacing: 12) {
            ForEach(Look.allCases, id: \.self) { look in
                let p = look.palette
                Button { app.look = look } label: {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack(spacing: 0) {
                            p.side.frame(width: 34)
                            VStack(alignment: .leading, spacing: 6) {
                                Capsule().fill(p.text).frame(width: 64, height: 6)
                                Capsule().fill(p.dim).frame(width: 96, height: 5)
                                HStack(spacing: 5) {
                                    Circle().fill(p.accent).frame(width: 12, height: 12)
                                    Circle().fill(p.tan).frame(width: 12, height: 12)
                                    Capsule().fill(p.primary).frame(width: 34, height: 12)
                                }
                                .padding(.top, 4)
                            }
                            .padding(12).frame(maxWidth: .infinity, alignment: .leading).background(p.bg)
                        }
                        .frame(height: 78).clipShape(RoundedRectangle(cornerRadius: 9))
                        HStack(spacing: 6) {
                            Text(look.rawValue).font(.system(size: 13.5, weight: .semibold))
                            if look == .earth { Text("Default").font(.system(size: 11.5)).foregroundStyle(Theme.faint) }
                            Spacer()
                            if app.look == look { Image(systemName: "checkmark.circle.fill").foregroundStyle(Theme.accent) }
                        }
                        Text(look.note).font(.system(size: 12.5)).foregroundStyle(Theme.dim).lineSpacing(2)
                            .multilineTextAlignment(.leading).fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(12).frame(maxWidth: .infinity, minHeight: 176, alignment: .topLeading)
                    .background(RoundedRectangle(cornerRadius: 14).fill(Theme.ink.opacity(0.035)))
                    .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(app.look == look ? Theme.accent : Theme.line, lineWidth: app.look == look ? 1.5 : 1))
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
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
                Text("Your model list gives \(model.name) \(model.efforts.count) steps: \(model.efforts.map(Effort.label).joined(separator: ", ")). Dighouse shows what the list says and has not tested every step on every model. If a provider refuses a step, or the model itself, the chat shows the provider's message.")
                    .font(.system(size: 12)).foregroundStyle(Theme.faint).fixedSize(horizontal: false, vertical: true)
            } else {
                Text("\(app.modelName) has no effort setting. It always thinks the same amount.")
                    .font(.system(size: 12.5)).foregroundStyle(Theme.dim).fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(14).frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// One part of Dighouse: what it is in a sentence, whether it is working, and what you can do about it.
private struct PartRow<Action: View>: View {
    let icon: String, title: String, text: String
    let ok: Bool?
    let status: String
    @ViewBuilder let action: () -> Action

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: icon).font(.system(size: 15)).foregroundStyle(Theme.tan).frame(width: 22).padding(.top, 1)
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.system(size: 13.5, weight: .semibold))
                Text(text).font(.system(size: 12.5)).foregroundStyle(Theme.dim).lineSpacing(2).fixedSize(horizontal: false, vertical: true)
                action().padding(.top, 4)
            }
            Spacer(minLength: 12)
            HStack(spacing: 6) {
                Circle().fill(ok == true ? Theme.green : ok == false ? Theme.amber : Theme.faint).frame(width: 7, height: 7)
                Text(status).font(.system(size: 12.5)).foregroundStyle(ok == false ? Theme.amber : Theme.text).lineLimit(2)
                    .multilineTextAlignment(.trailing)
            }
            .frame(maxWidth: 210, alignment: .trailing)
        }
        .padding(14).frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// What happens when a message is sent, drawn as a loop.
private struct LoopDiagram: View {
    private let stops: [(String, String, String)] = [
        ("person", "You ask", "in plain words"),
        ("cpu", "The model decides", "the next step"),
        ("bolt", "The engine runs", "the tool it asked for"),
        ("wrench.and.screwdriver", "The tool reads", "open data"),
    ]

    var body: some View {
        VStack(spacing: 10) {
            HStack(alignment: .top, spacing: 0) {
                ForEach(Array(stops.enumerated()), id: \.offset) { index, stop in
                    if index > 0 {
                        Image(systemName: "arrow.right").font(.system(size: 11, weight: .bold)).foregroundStyle(Theme.faint).padding(.top, 14)
                    }
                    VStack(spacing: 6) {
                        Image(systemName: stop.0).font(.system(size: 16)).foregroundStyle(index == 0 ? Theme.accent : Theme.tan)
                            .frame(width: 40, height: 40).background(Circle().fill(Theme.ink.opacity(0.07)))
                        Text(stop.1).font(.system(size: 12.5, weight: .semibold)).multilineTextAlignment(.center)
                        Text(stop.2).font(.system(size: 11.5)).foregroundStyle(Theme.faint).multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            HStack(spacing: 7) {
                Image(systemName: "arrow.uturn.backward").font(.system(size: 10, weight: .bold))
                Text("The result goes back to the model, and the loop repeats until the job is done.")
            }
            .font(.system(size: 12)).foregroundStyle(Theme.dim)
        }
        .padding(16).frame(maxWidth: .infinity).panel()
    }
}

private struct EngineSettings: View {
    @EnvironmentObject var app: AppState
    @EnvironmentObject var engine: Engine
    @EnvironmentObject var setup: Setup

    var body: some View {
        Text("Everything runs from this Mac. Dighouse has no account and no server of its own.")
            .font(.system(size: 13.5)).foregroundStyle(Theme.dim).fixedSize(horizontal: false, vertical: true)
        LoopDiagram()
        VStack(spacing: 0) {
            PartRow(icon: "cpu", title: "AI model",
                    text: "Reads your request, decides each step, and looks at the terrain pictures.",
                    ok: engine.ready ? true : nil,
                    status: engine.ready ? "\(engine.models.count) available" : app.starting ? "Starting" : "Waiting for the engine") {
                if engine.ready {
                    ModelPicker(title: app.modelName, models: engine.models, current: app.model?.id) { app.modelID = $0.id }
                }
            }
            Hairline()
            PartRow(icon: "bolt", title: "Agent engine",
                    text: "Codex, a free open-source program from OpenAI. It runs the tools the model asks for, keeps the plan, starts helper agents and saves each chat.",
                    ok: setup.codex == nil ? false : engine.ready,
                    status: setup.codex == nil ? "Codex not found" : engine.ready ? setup.codexVersion : app.starting ? "Starting" : (engine.problem ?? "Not running")) {
                HStack(spacing: 8) {
                    if setup.codex == nil, let url = URL(string: "https://github.com/openai/codex") {
                        Link("Get Codex", destination: url).font(.system(size: 13)).foregroundStyle(Theme.accent)
                    }
                    Button("Restart") { Task { await app.boot() } }.buttonStyle(SecondaryButton()).disabled(app.starting)
                        .help("Use this after signing in to Codex or changing its settings. Running work stops.")
                    if app.starting { ProgressView().controlSize(.small) }
                }
            }
            Hairline()
            PartRow(icon: "wrench.and.screwdriver", title: "Archaeology tools",
                    text: "\(ToolGuide.toolCount) tools that come with Dighouse. They fetch lidar, build the bare ground, cut sections, check maps and archives, read the literature and keep the records.",
                    ok: setup.toolsReady ? true : setup.toolsBusy ? nil : false,
                    status: setup.toolsReady ? "Ready" : setup.toolsBusy ? "Preparing"
                        : setup.uv == nil ? "Needs uv" : (setup.toolsProblem ?? "Not prepared")) {
                HStack(spacing: 8) {
                    Button("Open the Toolbox") { app.show(.toolbox) }.buttonStyle(SecondaryButton())
                    if !setup.toolsReady, !setup.toolsBusy, setup.uv != nil {
                        Button("Prepare tools") { Task { await setup.prepareTools(); await app.boot() } }.buttonStyle(PrimaryButton())
                    }
                    if setup.uv == nil, let url = URL(string: "https://docs.astral.sh/uv/getting-started/installation/") {
                        Link("Get uv", destination: url).font(.system(size: 13)).foregroundStyle(Theme.accent)
                    }
                }
            }
            Hairline()
            PartRow(icon: "arrow.triangle.branch", title: "Model router (optional)",
                    text: "OpenCodex adds models from other providers, so a different maker's model can give the second opinion.",
                    ok: setup.ocxRunning ? true : nil, status: setup.ocxRunning ? "Running" : "Not running") { EmptyView() }
        }
        .panel()
        VStack(spacing: 0) {
            SettingRow(title: "Account",
                       note: engine.account.map { "Codex on this Mac is signed in as \($0)\(engine.plan.map { " (\($0) plan)" } ?? ""). The Codex models run on that account. Models added by the router use their own keys." }
                        ?? "Codex is not signed in. Run codex login in Terminal, then restart the engine.") { EmptyView() }
            Hairline()
            SettingRow(title: "The web",
                       note: "The agent can search the web through the engine, and open pages and PDFs with its own reader. Pages that need a sign-in or block programs cannot be read; you can open those yourself in a project's Sources tab.") { EmptyView() }
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


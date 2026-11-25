import SwiftUI

/// Settings, shown as a page in the main window, in five parts by what a person wants: who runs the search and what it
/// costs, where the data goes, how the app looks, the tools, and the rest.
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
                                HStack(spacing: 10) {
                                    Glyph(name: section.icon, size: 13.5 * Theme.scale).frame(width: 20)
                                    Text(section.rawValue).font(.system(size: 13.5 * Theme.scale))
                                }
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
                            // Wraps onto a second line when narrow, so no section is cut off.
                            Flow(spacing: 4) {
                                Group {
                                    ForEach(SettingsSection.allCases, id: \.self) { section in
                                        Button { app.settingsSection = section } label: {
                                            Text(section.rawValue).font(.system(size: 13 * Theme.scale, weight: .medium))
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
                        VStack(alignment: .leading, spacing: 6) {
                            Text(app.settingsSection.rawValue).font(.system(size: 24 * Theme.scale, weight: .bold))
                            Text(app.settingsSection.about).font(.system(size: 14 * Theme.scale)).foregroundStyle(Theme.dim)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        Group {
                            switch app.settingsSection {
                            case .account: AccountSettings()
                            case .data: DataSettings()
                            case .look: LookSettings()
                            case .tools: ToolsSettings()
                            case .advanced: AdvancedSettings()
                            }
                        }
                        .id(app.settingsSection).arrives()
                    }
                    .padding(.horizontal, 32).padding(.vertical, 24)
                    .frame(maxWidth: 760, alignment: .leading).frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
        .background(Theme.bg)
    }
}

extension SettingsSection {
    var icon: String {
        switch self {
        case .account: return "person.crop.circle"
        case .data: return "lock"
        case .look: return "paintpalette"
        case .tools: return "wrench.and.screwdriver"
        case .advanced: return "slider.horizontal.3"
        }
    }

    /// One sentence under the title, saying what the part is for.
    var about: String {
        switch self {
        case .account: return "What runs your search, what checks each find, and what each costs."
        case .data: return "Where your projects are kept, what leaves this Mac, and free keys some open data asks for."
        case .look: return "Text size, colours, and how a project opens."
        case .tools: return "Every tool the agent can use. Press one to see what it does."
        case .advanced: return "How the parts fit together, the models on offer, and the version."
        }
    }
}

/// A heading over a group of settings: the same size and gap on every page.
private struct GroupTitle: View {
    let text: String
    init(_ text: String) { self.text = text }
    var body: some View {
        Text(text).font(.system(size: 15 * Theme.scale, weight: .semibold)).padding(.top, 6)
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
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.system(size: 13.5 * Theme.scale, weight: .medium))
            if !note.isEmpty {
                Text(note).font(.system(size: 12.5 * Theme.scale)).foregroundStyle(Theme.dim).lineSpacing(2).fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

/// What runs, what checks and what it costs, as three cards at the top of Account and models.
private struct RunsSummary: View {
    @EnvironmentObject var app: AppState
    @EnvironmentObject var engine: Engine
    @EnvironmentObject var setup: Setup
    @EnvironmentObject var chat: ChatModel

    private var searchCost: String {
        guard let account = engine.account else { return "Not signed in yet" }
        if account == "an OpenAI API key" { return "Billed to your OpenAI API key" }
        let plan = engine.plan.map { "Your ChatGPT \($0.capitalized) plan" } ?? "Your ChatGPT plan"
        return plan + (chat.usageLeft.map { ", \($0)% left" } ?? "")
    }

    private var opinionCost: String {
        guard let id = app.secondModelID else { return "No model chosen" }
        if ModelInfo.viaClaudeCode(id) { return "Your Claude account, through Claude Code" }
        if app.onThisAccount(id) { return "Your ChatGPT plan; they wait below \(AppState.opinionFloor)% left" }
        return "The \(id.split(separator: "/").first.map(String.init) ?? "router's") account, through OpenCodex"
    }

    var body: some View {
        // One panel in three parts, side by side when there is room and one under the other when narrow.
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .top, spacing: 0) {
                part(0); Hairline(vertical: true); part(1); Hairline(vertical: true); part(2)
            }
            .fixedSize(horizontal: false, vertical: true)
            VStack(spacing: 0) { part(0); Hairline(); part(1); Hairline(); part(2) }
        }
        .panel()
    }

    @ViewBuilder private func part(_ i: Int) -> some View {
        switch i {
        case 0:
            column(icon: "cpu", title: "The search", value: engine.ready ? app.modelName : (app.starting ? "Starting…" : "Not running"),
                   ok: engine.ready && engine.account != nil ? true : app.starting ? nil : false,
                   status: engine.ready ? "Runs on Codex, \(Self.version(setup.codexVersion))" : (engine.problem ?? (setup.codex == nil ? "Codex is not on this Mac" : "The engine is not running")),
                   cost: searchCost) {
                if !engine.ready, !app.starting { Button("Restart") { Task { await app.boot() } }.buttonStyle(SecondaryButton()) }
            }
        case 1:
            column(icon: "person.2", title: "Second opinions", value: app.secondModelName,
                   ok: app.secondModelID == nil ? false : app.opinionsWaiting == nil ? true : nil,
                   status: app.opinionsWaiting == nil ? "Asked only about finds a person will see" : "Waiting until usage resets",
                   cost: opinionCost) { EmptyView() }
        default:
            column(icon: "map", title: "Open data", value: "Free and public", ok: true,
                   status: "No account needed", cost: "Two services ask for a free key") {
                Button { app.settingsSection = .data } label: { Label("Keys", systemImage: "arrow.right").labelStyle(TrailingIcon()) }
                    .buttonStyle(.plain).font(.system(size: 12.5 * Theme.scale, weight: .medium)).foregroundStyle(Theme.tan)
            }
        }
    }

    /// "codex-cli 0.171.0-alpha.2" as "0.171.0".
    static func version(_ text: String) -> String {
        text.split(separator: " ").last?.split(separator: "-").first.map(String.init) ?? text
    }

    private func column<Action: View>(icon: String, title: String, value: String, ok: Bool?, status: String, cost: String,
                                      @ViewBuilder action: () -> Action) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Glyph(name: icon, size: 12 * Theme.scale).foregroundStyle(Theme.tan)
                Text(title).font(.system(size: 12 * Theme.scale, weight: .semibold)).foregroundStyle(Theme.dim)
            }
            Text(value).font(.system(size: 16 * Theme.scale, weight: .semibold)).lineLimit(2).fixedSize(horizontal: false, vertical: true)
            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Circle().fill(ok == true ? Theme.green : ok == false ? Theme.amber : Theme.faint).frame(width: 6, height: 6)
                    Text(status).foregroundStyle(ok == false ? Theme.amber : Theme.dim)
                }
                Text(cost).foregroundStyle(Theme.faint)
            }
            .font(.system(size: 12.5 * Theme.scale)).fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
            action()
        }
        .padding(16)
        .frame(minWidth: 0, idealWidth: 190 * Theme.scale, maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

/// A label with its icon after the words: "Keys →".
private struct TrailingIcon: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 4) { configuration.title; configuration.icon.font(.system(size: 10 * Theme.scale, weight: .bold)) }
    }
}

private struct AccountSettings: View {
    @EnvironmentObject var app: AppState
    @EnvironmentObject var engine: Engine
    @EnvironmentObject var setup: Setup
    @State private var signingIn = false
    @State private var signInProblem: String?

    /// Plain warnings about the two choices, or none when they are sound.
    private var warnings: [String] {
        var out: [String] = []
        if let notice = app.modelNotice { out.append(notice) }
        if let m = app.model, !m.readsImages { out.append("\(m.name) cannot read images, so it cannot look at tiles. Choose a model that reads images.") }
        if app.secondModelID == nil { out.append("No second opinion model is chosen, so finds cannot get an independent second opinion.") }
        if let refusal = app.refusedSecondModel, app.secondOpinionModels.isEmpty {
            out.append("\(app.secondModelName) refused the last second opinion: \(ProjectOverview.shortReason(refusal)) Choose another model.")
        }
        if app.secondModelID != nil, app.secondModelID == app.model?.id { out.append("The second opinion uses the same model as the agent. A different model gives a truly independent opinion.") }
        return out
    }

    var body: some View {
        RunsSummary()
        if !warnings.isEmpty {
            VStack(alignment: .leading, spacing: 6) {
                ForEach(warnings, id: \.self) { w in
                    Label(w, systemImage: "exclamationmark.triangle").font(.system(size: 12.5 * Theme.scale)).foregroundStyle(Theme.amber)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(12).frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 10).fill(Theme.amber.opacity(0.08)))
        }

        GroupTitle("You")
        VStack(spacing: 0) {
            SettingRow(title: "Your name", note: "Signs your decisions.") {
                TextField("Name", text: $app.userName).field().font(.system(size: 13 * Theme.scale)).frame(width: 220)
            }
            Hairline()
            if let account = engine.account {
                SettingRow(title: "Signed in", note: "As \(account)\(engine.plan.map { ", on a \($0) plan" } ?? ""). Dighouse never sees a password, and keeps no copy of a key.") { EmptyView() }
            } else {
                VStack(alignment: .leading, spacing: 10) {
                    SettingRow(title: "Sign in", note: signInProblem ?? (setup.codex == nil
                        ? "The search runs on Codex, OpenAI's free engine. Install it from the welcome guide, then sign in."
                        : "With a ChatGPT account, in your browser, or with an OpenAI API key.")) {
                        if setup.codex == nil {
                            Button("Welcome guide") { app.showWelcome = true }.buttonStyle(SecondaryButton())
                        } else if signingIn { DigIndicator() } else {
                            Button("Sign in with ChatGPT") {
                                signingIn = true
                                signInProblem = nil
                                Task {
                                    do { try await engine.signIn(); await app.boot() } catch { signInProblem = error.localizedDescription }
                                    signingIn = false
                                }
                            }
                            .buttonStyle(PrimaryButton()).disabled(!engine.running)
                        }
                    }
                    if setup.codex != nil, engine.running, !signingIn { APIKeySignIn().padding(.horizontal, 14).padding(.bottom, 12) }
                }
            }
        }
        .panel()

        GroupTitle("The search")
        VStack(spacing: 0) {
            SettingRow(title: "Agent model", note: "Runs the search and looks at every tile, so it must read images.") {
                ModelPicker(title: app.modelName, models: engine.models, current: app.model?.id) { app.modelID = $0.id; app.modelNotice = nil }
            }
            Hairline()
            effortRow
        }
        .panel()

        GroupTitle("Second opinions")
        VStack(spacing: 0) {
            SettingRow(title: "Second opinion model", note: "Looks at each find on its own, without the agent's verdict. GPT-6 Luna is the economical choice. Claude Sonnet found more of the known features in a test (19 of 24, against 9).") {
                ModelPicker(title: app.secondModelName, models: app.opinionChoices,
                            current: app.secondModelID) { app.secondModelID = $0.id; app.modelNotice = nil }
            }
            Hairline()
            secondOrder
        }
        .panel()

        GroupTitle("Claude")
        ClaudeCodeSettings()

        Text(setup.ocxRunning || engine.models.contains { $0.id.contains("/") }
             ? "\(engine.models.count) models, from your Codex sign-in and the OpenCodex router on this Mac. The start of each name is the account it runs through."
             : "\(engine.models.count) models, from your Codex sign-in. The OpenCodex router, if you want it, adds models from other makers. Dighouse does not need it.")
            .font(.system(size: 12.5 * Theme.scale)).foregroundStyle(Theme.faint).lineSpacing(2).fixedSize(horizontal: false, vertical: true)
    }

    /// The second-opinion models in the order they are asked, each with a check that sends it one lidar picture.
    private var secondOrder: some View {
        // The chosen model, then the defaults this Mac offers (the same model is listed once whichever way it is reached).
        let ids = ([app.secondModelID].compactMap { $0 } + ModelInfo.secondOpinionOrder.filter { id in app.opinionChoices.contains { $0.id == id } })
            .reduce(into: [String]()) { list, id in
                if !list.contains(where: { $0 == id || $0.split(separator: "/").last == id.split(separator: "/").last }) { list.append(id) }
            }
        return VStack(alignment: .leading, spacing: 8) {
            Text("Asked in this order").font(.system(size: 13.5 * Theme.scale, weight: .medium))
            ForEach(Array(ids.enumerated()), id: \.element) { i, id in
                let model = app.opinionChoices.first { $0.id == id }
                HStack(alignment: .top, spacing: 10) {
                    Text("\(i + 1)").font(.system(size: 12 * Theme.scale, weight: .bold, design: .monospaced)).foregroundStyle(Theme.faint).frame(width: 14)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(model?.name ?? id).font(.system(size: 13 * Theme.scale))
                        if model == nil {
                            Text("Not offered by the router on this Mac.").font(.system(size: 12 * Theme.scale)).foregroundStyle(Theme.faint)
                        } else if let check = app.modelCheck[id] {
                            Text(check.text).font(.system(size: 12 * Theme.scale)).foregroundStyle(check.ok ? Theme.dim : Theme.amber)
                                .fixedSize(horizontal: false, vertical: true)
                        } else if let failed = app.secondFailed[id] {
                            Text("Did not answer last time: " + ProjectOverview.shortReason(failed)).font(.system(size: 12 * Theme.scale)).foregroundStyle(Theme.amber)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    Spacer(minLength: 8)
                    if model != nil {
                        Button("Check") { app.checkModel(id) }.buttonStyle(SecondaryButton())
                            .disabled(app.modelCheck[id]?.text == "Asking…")
                            .help("Sends the model one lidar picture and shows what it says.")
                    }
                }
            }
        }
        .padding(14).frame(maxWidth: .infinity, alignment: .leading)
    }

    /// How long the model thinks. The steps, what each is for and the default all come from the model list.
    @ViewBuilder private var effortRow: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let model = app.model, let effort = app.activeEffort {
                HStack(alignment: .firstTextBaseline) {
                    Text("Thinking effort").font(.system(size: 13.5 * Theme.scale, weight: .medium))
                    Spacer()
                    Text(Effort.label(effort)).font(.system(size: 13.5 * Theme.scale, weight: .semibold)).foregroundStyle(Theme.accent)
                }
                StepSlider(steps: model.efforts, value: Binding(get: { effort }, set: { app.effort = $0 }), showLabels: true)
                Text(Effort.note(effort, for: model))
                    .font(.system(size: 12.5 * Theme.scale)).foregroundStyle(Theme.dim).fixedSize(horizontal: false, vertical: true)
            } else {
                Text("Thinking effort").font(.system(size: 13.5 * Theme.scale, weight: .medium))
                Text("\(app.modelName) has no effort steps in the model list.")
                    .font(.system(size: 12.5 * Theme.scale)).foregroundStyle(Theme.dim).fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(14).frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// Claude Code, for people who use Claude: second opinions on the Claude plan, and searches run from Claude Code.
private struct ClaudeCodeSettings: View {
    @EnvironmentObject var setup: Setup
    @State private var connected: Bool?
    @State private var busy = false
    @State private var problem: String?

    var body: some View {
        VStack(spacing: 0) {
            SettingRow(title: "Claude Code",
                       note: setup.claude != nil
                       ? "On this Mac, version \(setup.claudeVersion.split(separator: " ").first.map(String.init) ?? ""). Second opinions can go to Claude Sonnet or Haiku through it, on your Claude account: choose one above."
                       : "Not on this Mac. With it, second opinions can go to Claude on your Claude account, and Claude Code can run searches with Dighouse's tools.") {
                if setup.claude == nil, let url = URL(string: "https://docs.claude.com/en/docs/claude-code/setup") {
                    Button { NSWorkspace.shared.open(url) } label: { Label("Get Claude Code", systemImage: "arrow.up.right") }.buttonStyle(SecondaryButton())
                }
            }
            if let claude = setup.claude, setup.toolsReady {
                Hairline()
                SettingRow(title: "Search from Claude Code",
                           note: problem ?? (connected == true
                           ? "Claude Code has Dighouse's tools and search guide. Ask it to search a place there; the projects it makes appear here, to look at and decide."
                           : "Gives Claude Code Dighouse's tools and search guide, so you can run a search from Claude Code. The projects it makes appear here.")) {
                    if busy || connected == nil { DigIndicator() } else if connected == true {
                        Button("Remove") { Task { await change(claude, add: false) } }.buttonStyle(SecondaryButton())
                    } else {
                        Button("Add to Claude Code") { Task { await change(claude, add: true) } }.buttonStyle(SecondaryButton())
                    }
                }
            }
        }
        .panel()
        .task(id: setup.claude) {
            if let claude = setup.claude { connected = await ClaudeCode.connected(claude) }
        }
    }

    private func change(_ claude: String, add: Bool) async {
        busy = true
        problem = add ? await ClaudeCode.connect(claude, tools: setup.toolsBinary, skill: setup.skill) : await ClaudeCode.disconnect(claude)
        connected = await ClaudeCode.connected(claude)
        busy = false
    }
}

/// Text size, how a project opens, and the colours.
private struct LookSettings: View {
    @EnvironmentObject var app: AppState

    var body: some View {
        VStack(spacing: 0) {
            SettingRow(title: "Text size", note: "⌘+ and ⌘− change it too.") {
                HStack(spacing: 2) {
                    ForEach(TextSize.all, id: \.id) { item in
                        Button { app.textSize = item.id } label: {
                            Text(item.name).font(.system(size: 12.5 * Theme.scale, weight: app.textSize == item.id ? .semibold : .medium))
                                .foregroundStyle(app.textSize == item.id ? Theme.text : Theme.dim)
                                .padding(.horizontal, 12).frame(height: 26)
                                .background(RoundedRectangle(cornerRadius: 6).fill(app.textSize == item.id ? Theme.raised : .clear))
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(2).background(RoundedRectangle(cornerRadius: 8).fill(Theme.ink.opacity(0.06)))
            }
            Hairline()
            SettingRow(title: "A project opens as", note: "The chat, the map and work, or both side by side.") {
                PillMenu(title: PaneLayout.names[app.layout] ?? "") {
                    PaneLayout.allCases.map { layout in
                        MenuEntry(title: PaneLayout.names[layout] ?? "", icon: layout.icon, checked: app.layout == layout) { app.layout = layout }
                    }
                }
            }
        }
        .panel()
        GroupTitle("Colours")
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
                                HStack(spacing: 4) {
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
                            Text(look.rawValue).font(.system(size: 13.5 * Theme.scale, weight: .semibold))
                            if look == .earth { Text("Default").font(.system(size: 11.5 * Theme.scale)).foregroundStyle(Theme.faint) }
                            Spacer()
                            if app.look == look { Image(systemName: "checkmark.circle.fill").foregroundStyle(Theme.accent) }
                        }
                        Text(look.note).font(.system(size: 12.5 * Theme.scale)).foregroundStyle(Theme.dim)
                    }
                    .padding(12).frame(maxWidth: .infinity, alignment: .topLeading)
                    .background(RoundedRectangle(cornerRadius: 14).fill(Theme.ink.opacity(0.035)))
                    .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(app.look == look ? Theme.accent : Theme.line, lineWidth: app.look == look ? 1.5 : 1))
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
    }
}

/// Where projects are kept, what leaves this Mac, and the free keys.
private struct DataSettings: View {
    @AppStorage("projectsHome") private var projectsHome = ""
    private let rows: [(String, String)] = [
        ("Messages and images", "Go to the provider of the model you chose, through the engine."),
        ("Locations", "Stay in each project's private folder on this Mac. Records, notes and reports carry none."),
        ("Open data services", "Each sees the area or the search words in a request, and nothing else."),
        ("The map", "New project uses Apple Maps, which sees where you look."),
        ("Reports", "Nothing is sent. A report is a draft until you send it."),
    ]

    var body: some View {
        VStack(spacing: 0) {
            SettingRow(title: "Projects folder", note: (projectsHome.isEmpty ? Paths.projectsHome.path : projectsHome).tildePath) {
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
            SettingRow(title: "Chats, catalogs and the tools", note: Paths.support.path.tildePath) {
                Button("Show") { NSWorkspace.shared.open(Paths.support) }.buttonStyle(SecondaryButton())
            }
        }
        .panel()
        CloudNotice()

        GroupTitle("What leaves this Mac")
        VStack(spacing: 0) {
            ForEach(Array(rows.enumerated()), id: \.offset) { index, row in
                if index > 0 { Hairline() }
                SettingRow(title: row.0, note: row.1) { EmptyView() }
            }
        }
        .panel()

        GroupTitle("Free keys")
        OpenDataKeys()
    }
}

/// How the parts fit together, the models on offer, the guide, and the version.
private struct AdvancedSettings: View {
    @EnvironmentObject var app: AppState
    @EnvironmentObject var engine: Engine
    @EnvironmentObject var setup: Setup

    /// The makers behind the models on offer, read from each model's name, with how many of theirs there are.
    private var makers: [(family: String, count: Int)] {
        let known: [(String, String)] = [("claude", "Claude"), ("gpt", "GPT"), ("grok", "Grok"), ("kimi", "Kimi"),
                                         ("glm", "GLM"), ("qwen", "Qwen"), ("deepseek", "DeepSeek"), ("llama", "Llama")]
        var counts: [String: Int] = [:]
        for m in engine.models {
            let text = (m.id + " " + m.name).lowercased()
            counts[known.first { text.contains($0.0) }?.1 ?? "Other", default: 0] += 1
        }
        return known.map(\.1).compactMap { name in counts[name].map { (name, $0) } }.sorted { $0.count > $1.count }
            + (counts["Other"].map { [("Other", $0)] } ?? [])
    }
    private var routed: Bool { setup.ocxRunning || engine.models.contains { $0.id.contains("/") } }

    var body: some View {
        GroupTitle("How it runs")
        VStack(spacing: 14) {
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .top, spacing: 0) { parts(arrow: "arrow.right") }
                VStack(spacing: 6) { parts(arrow: "arrow.down") }
            }
            HStack(spacing: 8) {
                Image(systemName: "arrow.uturn.backward").font(.system(size: 10 * Theme.scale, weight: .bold))
                Text("Each result goes back to the model, until the job is done.")
            }
            .font(.system(size: 12.5 * Theme.scale)).foregroundStyle(Theme.dim)
        }
        .padding(16).frame(maxWidth: .infinity).panel()

        GroupTitle("Models on offer")
        VStack(spacing: 0) {
            SettingRow(title: routed ? "From Codex and the OpenCodex router" : "From your Codex sign-in",
                       note: routed ? "The router on this Mac adds other makers' models." : "OpenCodex, a router you can add, offers other makers' models. Dighouse does not need it.") {
                if let url = URL(string: "https://github.com/lidge-jun/opencodex") {
                    Button { NSWorkspace.shared.open(url) } label: { Label("OpenCodex", systemImage: "arrow.up.right") }.buttonStyle(SecondaryButton())
                }
            }
            if engine.ready {
                Flow(spacing: 8) {
                    ForEach(makers, id: \.family) { m in
                        HStack(spacing: 6) {
                            Text(m.family).font(.system(size: 12.5 * Theme.scale, weight: .semibold))
                            Text("\(m.count)").font(.system(size: 12 * Theme.scale)).foregroundStyle(Theme.faint)
                        }
                        .padding(.horizontal, 10).frame(height: 26)
                        .background(RoundedRectangle(cornerRadius: 7).fill(Theme.ink.opacity(0.06)))
                    }
                }
                .padding(.horizontal, 14).padding(.bottom, 14).frame(maxWidth: .infinity, alignment: .leading)
            }
            Hairline()
            SettingRow(title: "The web", note: "The agent can search the web and read pages and PDFs that need no sign-in.") { EmptyView() }
        }
        .panel()

        GroupTitle("About")
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? ""
        VStack(spacing: 0) {
            HStack(spacing: 14) {
                Image(nsImage: NSApp.applicationIconImage).resizable().frame(width: 48, height: 48)
                VStack(alignment: .leading, spacing: 4) {
                    Text("Dighouse \(version)").font(.system(size: 15 * Theme.scale, weight: .semibold))
                    Text("A free, open tool for searching public lidar for places people built. Open source, Apache 2.0.")
                        .font(.system(size: 12.5 * Theme.scale)).foregroundStyle(Theme.dim).fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 8)
                if let url = URL(string: "https://github.com/chrissotraidis/dighouse") {
                    Button { NSWorkspace.shared.open(url) } label: { Label("GitHub", systemImage: "arrow.up.right") }.buttonStyle(SecondaryButton())
                }
            }
            .padding(14)
            Hairline()
            SettingRow(title: "Versions", note: "Dighouse \(version), engine \(setup.codexVersion.isEmpty ? "not found" : setup.codexVersion)") {
                Button("Copy") {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString("Dighouse \(version), engine \(setup.codexVersion)", forType: .string)
                }
                .buttonStyle(SecondaryButton()).help("Copy these to include when you report a problem.")
            }
            Hairline()
            SettingRow(title: "Welcome guide", note: "What Dighouse does, and what it needs on this Mac.") {
                Button("Open") { app.showWelcome = true }.buttonStyle(SecondaryButton())
            }
            Hairline()
            SettingRow(title: "The word lidar", note: "Written in lowercase here, as the US Geological Survey writes it.") { EmptyView() }
        }
        .panel()
    }

    @ViewBuilder private func parts(arrow: String) -> some View {
        part(icon: "person", tint: Theme.accent, title: "You", role: "ask in plain words", ok: true, status: app.userName) { EmptyView() }
        link(arrow)
        part(icon: "cpu", tint: Theme.tan, title: "The model", role: "decides each step",
             ok: engine.ready && !app.starting ? true : nil, status: app.starting ? "Starting" : engine.ready ? app.modelName : "Waiting") {
            Button("Change") { app.settingsSection = .account }.buttonStyle(SecondaryButton()).disabled(!engine.ready)
        }
        link(arrow)
        part(icon: "bolt", tint: Theme.tan, title: "The engine", role: "runs what it asks for",
             ok: setup.codex == nil ? false : app.starting ? nil : engine.ready,
             // The short version here; About has the full one.
             status: setup.codex == nil ? "Codex not found" : app.starting ? "Starting"
                : engine.ready ? "Codex " + (setup.codexVersion.split(separator: " ").last?.split(separator: "-").first.map(String.init) ?? "")
                : (engine.problem ?? "Not running")) {
            if setup.codex == nil, let url = URL(string: "https://github.com/openai/codex") {
                Button("Get Codex") { NSWorkspace.shared.open(url) }.buttonStyle(PrimaryButton())
            } else {
                Button("Restart") { Task { await app.boot() } }.buttonStyle(SecondaryButton()).disabled(app.starting)
                    .help("Use this after signing in to Codex or changing its settings. Running work stops.")
            }
        }
        link(arrow)
        part(icon: "wrench.and.screwdriver", tint: Theme.tan, title: "The tools", role: "read open data",
             ok: setup.toolsReady ? true : setup.toolsBusy ? nil : false,
             status: setup.toolsReady ? "\(ToolGuide.toolCount) ready" : setup.toolsBusy ? "Preparing" : setup.uv == nil ? "Needs uv" : (setup.toolsProblem ?? "Not prepared")) {
            if setup.toolsReady || setup.toolsBusy {
                Button("See them") { app.settingsSection = .tools }.buttonStyle(SecondaryButton())
            } else if setup.uv == nil, let url = URL(string: "https://docs.astral.sh/uv/getting-started/installation/") {
                Button("Get uv") { NSWorkspace.shared.open(url) }.buttonStyle(PrimaryButton())
            } else {
                Button("Prepare") { Task { await setup.prepareTools(); await app.boot() } }.buttonStyle(PrimaryButton())
            }
        }
    }

    private func link(_ arrow: String) -> some View {
        Image(systemName: arrow).font(.system(size: 11 * Theme.scale, weight: .bold)).foregroundStyle(Theme.faint)
            .padding(.top, arrow == "arrow.right" ? 22 : 0).padding(.horizontal, 2)
    }

    /// One part of the picture: what it is, what it does, how it is now, and the one thing you can do about it.
    private func part<Action: View>(icon: String, tint: Color, title: String, role: String, ok: Bool?, status: String,
                                    @ViewBuilder action: () -> Action) -> some View {
        VStack(spacing: 8) {
            Glyph(name: icon, size: 17 * Theme.scale).foregroundStyle(tint)
                .frame(width: 44, height: 44).background(Circle().fill(Theme.ink.opacity(0.07)))
            VStack(spacing: 1) {
                Text(title).font(.system(size: 13.5 * Theme.scale, weight: .semibold))
                Text(role).font(.system(size: 12 * Theme.scale)).foregroundStyle(Theme.faint).multilineTextAlignment(.center)
            }
            HStack(spacing: 4) {
                Circle().fill(ok == true ? Theme.green : ok == false ? Theme.amber : Theme.faint).frame(width: 7, height: 7)
                Text(status).font(.system(size: 12 * Theme.scale)).foregroundStyle(ok == false ? Theme.amber : Theme.dim).lineLimit(2)
                    .multilineTextAlignment(.center)
            }
            action().frame(height: 28)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
    }
}

/// Every tool the agent has: a search box, and the tools of each stage as names to press.
private struct ToolsSettings: View {
    @EnvironmentObject var app: AppState
    @State private var query = ""
    @State private var picked: String?

    private func matches(_ tool: ToolGuide.Tool) -> Bool {
        query.isEmpty || [tool.title, tool.does, tool.name].contains { $0.localizedCaseInsensitiveContains(query) }
    }

    var body: some View {
        HStack(spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass").font(.system(size: 12 * Theme.scale)).foregroundStyle(Theme.faint)
                TextField("Search \(ToolGuide.toolCount) tools", text: $query).textFieldStyle(.plain).font(.system(size: 13 * Theme.scale))
            }
            .padding(.horizontal, 10).frame(height: 32)
            .background(RoundedRectangle(cornerRadius: 9).fill(Theme.ink.opacity(0.06)))
            Button { UserDefaults.standard.set(ToolboxView.Tab.act.rawValue, forKey: "toolboxPart"); app.show(.toolbox) } label: { Label("Add tools", systemImage: "plus") }
                .buttonStyle(SecondaryButton()).help("Other tools the agent can use, and adding a tool server, are in the Toolbox.")
        }
        let shown = ToolGuide.packs.map { pack in (pack, pack.tools.filter(matches)) }.filter { !$0.1.isEmpty }
        if shown.isEmpty {
            Text("No tool matches.").font(.system(size: 13 * Theme.scale)).foregroundStyle(Theme.faint)
        }
        VStack(spacing: 0) {
            ForEach(Array(shown.enumerated()), id: \.element.0.id) { index, group in
                if index > 0 { Hairline() }
                HStack(alignment: .top, spacing: 12) {
                    IconTile(name: group.0.icon, size: 30)
                    VStack(alignment: .leading, spacing: 8) {
                        Text(group.0.title).font(.system(size: 13.5 * Theme.scale, weight: .semibold))
                        Flow(spacing: 6) {
                            ForEach(group.1) { tool in
                                Button { picked = picked == tool.name ? nil : tool.name } label: {
                                    Text(tool.title).font(.system(size: 12.5 * Theme.scale))
                                        .foregroundStyle(picked == tool.name ? .black : Theme.text.opacity(0.9))
                                        .padding(.horizontal, 10).frame(height: 26)
                                        .background(Capsule().fill(picked == tool.name ? Theme.tan : Theme.ink.opacity(0.07)))
                                        .contentShape(Capsule())
                                }
                                .buttonStyle(.plain).help(tool.does)
                            }
                        }
                        if let tool = group.1.first(where: { $0.name == picked }) {
                            (Text(tool.does).foregroundColor(Theme.dim) + Text("  " + tool.name).font(.system(size: 11.5 * Theme.scale, design: .monospaced)).foregroundColor(Theme.faint))
                                .font(.system(size: 12.5 * Theme.scale)).fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    Spacer(minLength: 0)
                }
                .padding(14)
            }
        }
        .panel()
    }
}

/// Accounts some open data services ask for. Denmark's ground model needs a free token from Dataforsyningen; OpenAlex,
/// where the literature is searched, shares a small daily budget among everyone without a key.
private struct OpenDataKeys: View {
    var body: some View {
        VStack(spacing: 0) {
            KeyRow(name: "dataforsyningen", title: "Denmark's ground model", field: "Token", get: "Get a token",
                   note: "Dataforsyningen asks for a free account and a token. Paste the token here. It stays in a file only you can read on this Mac.",
                   link: "https://confluence.kds.dk/display/MYD/Log%2Bind%2Bog%2BToken")
            Hairline()
            KeyRow(name: "openalex", title: "Books and papers (OpenAlex)", field: "Key", get: "Get a key",
                   note: "Without a key, everyone on your network shares about 100 literature searches a day, and Dighouse falls back to Crossref after that. A free key gives you your own. Asking for one sends OpenAlex your email address.",
                   link: "https://help.openalex.org/api/authentication/")
        }
        .panel()
    }
}

private struct KeyRow: View {
    let name: String, title: String, field: String, get: String, note: String, link: String
    @State private var value = ""
    @State private var saved = ""

    var body: some View {
        SettingRow(title: title, note: note) {
            HStack(spacing: 8) {
                SecureField(field, text: $value).textFieldStyle(.plain).font(.system(size: 13 * Theme.scale))
                    .padding(.horizontal, 10).frame(width: 190, height: 30)
                    .background(RoundedRectangle(cornerRadius: 8).fill(Theme.ink.opacity(0.06)))
                Button(value == saved ? (saved.isEmpty ? "Save" : "Saved") : "Save") {
                    Keys.write(name, value)
                    saved = Keys.read(name)
                }
                .buttonStyle(SecondaryButton()).disabled(value == saved)
                if let url = URL(string: link) {
                    Link(destination: url) { Label(get, systemImage: "arrow.up.right").font(.system(size: 12.5 * Theme.scale)) }
                        .foregroundStyle(Theme.green)
                }
            }
        }
        .onAppear { value = Keys.read(name); saved = value }
    }
}


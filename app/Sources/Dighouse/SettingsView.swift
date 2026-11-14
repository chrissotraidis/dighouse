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
                                HStack(spacing: 9) {
                                    Glyph(name: icon(section), size: 13.5 * Theme.scale).frame(width: 20)
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
                        Text(app.settingsSection.rawValue).font(.system(size: 24 * Theme.scale, weight: .bold))
                        switch app.settingsSection {
                        case .general: GeneralSettings()
                        case .look: LookSettings()
                        case .models: ModelSettings()
                        case .engine: EngineSettings()
                        case .tools: ToolsSettings()
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
        case .engine: return "point.3.connected.trianglepath.dotted"
        case .tools: return "wrench.and.screwdriver"
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
            Text(title).font(.system(size: 13.5 * Theme.scale, weight: .medium))
            if !note.isEmpty {
                Text(note).font(.system(size: 12.5 * Theme.scale)).foregroundStyle(Theme.dim).lineSpacing(2).fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

private struct GeneralSettings: View {
    @EnvironmentObject var app: AppState
    @AppStorage("projectsHome") private var projectsHome = ""

    var body: some View {
        VStack(spacing: 0) {
            SettingRow(title: "Your name", note: "Written into a record when you make a decision on a find.") {
                TextField("Name", text: $app.userName).field().font(.system(size: 13 * Theme.scale)).frame(width: 220)
            }
            Hairline()
            SettingRow(title: "Projects folder", note: "New projects are created in \((projectsHome.isEmpty ? Paths.projectsHome.path : projectsHome).tildePath).") {
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
                PillMenu(title: PaneLayout.names[app.layout] ?? "") {
                    PaneLayout.allCases.map { layout in
                        MenuEntry(title: PaneLayout.names[layout] ?? "", icon: layout.icon, checked: app.layout == layout) { app.layout = layout }
                    }
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
        VStack(spacing: 0) {
            SettingRow(title: "Text size", note: "Makes every word in Dighouse larger. The window redraws when you change it.") {
                HStack(spacing: 2) {
                    ForEach([("standard", "Standard"), ("large", "Large"), ("larger", "Larger")], id: \.0) { item in
                        Button { app.textSize = item.0 } label: {
                            Text(item.1).font(.system(size: 12.5 * Theme.scale, weight: app.textSize == item.0 ? .semibold : .medium))
                                .foregroundStyle(app.textSize == item.0 ? Theme.text : Theme.dim)
                                .padding(.horizontal, 12).frame(height: 26)
                                .background(RoundedRectangle(cornerRadius: 6).fill(app.textSize == item.0 ? Theme.raised : .clear))
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(2).background(RoundedRectangle(cornerRadius: 8).fill(Theme.ink.opacity(0.06)))
            }
        }
        .panel()
        Text("Colours").font(.system(size: 15 * Theme.scale, weight: .semibold)).padding(.top, 4)
        Text("Dighouse wears the colours of its icon: dark soil, the tan line of the ground, and the green of the canopy above it. Pick another look if you prefer.")
            .font(.system(size: 13.5 * Theme.scale)).foregroundStyle(Theme.dim).lineSpacing(3).fixedSize(horizontal: false, vertical: true)
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
                            Text(look.rawValue).font(.system(size: 13.5 * Theme.scale, weight: .semibold))
                            if look == .earth { Text("Default").font(.system(size: 11.5 * Theme.scale)).foregroundStyle(Theme.faint) }
                            Spacer()
                            if app.look == look { Image(systemName: "checkmark.circle.fill").foregroundStyle(Theme.accent) }
                        }
                        Text(look.note).font(.system(size: 12.5 * Theme.scale)).foregroundStyle(Theme.dim).lineSpacing(2)
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

    /// The maker behind a model, from its id, so two choices from the same maker can be pointed out.
    private func maker(_ id: String?) -> String? {
        guard let id = id?.lowercased() else { return nil }
        for (key, name) in [("claude", "Anthropic"), ("anthropic", "Anthropic"), ("gpt", "OpenAI"), ("gemini", "Google"),
                            ("grok", "xAI"), ("kimi", "Moonshot"), ("glm", "Zhipu"), ("qwen", "Alibaba"), ("deepseek", "DeepSeek")] where id.contains(key) {
            return name
        }
        return nil
    }

    /// Plain warnings about the two choices, or none when they are sound.
    private var warnings: [String] {
        var out: [String] = []
        if let m = app.model, !m.readsImages { out.append("\(m.name) cannot read images, so it cannot look at tiles. Choose a model that reads images.") }
        if app.secondModelID == nil { out.append("No second opinion model is chosen, so finds cannot get an independent second opinion.") }
        if app.secondModelID != nil, app.secondModelID == app.model?.id { out.append("The second opinion uses the same model as the agent. A different model gives a truly independent opinion.") }
        else if let a = maker(app.model?.id), let b = maker(app.secondModelID), a == b {
            out.append("Both models come from \(a). A model from a different maker gives a more independent second opinion.")
        }
        return out
    }

    var body: some View {
        Text("One model runs the search. A second, from a different maker, gives each find its own opinion.")
            .font(.system(size: 14 * Theme.scale)).foregroundStyle(Theme.dim).fixedSize(horizontal: false, vertical: true)
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
        VStack(spacing: 0) {
            SettingRow(title: "Agent model", note: "Runs the search. It must be able to read images.") {
                ModelPicker(title: app.modelName, models: engine.models, current: app.model?.id) { app.modelID = $0.id }
            }
            Hairline()
            effortRow
            Hairline()
            SettingRow(title: "Second opinion model", note: "Gives the second opinion on each find.") {
                ModelPicker(title: app.secondModelName, models: engine.models.filter { $0.readsImages },
                            current: app.secondModelID) { app.secondModelID = $0.id }
            }
        }
        .panel()
        Text(setup.ocxRunning
             ? "\(engine.models.count) models, from the OpenCodex router on this Mac. The start of each name is the provider or account it runs through."
             : "\(engine.models.count) models, from the Codex sign-in on this Mac. The OpenCodex router adds models from other providers.")
            .font(.system(size: 12.5 * Theme.scale)).foregroundStyle(Theme.faint).lineSpacing(2).fixedSize(horizontal: false, vertical: true)
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

/// One part of Dighouse: what it is in a sentence, whether it is working, and what you can do about it.
private struct PartRow<Action: View>: View {
    let icon: String, title: String, text: String
    let ok: Bool?
    let status: String
    @ViewBuilder let action: () -> Action

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: icon).font(.system(size: 15 * Theme.scale)).foregroundStyle(Theme.tan).frame(width: 22).padding(.top, 1)
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.system(size: 13.5 * Theme.scale, weight: .semibold))
                Text(text).font(.system(size: 12.5 * Theme.scale)).foregroundStyle(Theme.dim).lineSpacing(2).fixedSize(horizontal: false, vertical: true)
                action().padding(.top, 4)
            }
            Spacer(minLength: 12)
            HStack(spacing: 6) {
                Circle().fill(ok == true ? Theme.green : ok == false ? Theme.amber : Theme.faint).frame(width: 7, height: 7)
                Text(status).font(.system(size: 12.5 * Theme.scale)).foregroundStyle(ok == false ? Theme.amber : Theme.text).lineLimit(2)
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
                        Image(systemName: "arrow.right").font(.system(size: 11 * Theme.scale, weight: .bold)).foregroundStyle(Theme.faint).padding(.top, 14)
                    }
                    VStack(spacing: 6) {
                        Image(systemName: stop.0).font(.system(size: 16 * Theme.scale)).foregroundStyle(index == 0 ? Theme.accent : Theme.tan)
                            .frame(width: 40, height: 40).background(Circle().fill(Theme.ink.opacity(0.07)))
                        Text(stop.1).font(.system(size: 12.5 * Theme.scale, weight: .semibold)).multilineTextAlignment(.center)
                        Text(stop.2).font(.system(size: 11.5 * Theme.scale)).foregroundStyle(Theme.faint).multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            HStack(spacing: 7) {
                Image(systemName: "arrow.uturn.backward").font(.system(size: 10 * Theme.scale, weight: .bold))
                Text("The result goes back to the model, and the loop repeats until the job is done.")
            }
            .font(.system(size: 12 * Theme.scale)).foregroundStyle(Theme.dim)
        }
        .padding(16).frame(maxWidth: .infinity).panel()
    }
}

private struct EngineSettings: View {
    @EnvironmentObject var app: AppState
    @EnvironmentObject var engine: Engine
    @EnvironmentObject var setup: Setup

    /// The makers behind the models on offer, read from each model's name, with how many of theirs there are.
    private var makers: [(maker: String, family: String, count: Int)] {
        let known: [(String, String, String)] = [("claude", "Anthropic", "Claude"), ("gpt", "OpenAI", "GPT"), ("gemini", "Google", "Gemini"),
                                                 ("grok", "xAI", "Grok"), ("kimi", "Moonshot", "Kimi"), ("glm", "Zhipu", "GLM"),
                                                 ("qwen", "Alibaba", "Qwen"), ("deepseek", "DeepSeek", "DeepSeek"), ("llama", "Meta", "Llama")]
        var counts: [String: Int] = [:]
        for m in engine.models {
            let text = (m.id + " " + m.name).lowercased()
            if let hit = known.first(where: { text.contains($0.0) }) { counts[hit.1, default: 0] += 1 } else { counts["Other", default: 0] += 1 }
        }
        return known.compactMap { k in counts[k.1].map { (k.1, k.2, $0) } }.sorted { $0.count > $1.count }
            + (counts["Other"].map { [("Other makers", "", $0)] } ?? [])
    }

    var body: some View {
        Text("Dighouse is made of three parts that work together. You can change the first one; the other two come with it.")
            .font(.system(size: 14 * Theme.scale)).foregroundStyle(Theme.dim).fixedSize(horizontal: false, vertical: true)
        LoopDiagram()
        VStack(spacing: 0) {
            PartRow(icon: "cpu", title: "1. The AI model: the thinker",
                    text: "The model reads your request, decides each step, and looks at the pictures of the ground. You choose it. It can be Claude, GPT, Gemini, Grok or any other model your setup offers; pick one that reads images.",
                    ok: engine.ready ? true : nil,
                    status: engine.ready ? "\(engine.models.count) to choose from" : app.starting ? "Starting" : "Waiting for the engine") {
                if engine.ready {
                    HStack(spacing: 8) {
                        ModelPicker(title: app.modelName, models: engine.models, current: app.model?.id) { app.modelID = $0.id }
                        Button("Test and settings") { app.settingsSection = .models }.buttonStyle(SecondaryButton())
                    }
                }
            }
            Hairline()
            PartRow(icon: "bolt", title: "2. The agent engine: the hands",
                    text: "The engine carries out what the model decides: it calls the tools, keeps the plan, starts helper agents and saves every chat. Dighouse uses Codex, a free, open-source engine from OpenAI. The engine is not the model: Codex runs Claude or any other model just as well.",
                    ok: setup.codex == nil ? false : engine.ready,
                    status: setup.codex == nil ? "Codex not found" : engine.ready ? setup.codexVersion : app.starting ? "Starting" : (engine.problem ?? "Not running")) {
                HStack(spacing: 8) {
                    if setup.codex == nil, let url = URL(string: "https://github.com/openai/codex") {
                        Link("Get Codex", destination: url).font(.system(size: 13 * Theme.scale)).foregroundStyle(Theme.accent)
                    }
                    Button { Task { await app.boot() } } label: { Label("Restart", systemImage: "arrow.clockwise") }
                        .buttonStyle(SecondaryButton()).disabled(app.starting)
                        .help("Use this after signing in to Codex or changing its settings. Running work stops.")
                    if app.starting { DigIndicator() }
                }
            }
            Hairline()
            PartRow(icon: "wrench.and.screwdriver", title: "3. The archaeology tools: what it can do",
                    text: "\(ToolGuide.toolCount) tools that come with Dighouse: they fetch open lidar, build the bare ground, cut slices, check maps and archives, read the literature and keep the records.",
                    ok: setup.toolsReady ? true : setup.toolsBusy ? nil : false,
                    status: setup.toolsReady ? "Ready" : setup.toolsBusy ? "Preparing"
                        : setup.uv == nil ? "Needs uv" : (setup.toolsProblem ?? "Not prepared")) {
                HStack(spacing: 8) {
                    Button("See the tools") { app.settingsSection = .tools }.buttonStyle(SecondaryButton())
                    if !setup.toolsReady, !setup.toolsBusy, setup.uv != nil {
                        Button("Prepare tools") { Task { await setup.prepareTools(); await app.boot() } }.buttonStyle(PrimaryButton())
                    }
                    if setup.uv == nil, let url = URL(string: "https://docs.astral.sh/uv/getting-started/installation/") {
                        Link("Get uv", destination: url).font(.system(size: 13 * Theme.scale)).foregroundStyle(Theme.accent)
                    }
                }
            }
        }
        .panel()

        VStack(alignment: .leading, spacing: 10) {
            Text("Which models you can use").font(.system(size: 15 * Theme.scale, weight: .semibold))
            Text(setup.ocxRunning
                 ? "Your Codex sign-in gives you OpenAI's models. The OpenCodex router is running on this Mac, so models from other makers, Claude among them, are listed too, each through its own account or key. The short code at the start of a model's name (Cl, AG, xAI…) is the account it runs through."
                 : "Your Codex sign-in gives you OpenAI's models. To use Claude, Gemini or others, run the free OpenCodex router: it adds them to Codex, and Dighouse lists them here.")
                .font(.system(size: 13 * Theme.scale)).foregroundStyle(Theme.dim).fixedSize(horizontal: false, vertical: true)
            if engine.ready {
                Flow(spacing: 8) {
                    ForEach(makers, id: \.maker) { m in
                        HStack(spacing: 6) {
                            Text(m.family.isEmpty ? m.maker : "\(m.family)").font(.system(size: 12.5 * Theme.scale, weight: .semibold))
                            Text(m.family.isEmpty ? "\(m.count)" : "\(m.maker) · \(m.count)").font(.system(size: 12 * Theme.scale)).foregroundStyle(Theme.faint)
                        }
                        .padding(.horizontal, 10).frame(height: 28)
                        .background(RoundedRectangle(cornerRadius: 7).fill(Theme.ink.opacity(0.06)))
                    }
                }
            }
            HStack(spacing: 10) {
                HStack(spacing: 6) {
                    Circle().fill(setup.ocxRunning ? Theme.green : Theme.faint).frame(width: 7, height: 7)
                    Text(setup.ocxRunning ? "OpenCodex router running" : "OpenCodex router not running").font(.system(size: 12.5 * Theme.scale)).foregroundStyle(Theme.dim)
                }
                if let url = URL(string: "https://github.com/lidge-jun/opencodex") {
                    Link(destination: url) { Label("About OpenCodex", systemImage: "arrow.up.right") }.font(.system(size: 12.5 * Theme.scale)).foregroundStyle(Theme.accent)
                }
            }
            Text("Claude Code, Anthropic's own engine, cannot stand in for Codex yet: Dighouse speaks to the engine through Codex's app-server. Claude the model works fully.")
                .font(.system(size: 12 * Theme.scale)).foregroundStyle(Theme.faint).fixedSize(horizontal: false, vertical: true)
        }
        .padding(16).frame(maxWidth: .infinity, alignment: .leading).panel()

        VStack(spacing: 0) {
            SettingRow(title: "Account",
                       note: engine.account.map { _ in "Codex on this Mac is signed in\(engine.plan.map { " on a \($0) plan" } ?? ""). OpenAI's models run on that account; models added by the router use their own keys. Dighouse never sees a password or a key." }
                        ?? "Codex is not signed in. Run codex login in Terminal, then press Restart above.") { EmptyView() }
            Hairline()
            SettingRow(title: "The web",
                       note: "The agent can search the web and open pages and PDFs. Pages that need a sign-in or block programs cannot be read; open those yourself in a project's Sources tab and hand them to the agent.") { EmptyView() }
        }
        .panel()
    }
}

/// The archaeology tools and any other tool servers, in Settings.
private struct ToolsSettings: View {
    @EnvironmentObject var app: AppState

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text("Every tool the agent has, by stage. The agent picks them itself; you never call them by hand.")
                .font(.system(size: 14 * Theme.scale)).foregroundStyle(Theme.dim).fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 12)
            Button { app.show(.toolbox) } label: { Label("Guided tour", systemImage: "map") }.buttonStyle(SecondaryButton())
                .help("The Toolbox walks through a real search, stage by stage.")
        }
        ForEach(ToolGuide.packs) { pack in
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 10) {
                    IconTile(name: pack.icon, size: 28)
                    Text(pack.title).font(.system(size: 14 * Theme.scale, weight: .semibold))
                    Spacer()
                    Text("\(pack.tools.count) tool\(pack.tools.count == 1 ? "" : "s")").font(.system(size: 12 * Theme.scale)).foregroundStyle(Theme.faint)
                }
                .padding(.horizontal, 14).padding(.vertical, 10)
                ForEach(pack.tools) { tool in
                    Hairline()
                    HStack(alignment: .firstTextBaseline, spacing: 12) {
                        Text(tool.title).font(.system(size: 13 * Theme.scale, weight: .medium)).frame(width: 190, alignment: .leading)
                        Text(tool.does).font(.system(size: 12.5 * Theme.scale)).foregroundStyle(Theme.dim).fixedSize(horizontal: false, vertical: true)
                        Spacer(minLength: 0)
                    }
                    .padding(.horizontal, 14).padding(.vertical, 8)
                    .help("The agent calls this tool \(tool.name)")
                }
            }
            .panel()
        }
        VStack(alignment: .leading, spacing: 8) {
            Text("More tools").font(.system(size: 15 * Theme.scale, weight: .semibold))
            Text("Tools from your Codex setup work here too, and you can add a tool server of your own (a small program that speaks MCP).")
                .font(.system(size: 13 * Theme.scale)).foregroundStyle(Theme.dim).fixedSize(horizontal: false, vertical: true)
            Button { UserDefaults.standard.set("More tools", forKey: "toolboxTab"); app.show(.toolbox) } label: { Label("Manage tool servers", systemImage: "puzzlepiece.extension") }
                .buttonStyle(SecondaryButton())
        }
    }
}


private struct PrivacySettings: View {
    private let rows: [(String, String)] = [
        ("Messages and images", "What you type, and the tiles the agent looks at, go to the provider of the model you chose, through the Codex engine. Dighouse adds no service in between."),
        ("Locations", "A project's search area and the position of each find are kept in its private folder on this Mac. Records, notes and reports carry no coordinates, so they can be shared. Each project keeps a history of its records and notes with git, which leaves out the private folder and the downloaded data."),
        ("Open data services", "The tools ask OpenTopography, USGS, the Environment Agency (England), PDOK (Netherlands), IGN (France), Wikidata, OpenStreetMap (and a copy of Wikidata for faster searches), the National Register, Pleiades, Open Context and OpenAlex for data. Each sees the area or the search words in the request, and nothing else."),
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
            SettingRow(title: "Projects", note: Paths.projectsHome.path.tildePath) {
                Button("Show") { NSWorkspace.shared.open(Paths.projectsHome) }.buttonStyle(SecondaryButton())
            }
            Hairline()
            SettingRow(title: "General chats, downloaded catalogs and the tools", note: Paths.support.path.tildePath) {
                Button("Show") { NSWorkspace.shared.open(Paths.support) }.buttonStyle(SecondaryButton())
            }
        }
        .panel()
    }
}

private struct AboutSettings: View {
    @EnvironmentObject var app: AppState
    @EnvironmentObject var setup: Setup

    var body: some View {
        HStack(spacing: 16) {
            Image(nsImage: NSApp.applicationIconImage).resizable().frame(width: 72, height: 72)
            VStack(alignment: .leading, spacing: 4) {
                Text("Dighouse").font(.system(size: 20 * Theme.scale, weight: .bold))
                Text("Version \(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "")")
                    .font(.system(size: 13 * Theme.scale)).foregroundStyle(Theme.dim)
            }
        }
        Text("A free, open tool for searching public lidar for places people built. An AI agent does the patient work: it fetches the ground, looks at every tile, checks each find and reads what has been published. You decide what each find is. It runs on the Codex engine with any model you have.")
            .font(.system(size: 13.5 * Theme.scale)).foregroundStyle(Theme.dim).lineSpacing(3).fixedSize(horizontal: false, vertical: true)
        VStack(spacing: 0) {
            SettingRow(title: "About the word lidar",
                       note: "Lidar maps the ground with laser pulses from an aircraft. The word began as a blend of light and radar, and Dighouse writes it in lowercase, as the US Geological Survey and NOAA do.") { EmptyView() }
            Hairline()
            SettingRow(title: "Source code", note: "Open source under the Apache 2.0 licence.") {
                if let url = URL(string: "https://github.com/chrissotraidis/dighouse") {
                    Button { NSWorkspace.shared.open(url) } label: { Label("GitHub", systemImage: "arrow.up.right") }.buttonStyle(SecondaryButton())
                }
            }
            Hairline()
            SettingRow(title: "Versions", note: "Dighouse \(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? ""), engine \(setup.codexVersion.isEmpty ? "not found" : setup.codexVersion). Include these when you report a problem.") { EmptyView() }
        }
        .panel()
    }
}


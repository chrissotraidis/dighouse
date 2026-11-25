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
                        Group {
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
                        .id(app.settingsSection).arrives()
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
            SettingRow(title: "Your name", note: "Signs your decisions.") {
                TextField("Name", text: $app.userName).field().font(.system(size: 13 * Theme.scale)).frame(width: 220)
            }
            Hairline()
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
            SettingRow(title: "A project opens as") {
                PillMenu(title: PaneLayout.names[app.layout] ?? "") {
                    PaneLayout.allCases.map { layout in
                        MenuEntry(title: PaneLayout.names[layout] ?? "", icon: layout.icon, checked: app.layout == layout) { app.layout = layout }
                    }
                }
            }
            Hairline()
            SettingRow(title: "Welcome guide") {
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
        }
        .panel()
        Text("Colours").font(.system(size: 15 * Theme.scale, weight: .semibold)).padding(.top, 4)
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

private struct ModelSettings: View {
    @EnvironmentObject var app: AppState
    @EnvironmentObject var engine: Engine
    @EnvironmentObject var setup: Setup

    /// The maker behind a model, from its id, so two choices from the same maker can be pointed out.
    private func maker(_ id: String?) -> String? {
        guard let id = id?.lowercased() else { return nil }
        for (key, name) in [("claude", "Anthropic"), ("anthropic", "Anthropic"), ("gpt", "OpenAI"),
                            ("grok", "xAI"), ("kimi", "Moonshot"), ("glm", "Zhipu"), ("qwen", "Alibaba"), ("deepseek", "DeepSeek")] where id.contains(key) {
            return name
        }
        return nil
    }

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
        else if let a = maker(app.model?.id), let b = maker(app.secondModelID), a == b {
            out.append("Both models come from \(a). A model from a different maker gives a more independent second opinion.")
        }
        return out
    }

    var body: some View {
        Text("One model runs the search. A second model gives each find its own opinion, without seeing the first one.")
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
                ModelPicker(title: app.modelName, models: engine.models, current: app.model?.id) { app.modelID = $0.id; app.modelNotice = nil }
            }
            Hairline()
            effortRow
            Hairline()
            SettingRow(title: "Second opinion model", note: "Gives the second opinion on each find. GPT-6 Luna, on your ChatGPT account, is the economical choice and waits when less than 20% of the account is left. Claude Sonnet 5.5 found more of the known features in a test (19 of 24, against 9) and uses your Claude account.") {
                ModelPicker(title: app.secondModelName, models: engine.models.filter { $0.readsImages },
                            current: app.secondModelID) { app.secondModelID = $0.id; app.modelNotice = nil }
            }
            Hairline()
            secondOrder
        }
        .panel()
        Text(setup.ocxRunning || engine.models.contains { $0.id.contains("/") }
             ? "\(engine.models.count) models, from the OpenCodex router on this Mac. The start of each name is the provider or account it runs through."
             : "\(engine.models.count) models, from the Codex sign-in on this Mac. The OpenCodex router adds models from other providers.")
            .font(.system(size: 12.5 * Theme.scale)).foregroundStyle(Theme.faint).lineSpacing(2).fixedSize(horizontal: false, vertical: true)
    }

    /// The second-opinion models in the order they are asked, each with a check that sends it one lidar picture.
    private var secondOrder: some View {
        // The chosen model, then the defaults this Mac offers (the same model is listed once whichever way it is reached).
        let ids = ([app.secondModelID].compactMap { $0 } + ModelInfo.secondOpinionOrder.filter { id in engine.models.contains { $0.id == id } })
            .reduce(into: [String]()) { list, id in
                if !list.contains(where: { $0 == id || $0.split(separator: "/").last == id.split(separator: "/").last }) { list.append(id) }
            }
        return VStack(alignment: .leading, spacing: 8) {
            Text("Asked in this order").font(.system(size: 13.5 * Theme.scale, weight: .medium))
            ForEach(Array(ids.enumerated()), id: \.element) { i, id in
                let model = engine.models.first { $0.id == id }
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

/// How Dighouse runs, as one picture: you, the model, the engine and the tools, each with its state now and the one thing to do about it.
private struct EngineSettings: View {
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
        VStack(spacing: 14) {
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .top, spacing: 0) { parts(arrow: "arrow.right") }
                VStack(spacing: 6) { parts(arrow: "arrow.down") }
            }
            HStack(spacing: 7) {
                Image(systemName: "arrow.uturn.backward").font(.system(size: 10 * Theme.scale, weight: .bold))
                Text("Each result goes back to the model, until the job is done.")
            }
            .font(.system(size: 12.5 * Theme.scale)).foregroundStyle(Theme.dim)
        }
        .padding(16).frame(maxWidth: .infinity).panel()

        VStack(spacing: 0) {
            SettingRow(title: "Models come from",
                       note: routed ? "Your Codex sign-in, and the OpenCodex router on this Mac." : "Your Codex sign-in. The OpenCodex router adds other makers' models.") {
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
            SettingRow(title: "Account",
                       note: engine.account != nil ? "Codex is signed in\(engine.plan.map { ", on a \($0) plan" } ?? ""). Dighouse never sees a password or a key."
                                                   : "Codex is not signed in. Run codex login in Terminal, then Restart.") { EmptyView() }
            Hairline()
            SettingRow(title: "The web", note: "The agent can search the web and read pages and PDFs that need no sign-in.") { EmptyView() }
        }
        .panel()
    }

    @ViewBuilder private func parts(arrow: String) -> some View {
        part(icon: "person", tint: Theme.accent, title: "You", role: "ask in plain words", ok: true, status: app.userName) { EmptyView() }
        link(arrow)
        part(icon: "cpu", tint: Theme.tan, title: "The model", role: "decides each step",
             ok: engine.ready && !app.starting ? true : nil, status: app.starting ? "Starting" : engine.ready ? app.modelName : "Waiting") {
            Button("Change") { app.settingsSection = .models }.buttonStyle(SecondaryButton()).disabled(!engine.ready)
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
        VStack(spacing: 7) {
            Glyph(name: icon, size: 17 * Theme.scale).foregroundStyle(tint)
                .frame(width: 44, height: 44).background(Circle().fill(Theme.ink.opacity(0.07)))
            VStack(spacing: 1) {
                Text(title).font(.system(size: 13.5 * Theme.scale, weight: .semibold))
                Text(role).font(.system(size: 12 * Theme.scale)).foregroundStyle(Theme.faint).multilineTextAlignment(.center)
            }
            HStack(spacing: 5) {
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

private struct PrivacySettings: View {
    private let rows: [(String, String)] = [
        ("Messages and images", "Go to the provider of the model you chose, through the engine."),
        ("Locations", "Stay in each project's private folder on this Mac. Records, notes and reports carry none."),
        ("Open data services", "Each sees the area or the search words in a request, and nothing else."),
        ("The map", "New project uses Apple Maps, which sees where you look."),
        ("Reports", "Nothing is sent. A report is a draft until you send it."),
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
            SettingRow(title: "Chats, catalogs and the tools", note: Paths.support.path.tildePath) {
                Button("Show") { NSWorkspace.shared.open(Paths.support) }.buttonStyle(SecondaryButton())
            }
        }
        .panel()
        CloudNotice()
        OpenDataKeys()
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

private struct AboutSettings: View {
    @EnvironmentObject var app: AppState
    @EnvironmentObject var setup: Setup

    var body: some View {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? ""
        HStack(spacing: 16) {
            Image(nsImage: NSApp.applicationIconImage).resizable().frame(width: 72, height: 72)
            VStack(alignment: .leading, spacing: 4) {
                Text("Dighouse").font(.system(size: 20 * Theme.scale, weight: .bold))
                Text("A free, open tool for searching public lidar for places people built.")
                    .font(.system(size: 13.5 * Theme.scale)).foregroundStyle(Theme.dim).fixedSize(horizontal: false, vertical: true)
            }
        }
        VStack(spacing: 0) {
            SettingRow(title: "Versions", note: "Dighouse \(version), engine \(setup.codexVersion.isEmpty ? "not found" : setup.codexVersion)") {
                Button("Copy") {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString("Dighouse \(version), engine \(setup.codexVersion)", forType: .string)
                }
                .buttonStyle(SecondaryButton()).help("Copy these to include when you report a problem.")
            }
            Hairline()
            SettingRow(title: "Source code", note: "Open source, Apache 2.0.") {
                if let url = URL(string: "https://github.com/chrissotraidis/dighouse") {
                    Button { NSWorkspace.shared.open(url) } label: { Label("GitHub", systemImage: "arrow.up.right") }.buttonStyle(SecondaryButton())
                }
            }
            Hairline()
            SettingRow(title: "The word lidar", note: "Written in lowercase here, as the US Geological Survey writes it.") { EmptyView() }
        }
        .panel()
    }
}

import SwiftUI

/// Settings, shown as a page in the main window, in six parts by what a person wants: the account and the models, where
/// the data goes, how the app looks, the tools, how the parts run, and the version.
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
                        HStack(alignment: .center, spacing: 14) {
                            IconTile(name: app.settingsSection.icon, size: 42)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(app.settingsSection.rawValue).font(.system(size: 22 * Theme.scale, weight: .bold))
                                Text(app.settingsSection.about).font(.system(size: 13.5 * Theme.scale)).foregroundStyle(Theme.dim)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                        .padding(.bottom, 4)
                        Group {
                            switch app.settingsSection {
                            case .account: AccountSettings()
                            case .data: DataSettings()
                            case .look: LookSettings()
                            case .tools: ToolsSettings()
                            case .runs: RunSettings()
                            case .about: AboutSettings()
                            }
                        }
                        .id(app.settingsSection).arrives()
                    }
                    .padding(.horizontal, 32).padding(.top, 24).padding(.bottom, 48)
                    // One column in the middle of the page, as on Home and in the Toolbox.
                    .frame(maxWidth: 760, alignment: .leading).frame(maxWidth: .infinity)
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
        case .runs: return "arrow.triangle.2.circlepath"
        case .about: return "info.circle"
        }
    }

    /// One sentence under the title, saying what the part is for.
    var about: String {
        switch self {
        case .account: return "Your ChatGPT and Claude accounts, and the models that search and check."
        case .data: return "Where your work is kept, the space it takes, what leaves this Mac, and free keys."
        case .look: return "Colours, text size, and how a project opens."
        case .tools: return "What the agent can do by itself, and the other apps it can reach."
        case .runs: return "What happens when you ask for something, and the models you can use."
        case .about: return "The version, new versions, and help."
        }
    }
}

/// A heading over a group of settings, with how the group stands at its right: the same size and gap on every page.
private struct GroupTitle<Trailing: View>: View {
    let text: String
    @ViewBuilder let trailing: () -> Trailing

    init(_ text: String, @ViewBuilder trailing: @escaping () -> Trailing) {
        self.text = text
        self.trailing = trailing
    }

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Text(text).font(.system(size: 15 * Theme.scale, weight: .semibold))
            Spacer(minLength: 8)
            trailing()
        }
        .padding(.top, 6)
    }
}

extension GroupTitle where Trailing == EmptyView {
    init(_ text: String) { self.init(text) { EmptyView() } }
}

/// How a part stands, as a dot and a few words: green for ready, amber for a problem, grey while waiting.
private struct StatusWord: View {
    let ok: Bool?
    let text: String

    var body: some View {
        HStack(spacing: 6) {
            Circle().fill(ok == true ? Theme.green : ok == false ? Theme.amber : Theme.faint).frame(width: 7, height: 7)
            Text(text).font(.system(size: 12.5 * Theme.scale)).foregroundStyle(ok == false ? Theme.amber : Theme.dim).lineLimit(1)
        }
        .accessibilityElement(children: .combine)
    }
}

struct SettingRow<Content: View>: View {
    let title: String
    var note = ""
    @ViewBuilder let content: () -> Content

    var body: some View {
        HStack(alignment: .center, spacing: 16) {
            label.frame(maxWidth: .infinity, alignment: .leading)
            content().fixedSize()
        }
        .padding(.horizontal, 14).padding(.vertical, 10).frame(maxWidth: .infinity, alignment: .leading)
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

// MARK: - Account and models

private struct AccountSettings: View {
    @EnvironmentObject var app: AppState
    @EnvironmentObject var engine: Engine
    @EnvironmentObject var setup: Setup
    @EnvironmentObject var chat: ChatModel
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

    private var withKey: Bool { engine.account == "an OpenAI API key" }

    /// Whose account a second opinion runs on, as one sentence.
    private var opinionCost: String {
        guard let id = app.secondModelID else { return "" }
        if ModelInfo.viaClaudeCode(id) { return "It runs on your Claude account, through Claude Code." }
        if app.onThisAccount(id) { return withKey ? "It is billed to your API key." : "It runs on your ChatGPT plan, and waits while under \(AppState.opinionFloor)% is left." }
        return "It runs on the \(id.split(separator: "/").first.map(String.init) ?? "router's") account, through OpenCodex."
    }

    var body: some View {
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

        GroupTitle("Your accounts") {
            Text("Use either, or both").font(.system(size: 12.5 * Theme.scale)).foregroundStyle(Theme.faint)
        }
        account
        ClaudeAccount()
        Text("The search inside Dighouse runs through Codex, so it needs ChatGPT, an OpenAI key, or a router such as OpenCodex. With Claude alone, search from Claude Code and decide the finds here.")
            .font(.system(size: 12.5 * Theme.scale)).foregroundStyle(Theme.faint).lineSpacing(2).fixedSize(horizontal: false, vertical: true)

        VStack(spacing: 0) {
            SettingRow(title: "Your name", note: "Signs your decisions.") {
                TextField("Name", text: $app.userName).field().font(.system(size: 13 * Theme.scale)).frame(width: 220)
            }
        }
        .panel()

        GroupTitle("The search") {
            HStack(spacing: 10) {
                StatusWord(ok: engine.ready ? true : app.starting ? nil : false,
                           text: engine.ready ? "Codex \(Self.version(setup.codexVersion)) is running" : app.starting ? "Starting"
                            : (engine.problem ?? (setup.codex == nil ? "Codex is not on this Mac" : "The engine is not running")))
                if !engine.ready, !app.starting, setup.codex != nil {
                    Button("Restart") { Task { await app.boot() } }.buttonStyle(SecondaryButton())
                }
            }
        }
        VStack(spacing: 0) {
            SettingRow(title: "Model", note: "Runs the search and looks at every tile, so it must read images.") {
                ModelPicker(title: app.modelName, models: engine.models, current: app.model?.id) { app.modelID = $0.id; app.modelNotice = nil }
            }
            Hairline()
            effortRow
        }
        .panel()

        GroupTitle("Second opinions") {
            StatusWord(ok: app.secondModelID == nil ? false : app.opinionsWaiting == nil ? true : nil,
                       text: app.secondModelID == nil ? "No model chosen" : app.opinionsWaiting == nil ? "Asked about finds a person will see" : "Waiting until usage resets")
        }
        VStack(spacing: 0) {
            SettingRow(title: "Model", note: ["Sees each find on its own, without the agent's verdict.", opinionCost].filter { !$0.isEmpty }.joined(separator: " ")) {
                ModelPicker(title: app.secondModelName, models: app.opinionChoices,
                            current: app.secondModelID) { app.secondModelID = $0.id; app.modelNotice = nil }
            }
            Hairline()
            secondOrder
        }
        .panel()

        Text(setup.ocxRunning || engine.models.contains { $0.id.contains("/") }
             ? "\(engine.models.count) models, from your Codex sign-in and the OpenCodex router on this Mac. The start of each name is the account it runs through."
             : "\(engine.models.count) models, from your Codex sign-in. The OpenCodex router, if you want it, adds models from other makers. Dighouse does not need it.")
            .font(.system(size: 12.5 * Theme.scale)).foregroundStyle(Theme.faint).lineSpacing(2).fixedSize(horizontal: false, vertical: true)
    }

    /// "codex-cli 0.171.0-alpha.2" as "0.171.0".
    static func version(_ text: String) -> String {
        text.split(separator: " ").last?.split(separator: "-").first.map(String.init) ?? text
    }

    /// Who is signed in, said plainly, with the plan and how much of it is left as a dial; then the name that signs decisions.
    private var account: some View {
        VStack(spacing: 0) {
            HStack(alignment: .center, spacing: 14) {
                // The first letter of the name on a round tile, or a key, or a question mark while nobody is signed in.
                Group {
                    Glyph(name: withKey ? "key" : "bubble.left.and.text.bubble.right", size: 16 * Theme.scale, weight: .medium)
                }
                .foregroundStyle(Theme.tan).frame(width: 42, height: 42).background(Circle().fill(Theme.tan.opacity(0.13)))
                .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 2) {
                    Text(withKey ? "OpenAI API key" : "ChatGPT").font(.system(size: 15 * Theme.scale, weight: .semibold))
                    if let who = engine.account {
                        Label(withKey ? "Signed in with a key" : "Signed in as \(who)", systemImage: "checkmark.seal.fill")
                            .font(.system(size: 12.5 * Theme.scale, weight: .medium)).foregroundStyle(Theme.green)
                    } else {
                        Text("Not signed in").font(.system(size: 12.5 * Theme.scale, weight: .medium)).foregroundStyle(Theme.faint)
                    }
                    Text(signInProblem ?? (engine.account != nil
                        ? (withKey ? "Runs the search and second opinions. Each request is billed to the key, and Dighouse keeps no copy of it."
                           : "Runs the search and second opinions. You signed in to Codex in your browser, and Dighouse never sees your password.")
                        : setup.codex == nil ? "The search runs on Codex, OpenAI's free engine. The welcome guide installs it."
                        : "Sign in with a ChatGPT account, in your browser, or use an OpenAI API key."))
                        .font(.system(size: 12.5 * Theme.scale)).foregroundStyle(signInProblem == nil ? Theme.dim : Theme.amber)
                        .lineSpacing(2).fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 8)
                if engine.account != nil {
                    Badge(text: withKey ? "Pay as you go" : engine.plan.map { "ChatGPT \($0.capitalized)" } ?? "ChatGPT", color: Theme.tan)
                    if !withKey, let left = chat.usageLeft {
                        VStack(spacing: 2) {
                            UsageDial(left: left, size: 46, number: true)
                            Text("left").font(.system(size: 11 * Theme.scale)).foregroundStyle(Theme.faint)
                        }
                        .help("\(left)% of your plan's usage is left. Searches and second opinions on this account draw on it, and second opinions wait while under \(AppState.opinionFloor)% is left.")
                    }
                } else if setup.codex == nil {
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
            .padding(14)
            if engine.account == nil, setup.codex != nil, engine.running, !signingIn {
                APIKeySignIn().padding(.leading, 70).padding(.trailing, 14).padding(.bottom, 12)   // aligns under the name
            }
        }
        .panel()
    }

    /// The second-opinion models in the order they are asked, each with a check that sends it one lidar picture.
    private var secondOrder: some View {
        // The chosen model, then the defaults this Mac offers (the same model is listed once whichever way it is reached).
        let ids = ([app.secondModelID].compactMap { $0 } + ModelInfo.secondOpinionOrder.filter { id in app.opinionChoices.contains { $0.id == id } })
            .reduce(into: [String]()) { list, id in
                if !list.contains(where: { $0 == id || $0.split(separator: "/").last == id.split(separator: "/").last }) { list.append(id) }
            }
        return VStack(alignment: .leading, spacing: 10) {
            VStack(alignment: .leading, spacing: 4) {
                Text(ids.count > 1 ? "Asked in this order" : "Check that it answers").font(.system(size: 13.5 * Theme.scale, weight: .medium))
                Text("Check sends one lidar picture and shows the reply. GPT-6 Luna costs least; Claude Sonnet found more known features in a test (19 of 24, against 9).")
                    .font(.system(size: 12.5 * Theme.scale)).foregroundStyle(Theme.dim).lineSpacing(2).fixedSize(horizontal: false, vertical: true)
            }
            ForEach(Array(ids.enumerated()), id: \.element) { i, id in
                let model = app.opinionChoices.first { $0.id == id }
                HStack(alignment: .center, spacing: 10) {
                    Text("\(i + 1)").font(.system(size: 11.5 * Theme.scale, weight: .bold)).foregroundStyle(Theme.dim)
                        .frame(width: 20, height: 20).background(Circle().fill(Theme.ink.opacity(0.08)))
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
        if let model = app.model, let effort = app.activeEffort {
            let steps = Segmented(choices: model.efforts.map { .init(value: $0, title: Effort.label($0)) },
                                  pick: Binding(get: { effort }, set: { app.effort = $0 }), compact: true)
                .accessibilityElement(children: .contain).accessibilityLabel("Thinking effort")
            let title = Text("Thinking effort").font(.system(size: 13.5 * Theme.scale, weight: .medium))
            VStack(alignment: .leading, spacing: 6) {
                // The steps sit beside the title when there is room, and under it when the window is narrow or the text large.
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 16) { title; Spacer(minLength: 8); steps }
                    VStack(alignment: .leading, spacing: 8) { title; steps }
                }
                Text(Effort.note(effort, for: model))
                    .font(.system(size: 12.5 * Theme.scale)).foregroundStyle(Theme.dim).fixedSize(horizontal: false, vertical: true)
            }
            .padding(14).frame(maxWidth: .infinity, alignment: .leading)
        } else {
            SettingRow(title: "Thinking effort", note: "\(app.modelName) has no effort steps in the model list.") { EmptyView() }
        }
    }
}

/// Claude, beside ChatGPT: what a Claude plan does here, and one press for each. Second opinions run on the Claude plan
/// through Claude Code, and Claude Code can run a whole search itself with Dighouse's tools.
private struct ClaudeAccount: View {
    @EnvironmentObject var app: AppState
    @EnvironmentObject var engine: Engine
    @EnvironmentObject var setup: Setup
    @State private var connected: Bool?
    @State private var busy = false
    @State private var problem: String?

    private var givesOpinions: Bool { app.secondModelID.map(ModelInfo.viaClaudeCode) ?? false }
    /// Claude models a router on this Mac lists, which can run the search here.
    private var routed: [ModelInfo] { engine.models.filter { $0.readsImages && ($0.id + " " + $0.name).lowercased().contains("claude") } }

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .center, spacing: 14) {
                Glyph(name: "asterisk", size: 17 * Theme.scale, weight: .semibold).foregroundStyle(Theme.tan)
                    .frame(width: 42, height: 42).background(Circle().fill(Theme.tan.opacity(0.13))).accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Claude").font(.system(size: 15 * Theme.scale, weight: .semibold))
                    if setup.claude != nil {
                        Label("Claude Code is on this Mac", systemImage: "checkmark.seal.fill")
                            .font(.system(size: 12.5 * Theme.scale, weight: .medium)).foregroundStyle(Theme.green)
                    } else {
                        Text("Claude Code is not on this Mac").font(.system(size: 12.5 * Theme.scale, weight: .medium)).foregroundStyle(Theme.faint)
                    }
                    Text(setup.claude != nil ? "Runs second opinions, and whole searches from Claude Code, on your Claude plan."
                         : "With Claude Code on this Mac, a Claude plan runs second opinions, and whole searches from Claude Code.")
                        .font(.system(size: 12.5 * Theme.scale)).foregroundStyle(Theme.dim).lineSpacing(2).fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 8)
                if setup.claude == nil, let url = URL(string: "https://docs.claude.com/en/docs/claude-code/setup") {
                    Button { NSWorkspace.shared.open(url) } label: { Label("Get Claude Code", systemImage: "arrow.up.right") }.buttonStyle(SecondaryButton())
                } else if let version = setup.claudeVersion.split(separator: " ").first {
                    Badge(text: "Claude Code \(version)", color: Theme.tan)
                }
            }
            .padding(14)
            if let claude = setup.claude {
                Hairline()
                SettingRow(title: "Second opinions",
                           note: givesOpinions ? "\(app.secondModelName) gives an opinion on each find a person will see."
                           : "Claude Sonnet gives an opinion on each find a person will see, in place of \(app.secondModelName).") {
                    if givesOpinions { StatusWord(ok: true, text: "In use") } else {
                        Button("Use Claude") { app.secondModelID = ModelInfo.claudeCode[0].id; app.modelNotice = nil }.buttonStyle(SecondaryButton())
                    }
                }
                if setup.toolsReady {
                    Hairline()
                    SettingRow(title: "Search from Claude Code",
                               note: problem ?? (connected == true
                               ? "Claude Code has Dighouse's tools and search guide. Ask it to search a place, and the project appears here."
                               : "Gives Claude Code Dighouse's tools and search guide. The projects it makes appear here.")) {
                        if busy || connected == nil { DigIndicator() } else if connected == true {
                            Button("Remove") { Task { await change(claude, add: false) } }.buttonStyle(SecondaryButton())
                        } else {
                            Button("Add to Claude Code") { Task { await change(claude, add: true) } }.buttonStyle(SecondaryButton())
                        }
                    }
                }
                if !routed.isEmpty {
                    let inUse = routed.contains { $0.id == app.model?.id }
                    Hairline()
                    SettingRow(title: "The search in Dighouse",
                               note: "OpenCodex on this Mac lists \(routed.count) Claude model\(routed.count == 1 ? "" : "s"). Choose one under The search, below.") {
                        if inUse { StatusWord(ok: true, text: "In use") }
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
        app.searchesFromClaude = connected == true
        busy = false
    }
}

// MARK: - How it looks

/// The colours, the text size, and how a project opens.
private struct LookSettings: View {
    @EnvironmentObject var app: AppState

    var body: some View {
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
                            .multilineTextAlignment(.leading).fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(12).frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    .surface()
                    .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(app.look == look ? Theme.accent : .clear, lineWidth: 1.5))
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(app.look == look ? .isSelected : [])
            }
        }

        GroupTitle("Text and layout")
        VStack(spacing: 0) {
            SettingRow(title: "Text size", note: "⌘+ and ⌘− change it too.") {
                Segmented(choices: TextSize.all.map { .init(value: $0.id, title: $0.name) }, pick: $app.textSize, compact: true)
            }
            Hairline()
            SettingRow(title: "A project opens as", note: "The chat, the map and work, or both side by side.") {
                Segmented(choices: PaneLayout.allCases.map { .init(value: $0, title: PaneLayout.names[$0] ?? "", icon: $0.icon) },
                          pick: $app.layout, compact: true)
            }
        }
        .panel()
    }
}

// MARK: - Data and keys

/// Where projects are kept, what leaves this Mac, and the free keys.
private struct DataSettings: View {
    @AppStorage("projectsHome") private var projectsHome = ""

    var body: some View {
        GroupTitle("On this Mac")
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
            Hairline()
            SettingRow(title: "Downloads kept for later", note: DiskUse.cacheFolder.tildePath) {
                Button("Show") { NSWorkspace.shared.open(URL(fileURLWithPath: DiskUse.cacheFolder)) }.buttonStyle(SecondaryButton())
            }
        }
        .panel()
        CloudNotice()

        StorageSettings()

        GroupTitle("Privacy") { StatusWord(ok: true, text: "Locations never leave this Mac") }
        PrivacyTable()

        GroupTitle("Free keys") {
            Text("Two open data services ask for one").font(.system(size: 12.5 * Theme.scale)).foregroundStyle(Theme.faint)
        }
        OpenDataKeys()
        Text("Each key is checked with its own service when you save it, and sent nowhere else. Finland and Sweden also give their lidar to a free account. Dighouse does not read those two yet.")
            .font(.system(size: 12.5 * Theme.scale)).foregroundStyle(Theme.faint).lineSpacing(2).fixedSize(horizontal: false, vertical: true)
    }
}

/// What Dighouse keeps on disk, part by part: what each part is, how much it takes, and a way to clear what can be
/// fetched again. The projects unfold into a list, largest first.
private struct StorageSettings: View {
    @EnvironmentObject var app: AppState
    @EnvironmentObject var store: ProjectStore
    @State private var use: DiskUse?
    /// The part, or the project's folder, a person is about to clear.
    @State private var asking: String?
    @State private var note = ""
    @State private var listing = false
    @State private var all = false

    /// The downloads kept outside the projects: what a person would call each, what it is, and whether it can be cleared.
    private static var kept: [(id: String, title: String, about: String, color: Color)] {
        [("loose", "Raw points no project holds", "Kept in case a search returns to the same ground.", Theme.amber),
         ("files", "Lidar files as downloaded", "Kept so the same file is not downloaded twice.", Theme.water),
         ("national", "National ground models", "Map sheets from national services, kept for the next search nearby.", Theme.violet),
         ("quicklook", "Quick looks", "The pictures behind What is this?", Theme.rose)]
    }

    private func bytes(_ id: String, in use: DiskUse) -> Int64 { id == "loose" ? use.loose : use.kept[id] ?? 0 }

    var body: some View {
        GroupTitle("Space used") {
            if let use {
                Text(DiskUse.words(use.projects + use.cache) + " in all").font(.system(size: 12.5 * Theme.scale)).foregroundStyle(Theme.faint)
            } else {
                HStack(spacing: 6) { DigIndicator(size: 12); Text("Measuring").font(.system(size: 12.5 * Theme.scale)).foregroundStyle(Theme.faint) }
            }
        }
        .task { await measure() }
        if let use {
            VStack(spacing: 0) {
                bar(use).padding(.horizontal, 14).padding(.top, 14).padding(.bottom, 6)
                part(Theme.tan, "Projects", "\(use.byProject.count) folders: the ground, the pictures, the finds and your decisions.", use.projects) {
                    Button(listing ? "Hide the list" : "List them") { withAnimation(Motion.ease(0.15)) { listing.toggle() } }.buttonStyle(SecondaryButton())
                }
                if listing { projects(use) }
                ForEach(Self.kept, id: \.id) { kind in
                    let size = bytes(kind.id, in: use)
                    Hairline()
                    part(kind.color, kind.title, kind.about, size) {
                        if size > 0 { Button("Clear") { asking = kind.id }.buttonStyle(SecondaryButton()).disabled(app.working || asking == kind.id) }
                    }
                    if asking == kind.id {
                        confirm("Remove \(DiskUse.words(size))? A search that needs any of it downloads it again.", action: "Remove") { clear(kind.id, use) }
                    }
                }
                Hairline()
                part(Theme.faint, "Catalogs and scores", "Lists of surveys and known sites, and the blind tests' scores. Small, and kept.", use.kept["other"] ?? 0) { EmptyView() }
            }
            .panel()
            if app.working {
                Text("A search is running, so downloads cannot be cleared until it ends.")
                    .font(.system(size: 12.5 * Theme.scale)).foregroundStyle(Theme.faint)
            } else if !note.isEmpty {
                Label(note, systemImage: "checkmark.circle.fill").font(.system(size: 12.5 * Theme.scale)).foregroundStyle(Theme.green)
            }
        }
    }

    /// The whole of it as one bar, a colour for each part.
    private func bar(_ use: DiskUse) -> some View {
        let total = max(use.projects + use.cache, 1)
        let parts: [(Color, Int64)] = [(Theme.tan, use.projects)] + Self.kept.map { ($0.color, bytes($0.id, in: use)) }
        return GeometryReader { geo in
            HStack(spacing: 2) {
                ForEach(Array(parts.enumerated()), id: \.offset) { _, p in
                    if p.1 > 0 {
                        RoundedRectangle(cornerRadius: 3).fill(p.0.opacity(0.85))
                            .frame(width: max(3, (geo.size.width - 8) * CGFloat(p.1) / CGFloat(total)))
                    }
                }
                Spacer(minLength: 0)
            }
        }
        .frame(height: 8).accessibilityHidden(true)
    }

    private func part<Action: View>(_ color: Color, _ title: String, _ about: String, _ size: Int64, @ViewBuilder action: () -> Action) -> some View {
        HStack(alignment: .center, spacing: 12) {
            RoundedRectangle(cornerRadius: 3).fill(color.opacity(0.85)).frame(width: 10, height: 10).accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.system(size: 13.5 * Theme.scale, weight: .medium))
                Text(about).font(.system(size: 12.5 * Theme.scale)).foregroundStyle(Theme.dim).fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 8)
            Text(size > 0 ? DiskUse.words(size) : "Nothing").font(.system(size: 13 * Theme.scale, weight: .medium)).monospacedDigit()
                .foregroundStyle(size > 0 ? Theme.text : Theme.faint)
            action()
        }
        .padding(.horizontal, 14).padding(.vertical, 8)
        .accessibilityElement(children: .contain)
    }

    /// Each project with what it takes, largest first: eight, then all of them.
    private func projects(_ use: DiskUse) -> some View {
        let shown = all ? use.byProject : Array(use.byProject.prefix(8))
        let largest = max(use.byProject.first?.bytes ?? 1, 1)
        return VStack(alignment: .leading, spacing: 0) {
            ForEach(shown, id: \.path) { item in
                let ref = store.projects.first { $0.path == item.path }
                HStack(spacing: 10) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(ref?.name ?? URL(fileURLWithPath: item.path).lastPathComponent).font(.system(size: 13 * Theme.scale))
                            .fixedSize(horizontal: false, vertical: true)
                        Capsule().fill(Theme.tan.opacity(0.6)).frame(width: max(3, 180 * CGFloat(item.bytes) / CGFloat(largest)), height: 3)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    Text(DiskUse.words(item.bytes)).font(.system(size: 12.5 * Theme.scale)).monospacedDigit().foregroundStyle(Theme.dim)
                    Button("Show") { NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: item.path) }.buttonStyle(SecondaryButton())
                        .help("Show the project's folder in the Finder")
                    Button("Trash…") { asking = item.path }.buttonStyle(SecondaryButton()).disabled(asking == item.path)
                }
                .padding(.vertical, 6)
                if asking == item.path, let ref {
                    confirm("Move \(ref.name) to the Trash? Its finds and your decisions go with it. Emptying the Trash frees the space.", action: "Move to Trash") { trash(ref) }
                        .padding(.horizontal, -14)   // aligns with the list
                }
            }
            if !all, use.byProject.count > shown.count {
                Button("Show all \(use.byProject.count)") { all = true }.buttonStyle(.plain)
                    .font(.system(size: 12.5 * Theme.scale, weight: .medium)).foregroundStyle(Theme.tan).padding(.vertical, 6)
            }
        }
        .padding(.leading, 36).padding(.trailing, 14).padding(.bottom, 8)   // aligns under the part's name
    }

    private func confirm(_ question: String, action: String, run: @escaping () -> Void) -> some View {
        HStack(spacing: 8) {
            Text(question).font(.system(size: 12.5 * Theme.scale)).foregroundStyle(Theme.text).fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 8)
            Button("Cancel") { asking = nil }.buttonStyle(SecondaryButton())
            Button(action, action: run).buttonStyle(SecondaryButton())
        }
        .padding(.horizontal, 14).padding(.vertical, 8)
        .background(Theme.amber.opacity(0.08))
    }

    private func measure() async {
        let roots = store.projects.map(\.path)
        use = await Task.detached { DiskUse.measure(roots) }.value
    }

    private func clear(_ id: String, _ use: DiskUse) {
        asking = nil
        let files = use.looseFiles
        Task {
            let freed = await Task.detached { id == "loose" ? DiskUse.free(files) : DiskUse.clear(id) }.value
            note = "Freed \(DiskUse.words(freed))."
            await measure()
        }
    }

    /// Move a project's folder to the Trash and take it off the list. Raw points it shared with the downloads are then
    /// held by no project, and show under that part.
    private func trash(_ ref: ProjectRef) {
        asking = nil
        if store.current == ref { app.goHome() }
        do {
            try FileManager.default.trashItem(at: URL(fileURLWithPath: ref.path), resultingItemURL: nil)
            store.remove(ref)
            note = "\(ref.name) is in the Trash."
        } catch {
            note = "\(ref.name) could not be moved: \(error.localizedDescription)"
        }
        Task { await measure() }
    }
}

/// What stays on this Mac and what leaves it, one line each: the thing, and where it goes.
private struct PrivacyTable: View {
    @AppStorage("checkUpdates") private var checkUpdates = true

    var body: some View {
        VStack(spacing: 0) {
            row("mappin.and.ellipse", "Locations", "in each project's private folder")
            Hairline()
            row("doc.text", "Records, notes and reports", "carry no location; a report is a draft only you send")
            Hairline()
            row("key", "Keys", "in a file only you can read")
            Hairline()
            row("bubble.left", "Messages and pictures", "to the model you chose, through the engine", to: "Model provider")
            Hairline()
            row("magnifyingglass", "An area or search words", "to the open data service asked, and nothing else", to: "Open data")
            Hairline()
            row("map", "Where you look in New project", "its map is Apple's, as are Open in Maps and Name the nearest town", to: "Apple Maps")
            Hairline()
            row("arrow.down.circle", "A version check, once a day", "asks for the latest version number", to: "GitHub",
                trailing: AnyView(Toggle("", isOn: $checkUpdates).labelsHidden().toggleStyle(.switch).controlSize(.small)
                    .onChange(of: checkUpdates) { Task { await Updates.shared.check() } }
                    .accessibilityLabel("Check for a new version once a day")))
        }
        .panel()
    }

    /// One line: what it is and what happens to it, then where it goes. Nothing after the words means it stays here.
    private func row(_ icon: String, _ what: String, _ detail: String, to: String? = nil, trailing: AnyView? = nil) -> some View {
        HStack(alignment: .center, spacing: 12) {
            Glyph(name: icon, size: 12.5 * Theme.scale, weight: .medium).foregroundStyle(to == nil ? Theme.green : Theme.tan).frame(width: 18)
            (Text(what).font(.system(size: 13 * Theme.scale, weight: .medium))
                + Text("  " + detail).font(.system(size: 12.5 * Theme.scale)).foregroundColor(Theme.dim))
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 8)
            if let trailing { trailing }
            Label(to ?? "Stays here", systemImage: to == nil ? "lock.fill" : "arrow.up.right")
                .font(.system(size: 11.5 * Theme.scale, weight: .medium)).foregroundStyle(to == nil ? Theme.green : Theme.tan)
                .lineLimit(1).fixedSize()
                .padding(.horizontal, 8).frame(height: 22).background(Capsule().fill((to == nil ? Theme.green : Theme.tan).opacity(0.13)))
        }
        .padding(.horizontal, 14).padding(.vertical, 8)
        .accessibilityElement(children: .combine)
    }
}

/// Accounts some open data services ask for. Denmark's ground model needs a free token from Dataforsyningen; OpenAlex,
/// where the literature is searched, shares a small daily budget among everyone without a key.
private struct OpenDataKeys: View {
    var body: some View {
        VStack(spacing: 0) {
            KeyRow(name: "dataforsyningen", service: "Dataforsyningen", title: "Denmark's ground model", field: "token", get: "Get a token",
                   note: "Dataforsyningen gives a token with a free account. Without it, Denmark cannot be searched.",
                   link: "https://confluence.kds.dk/display/MYD/Log%2Bind%2Bog%2BToken")
            Hairline()
            KeyRow(name: "openalex", service: "OpenAlex", title: "Books and papers (OpenAlex)", field: "key", get: "Get a key",
                   note: "Without a key, your network shares about 100 literature searches a day, then Crossref is used. Asking for a key sends OpenAlex your email address.",
                   link: "https://help.openalex.org/api/authentication/")
        }
        .panel()
    }
}

/// One key on one line: whether it is added, where to get one, and Add. The box to paste into shows only while adding,
/// and Save asks the key's own service whether it takes it before keeping it.
private struct KeyRow: View {
    let name: String, service: String, title: String, field: String, get: String, note: String, link: String
    @State private var value = ""
    @State private var saved = false
    @State private var adding = false
    @State private var checking = false
    /// What the service said about the last key pasted, and whether that was a refusal.
    @State private var said: (text: String, bad: Bool)?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 8) {
                        Text(title).font(.system(size: 13.5 * Theme.scale, weight: .medium))
                        if saved {
                            Label("Added", systemImage: "checkmark.circle.fill").font(.system(size: 12 * Theme.scale, weight: .medium)).foregroundStyle(Theme.green)
                        } else {
                            Text("Not added").font(.system(size: 12 * Theme.scale)).foregroundStyle(Theme.faint)
                        }
                    }
                    Text(note).font(.system(size: 12.5 * Theme.scale)).foregroundStyle(Theme.dim).lineSpacing(2).fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                if saved, !adding {
                    Button("Replace") { value = ""; said = nil; adding = true }.buttonStyle(SecondaryButton())
                    Button("Remove") { Keys.write(name, ""); saved = !Keys.read(name).isEmpty; said = nil }.buttonStyle(SecondaryButton())
                        .help("Takes the \(field) off this Mac.")
                } else if !adding {
                    Button("Add") { said = nil; adding = true }.buttonStyle(SecondaryButton())
                }
            }
            if adding {
                // The two steps side by side: get it from the service, then paste it.
                HStack(spacing: 8) {
                    if let url = URL(string: link) {
                        Button { NSWorkspace.shared.open(url) } label: { Label("1. " + get, systemImage: "arrow.up.right") }.buttonStyle(SecondaryButton())
                            .help("Opens \(service)'s page in your browser.")
                    }
                    SecureField("2. Paste the \(field) here", text: $value).textFieldStyle(.plain).font(.system(size: 13 * Theme.scale))
                        .padding(.horizontal, 10).frame(height: 30).frame(maxWidth: 300)
                        .background(RoundedRectangle(cornerRadius: 8).fill(Theme.ink.opacity(0.06)))
                        .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(Theme.line))
                        .onSubmit(save)
                    if checking { DigIndicator() } else {
                        Button("Save", action: save).buttonStyle(PrimaryButton())
                            .disabled(value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                    Button("Cancel") { adding = false; value = ""; said = nil }.buttonStyle(SecondaryButton()).disabled(checking)
                    Spacer(minLength: 0)
                }
            }
            if let said {
                Label(said.text, systemImage: said.bad ? "exclamationmark.triangle" : "checkmark.circle.fill")
                    .font(.system(size: 12.5 * Theme.scale)).foregroundStyle(said.bad ? Theme.amber : Theme.green)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.horizontal, 14).padding(.vertical, 10).frame(maxWidth: .infinity, alignment: .leading)
        .onAppear { saved = !Keys.read(name).isEmpty }
    }

    /// Ask the service whether it takes the key. A refusal keeps the box open; no answer saves it and says so.
    private func save() {
        let key = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !key.isEmpty, !checking else { return }
        checking = true
        Task {
            let taken = await Keys.accepted(name, key)
            checking = false
            if taken == false {
                said = ("\(service) did not accept this \(field). Copy it again and paste it whole.", true)
                return
            }
            Keys.write(name, key)
            saved = !Keys.read(name).isEmpty
            value = ""
            adding = false
            said = taken == true ? ("\(service) accepted the \(field).", false)
                : ("Saved. \(service) could not be reached to check it, so the next search will show whether it works.", false)
        }
    }
}

// MARK: - Tools

/// Every tool the agent has, folded into the six stages of a search. A stage unfolds to its tools, each with one line.
private struct ToolsSettings: View {
    @EnvironmentObject var app: AppState
    @EnvironmentObject var setup: Setup
    @EnvironmentObject var engine: Engine
    @State private var query = ""
    @State private var open: Set<String> = []

    private func matches(_ tool: ToolGuide.Tool) -> Bool {
        query.isEmpty || [tool.title, tool.does, tool.name].contains { $0.localizedCaseInsensitiveContains(query) }
    }

    var body: some View {
        GroupTitle("What the agent can do") {
            StatusWord(ok: setup.toolsReady ? true : setup.toolsBusy ? nil : false,
                       text: setup.toolsReady ? "\(ToolGuide.toolCount) tools ready" : setup.toolsBusy ? "Preparing" : (setup.toolsProblem ?? "Not prepared"))
        }
        example
        Text("Each line below is a tool: one job the agent does by itself when your request needs it. You never run one. They are grouped by the six stages of a search.")
            .font(.system(size: 13 * Theme.scale)).foregroundStyle(Theme.dim).lineSpacing(2).fixedSize(horizontal: false, vertical: true)
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass").font(.system(size: 12 * Theme.scale)).foregroundStyle(Theme.faint)
            TextField("Search \(ToolGuide.toolCount) tools", text: $query).textFieldStyle(.plain).font(.system(size: 13 * Theme.scale))
            if !query.isEmpty {
                Button { query = "" } label: { Image(systemName: "xmark.circle.fill").foregroundStyle(Theme.faint) }
                    .buttonStyle(.plain).help("Clear the search")
            }
        }
        .padding(.horizontal, 10).frame(height: 32)
        .background(RoundedRectangle(cornerRadius: 9).fill(Theme.ink.opacity(0.06)))
        let shown = ToolGuide.packs.enumerated().map { ($0.offset, $0.element, $0.element.tools.filter(matches)) }.filter { !$0.2.isEmpty }
        if shown.isEmpty {
            Text("No tool matches.").font(.system(size: 13 * Theme.scale)).foregroundStyle(Theme.faint)
        } else {
            VStack(spacing: 0) {
                ForEach(Array(shown.enumerated()), id: \.element.1.id) { index, group in
                    if index > 0 { Hairline() }
                    stage(number: group.0 + 1, pack: group.1, tools: group.2)
                }
            }
            .panel()
        }

        GroupTitle("Other apps the agent can use") {
            Text("Connected in Codex on this Mac").font(.system(size: 12.5 * Theme.scale)).foregroundStyle(Theme.faint)
        }
        MoreTools().task(id: engine.ready) { await engine.loadConnections() }
    }

    /// One request, followed through: what was asked, the tools the agent used for it, and what came back.
    private var example: some View {
        HStack(alignment: .top, spacing: 0) {
            step("You ask", "person") {
                Text("“Is there open lidar over the Newark Earthworks?”")
            }
            arrow
            step("The agent uses two tools", "wrench.and.screwdriver") {
                VStack(alignment: .leading, spacing: 4) {
                    Label("Find a place", glyph: "mappin.and.ellipse")
                    Label("Find lidar for an area", glyph: "dig.mound")
                }
                .foregroundStyle(Theme.tan)
            }
            arrow
            step("You get", "text.bubble") {
                Text("An answer that names each survey over that ground.")
            }
        }
        .fixedSize(horizontal: false, vertical: true)
        .panel()
        .accessibilityElement(children: .combine)
    }

    private var arrow: some View {
        Image(systemName: "arrow.right").font(.system(size: 11 * Theme.scale, weight: .semibold)).foregroundStyle(Theme.faint)
            .frame(maxHeight: .infinity).accessibilityHidden(true)
    }

    private func step<Content: View>(_ title: String, _ icon: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Glyph(name: icon, size: 11.5 * Theme.scale, weight: .medium)
                Text(title).font(.system(size: 12 * Theme.scale, weight: .semibold))
            }
            .foregroundStyle(Theme.faint)
            content().font(.system(size: 13 * Theme.scale)).fixedSize(horizontal: false, vertical: true)
        }
        .padding(14).frame(maxWidth: .infinity, alignment: .topLeading)
    }

    /// One stage: its number, name and count, and under it, when unfolded, each tool with what it does.
    @ViewBuilder private func stage(number: Int, pack: ToolGuide.Pack, tools: [ToolGuide.Tool]) -> some View {
        // A search unfolds every stage that holds a match.
        let unfolded = !query.isEmpty || open.contains(pack.id)
        Button {
            withAnimation(Motion.ease(0.15)) { if open.contains(pack.id) { open.remove(pack.id) } else { open.insert(pack.id) } }
        } label: {
            HStack(alignment: .center, spacing: 12) {
                IconTile(name: pack.icon, size: 30)
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(number). \(pack.title)").font(.system(size: 13.5 * Theme.scale, weight: .semibold))
                    Text(pack.summary).font(.system(size: 12.5 * Theme.scale)).foregroundStyle(Theme.dim)
                        .multilineTextAlignment(.leading).fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 8)
                Text("\(tools.count) tool\(tools.count == 1 ? "" : "s")").font(.system(size: 12.5 * Theme.scale)).foregroundStyle(Theme.faint).fixedSize()
                Image(systemName: "chevron.right").font(.system(size: 10 * Theme.scale, weight: .semibold)).foregroundStyle(Theme.faint)
                    .rotationEffect(.degrees(unfolded ? 90 : 0))
            }
            .padding(14).contentShape(Rectangle())
        }
        .buttonStyle(.plain).disabled(!query.isEmpty)
        .accessibilityLabel("\(pack.title), \(tools.count) tools").accessibilityAddTraits(unfolded ? .isSelected : [])
        if unfolded {
            VStack(alignment: .leading, spacing: 8) {
                ForEach(tools) { tool in
                    HStack(alignment: .firstTextBaseline, spacing: 12) {
                        Text(tool.title).font(.system(size: 13 * Theme.scale, weight: .medium)).frame(width: 190 * Theme.scale, alignment: .leading)
                        Text(tool.does).font(.system(size: 12.5 * Theme.scale)).foregroundStyle(Theme.dim)
                            .fixedSize(horizontal: false, vertical: true).frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .help("The agent calls this tool \(tool.name)")
                }
            }
            .padding(.leading, 56).padding(.trailing, 14).padding(.bottom, 14)   // aligns under the stage's name
        }
    }
}

// MARK: - How it runs

/// What happens when a person asks for something, as four sentences with how each part stands, and the models to use.
private struct RunSettings: View {
    @EnvironmentObject var app: AppState
    @EnvironmentObject var engine: Engine
    @EnvironmentObject var setup: Setup

    /// The makers behind the models, read from each model's name, with how many of theirs there are.
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
        GroupTitle("When you ask for something") {
            StatusWord(ok: engine.ready && setup.toolsReady ? true : app.starting ? nil : false,
                       text: engine.ready && setup.toolsReady ? "All four are ready" : app.starting ? "Starting" : "Something is not ready")
        }
        VStack(spacing: 0) {
            part(1, "You", "type what you want, in your own words.", ok: true, status: app.userName) { EmptyView() }
            Hairline().padding(.leading, 48)   // aligns under the names
            part(2, "The model", "reads it and chooses the next step.",
                 ok: engine.ready && !app.starting ? true : nil, status: app.starting ? "Starting" : engine.ready ? app.modelName : "Waiting") {
                Button("Change") { app.settingsSection = .account }.buttonStyle(SecondaryButton()).disabled(!engine.ready)
            }
            Hairline().padding(.leading, 48)   // aligns under the names
            part(3, "The engine", "is Codex, a program on this Mac. It carries the step out.",
                 ok: setup.codex == nil ? false : app.starting ? nil : engine.ready,
                 // The short version here; About has the full one.
                 status: setup.codex == nil ? "Codex not found" : app.starting ? "Starting"
                    : engine.ready ? "Codex " + AccountSettings.version(setup.codexVersion)
                    : (engine.problem ?? "Not running")) {
                if setup.codex == nil, let url = URL(string: "https://github.com/openai/codex") {
                    Button("Get Codex") { NSWorkspace.shared.open(url) }.buttonStyle(PrimaryButton())
                } else {
                    Button("Restart") { Task { await app.boot() } }.buttonStyle(SecondaryButton()).disabled(app.starting)
                        .help("Use this after signing in to Codex or changing its settings. Running work stops.")
                }
            }
            Hairline().padding(.leading, 48)   // aligns under the names
            part(4, "The tools", "do the work: fetch lidar, check a find, keep the record.",
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
            Hairline()
            HStack(spacing: 8) {
                Image(systemName: "arrow.uturn.backward").font(.system(size: 10 * Theme.scale, weight: .bold))
                Text("The model reads each result and chooses again, until the work is done.")
            }
            .font(.system(size: 12.5 * Theme.scale)).foregroundStyle(Theme.faint)
            .padding(.horizontal, 14).padding(.vertical, 8).frame(maxWidth: .infinity, alignment: .leading)
        }
        .panel()

        let own = engine.models.filter { app.onThisAccount($0.id) }.count
        GroupTitle("Models you can use") {
            if engine.ready { StatusWord(ok: true, text: "\(engine.models.count) in all") }
        }
        VStack(spacing: 0) {
            SettingRow(title: routed ? "\(own) with your ChatGPT sign-in, \(engine.models.count - own) more through OpenCodex" : "\(engine.models.count) with your sign-in",
                       note: routed ? "OpenCodex is a router on this Mac that adds other makers' models. The start of a model's name is the account it runs on."
                        : "OpenCodex, a router you can add, brings other makers' models. Dighouse does not need it.") {
                if let url = URL(string: "https://github.com/lidge-jun/opencodex") {
                    Button { NSWorkspace.shared.open(url) } label: { Label("OpenCodex", systemImage: "arrow.up.right") }.buttonStyle(SecondaryButton())
                }
            }
            if engine.ready {
                Flow(spacing: 6) {
                    ForEach(makers, id: \.family) { m in
                        HStack(spacing: 6) {
                            Text(m.family).font(.system(size: 12 * Theme.scale, weight: .medium))
                            Text("\(m.count)").font(.system(size: 12 * Theme.scale)).foregroundStyle(Theme.faint)
                        }
                        .padding(.horizontal, 10).frame(height: 24)
                        .background(Capsule().fill(Theme.ink.opacity(0.06)))
                    }
                }
                .padding(.horizontal, 14).padding(.bottom, 12).frame(maxWidth: .infinity, alignment: .leading)
            }
            Hairline()
            SettingRow(title: "The web", note: "The agent can search the web and read pages and PDFs that need no sign-in.") {
                StatusWord(ok: true, text: "On")
            }
        }
        .panel()
    }

    /// One part on one line: its number in the order a request passes through, what it is and does, how it stands, and
    /// the one thing you can do about it.
    private func part<Action: View>(_ number: Int, _ title: String, _ role: String, ok: Bool?, status: String,
                                    @ViewBuilder action: () -> Action) -> some View {
        HStack(alignment: .center, spacing: 12) {
            Text("\(number)").font(.system(size: 11.5 * Theme.scale, weight: .bold)).foregroundStyle(Theme.tan)
                .frame(width: 22, height: 22).background(Circle().fill(Theme.tan.opacity(0.14)))
            (Text(title).font(.system(size: 13.5 * Theme.scale, weight: .semibold))
                + Text(" " + role).font(.system(size: 13.5 * Theme.scale)).foregroundColor(Theme.dim))
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 8)
            StatusWord(ok: ok, text: status)
            action()
        }
        .padding(.horizontal, 14).padding(.vertical, 8).frame(minHeight: 46)
        .accessibilityElement(children: .contain)
    }
}

// MARK: - About

/// The version, new versions, and where to get help.
private struct AboutSettings: View {
    @EnvironmentObject var app: AppState
    @EnvironmentObject var setup: Setup
    @AppStorage("checkUpdates") private var checkUpdates = true

    var body: some View {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? ""
        let versions = "Dighouse \(version), engine \(setup.codexVersion.isEmpty ? "not found" : setup.codexVersion)"
        VStack(spacing: 0) {
            HStack(spacing: 14) {
                Image(nsImage: NSApp.applicationIconImage).resizable().frame(width: 56, height: 56)
                VStack(alignment: .leading, spacing: 4) {
                    Text("Dighouse \(version)").font(.system(size: 17 * Theme.scale, weight: .semibold))
                    Text("A free, open tool for searching public lidar for places people built.")
                        .font(.system(size: 12.5 * Theme.scale)).foregroundStyle(Theme.dim).fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 8)
                if let url = URL(string: "https://github.com/chrissotraidis/dighouse") {
                    Button { NSWorkspace.shared.open(url) } label: { Label("GitHub", systemImage: "arrow.up.right") }.buttonStyle(SecondaryButton())
                }
            }
            .padding(14)
            Hairline()
            SettingRow(title: "Versions", note: versions) {
                Button("Copy") {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(versions, forType: .string)
                }
                .buttonStyle(SecondaryButton()).help("Copy these to include when you report a problem.")
            }
            Hairline()
            SettingRow(title: "New versions", note: Updates.shared.newer == nil ? "Asks GitHub once a day whether a newer version is out. Nothing is downloaded." : "") {
                HStack(spacing: 10) {
                    UpdateLine()
                    Toggle("", isOn: $checkUpdates).labelsHidden().toggleStyle(.switch)
                        .onChange(of: checkUpdates) { Task { await Updates.shared.check() } }
                }
            }
        }
        .panel()

        GroupTitle("Help")
        VStack(spacing: 0) {
            SettingRow(title: "Welcome guide", note: "What Dighouse does, and what it needs on this Mac.") {
                Button("Open") { app.showWelcome = true }.buttonStyle(SecondaryButton())
            }
            Hairline()
            SettingRow(title: "Report a problem", note: "Opens a new issue on GitHub with the versions filled in and locations taken out. You read it and send it.") {
                Button("Report…") { ProblemReport.open(app: app) }.buttonStyle(SecondaryButton())
            }
        }
        .panel()

        Text("Open source, under the Apache 2.0 licence. The word lidar is written in lowercase here, as the US Geological Survey writes it.")
            .font(.system(size: 12.5 * Theme.scale)).foregroundStyle(Theme.faint).lineSpacing(2).fixedSize(horizontal: false, vertical: true)
    }
}

import SwiftUI

/// The first-run guide, in three steps: what Dighouse is, setting it up with a model, and a first search.
struct WelcomeView: View {
    @EnvironmentObject var app: AppState
    @EnvironmentObject var engine: Engine
    @EnvironmentObject var setup: Setup
    @State private var page = 0

    private let titles = ["Welcome", "Set up", "First search"]

    var body: some View {
        VStack(spacing: 0) {
            steps.padding(.top, 48)

            // Each page sits in the middle of the window, and scrolls only when the window is shorter than the page.
            GeometryReader { geo in
                ScrollView {
                    Group {
                        switch page {
                        case 0: intro
                        case 1: setupPage
                        default: app.modelReady || !app.searchesFromClaude ? AnyView(first) : AnyView(firstFromClaude)
                        }
                    }
                    .id(page).arrives()
                    .frame(width: Self.column, alignment: .leading).padding(.vertical, 24)
                    .frame(maxWidth: .infinity, minHeight: geo.size.height)
                }
            }

            Rectangle().fill(Theme.line).frame(height: 1)
            HStack(spacing: 10) {
                if page > 0 { Button("Back") { page -= 1 }.buttonStyle(SecondaryButton()) }
                // The fetching starts on the first page, so the first page says what is being fetched, and from where.
                if page == 0, setup.engineBusy || setup.toolsBusy {
                    DigIndicator(size: 13)
                    Text(setup.engineBusy ? "Getting ready: downloading the Codex engine from OpenAI's releases on GitHub."
                         : "Getting ready: preparing the archaeology tools, about a minute.")
                        .font(.system(size: 12.5 * Theme.scale)).foregroundStyle(Theme.dim).fixedSize(horizontal: false, vertical: true)
                }
                Spacer()
                if page == 1, !canContinue {
                    Text("Continue lights up when a model is ready.").font(.system(size: 13 * Theme.scale)).foregroundStyle(Theme.faint)
                }
                if app.onboarded { Button("Close guide") { app.showWelcome = false }.buttonStyle(SecondaryButton()) }
                else if page == 2, app.modelReady || !app.searchesFromClaude {
                    Button("Skip for now") { app.finishOnboarding() }.buttonStyle(SecondaryButton()).help("Go to Home. The guided search stays there.")
                }
                if page == 2, !app.modelReady, app.searchesFromClaude {
                    Button("Go to Home") { app.finishOnboarding() }.buttonStyle(PrimaryButton()).keyboardShortcut(.defaultAction)
                } else if page == 2 {
                    Button("Start the guided search") { guided() }
                        .buttonStyle(PrimaryButton()).disabled(!app.modelReady)
                        .keyboardShortcut(.defaultAction)
                } else {
                    Button(page == 0 ? "Get started" : "Continue") { page += 1 }
                        .buttonStyle(PrimaryButton()).disabled(page == 1 && !canContinue)
                        .keyboardShortcut(.defaultAction)
                }
            }
            .frame(width: Self.column).padding(.vertical, 16)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        // On a first run the engine and the tools are fetched while the person reads the first page.
        .task { if !app.onboarded { await app.getReady() } }
    }

    /// How wide the guide's one column is.
    private static let column: CGFloat = 720

    /// A model in Dighouse, or Claude Code holding Dighouse's tools: either is enough to go on.
    private var canContinue: Bool { app.modelReady || app.searchesFromClaude }

    /// Earlier steps are always open. Someone who has been through the guide can jump ahead, but not past setup until the engine runs.
    private func reachable(_ i: Int) -> Bool {
        i < page || (app.onboarded && (i < 2 || canContinue))
    }

    private var steps: some View {
        HStack(spacing: 10) {
            ForEach(titles.indices, id: \.self) { i in
                Button { if reachable(i) { page = i } } label: {
                    HStack(spacing: 8) {
                        ZStack {
                            Circle().fill(i == page ? Theme.primary : i < page ? Theme.green.opacity(0.9) : Theme.raised)
                            if i < page {
                                Image(systemName: "checkmark").font(.system(size: 9 * Theme.scale, weight: .bold)).foregroundStyle(.black)
                            } else {
                                Text("\(i + 1)").font(.system(size: 11 * Theme.scale, weight: .semibold)).foregroundStyle(i == page ? .black : Theme.dim)
                            }
                        }
                        .frame(width: 20, height: 20)
                        Text(titles[i]).font(.system(size: 13.5 * Theme.scale, weight: i == page ? .semibold : .regular))
                            .foregroundStyle(i == page ? Theme.text : Theme.dim)
                    }
                }
                .buttonStyle(.plain).disabled(!reachable(i) && i != page)
                if i < titles.count - 1 { Rectangle().fill(Theme.line).frame(width: 28, height: 1) }
            }
        }
    }

    private var intro: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack(spacing: 16) {
                Image(nsImage: NSApp.applicationIconImage).resizable().frame(width: 64, height: 64)
                Text("Dighouse").font(.system(size: 40 * Theme.scale, weight: .bold))
            }
            Text("Open archaeology on your Mac. An AI agent searches public lidar for places people built, and checks each find. You decide what it is.")
                .font(.system(size: 18 * Theme.scale)).foregroundStyle(Theme.dim).lineSpacing(3).fixedSize(horizontal: false, vertical: true)
            VStack(alignment: .leading, spacing: 8) {
                ForestReveal(height: 300)
                Text("Lidar is a laser scan from an aircraft that sees the ground through the trees. Drag the handle, at Serpent Mound in Ohio.")
                    .font(.system(size: 13 * Theme.scale)).foregroundStyle(Theme.faint).fixedSize(horizontal: false, vertical: true)
            }
            HStack(alignment: .top, spacing: 10) {
                point("dig.grid", "The agent searches", "It fetches open lidar, takes the trees away, and looks at every tile.")
                point("dig.layers", "Every find is checked", "A slice, a second model's opinion, open maps, and what is published.")
                point("person", "You decide", "Nothing is called new. Locations stay on this Mac.")
            }
            .fixedSize(horizontal: false, vertical: true)
        }
        .font(.system(size: 13.5 * Theme.scale))
    }

    private var setupPage: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Set up").font(.system(size: 32 * Theme.scale, weight: .bold))
            Text("Dighouse fetches what it runs on. Then you give it a model to think with: the ChatGPT or Claude account you already have.")
                .font(.system(size: 16 * Theme.scale)).foregroundStyle(Theme.dim).lineSpacing(2).fixedSize(horizontal: false, vertical: true)
            SetupChecklist()
        }
    }

    /// The last page for a person with Claude alone: the first search is asked for in Claude Code, and shows up here.
    private var firstFromClaude: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Your first search, from Claude Code").font(.system(size: 32 * Theme.scale, weight: .bold))
            Text("Claude Code has Dighouse's tools and its search guide. Ask it for a search, and the project appears here for you to decide.")
                .font(.system(size: 16 * Theme.scale)).foregroundStyle(Theme.dim).lineSpacing(2).fixedSize(horizontal: false, vertical: true)
            VStack(alignment: .leading, spacing: 12) {
                claudeStep(1, "Open Claude Code", "In Terminal, type claude.")
                claudeStep(2, "Ask for a search", "For a first one: “Use Dighouse to search Serpent Mound in Ohio and report back.”")
                claudeStep(3, "Decide here", "The project shows in Dighouse's sidebar with its finds, each waiting for your decision.")
            }
            .padding(16).frame(maxWidth: .infinity, alignment: .leading).panel()
            Text("The chat inside Dighouse stays off until you add ChatGPT or an OpenAI key, in Settings.")
                .font(.system(size: 13.5 * Theme.scale)).foregroundStyle(Theme.faint).fixedSize(horizontal: false, vertical: true)
        }
    }

    private func claudeStep(_ number: Int, _ title: String, _ text: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text("\(number)").font(.system(size: 12 * Theme.scale, weight: .bold)).foregroundStyle(Theme.tan)
                .frame(width: 22, height: 22).background(Circle().fill(Theme.tan.opacity(0.14)))
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.system(size: 15 * Theme.scale, weight: .semibold))
                Text(text).font(.system(size: 14 * Theme.scale)).foregroundStyle(Theme.dim).fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var first: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Your first search").font(.system(size: 32 * Theme.scale, weight: .bold))
            Text("Start with a guided search of a place everyone knows. It shows every step, and ends with your own decision.")
                .font(.system(size: 16 * Theme.scale)).foregroundStyle(Theme.dim).lineSpacing(2).fixedSize(horizontal: false, vertical: true)
            StartTile(icon: "dig.trowel", title: "The guided first search",
                      text: "Ten minutes at Serpent Mound in Ohio, a step at a time: get the ground, look at it, open a find, read the record and decide.",
                      strong: true, grow: 1.12) { guided() }
                .disabled(!app.modelReady)
            Text("Or go straight to your own").font(.system(size: 15 * Theme.scale, weight: .semibold)).padding(.top, 8)
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 10, alignment: .top), GridItem(.flexible(), spacing: 10, alignment: .top)], spacing: 10) {
                StartTile(icon: "sparkle.magnifyingglass", title: "Find something",
                          text: "The agent picks a region with open lidar and little on record, and searches it for as long as you choose.",
                          tint: Theme.clay, grow: 1.12) {
                    app.finishOnboarding()
                    if let flow = ToolGuide.workflows.first(where: { $0.id == "timed-research" }) { app.run(flow) }
                }
                StartTile(icon: "map", title: "Pick a place",
                          text: "Click anywhere on the map with open lidar and start a search there.", tint: Theme.sky, grow: 1.12) {
                    app.finishOnboarding()
                    app.startProject()
                }
            }
            .disabled(!app.modelReady)
            Text("Home has more: known sites to learn on, open surveys, and a test that scores the agent on a famous site.")
                .font(.system(size: 13.5 * Theme.scale)).foregroundStyle(Theme.faint).fixedSize(horizontal: false, vertical: true)
        }
    }

    /// Leave the guide for the first-project tutorial: one real search, a step at a time.
    private func guided() {
        app.finishOnboarding()
        app.startTutorial()
    }

    private func point(_ icon: String, _ title: String, _ text: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            IconTile(name: icon, size: 30)
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.system(size: 15 * Theme.scale, weight: .semibold))
                Text(text).foregroundStyle(Theme.dim).lineSpacing(2).fixedSize(horizontal: false, vertical: true)
            }
        }
        .font(.system(size: 13.5 * Theme.scale)).padding(14)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading).panel()
    }
}

/// What Dighouse needs, in the order it needs it: the engine, the tools, then a model. Each step says where it stands,
/// and the first one still to do offers the one thing to press.
struct SetupChecklist: View {
    @EnvironmentObject var app: AppState
    @EnvironmentObject var setup: Setup
    @EnvironmentObject var engine: Engine
    @State private var signingIn = false
    @State private var signInProblem: String?
    @State private var claudeBusy = false
    @State private var claudeProblem: String?

    /// A model in Dighouse, or Claude Code holding Dighouse's tools.
    private var thinks: Bool { app.modelReady || app.searchesFromClaude }

    /// The first step still to do: 0 the engine, 1 the tools, 2 the model, 3 nothing.
    private var current: Int { setup.codex == nil ? 0 : !setup.toolsReady ? 1 : !thinks ? 2 : 3 }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(spacing: 0) {
                step(0, done: setup.codex != nil, busy: setup.engineBusy, "The agent engine",
                     setup.codex != nil ? "Codex, \(setup.codexVersion.split(separator: " ").last.map(String.init) ?? setup.codexVersion)"
                     : setup.engineBusy ? "Downloading Codex from OpenAI's releases on GitHub."
                     : (setup.engineProblem ?? "Codex, OpenAI's free program that lets a model use tools. Dighouse keeps its own copy.")) {
                    if setup.codex == nil, !setup.engineBusy {
                        Button(setup.engineProblem == nil ? "Install it" : "Try again") { Task { await setup.installEngine(); await app.boot() } }.buttonStyle(PrimaryButton())
                    }
                }
                Hairline()
                step(1, done: setup.toolsReady, busy: setup.toolsBusy, "The archaeology tools",
                     setup.toolsReady ? "\(ToolGuide.toolCount) tools that fetch lidar, check finds and keep records."
                     : setup.toolsSource == nil ? "The tools are missing from this copy of Dighouse."
                     : setup.uv == nil ? "Needs uv, a small program that runs the tools. A downloaded Dighouse carries it; this copy does not, so install it, then check again."
                     : setup.toolsBusy ? "Preparing \(ToolGuide.toolCount) tools. This takes about a minute the first time."
                     : (setup.toolsProblem ?? "\(ToolGuide.toolCount) tools that fetch lidar, check finds and keep records. Preparing them takes about a minute."),
                     link: setup.uv == nil ? ("Get uv", "https://docs.astral.sh/uv/getting-started/installation/") : nil) {
                    if !setup.toolsReady, !setup.toolsBusy, setup.uv != nil, setup.toolsSource != nil {
                        Button(setup.toolsProblem == nil ? "Prepare them" : "Try again") { Task { await setup.prepareTools(); await app.boot() } }
                            .buttonStyle(current == 1 ? AnyButtonStyle(PrimaryButton()) : AnyButtonStyle(SecondaryButton()))
                    }
                }
                Hairline()
                step(2, done: thinks, busy: signingIn || (current == 2 && app.starting), "A model to think with",
                     !app.modelReady && app.searchesFromClaude ? "Claude, through Claude Code. It runs the search with Dighouse's tools, and you decide the finds here."
                     : app.modelReady ? "\(engine.account.map { "Signed in as \($0). " } ?? "")\(engine.models.count) models, from Codex\(engine.models.contains { $0.id.contains("/") } ? " and the OpenCodex router" : "")."
                     : signingIn ? "Finish signing in in your browser. This page moves on by itself."
                     : signInProblem ?? (engine.account != nil ? (engine.problem ?? "Signed in. Reading the models.")
                        : current < 2 ? "ChatGPT, Claude or an OpenAI API key, once the first two are ready."
                        : "Dighouse runs on the AI you already have, and your work goes only to that provider. Choose one.")) {
                    if app.modelReady {
                        ModelPicker(title: app.modelName, models: engine.models, current: app.model?.id) { app.modelID = $0.id }
                    }
                }
                if current == 2, engine.account == nil, engine.running, !signingIn { accounts; claudeChoice }
            }
            .panel()

            HStack(spacing: 12) {
                Button("Check again") { Task { await app.boot() } }.buttonStyle(SecondaryButton()).disabled(app.starting)
                if app.starting { DigIndicator() }
                if app.modelReady {
                    Text("Looking at tiles needs a model that reads images. You can change the model at any time from the chat.")
                        .font(.system(size: 12.5 * Theme.scale)).foregroundStyle(Theme.faint).fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .font(.system(size: 14 * Theme.scale))
    }

    /// Claude as the third account: Claude Code is given Dighouse's tools, and runs the search itself.
    private var claudeChoice: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("A Claude account").font(.system(size: 14.5 * Theme.scale, weight: .semibold))
                Text(claudeProblem ?? (setup.claude != nil
                     ? "Claude Code is on this Mac. It gets Dighouse's tools and runs the search on your Claude plan. You decide the finds here."
                     : "Needs Claude Code on this Mac. It then gets Dighouse's tools and runs the search on your Claude plan."))
                    .foregroundStyle(claudeProblem == nil ? Theme.dim : Theme.amber).fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 8)
            if claudeBusy { DigIndicator() } else if let claude = setup.claude {
                Button("Use Claude Code") {
                    claudeBusy = true
                    claudeProblem = nil
                    Task {
                        claudeProblem = await ClaudeCode.connect(claude, tools: setup.toolsBinary, skill: setup.skill)
                        if claudeProblem == nil { app.searchesFromClaude = true }
                        claudeBusy = false
                    }
                }
                .buttonStyle(SecondaryButton())
                .help("Adds Dighouse's tools and search guide to Claude Code. Settings can take them out again.")
            } else if let url = URL(string: "https://docs.claude.com/en/docs/claude-code/setup") {
                Button { NSWorkspace.shared.open(url) } label: { Label("Get Claude Code", systemImage: "arrow.up.right") }.buttonStyle(SecondaryButton())
            }
        }
        .padding(14).frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Theme.ink.opacity(0.04)))
        .padding(.leading, 50).padding(.trailing, 16).padding(.bottom, 16)   // aligns under the step's name
    }

    /// The two accounts the search can run on, side by side.
    private var accounts: some View {
        HStack(alignment: .top, spacing: 10) {
            VStack(alignment: .leading, spacing: 8) {
                Text("A ChatGPT account").font(.system(size: 14.5 * Theme.scale, weight: .semibold))
                Text("Uses your ChatGPT plan. You sign in in your browser, and Dighouse never sees the password.")
                    .foregroundStyle(Theme.dim).fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
                Button("Sign in with ChatGPT") {
                    signingIn = true
                    signInProblem = nil
                    Task {
                        do { try await engine.signIn(); await app.boot() } catch { signInProblem = error.localizedDescription }
                        signingIn = false
                    }
                }
                .buttonStyle(PrimaryButton())
            }
            .padding(14).frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Theme.ink.opacity(0.04)))
            VStack(alignment: .leading, spacing: 8) {
                Text("An OpenAI API key").font(.system(size: 14.5 * Theme.scale, weight: .semibold))
                APIKeySignIn(alwaysOpen: true)
            }
            .padding(14).frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Theme.ink.opacity(0.04)))
        }
        .fixedSize(horizontal: false, vertical: true)
        .padding(.leading, 50).padding(.trailing, 16).padding(.bottom, 10)   // aligns under the step's name
    }

    private func step(_ index: Int, done: Bool, busy: Bool, _ title: String, _ detail: String, link: (String, String)? = nil,
                      @ViewBuilder action: () -> some View = { EmptyView() }) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Group {
                if done {
                    Image(systemName: "checkmark.circle.fill").font(.system(size: 18 * Theme.scale)).foregroundStyle(Theme.green)
                } else if busy {
                    DigIndicator(size: 13)
                } else {
                    Text("\(index + 1)").font(.system(size: 11.5 * Theme.scale, weight: .bold)).foregroundStyle(current == index ? .black : Theme.dim)
                        .frame(width: 20, height: 20).background(Circle().fill(current == index ? Theme.primary : Theme.ink.opacity(0.1)))
                }
            }
            .frame(width: 22, height: 22)
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.system(size: 15 * Theme.scale, weight: .semibold)).foregroundStyle(done || current == index ? Theme.text : Theme.dim)
                Text(detail).foregroundStyle(Theme.dim).fixedSize(horizontal: false, vertical: true)
                if let link, let url = URL(string: link.1) { Link(link.0, destination: url).foregroundStyle(Theme.accent) }
            }
            Spacer(minLength: 8)
            action()
        }
        .padding(16)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Step \(index + 1), \(title): \(done ? "done" : busy ? "working" : "to do")")
    }
}

/// Either of two button styles in one place, so a button can be the main one only while its step is the next.
struct AnyButtonStyle: ButtonStyle {
    private let make: (Configuration) -> AnyView
    init<S: ButtonStyle>(_ style: S) { make = { AnyView(style.makeBody(configuration: $0)) } }
    func makeBody(configuration: Configuration) -> some View { make(configuration) }
}

/// Sign the engine in with an OpenAI API key instead of a ChatGPT account. Offered only while nothing is signed in, so it
/// never replaces a person's Codex sign-in.
struct APIKeySignIn: View {
    @EnvironmentObject var app: AppState
    @EnvironmentObject var engine: Engine
    /// Shown without the line that unfolds it, where the key is one of two choices side by side.
    var alwaysOpen = false
    @State private var open = false
    @State private var key = ""
    @State private var busy = false
    @State private var problem: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if !alwaysOpen {
                Button { withAnimation(.easeOut(duration: 0.15)) { open.toggle() } } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.right").font(.system(size: 9 * Theme.scale, weight: .bold)).rotationEffect(.degrees(open ? 90 : 0))
                        Text("Use an OpenAI API key instead")
                    }
                    .font(.system(size: 12.5 * Theme.scale)).foregroundStyle(Theme.dim).contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            if open || alwaysOpen {
                Text(problem ?? (alwaysOpen ? "Pay as you go, with no plan limit. The key is checked with OpenAI, then kept in a file only you can read."
                     : "Each request is billed to the key, so there is no plan limit to run into. The key is checked with OpenAI, then kept the way Codex keeps it, in a file only you can read."))
                    .font(.system(size: (alwaysOpen ? 13 : 12) * Theme.scale)).foregroundStyle(problem == nil ? (alwaysOpen ? Theme.dim : Theme.faint) : Theme.amber)
                    .fixedSize(horizontal: false, vertical: true)
                HStack(spacing: 8) {
                    SecureField("sk-…", text: $key).textFieldStyle(.plain).font(.system(size: 13 * Theme.scale))
                        .padding(.horizontal, 10).frame(height: 30).frame(maxWidth: 260)
                        .background(RoundedRectangle(cornerRadius: 8).fill(Theme.ink.opacity(0.06)))
                        .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(Theme.line))
                    if busy { DigIndicator() } else {
                        Button("Sign in") {
                            busy = true
                            problem = nil
                            Task {
                                do { try await engine.signIn(apiKey: key); key = ""; await app.boot() } catch { problem = error.localizedDescription }
                                busy = false
                            }
                        }
                        .buttonStyle(SecondaryButton()).disabled(key.trimmingCharacters(in: .whitespaces).count < 20)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

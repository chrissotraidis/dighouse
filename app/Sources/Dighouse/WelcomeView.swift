import SwiftUI

/// The first-run guide: what Dighouse is, how a search works, setting up inference, and a first project.
struct WelcomeView: View {
    @EnvironmentObject var app: AppState
    @EnvironmentObject var engine: Engine
    @State private var page = 0
    @State private var choice = StartingPoints.all[0]
    @State private var busy = false
    @State private var problem: String?

    private let titles = ["Welcome", "How it works", "Set up", "First project"]

    var body: some View {
        VStack(spacing: 0) {
            steps.padding(.top, 52)

            ScrollView {
                Group {
                    switch page {
                    case 0: intro
                    case 1: how
                    case 2: setupPage
                    default: first
                    }
                }
                .id(page).arrives()
                .frame(width: 640, alignment: .leading).padding(.vertical, 36)
                .frame(maxWidth: .infinity)
            }

            Rectangle().fill(Theme.line).frame(height: 1)
            HStack(spacing: 10) {
                if page > 0 { Button("Back") { page -= 1 }.buttonStyle(SecondaryButton()) }
                Spacer()
                if app.onboarded && page < 3 { Button("Close guide") { app.showWelcome = false }.buttonStyle(SecondaryButton()) }
                if page == 3 {
                    firstActions
                } else {
                    Button(page == 0 ? "Get started" : "Continue") { page += 1 }
                        .buttonStyle(PrimaryButton()).disabled(page == 2 && !engine.ready)
                        .keyboardShortcut(.defaultAction)
                }
            }
            .frame(width: 640).padding(.vertical, 18)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    /// Earlier steps are always open. Someone who has been through the guide can jump ahead, but not past setup until the engine runs.
    private func reachable(_ i: Int) -> Bool {
        i < page || (app.onboarded && (i < 3 || engine.ready))
    }

    private var steps: some View {
        HStack(spacing: 10) {
            ForEach(titles.indices, id: \.self) { i in
                Button { if reachable(i) { page = i } } label: {
                    HStack(spacing: 7) {
                        ZStack {
                            Circle().fill(i == page ? Theme.primary : i < page ? Theme.green.opacity(0.9) : Theme.raised)
                            if i < page {
                                Image(systemName: "checkmark").font(.system(size: 9 * Theme.scale, weight: .bold)).foregroundStyle(.black)
                            } else {
                                Text("\(i + 1)").font(.system(size: 11 * Theme.scale, weight: .semibold)).foregroundStyle(i == page ? .black : Theme.dim)
                            }
                        }
                        .frame(width: 20, height: 20)
                        Text(titles[i]).font(.system(size: 12.5 * Theme.scale, weight: i == page ? .semibold : .regular))
                            .foregroundStyle(i == page ? .white : Theme.dim)
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
            Text("Open archaeology on your Mac. AI agents search public lidar for places people built, and check each find. You decide what it is.")
                .font(.system(size: 17 * Theme.scale)).foregroundStyle(Theme.dim).fixedSize(horizontal: false, vertical: true)
            VStack(alignment: .leading, spacing: 7) {
                ForestReveal()
                Text("Serpent Mound, Ohio. Drag the handle to take the trees away.").font(.system(size: 11.5 * Theme.scale)).foregroundStyle(Theme.faint)
            }
            Text("Lidar is a laser scan from an aircraft that maps the ground through gaps in the trees. Much of it is public. Dighouse gives an AI model the tools to fetch it, look through it and check what it finds.")
                .foregroundStyle(Theme.dim).fixedSize(horizontal: false, vertical: true)
            VStack(spacing: 0) {
                point("dig.grid", "Agents do the patient part",
                      "They fetch open lidar, take the trees away, and look at every tile of ground.")
                Rectangle().fill(Theme.line).frame(height: 1)
                point("dig.layers", "Every find is checked",
                      "A slice through the laser points, a second model's opinion, open maps, and what is published.")
                Rectangle().fill(Theme.line).frame(height: 1)
                point("person", "You decide",
                      "Nothing is called new. You see the evidence and decide, and locations stay on this Mac.")
            }
            .panel()
        }
        .font(.system(size: 13.5 * Theme.scale))
    }

    private var how: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("How a search works").font(.system(size: 28 * Theme.scale, weight: .bold))
            Text("Six sets of tools, used in this order. Ask for a search and the agent runs them all, then reports back. Watch, steer by typing, or come back later.")
                .font(.system(size: 14 * Theme.scale)).foregroundStyle(Theme.dim).fixedSize(horizontal: false, vertical: true)
            VStack(alignment: .leading, spacing: 16) {
                ForEach(Array(ToolGuide.packs.enumerated()), id: \.element.id) { index, pack in
                    HStack(alignment: .top, spacing: 14) {
                        IconTile(name: pack.icon)
                        VStack(alignment: .leading, spacing: 4) {
                            Text("\(index + 1). \(pack.title)").font(.system(size: 14 * Theme.scale, weight: .semibold))
                            Text(pack.summary).font(.system(size: 13 * Theme.scale)).foregroundStyle(Theme.dim).fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
            }
            Text("The Toolbox shows each stage with a picture you can try.")
                .font(.system(size: 12.5 * Theme.scale)).foregroundStyle(Theme.faint)
        }
    }

    private var setupPage: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Set up").font(.system(size: 28 * Theme.scale, weight: .bold))
            Text("Dighouse runs its agents on the Codex engine, using the models you already have. Your work goes only to the model provider you choose.")
                .font(.system(size: 14 * Theme.scale)).foregroundStyle(Theme.dim).fixedSize(horizontal: false, vertical: true)
            SetupChecklist()
        }
    }

    private var first: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Your first project").font(.system(size: 28 * Theme.scale, weight: .bold))
            Text("A project is a folder in ~/Dighouse with its own history: the question, the area, and everything the agents find. A published place makes a good first run, because it shows what a real site looks like.")
                .font(.system(size: 14 * Theme.scale)).foregroundStyle(Theme.dim).fixedSize(horizontal: false, vertical: true)
            VStack(spacing: 8) {
                ForEach(StartingPoints.all + [StartingPoints.own]) { option in
                    Button { choice = option } label: {
                        HStack(spacing: 12) {
                            Image(systemName: choice == option ? "largecircle.fill.circle" : "circle")
                                .foregroundStyle(choice == option ? Theme.accent : Theme.faint)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(option.title).font(.system(size: 13.5 * Theme.scale, weight: .semibold))
                                Text(option.place).font(.system(size: 12.5 * Theme.scale)).foregroundStyle(Theme.dim)
                                Text(option.about).font(.system(size: 12 * Theme.scale)).foregroundStyle(Theme.faint).lineLimit(2)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            Spacer()
                            if !option.source.isEmpty { Badge(text: option.source) }
                        }
                        .padding(12)
                        .background(RoundedRectangle(cornerRadius: 10).fill(Theme.ink.opacity(0.035)))
                        .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(choice == option ? Theme.accent.opacity(0.7) : Theme.line))
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
            if let problem { Text(problem).font(.system(size: 12.5 * Theme.scale)).foregroundStyle(Theme.amber) }
        }
    }

    /// The first-project choices, kept in the footer so they show without scrolling.
    @ViewBuilder private var firstActions: some View {
        if app.onboarded { Button("Close guide") { app.showWelcome = false }.buttonStyle(SecondaryButton()) }
        else { Button("Skip for now") { app.finishOnboarding() }.buttonStyle(SecondaryButton()) }
        Button("Suggest a place") {
            app.finishOnboarding()
            if let flow = ToolGuide.workflows.first(where: { $0.id == "research" }) { app.run(flow) }
        }
        .help("Starts a chat in which the agent reads the open archives and proposes three searches.")
        .buttonStyle(SecondaryButton()).disabled(!engine.ready)
        if busy { DigIndicator() }
        Button(choice.kind == .own ? "Pick an area" : "Create project", action: begin)
            .buttonStyle(PrimaryButton()).disabled(busy || !engine.ready)
            .keyboardShortcut(.defaultAction)
    }

    /// Create the project for a listed place, or go to the map for an area of the person's own.
    private func begin() {
        guard choice.kind != .own else {
            app.finishOnboarding()
            app.startProject()
            return
        }
        busy = true
        problem = nil
        Task { @MainActor in
            do {
                try await app.createProject(name: choice.name, question: choice.question, box: choice.box.compactMap(Double.init))
                app.finishOnboarding()
            } catch {
                problem = error.localizedDescription
            }
            busy = false
        }
    }

    private func point(_ icon: String, _ title: String, _ text: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            IconTile(name: icon)
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.system(size: 14 * Theme.scale, weight: .semibold))
                Text(text).foregroundStyle(Theme.dim).fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .font(.system(size: 13 * Theme.scale)).padding(16)
    }
}

/// What Dighouse needs, whether it is there, and how to fix what is missing.
struct SetupChecklist: View {
    @EnvironmentObject var app: AppState
    @EnvironmentObject var setup: Setup
    @EnvironmentObject var engine: Engine
    @State private var signingIn = false
    @State private var signInProblem: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(spacing: 0) {
                row(setup.codex != nil, "Agent engine (Codex)", "The free program from OpenAI that lets an AI model use tools.",
                    setup.codex != nil ? setup.codexVersion
                    : setup.engineBusy ? "Downloading it from OpenAI's releases on GitHub…"
                    : (setup.engineProblem ?? "Not on this Mac yet. Dighouse can install it in its own folder.")) {
                    if setup.codex == nil {
                        if setup.engineBusy { DigIndicator() } else {
                            Button("Install it") { Task { await setup.installEngine(); await app.boot() } }.buttonStyle(PrimaryButton())
                        }
                    }
                }
                Rectangle().fill(Theme.line).frame(height: 1)
                row(engine.account != nil, "Signed in", "The engine uses a ChatGPT account's models. You sign in in your browser; Dighouse never sees the password.",
                    engine.account.map { "Signed in as \($0)" } ?? (signInProblem ?? (setup.codex == nil ? "After the engine is installed." : "Not signed in yet."))) {
                    if engine.account == nil, setup.codex != nil {
                        if signingIn { DigIndicator() } else {
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
                }
                Rectangle().fill(Theme.line).frame(height: 1)
                row(setup.toolsReady, "Archaeology tools", "\(ToolGuide.toolCount) tools that fetch lidar, build the bare ground, cut slices, check maps, read the literature and keep records.",
                    setup.toolsReady ? "Ready"
                    : setup.toolsSource == nil ? "The tools are missing from this copy of Dighouse."
                    : setup.uv == nil ? "Needs uv, a small program that runs the tools. A downloaded Dighouse carries it; this copy does not, so install it, then check again."
                    : setup.toolsBusy ? "Preparing. This takes about a minute the first time."
                    : (setup.toolsProblem ?? "Not prepared yet."),
                    link: setup.uv == nil ? ("Get uv", "https://docs.astral.sh/uv/getting-started/installation/") : nil) {
                    if !setup.toolsReady, setup.uv != nil, setup.toolsSource != nil {
                        if setup.toolsBusy { DigIndicator() } else {
                            Button("Prepare tools") { Task { await setup.prepareTools(); await app.boot() } }
                                .buttonStyle(PrimaryButton())
                        }
                    }
                }
                Rectangle().fill(Theme.line).frame(height: 1)
                row(engine.ready, "AI models", "The models that do the thinking and the looking.",
                    engine.ready
                    ? "\(engine.models.count) available" + (setup.ocxRunning ? ", through Codex and the OpenCodex router." : ", from the Codex sign-in on this Mac.")
                    : app.starting ? "Checking…" : (engine.problem ?? "Available once the engine and the tools are ready.")) {
                    if engine.ready {
                        ModelPicker(title: app.modelName, models: engine.models, current: app.model?.id) { app.modelID = $0.id }
                    }
                }
            }
            .panel()

            HStack(spacing: 12) {
                Button("Check again") { Task { await app.boot() } }.buttonStyle(SecondaryButton()).disabled(app.starting)
                if app.starting { DigIndicator() }
                if engine.ready {
                    Text("Looking at tiles needs a model that reads images. You can change the model at any time from the chat.")
                        .font(.system(size: 12.5 * Theme.scale)).foregroundStyle(Theme.faint).fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .font(.system(size: 13 * Theme.scale))
    }

    private func row(_ ok: Bool, _ title: String, _ what: String, _ detail: String, link: (String, String)? = nil,
                     @ViewBuilder action: () -> some View = { EmptyView() }) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: ok ? "checkmark.circle.fill" : "circle").font(.system(size: 16 * Theme.scale))
                .foregroundStyle(ok ? Theme.green : Theme.faint).frame(width: 22).padding(.top, 1)
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.system(size: 14 * Theme.scale, weight: .semibold))
                Text(what).foregroundStyle(Theme.faint)
                Text(detail).foregroundStyle(Theme.dim).fixedSize(horizontal: false, vertical: true).padding(.top, 2)
                if let link, let url = URL(string: link.1) { Link(link.0, destination: url).foregroundStyle(Theme.accent) }
            }
            Spacer(minLength: 8)
            action()
        }
        .padding(16)
    }
}

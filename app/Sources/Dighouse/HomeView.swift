import AppKit
import SwiftUI

/// Places to begin. Every box here was fetched from the live data service before it was listed.
enum StartingPoints {
    static let own = StartingPoint(
        id: "own", kind: .own, title: "Your own area", place: "Anywhere with open lidar",
        about: "Pick an area on the map and see which open surveys cover it.",
        source: "", name: "", question: "", box: ["", "", "", ""])

    static let all: [StartingPoint] = [
        StartingPoint(
            id: "cahokia", kind: .learn, title: "Cahokia", place: "Illinois, United States",
            about: "Monks Mound, the largest earthwork north of Mexico, with modern paths and stairs on it. A good first run.",
            source: "USGS 3DEP", name: "Cahokia",
            question: "What built features show in the ground around Monks Mound, and are they already published?",
            box: ["-90.0652", "38.6585", "-90.0592", "38.6628"]),
        StartingPoint(
            id: "newark", kind: .learn, title: "Newark Great Circle", place: "Ohio, United States",
            about: "A Hopewell enclosure about 365 m across, inside a modern town. Tests telling an ancient bank from roads and house lots.",
            source: "USGS 3DEP", name: "Newark Great Circle",
            question: "Which features around the Great Circle are ancient earthworks and which are modern?",
            box: ["-82.4334", "40.0384", "-82.4266", "40.0440"]),
        StartingPoint(
            id: "serpent-mound", kind: .learn, title: "Serpent Mound", place: "Ohio, United States",
            about: "An effigy mound about 411 m long on a wooded ridge above a creek. Shows how a low, winding bank reads in relief.",
            source: "USGS 3DEP", name: "Serpent Mound",
            question: "How clearly does the effigy show in the ground returns, and what else is on the ridge?",
            box: ["-83.4334", "39.0226", "-83.4270", "39.0278"]),
        StartingPoint(
            id: "mound-city", kind: .learn, title: "Mound City Group", place: "Ohio, United States",
            about: "About two dozen Hopewell mounds inside a low earthen wall. Many small features in one tile.",
            source: "USGS 3DEP", name: "Mound City Group",
            question: "How many mounds can be counted inside the enclosure, and does the count match the published plan?",
            box: ["-83.0096", "39.3730", "-83.0032", "39.3782"]),
        StartingPoint(
            id: "moundville", kind: .learn, title: "Moundville", place: "Alabama, United States",
            about: "Mississippian platform mounds set around a plaza, beside steep natural ravines. Built and natural shapes side by side.",
            source: "USGS 3DEP", name: "Moundville",
            question: "Which raised features around the plaza are platform mounds, and which are natural?",
            box: ["-87.6350", "33.0040", "-87.6270", "33.0110"]),
        StartingPoint(
            id: "etowah", kind: .learn, title: "Etowah Mounds", place: "Georgia, United States",
            about: "Three platform mounds beside a river. The lidar here is sparser, so it shows what thin ground data looks like.",
            source: "USGS 3DEP", name: "Etowah Mounds",
            question: "What can be read from sparse ground returns at Etowah, and what cannot?",
            box: ["-84.8114", "34.1222", "-84.8046", "34.1278"]),
        StartingPoint(
            id: "poverty-point", kind: .learn, title: "Poverty Point", place: "Louisiana, United States",
            about: "Concentric earthen ridges and mounds more than 3,000 years old, crossed by a modern road and field lines.",
            source: "USGS 3DEP", name: "Poverty Point",
            question: "How much of the ridge system shows in the ground, and what has ploughing and the road removed?",
            box: ["-91.4115", "32.6320", "-91.4035", "32.6390"]),
        StartingPoint(
            id: "lauske", kind: .learn, title: "Lauske ring fort", place: "Saxony, Germany",
            about: "A ring fort on a wooded spur in Upper Lusatia, with two more nearby. Shows a rampart closing on itself in a 1 m ground model.",
            source: "GeoSN", name: "Lauske ring fort",
            question: "Which ramparts and ditches show around the Lauske ring fort, and what else on the spur is built?",
            box: ["14.6140", "51.1670", "14.6240", "51.1730"]),
        StartingPoint(
            id: "thunder-bay", kind: .learn, title: "Thunder Bay wreck", place: "Lake Huron, United States",
            about: "A wreck on the lake bed in a marine sanctuary, from NOAA's sonar surveys. Shows a hull and the seafloor around it.",
            source: "NOAA", name: "Thunder Bay wreck",
            question: "Which shapes on the lake bed here are wrecks or debris, and which are already charted?",
            box: ["-83.1850", "45.0627", "-83.1773", "45.0672"]),
        StartingPoint(
            id: "yucatan", kind: .search, title: "Yucatán lowlands", place: "Quintana Roo, Mexico",
            about: "A NASA G-LiHT strip over forest and limestone. A 2026 catalog lists structures detected in this data, so the work is checking each feature against it.",
            source: "OpenTopography", name: "Yucatan strip",
            question: "Which built features show in this G-LiHT strip, and which are already in the published catalog?",
            box: ["-88.9132", "19.6082", "-88.9085", "19.6128"]),
    ]

    /// One short line for each place, for the cards on Home.
    static let teaser: [String: String] = [
        "cahokia": "Monks Mound, the largest earthwork north of Mexico.",
        "newark": "A Hopewell circle 365 m across, inside a modern town.",
        "serpent-mound": "A 411 m effigy mound winding along a wooded ridge.",
        "mound-city": "Two dozen Hopewell mounds inside a low earthen wall.",
        "moundville": "Platform mounds around a plaza, beside natural ravines.",
        "etowah": "Three platform mounds by a river, in sparse lidar.",
        "poverty-point": "Earthen ridges over 3,000 years old, crossed by a road.",
        "lauske": "A ring fort on a wooded spur, its rampart closing on itself.",
        "thunder-bay": "A wreck on the bed of Lake Huron, from NOAA sonar.",
        "yucatan": "Forest over limestone, with a 2026 catalog to check against.",
    ]

    static func image(_ point: StartingPoint) -> NSImage? { image(named: point.id) }

    static func image(named id: String) -> NSImage? {
        guard let folder = Bundle.main.resourceURL?.appendingPathComponent("starts/\(id).jpg") else { return nil }
        return Images.load(folder.path)
    }
}

/// Home. A first visit shows what Dighouse is and a first search to take; after that it opens on your own work: a
/// message box, where you left off, and the finds that wait for you. Ways to start a new search follow on both.
struct HomeView: View {
    @EnvironmentObject var app: AppState
    @EnvironmentObject var store: ProjectStore
    @EnvironmentObject var engine: Engine

    private let cards = [GridItem(.adaptive(minimum: 200), spacing: 12, alignment: .top)]
    /// Three ways to start, always in one row that spans the column, like the chat box above them.
    private let paths = Array(repeating: GridItem(.flexible(minimum: 160), spacing: 12, alignment: .top), count: 3)
    /// 0 shows the known sites, 1 the open surveys, 2 the map of where open data reaches.
    @AppStorage("startTab") private var startKind = 0
    @State private var allSites = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 32) {
                CloudNotice()
                UpdateLine()
                if !app.modelReady, app.searchesFromClaude, !app.starting { claudeOnly }
                if app.offersTutorial {
                    hero.arrives()
                    // For a first visit, and for anyone part-way through: one real search, a step at a time.
                    StartTile(icon: "dig.trowel", title: app.tutorialProject == nil ? "Start your first project" : "Continue your first project",
                              text: "Ten minutes at Serpent Mound, a step at a time: get the ground, look at it, open a find, read the record and make a decision. You can leave and come back.",
                              strong: true) { app.startTutorial() }
                        .coach(.start, radius: 14)
                        .padding(.top, -8)
                        .arrives(1)
                    HowStrip().arrives(1)
                } else {
                    Desk()
                }
                ways.arrives(1)
                starts.arrives(2)
            }
            .padding(.horizontal, 32).padding(.top, 32).padding(.bottom, 48)
            .frame(maxWidth: 940, alignment: .leading).frame(maxWidth: .infinity)
        }
        .background(Theme.bg)
        .task(id: engine.ready) { await app.loadSurveys() }
    }

    /// For a person with Claude alone: where the search is asked for, and what stays off here until an account is added.
    private var claudeOnly: some View {
        HStack(alignment: .center, spacing: 14) {
            IconTile(name: "asterisk", size: 38)
            VStack(alignment: .leading, spacing: 2) {
                Text("You search from Claude Code").font(.system(size: 15 * Theme.scale, weight: .semibold))
                Text("In Terminal, run claude and ask it to use Dighouse on a place. The project appears in the sidebar, with its finds for you to decide. The chat and the searches on this page need ChatGPT or an OpenAI key.")
                    .font(.system(size: 13 * Theme.scale)).foregroundStyle(Theme.dim).lineSpacing(2).fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 8)
            Button("Add an account") { app.settingsSection = .account; app.show(.settings) }.buttonStyle(SecondaryButton())
        }
        .padding(14).panel()
    }

    private var hero: some View {
        VStack(spacing: 20) {
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .center, spacing: 24) {
                    pitch.frame(minWidth: 330, idealWidth: 330, maxWidth: .infinity, alignment: .leading)
                    reveal.frame(width: 440)
                }
                VStack(alignment: .leading, spacing: 16) {
                    pitch
                    reveal
                }
            }
            Composer()
        }
        .frame(maxWidth: .infinity)
    }

    private var pitch: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                MoundMark(lively: true).frame(width: 46, height: 20)
                Text("OPEN ARCHAEOLOGY").font(.system(size: 12.5 * Theme.scale, weight: .bold)).kerning(1.5).foregroundStyle(Theme.tan)
            }
            Text("Help find what the forest is hiding.").font(.system(size: 36 * Theme.scale, weight: .bold))
                .fixedSize(horizontal: false, vertical: true)
            Text("Dighouse searches public lidar, laser scans that see the ground through the trees, for mounds, walls and earthworks. An AI agent does the slow work and writes down every step, so you can check it.")
                .font(.system(size: 17 * Theme.scale)).foregroundStyle(Theme.text.opacity(0.78)).lineSpacing(5).fixedSize(horizontal: false, vertical: true)
            HStack(spacing: 10) {
                FindSomething()
                Button("See how it works") { app.showHow() }.buttonStyle(SecondaryButton(large: true))
            }
        }
    }

    private var reveal: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForestReveal()
            Text("Serpent Mound, Ohio, from open USGS lidar. Drag the handle to take the trees away.")
                .font(.system(size: 11.5 * Theme.scale)).foregroundStyle(Theme.faint).lineSpacing(2).fixedSize(horizontal: false, vertical: true)
        }
    }

    /// Three ways to start a search, and a project folder to open.
    private var ways: some View {
        PageSection(title: app.offersTutorial ? "" : "Start a new search") {
            LazyVGrid(columns: paths, spacing: 12) {
                StartChoice(icon: "map", title: "Pick a place",
                            text: "Click anywhere on the map with open lidar and start a search there.", tint: Theme.sky) {
                    app.startProject()
                }
                .help("Opens New project on a map that shades where open lidar reaches.")
                StartChoice(icon: "sparkle.magnifyingglass", title: "Suggest a place",
                            text: "The agent weighs open data against what is on record and proposes three searches.", tint: Theme.clay) {
                    if let flow = ToolGuide.workflows.first(where: { $0.id == "research" }) { app.preview(flow) }
                }
                .help("Shows what the agent will do, with Start.")
                StartChoice(icon: "dig.grid", title: "Test it blind",
                            text: "It searches a famous site without being told which, then gets a score.", tint: Theme.amber) {
                    app.testPicking = true
                }
                .help("Choose a site; the agent's finds are scored against the published features.")
            }
            HStack(spacing: 16) {
                // A project someone shared, or one from before: a folder, opened like any folder.
                Button("Open a project folder…") { app.chooseProjectFolder() }
                    .help("A project is a folder of Markdown records, so it opens like any folder, yours or one someone shared.")
                if !app.offersTutorial { Button("How a search works") { app.showHow() } }
            }
            .buttonStyle(.plain).font(.system(size: 12.5 * Theme.scale, weight: .medium)).foregroundStyle(Theme.tan)
        }
    }

    /// Where a search can begin: known sites to learn on, open surveys still worth searching, or anywhere on the map.
    private var starts: some View {
        PageSection(title: "Places to start",
                    caption: startKind == 0 ? "Real earthworks, a ring fort and a wreck, each with open data ready. One press sets up the project."
                        : startKind == 1 ? "Lidar flown for archaeology and published openly, from OpenTopography's live catalog."
                        : "The shaded places have open data the tools fetch with no account. Click anywhere to start a project there.") {
            Segmented(choices: [.init(value: 0, title: "Known sites"), .init(value: 1, title: "Open surveys"), .init(value: 2, title: "The map", icon: "map")],
                      pick: $startKind)
            switch startKind {
            case 0:
                // A mix first: earthworks, a ring fort in Saxony and a wreck, then the rest.
                let lead = ["cahokia", "newark", "lauske", "thunder-bay"]
                let ordered = StartingPoints.all.filter { lead.contains($0.id) } + StartingPoints.all.filter { !lead.contains($0.id) }
                let shown = allSites ? ordered : Array(ordered.prefix(4))
                LazyVGrid(columns: cards, alignment: .leading, spacing: 12) {
                    ForEach(shown) { point in StartCard(point: point, compact: true) { app.startProject(from: point) } }
                }
                Button(allSites ? "Show fewer" : "Show all \(StartingPoints.all.count) sites") {
                    withAnimation(.easeOut(duration: 0.2)) { allSites.toggle() }
                }
                .buttonStyle(SecondaryButton())
            case 1: surveys
            default: WhereItReaches()
            }
        }
    }

    @ViewBuilder private var surveys: some View {
        if app.surveysLoading {
            HStack(spacing: 8) {
                DigIndicator()
                Text("Reading the catalog").font(.system(size: 13 * Theme.scale)).foregroundStyle(Theme.dim)
            }
        } else if let problem = app.surveysProblem {
            HStack(spacing: 10) {
                Text("The catalog did not answer. \(problem)").font(.system(size: 13 * Theme.scale)).foregroundStyle(Theme.amber)
                    .fixedSize(horizontal: false, vertical: true)
                Button("Try again") { Task { await app.loadSurveys() } }.buttonStyle(SecondaryButton())
            }
        } else {
            VStack(spacing: 0) {
                ForEach(app.surveys) { survey in
                    HStack(alignment: .center, spacing: 12) {
                        IconTile(name: "dig.grid", size: 30)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(survey.title).font(.system(size: 13.5 * Theme.scale, weight: .medium)).fixedSize(horizontal: false, vertical: true)
                            Text((survey.collected.isEmpty ? "" : "Flown \(survey.collected) · ") + "OpenTopography")
                                .font(.system(size: 12 * Theme.scale)).foregroundStyle(Theme.faint)
                        }
                        Spacer(minLength: 8)
                        Button("Ask about it") {
                            app.askGeneral("Tell me about the open lidar survey \"\(survey.title)\" (\(survey.id)): where it is, what it was flown for, what has been published from it, and what a search there could add.")
                        }
                        .buttonStyle(SecondaryButton())
                        Button("Start a project") { app.startProject(from: survey) }.buttonStyle(SecondaryButton())
                    }
                    .padding(12)
                    Hairline()
                }
                Button {
                    if let flow = ToolGuide.workflows.first(where: { $0.id == "surveys" }) { app.preview(flow) }
                } label: {
                    HStack {
                        Text("See every open survey").font(.system(size: 13 * Theme.scale))
                        Spacer()
                        Image(systemName: "arrow.right").font(.system(size: 10 * Theme.scale, weight: .semibold)).foregroundStyle(Theme.faint)
                    }
                    .padding(.vertical, 4)
                }
                .buttonStyle(RowButton()).padding(4).help("Starts a chat in which the agent lists every survey in the catalog.")
            }
            .panel()
        }
    }
}

extension AppState {
    /// Open the Toolbox on its walk through one real search.
    func showHow(stage: Int? = nil) {
        if let stage { UserDefaults.standard.set(stage, forKey: "tourStage") }
        UserDefaults.standard.set(ToolboxView.Tab.how.rawValue, forKey: "toolboxPart")
        show(.toolbox)
    }
}

/// The one thing Dighouse is for, one press away: the agent picks a region and searches it for as long as you choose.
private struct FindSomething: View {
    @EnvironmentObject var app: AppState

    var body: some View {
        Button {
            if let flow = ToolGuide.workflows.first(where: { $0.id == "timed-research" }) { app.run(flow) }
        } label: { Label("Find something", systemImage: "sparkle.magnifyingglass") }
        .buttonStyle(PrimaryButton(large: true))
        .help("The agent picks a region with open lidar and little on record, searches it on its own for as long as you choose, and brings back what needs your decision.")
    }
}

/// How a search goes, in three steps. Each opens the walk through a real search at that step.
private struct HowStrip: View {
    @EnvironmentObject var app: AppState

    private let steps: [(icon: String, title: String, text: String, stage: Int)] = [
        ("dig.grid", "It searches", "The agent fetches open lidar, takes the trees away and looks at every tile of ground.", 2),
        ("dig.layers", "It checks", "Each find gets a slice, a second model's opinion, open maps and what is published.", 3),
        ("dig.brush", "You decide", "Every step is kept in a folder you can read. Nothing is called a site until you say so.", 5),
    ]

    var body: some View {
        PageSection(title: "How it works", caption: "A small area takes 5 to 15 minutes. Press a step to see it in a real search.") {
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(minimum: 160), spacing: 12, alignment: .top), count: 3), spacing: 12) {
                ForEach(Array(steps.enumerated()), id: \.offset) { index, step in
                    Button { app.showHow(stage: step.stage) } label: {
                        VStack(alignment: .leading, spacing: 10) {
                            HStack(spacing: 10) {
                                IconTile(name: step.icon, size: 34, tint: [Theme.green, Theme.amber, Theme.tan][index % 3])
                                Text("\(index + 1). \(step.title)").font(.system(size: 14.5 * Theme.scale, weight: .semibold))
                            }
                            Text(step.text).font(.system(size: 12.5 * Theme.scale)).foregroundStyle(Theme.dim).lineSpacing(2)
                                .multilineTextAlignment(.leading).fixedSize(horizontal: false, vertical: true)
                        }
                        .padding(16).frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    }
                    .buttonStyle(SurfaceButton())
                }
            }
        }
    }
}

/// Where a search can go, on a map that starts a project wherever it is clicked.
private struct WhereItReaches: View {
    @EnvironmentObject var app: AppState
    /// Where the person's own projects have searched, so a new search can go elsewhere.
    @State private var searched: [[Double]] = []

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            CoverageMap(surveys: app.surveys.map(\.box), searched: searched)
            // What each colour is, in a row; pointing at one says more.
            Flow(spacing: 6) {
                if !searched.isEmpty {
                    legend(.ring, "You have searched", "\(searched.count) area\(searched.count == 1 ? "" : "s") in your projects. Only this Mac shows them.")
                }
                legend(.dot(Theme.tan), "The United States", "Raw laser points from USGS 3DEP.")
                legend(.dot(Theme.green), "\(Reach.national.count) national ground models",
                       Reach.national.map { $0.name.replacingOccurrences(of: ", Spain", with: " (Spain)") }.joined(separator: ", ") + ", and Denmark with a free token.")
                legend(.dot(Theme.amber), "Surveys for archaeology", "Flown for archaeology and published on OpenTopography.")
                legend(.dot(Theme.water), "Sonar, the seafloor", "NOAA's surveys of US waters and the Great Lakes, and INFOMAR's of Irish waters, for wrecks.")
                legend(.icon("plus.circle"), "Your own data", "Anywhere else, give the agent your own ground model or point cloud, and it searches that.")
            }
            Button("Data sources and their status") {
                UserDefaults.standard.set(ToolboxView.Tab.data.rawValue, forKey: "toolboxPart")
                app.show(.toolbox)
            }
            .buttonStyle(SecondaryButton())
        }
        .padding(16).frame(maxWidth: .infinity, alignment: .leading)
        .panel()
        .task(id: app.store.projects.count) {
            let roots = app.store.projects.map(\.path)
            searched = await Task.detached { ProjectStore.searchedBoxes(roots) }.value
        }
    }

    private enum Mark { case dot(Color), icon(String), ring }

    /// One entry of the legend: a dot in the map's colour for a layer drawn on it, an icon for one that is not.
    private func legend(_ mark: Mark, _ title: String, _ text: String) -> some View {
        HStack(spacing: 6) {
            Group {
                switch mark {
                case .dot(let color): Circle().fill(color).frame(width: 9, height: 9)
                case .icon(let name): Image(systemName: name).font(.system(size: 10.5 * Theme.scale, weight: .semibold)).foregroundStyle(Theme.dim)
                case .ring: Circle().strokeBorder(.white.opacity(0.9), lineWidth: 1.6).frame(width: 9, height: 9)
                }
            }
            Text(title).font(.system(size: 12 * Theme.scale, weight: .medium)).foregroundStyle(Theme.dim)
        }
        .padding(.horizontal, 10).frame(height: 26)
        .background(Capsule().fill(Theme.ink.opacity(0.05)))
        .help(text)
        .accessibilityElement().accessibilityLabel("\(title). \(text)")
    }
}

/// For someone coming back: a greeting, the message box, the projects they last worked in, and the finds that wait.
private struct Desk: View {
    @EnvironmentObject var app: AppState
    @EnvironmentObject var store: ProjectStore
    /// The last reading, kept while the app runs: Home shows it at once when you come back to it, and the page does not
    /// jump as 80 project folders are read again (EASE_LOOP E3).
    @MainActor private static var last = Reading()
    private struct Reading {
        var totals = ""
        var recents: [(ref: ProjectRef, standing: String)] = []
        var session: (text: String, foot: String)?
        var inbox: [(ref: ProjectRef, needs: Int, agree: Int)] = []
        var leads: [(ref: ProjectRef, lead: ProjectStore.Lead)] = []
    }
    @State private var totals = Desk.last.totals
    /// The projects worked in last, newest first, each with where it stands.
    @State private var recents: [(ref: ProjectRef, standing: String)] = Desk.last.recents
    @State private var session: (text: String, foot: String)? = Desk.last.session
    /// Projects with finds that wait for a person, most first: the inbox across projects.
    @State private var inbox: [(ref: ProjectRef, needs: Int, agree: Int)] = Desk.last.inbox
    /// The strongest finds that wait for a person, across projects: where to spend ten minutes.
    @State private var leads: [(ref: ProjectRef, lead: ProjectStore.Lead)] = Desk.last.leads
    /// 0 lists the strongest leads, 1 the projects with finds waiting.
    @AppStorage("homeWaiting") private var waitingKind = 0

    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        let part = (5..<12).contains(hour) ? "Good morning" : (12..<18).contains(hour) ? "Good afternoon" : "Good evening"
        return app.firstName.isEmpty ? part + "." : "\(part), \(app.firstName)."
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .center, spacing: 16) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(greeting).font(.system(size: 28 * Theme.scale, weight: .bold)).fixedSize(horizontal: false, vertical: true)
                        if !totals.isEmpty { Text(totals).font(.system(size: 13 * Theme.scale)).foregroundStyle(Theme.dim) }
                    }
                    Spacer(minLength: 12)
                    FindSomething()
                }
                if let session {
                    PathCard(icon: "clock", title: "Searching on its own", text: session.text, foot: session.foot) { app.showTimedSession() }
                        .help("Open the session's chat")
                }
                Composer()
            }
            .arrives()
            if !recents.isEmpty {
                PageSection(title: "Where you left off") {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(minimum: 160), spacing: 12, alignment: .top), count: min(recents.count, 3)), spacing: 12) {
                        ForEach(recents, id: \.ref.path) { row in
                            Button { app.open(row.ref) } label: {
                                HStack(alignment: .center, spacing: 12) {
                                    IconTile(name: "dig.trowel", size: 34)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(row.ref.name).font(.system(size: 13.5 * Theme.scale, weight: .semibold))
                                            .multilineTextAlignment(.leading).fixedSize(horizontal: false, vertical: true)
                                        Text(row.standing).font(.system(size: 12.5 * Theme.scale)).foregroundStyle(Theme.dim)
                                            .multilineTextAlignment(.leading).fixedSize(horizontal: false, vertical: true)
                                    }
                                    Spacer(minLength: 0)
                                }
                                .padding(14).frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
                            }
                            .buttonStyle(SurfaceButton()).help("Open \(row.ref.name)")
                        }
                    }
                }
                .arrives(1)
            }
            if !leads.isEmpty || !inbox.isEmpty { waiting.arrives(1) }
        }
        .frame(maxWidth: .infinity)
        // The folders are read off the main thread: a project kept in iCloud can take a long time to answer.
        .task(id: store.projects.map(\.path)) {
            // Read again every half minute, so a session's progress moves while Home is showing.
            while !Task.isCancelled {
                await read()
                try? await Task.sleep(for: .seconds(30))
            }
        }
    }

    /// The finds that wait for a person: the strongest across every project as pictures, or the projects that hold them.
    private var waiting: some View {
        // With only one of the two to show, there is nothing to switch between.
        let both = !leads.isEmpty && !inbox.isEmpty
        let byProject = leads.isEmpty || (both && waitingKind == 1)
        return VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Waiting for you").font(.system(size: 16 * Theme.scale, weight: .semibold))
                    Text(byProject ? "Projects with finds to decide, most first." : "The finds most checks agree on, from every project. Press one to decide it.")
                        .font(.system(size: 13 * Theme.scale)).foregroundStyle(Theme.dim).fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 8)
                if both {
                    Segmented(choices: [.init(value: 0, title: "Strongest leads"), .init(value: 1, title: "By project")], pick: $waitingKind, compact: true)
                }
            }
            if byProject {
                VStack(spacing: 0) {
                    ForEach(Array(inbox.prefix(5).enumerated()), id: \.element.ref.path) { i, row in
                        if i > 0 { Hairline() }
                        HStack(spacing: 10) {
                            Text(row.ref.name).font(.system(size: 13 * Theme.scale, weight: .medium)).lineLimit(1)
                            Spacer(minLength: 8)
                            Text([row.needs > 0 ? "\(row.needs) need\(row.needs == 1 ? "s" : "") you" : nil, row.agree > 0 ? "\(row.agree) to agree with" : nil]
                                .compactMap { $0 }.joined(separator: " · "))
                                .font(.system(size: 12.5 * Theme.scale)).foregroundStyle(Theme.dim)
                            Button("Decide") { app.decide(in: row.ref) }
                            .buttonStyle(SecondaryButton())
                        }
                        .padding(.horizontal, 14).padding(.vertical, 8)
                    }
                }
                .panel()
                if inbox.count > 5 {
                    Text("\(inbox.count - 5) more project\(inbox.count - 5 == 1 ? "" : "s") with finds waiting, in the sidebar.")
                        .font(.system(size: 12 * Theme.scale)).foregroundStyle(Theme.faint)
                }
            } else {
                // Five across when there is room, three when the window is narrow.
                ViewThatFits(in: .horizontal) {
                    leadRow(leads)
                    leadRow(Array(leads.prefix(3)))
                }
            }
        }
    }

    private func leadRow(_ rows: [(ref: ProjectRef, lead: ProjectStore.Lead)]) -> some View {
        HStack(alignment: .top, spacing: 12) {
            ForEach(rows, id: \.lead) { row in
                LeadCard(ref: row.ref, lead: row.lead) { app.decide(in: row.ref, on: row.lead.id, limit: AppState.shortSession) }
                    .frame(minWidth: 150, idealWidth: 150, maxWidth: .infinity)
            }
        }
        .fixedSize(horizontal: false, vertical: true)
    }

    /// What a running timed session has done so far: the areas it fetched since it started, their size and finds.
    private func readSession() async -> (text: String, foot: String)? {
        guard let thread = UserDefaults.standard.string(forKey: "timedThread"), let status = app.chat.timed.status(for: thread) else { return nil }
        let start = Date(timeIntervalSince1970: UserDefaults.standard.double(forKey: "timedStart"))
        let refs = store.projects
        let (areas, km2, finds) = await Task.detached { () -> (Int, Double, Int) in
            var areas = 0, km2 = 0.0, finds = 0
            for ref in refs where (FileInfo.modified(ref.path + "/private/state/terrains.json") ?? .distantPast) >= start {
                let terrains = (FileManager.default.contents(atPath: ref.path + "/private/state/terrains.json")
                    .flatMap { try? JSONSerialization.jsonObject(with: $0) } as? [String: JSON]) ?? [:]
                areas += 1
                km2 += terrains.values.compactMap { $0["area_km2"] as? Double }.reduce(0, +)
                finds += ProjectStore.glance(ref.path).finds
            }
            return (areas, km2, finds)
        }.value
        let ends = status.components(separatedBy: " · ").last ?? status
        return (areas == 0 ? "Choosing the first area." : "\(areas) area\(areas == 1 ? "" : "s"), \(String(format: "%.1f", km2)) square km, \(finds) find\(finds == 1 ? "" : "s") so far.",
                ends.hasSuffix(".") ? ends : ends + ".")
    }

    /// The strongest leads across projects: most agreement first, then in the order of the projects, at most two from
    /// one project and five in all.
    nonisolated static func strongest(_ refs: [ProjectRef], _ all: [ProjectStore.Glance], skipping blind: Set<String>)
        -> [(ref: ProjectRef, lead: ProjectStore.Lead)] {
        var rows: [(ref: ProjectRef, lead: ProjectStore.Lead, order: Int)] = []
        for (ref, glance) in zip(refs, all) where !blind.contains(ref.path) {
            for lead in glance.leads { rows.append((ref, lead, rows.count)) }
        }
        rows.sort { a, b in a.lead.agreement != b.lead.agreement ? a.lead.agreement > b.lead.agreement : a.order < b.order }
        var perProject: [String: Int] = [:]
        var out: [(ref: ProjectRef, lead: ProjectStore.Lead)] = []
        for row in rows where out.count < 5 {
            perProject[row.ref.path, default: 0] += 1
            if perProject[row.ref.path]! <= 2 { out.append((row.ref, row.lead)) }
        }
        return out
    }

    /// Where a project stands, in a few words, from its counts and whether it is a blind test.
    nonisolated static func standing(_ it: ProjectStore.Glance, root: String) -> String {
        func count(_ n: Int, _ word: String) -> String { "\(n.formatted()) \(word)\(n == 1 ? "" : "s")" }
        let test = FileManager.default.fileExists(atPath: root + "/private/state/test.json")
        let scored = FileManager.default.fileExists(atPath: root + "/private/state/score.json")
        return test && scored ? "Its blind test is scored"
            : it.tiles == 0 && it.finds == 0 ? "Its search has not started"
            : it.unscreened > 0 ? "\(count(it.unscreened, "tile")) still to look at"
            : test ? "Its blind test is not scored yet"
            : it.needsYou > 0 ? "\(count(it.needsYou, "find")) \(it.needsYou == 1 ? "needs" : "need") you" + (it.toAgree > 0 ? ", \(it.toAgree.formatted()) to agree with" : "")
            : it.toAgree > 0 ? "\(count(it.toAgree, "find")) to agree with"
            : it.finds == 0 ? "Every tile looked at, nothing marked"
            : "Every find is decided"
    }

    private func read() async {
        let began = Date()
        defer { Perf.log("Home read \(store.projects.count) projects in \(Int(Date().timeIntervalSince(began) * 1000)) ms") }
        session = await readSession()
        let refs = store.projects
        let file = ProjectStore.glanceFile
        let found: ([(ref: ProjectRef, standing: String)], [ProjectStore.Glance])? = await Task.detached {
            func written(_ ref: ProjectRef) -> Date {
                ["/RESEARCH.md", "/PROJECT.md"].lazy.compactMap { FileInfo.modified(ref.path + $0) }.first ?? .distantPast
            }
            guard !refs.isEmpty else { return nil }
            let all = ProjectStore.glances(refs.map(\.path), keptIn: file)
            // The three projects whose records changed last.
            let newest = zip(refs, all).map { (ref: $0.0, glance: $0.1, at: written($0.0)) }.sorted { $0.at > $1.at }.prefix(3)
            return (newest.map { (ref: $0.ref, standing: Desk.standing($0.glance, root: $0.ref.path)) }, all)
        }.value
        guard let (newest, all) = found else { recents = []; inbox = []; leads = []; return }
        let blind = Set(store.blindTests)
        inbox = zip(refs, all).filter { !blind.contains($0.0.path) && $0.1.needsYou + $0.1.toAgree > 0 }
            .map { (ref: $0.0, needs: $0.1.needsYou, agree: $0.1.toAgree) }
            .sorted { $0.needs * 10 + $0.agree > $1.needs * 10 + $1.agree }
        leads = Self.strongest(refs, all, skipping: blind)
        recents = newest
        func count(_ n: Int, _ word: String) -> String { "\(n.formatted()) \(word)\(n == 1 ? "" : "s")" }
        let finds = all.reduce(0) { $0 + $1.finds }
        let decided = finds - all.reduce(0) { $0 + $1.undecided }
        totals = "\(count(all.count, "project")) · \(count(finds, "find")) · \(decided.formatted()) decided"
        Self.last = Reading(totals: totals, recents: recents, session: session, inbox: inbox, leads: leads)
    }
}

/// One of the strongest leads, as a picture of its ground with its rank: a press opens Decide on it.
private struct LeadCard: View {
    let ref: ProjectRef
    let lead: ProjectStore.Lead
    let action: () -> Void
    @State private var hover = false
    @State private var picture: NSImage?

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 0) {
                Theme.ink.opacity(0.04).aspectRatio(4 / 3, contentMode: .fit)
                    .overlay {
                        if let picture {
                            Image(nsImage: picture).resizable().aspectRatio(contentMode: .fill).scaleEffect(hover ? 1.04 : 1)
                        } else {
                            Glyph(name: "dig.mound", size: 22 * Theme.scale).foregroundStyle(Theme.faint)
                        }
                    }
                    .clipped()
                    .overlay(alignment: .topLeading) {
                        Text(lead.rank).font(.system(size: 11 * Theme.scale, weight: .bold)).foregroundStyle(.black)
                            .frame(width: 20, height: 20).background(Circle().fill(lead.agreement >= 3 ? Theme.green : Theme.tan))
                            .padding(8)
                    }
                VStack(alignment: .leading, spacing: 2) {
                    Text(lead.name.replacingOccurrences(of: "Seen in bulk: ", with: "")).font(.system(size: 13 * Theme.scale, weight: .medium))
                        .multilineTextAlignment(.leading).lineLimit(3).fixedSize(horizontal: false, vertical: true)
                    Text("\(lead.id) · \(ref.name)").font(.system(size: 12 * Theme.scale)).foregroundStyle(Theme.dim)
                        .multilineTextAlignment(.leading).lineLimit(2).fixedSize(horizontal: false, vertical: true)
                }
                .padding(10)
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .surface(hover: hover)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help("Rank \(lead.rank): \(lead.agreement) of 3 checks say built. Opens Decide on \(ref.name)'s strongest \(AppState.shortSession).")
        .onHover { hover = $0 }
        .animation(.easeOut(duration: 0.12), value: hover)
        .task(id: lead) {
            let (root, lead) = (ref.path, lead)
            picture = await Task.detached { Self.picture(of: lead, in: root) }.value
        }
    }

    /// The find's own picture, cut to the ground around it where its place on the tile is known.
    nonisolated private static func picture(of lead: ProjectStore.Lead, in root: String) -> NSImage? {
        let base = "\(root)/candidates/img/\(lead.id)-relief"
        guard let path = [base + ".jpg", base + ".png"].first(where: { FileManager.default.fileExists(atPath: $0) }) else { return nil }
        if let x = lead.x, let y = lead.y, let cut = Images.crop(path, x: x, y: y, side: 0.5) { return cut }
        return Images.load(path)
    }
}

/// One of the ways in from Home.
private struct PathCard: View {
    let icon: String, title: String, text: String
    var foot = ""
    let action: () -> Void
    @State private var hover = false

    var body: some View {
        Button(action: action) {
            HStack(alignment: .top, spacing: 14) {
                IconTile(name: icon, size: 38)
                VStack(alignment: .leading, spacing: 4) {
                    Text(title).font(.system(size: 15 * Theme.scale, weight: .semibold))
                    Text(text).font(.system(size: 12.5 * Theme.scale)).foregroundStyle(Theme.dim).lineSpacing(2)
                        .multilineTextAlignment(.leading).fixedSize(horizontal: false, vertical: true)
                    if !foot.isEmpty {
                        Text(foot).font(.system(size: 12 * Theme.scale)).foregroundStyle(Theme.faint).padding(.top, 2)
                    }
                }
                Spacer(minLength: 0)
                Image(systemName: "arrow.right").font(.system(size: 12 * Theme.scale, weight: .semibold)).foregroundStyle(hover ? Theme.text : Theme.faint)
                    .offset(x: hover ? 3 : 0)
            }
            .padding(16).frame(maxWidth: .infinity, minHeight: 84, alignment: .topLeading)
            .surface(hover: hover)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hover = $0 }
        .animation(.easeOut(duration: 0.12), value: hover)
    }
}

/// A place to begin, with a picture of its bare ground.
/// One of the four ways in on Home: an icon, a short title and one line on what happens.
private struct StartChoice: View {
    let icon: String, title: String, text: String
    var tint: Color = Theme.tan
    let action: () -> Void
    @State private var hover = false

    var body: some View {
        Button(action: action) {
            HStack(alignment: .top, spacing: 12) {
                IconTile(name: icon, size: 34, tint: tint)
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(title).font(.system(size: 14.5 * Theme.scale, weight: .semibold))
                        Image(systemName: "arrow.right").font(.system(size: 11 * Theme.scale, weight: .semibold))
                            .foregroundStyle(hover ? tint : Theme.faint).offset(x: hover ? 3 : 0)
                    }
                    Text(text).font(.system(size: 12.5 * Theme.scale)).foregroundStyle(Theme.dim).lineSpacing(2)
                        .multilineTextAlignment(.leading).fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
            }
            .padding(16).frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(LinearGradient(colors: [tint.opacity(hover ? 0.2 : 0.1), tint.opacity(0.01)], startPoint: .topLeading, endPoint: .bottomTrailing)))
            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(tint.opacity(hover ? 0.75 : 0.24)))
            .surface(hover: hover)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hover = $0 }
        .animation(.easeOut(duration: 0.12), value: hover)
    }
}

struct StartCard: View {
    let point: StartingPoint
    /// Four to a row on Home: a shorter picture and the description in three lines.
    var compact = false
    let action: () -> Void
    @State private var hover = false

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 0) {
                ZStack(alignment: .topTrailing) {
                    Theme.ink.opacity(0.04).aspectRatio(compact ? 3 / 2 : 16 / 9, contentMode: .fit)
                        .overlay {
                            if let image = StartingPoints.image(point) {
                                Image(nsImage: image).resizable().aspectRatio(contentMode: .fill).scaleEffect(hover ? 1.04 : 1)
                            }
                        }
                        .clipped()
                    if !point.source.isEmpty {
                        Text(point.source).font(.system(size: 11 * Theme.scale, weight: .medium)).foregroundStyle(.white)
                            .padding(.horizontal, 8).frame(height: 20)
                            .background(Capsule().fill(.black.opacity(0.62))).padding(8)
                    }
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text(point.title).font(.system(size: 14.5 * Theme.scale, weight: .semibold))
                    Text(point.place).font(.system(size: 12 * Theme.scale)).foregroundStyle(Theme.faint)
                    Text(compact ? StartingPoints.teaser[point.id] ?? point.about : point.about).font(.system(size: 12.5 * Theme.scale)).foregroundStyle(Theme.dim).lineSpacing(2)
                        .multilineTextAlignment(.leading).fixedSize(horizontal: false, vertical: true).padding(.top, 2)
                }
                .padding(compact ? 12 : 14)
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, minHeight: compact ? 0 : 270, alignment: .topLeading)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .surface(hover: hover)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(compact ? point.about : "")
        .onHover { hover = $0 }
        .animation(.easeOut(duration: 0.12), value: hover)
    }
}

/// Projects kept in iCloud make Dighouse freeze: their files go offline, and every read waits for a download.
/// This offers to move them to this Mac, once, and shows how far the move has got.
struct CloudNotice: View {
    @EnvironmentObject var store: ProjectStore
    @EnvironmentObject var chat: ChatModel

    var body: some View {
        let count = store.cloudProjects.count
        if count > 0 || store.moving != nil || store.moveProblem != nil {
            HStack(alignment: .top, spacing: 14) {
                Image(systemName: "icloud.slash").font(.system(size: 18 * Theme.scale)).foregroundStyle(Theme.amber).padding(.top, 2)
                VStack(alignment: .leading, spacing: 6) {
                    if let moving = store.moving {
                        Text("Moving \(moving.name), \(moving.done + 1) of \(moving.of)").font(.system(size: 14 * Theme.scale, weight: .semibold))
                        Text("iCloud is downloading the files that were offline. This can take a few minutes for each project. You can keep using Dighouse.")
                            .font(.system(size: 12.5 * Theme.scale)).foregroundStyle(Theme.dim).fixedSize(horizontal: false, vertical: true)
                        ProgressView(value: Double(moving.done), total: Double(max(moving.of, 1))).tint(Theme.green)
                    } else if count > 0 {
                        Text("\(count) project\(count == 1 ? " is" : "s are") in iCloud").font(.system(size: 14 * Theme.scale, weight: .semibold))
                        Text("iCloud keeps their files offline, and Dighouse freezes while it waits for them to download. Move them to \(Paths.localProjectsHome.path.tildePath) on this Mac; the originals go to the Trash once each copy is checked.")
                            .font(.system(size: 12.5 * Theme.scale)).foregroundStyle(Theme.dim).fixedSize(horizontal: false, vertical: true)
                    }
                    if let problem = store.moveProblem {
                        Text(problem).font(.system(size: 12.5 * Theme.scale)).foregroundStyle(Theme.amber).fixedSize(horizontal: false, vertical: true)
                    }
                }
                Spacer(minLength: 0)
                if store.moving == nil, count > 0 {
                    Button("Move to this Mac") { Task { await store.moveOutOfCloud() } }
                        .buttonStyle(PrimaryButton()).disabled(chat.running)
                        .help(chat.running ? "Wait until the agent finishes its run." : "Copy each project to this Mac, check it, then put the original in the Trash.")
                }
            }
            .padding(16).panel()
        }
    }
}

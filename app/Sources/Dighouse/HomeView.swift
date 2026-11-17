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

    static func image(_ point: StartingPoint) -> NSImage? { image(named: point.id) }

    static func image(named id: String) -> NSImage? {
        guard let folder = Bundle.main.resourceURL?.appendingPathComponent("starts/\(id).jpg") else { return nil }
        return Images.load(folder.path)
    }
}

/// Home: a message box, two ways in, and places where a search can begin today.
struct HomeView: View {
    @EnvironmentObject var app: AppState
    @EnvironmentObject var store: ProjectStore
    @EnvironmentObject var engine: Engine

    private let cards = [GridItem(.adaptive(minimum: 230), spacing: 12, alignment: .top)]
    private let paths = [GridItem(.adaptive(minimum: 300), spacing: 12, alignment: .top)]
    @AppStorage("startKind") private var startKind = 0

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 30) {
                CloudNotice()
                if !app.offersTutorial { WelcomeBack().padding(.bottom, -8) }
                hero.arrives()
                if app.offersTutorial {
                    // For a first visit, and for anyone part-way through: one real search, a step at a time.
                    StartTile(icon: "dig.trowel", title: app.tutorialProject == nil ? "Start your first project" : "Continue your first project",
                              text: "Ten minutes at Serpent Mound, a step at a time: get the ground, look at it, open a find, read the record and make a decision. You can leave and come back.",
                              strong: true) { app.startTutorial() }
                        .coach(.start, radius: 14)
                        .padding(.top, -8)
                        .arrives(1)
                }
                LazyVGrid(columns: paths, spacing: 12) {
                    PathCard(icon: "sparkle.magnifyingglass", title: "What should I research?",
                             text: "New to this? The agent reads the open archives and proposes three searches worth doing.") {
                        if let flow = ToolGuide.workflows.first(where: { $0.id == "research" }) { app.run(flow) }
                    }
                    PathCard(icon: "mappin.and.ellipse", title: "I know where to look",
                             text: "Pick an area on the map, see which open lidar covers it, and start the project.") {
                        app.startProject()
                    }
                    PathCard(icon: "dig.grid", title: "Test it on a known site",
                             text: "The agent looks at a famous site without being told which, then is scored against what is published.") {
                        app.testPicking = true
                    }
                }
                .padding(.top, -8)
                .arrives(1)
                HowItWorks().arrives(2)
                CompareBoard().arrives(2)
                starts.arrives(3)
            }
            .padding(.horizontal, 32).padding(.top, 34).padding(.bottom, 40)
            .frame(maxWidth: 940, alignment: .leading).frame(maxWidth: .infinity)
        }
        .background(Theme.bg)
        .task(id: engine.ready) { await app.loadSurveys() }
    }

    private var hero: some View {
        VStack(spacing: 20) {
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .center, spacing: 28) {
                    pitch.frame(minWidth: 330, idealWidth: 330, maxWidth: .infinity, alignment: .leading)
                    reveal.frame(width: 440)
                }
                VStack(alignment: .leading, spacing: 18) {
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
            Text("Dighouse is a free, open tool for searching public lidar, the laser scans that map the ground under the trees, for places people built. AI agents do the patient work and check every find. You decide what each one is.")
                .font(.system(size: 17 * Theme.scale)).foregroundStyle(Theme.text.opacity(0.78)).lineSpacing(5).fixedSize(horizontal: false, vertical: true)
            Button("See how it works") { app.show(.toolbox) }.buttonStyle(SecondaryButton()).padding(.top, 2)
        }
    }

    private var reveal: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForestReveal()
            Text("Serpent Mound, Ohio, from open USGS lidar. Drag the handle to take the trees away.")
                .font(.system(size: 11.5 * Theme.scale)).foregroundStyle(Theme.faint).lineSpacing(2).fixedSize(horizontal: false, vertical: true)
        }
    }

    /// Where a first project can begin: surveys that are still worth searching, or known sites to learn on.
    private var starts: some View {
        PageSection(title: "Places to start") {
            HStack(spacing: 4) {
                HStack(spacing: 2) {
                    startTab(0, "Open surveys to search")
                    startTab(1, "Known sites to learn on")
                }
                .padding(3)
                .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Theme.ink.opacity(0.06)))
                .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).strokeBorder(Theme.ink.opacity(0.1)))
                Spacer()
                Button { app.chooseProjectFolder() } label: { Label("Open a project folder…", systemImage: "folder") }
                    .buttonStyle(SecondaryButton())
                    .help("Someone shared a project with you? A project is a folder of Markdown records, so it opens like any folder.")
            }
            if startKind == 0 {
                Text("Lidar flown for archaeology and published openly, read from OpenTopography's live catalog. Dighouse fetched each one and built its bare ground first.")
                    .font(.system(size: 12.5 * Theme.scale)).foregroundStyle(Theme.dim).lineSpacing(2).fixedSize(horizontal: false, vertical: true)
                surveys
            } else {
                Text("Nine published sites, one of them a wreck on a lake bed, and one strip of Yucatán forest, each with open data ready to fetch. A run on a known site shows what real earthworks look like, and whether the agents find them again.")
                    .font(.system(size: 12.5 * Theme.scale)).foregroundStyle(Theme.dim).lineSpacing(2).fixedSize(horizontal: false, vertical: true)
                LazyVGrid(columns: cards, alignment: .leading, spacing: 12) {
                    ForEach(StartingPoints.all) { point in StartCard(point: point) { app.startProject(from: point) } }
                }
            }
        }
    }

    private func startTab(_ kind: Int, _ title: String) -> some View {
        // Two sides of one switch: the chosen side is raised, the other is plain text that changes on hover.
        Button { withAnimation(.easeOut(duration: 0.15)) { startKind = kind } } label: {
            Text(title).font(.system(size: 13 * Theme.scale, weight: startKind == kind ? .semibold : .medium))
                .foregroundStyle(startKind == kind ? Theme.text : Theme.dim)
                .padding(.horizontal, 14).frame(height: 28)
                .background(RoundedRectangle(cornerRadius: 7, style: .continuous).fill(startKind == kind ? Theme.raised : .clear)
                    .shadow(color: .black.opacity(startKind == kind ? 0.3 : 0), radius: 2, y: 1))
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(startKind == kind ? .isSelected : [])
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
                        VStack(alignment: .leading, spacing: 3) {
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
                    if let flow = ToolGuide.workflows.first(where: { $0.id == "surveys" }) { app.run(flow) }
                } label: {
                    HStack {
                        Text("See every open survey").font(.system(size: 13 * Theme.scale))
                        Spacer()
                        Image(systemName: "arrow.right").font(.system(size: 10 * Theme.scale, weight: .semibold)).foregroundStyle(Theme.faint)
                    }
                    .padding(.vertical, 5)
                }
                .buttonStyle(RowButton()).padding(4).help("Starts a chat in which the agent lists every survey in the catalog.")
            }
            .panel()
        }
    }
}

/// How Dighouse works, for someone deciding whether to trust it: how a search runs on its own, what it writes down,
/// and where it can look.
private struct HowItWorks: View {
    @EnvironmentObject var app: AppState
    @State private var picked = 0

    private let tabs = [("It searches on its own", "dig.trowel"), ("It writes everything down", "dig.brush"), ("Where it can look", "globe")]

    var body: some View {
        PageSection(title: "How it works", caption: "Ask for a search and leave it. Everything it does is kept in a folder you can read, check and share.") {
            VStack(alignment: .leading, spacing: 0) {
                Flow(spacing: 6) {
                    ForEach(tabs.indices, id: \.self) { i in
                        Button { withAnimation(.easeOut(duration: 0.15)) { picked = i } } label: {
                            Label(tabs[i].0, glyph: tabs[i].1).font(.system(size: 12.5 * Theme.scale, weight: .medium))
                                .foregroundStyle(picked == i ? .black : Theme.dim)
                                .padding(.horizontal, 12).frame(height: 30)
                                .background(Capsule().fill(picked == i ? Theme.tan : Theme.ink.opacity(0.06)))
                                .contentShape(Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(14)
                Hairline()
                Group {
                    switch picked {
                    case 0: alone
                    case 1: record
                    default: reach
                    }
                }
                .padding(16).frame(maxWidth: .infinity, alignment: .leading)
            }
            .panel()
        }
    }

    private func line(_ text: String, strong: Bool = false) -> some View {
        Text(text).font(.system(size: (strong ? 15 : 13.5) * Theme.scale, weight: strong ? .medium : .regular))
            .foregroundStyle(strong ? Theme.text : Theme.dim).lineSpacing(3).fixedSize(horizontal: false, vertical: true)
    }

    private var alone: some View {
        VStack(alignment: .leading, spacing: 14) {
            line("Type a place, or ask “Search Fort Ancient for anything built.” Press Find and report back, or say yes to the card the agent offers.", strong: true)
            Flow(spacing: 6) {
                ForEach(Array(ToolGuide.stages.enumerated()), id: \.offset) { i, stage in
                    HStack(spacing: 6) {
                        Glyph(name: stage.icon, size: 12.5 * Theme.scale).foregroundStyle(Theme.tan)
                        Text(stage.title).font(.system(size: 12.5 * Theme.scale))
                        if i < ToolGuide.stages.count - 1 {
                            Image(systemName: "chevron.right").font(.system(size: 9 * Theme.scale, weight: .semibold)).foregroundStyle(Theme.faint)
                        }
                    }
                    .padding(.horizontal, 10).frame(height: 28)
                    .background(Capsule().fill(Theme.ink.opacity(0.05)))
                }
            }
            line("It runs as a goal: the agent takes turn after turn until the report is written, about 5 to 15 minutes for a small area. A bar at the top of the chat shows it, with Stop.")
            line("Then a model from a different maker gives each find a second opinion. What each find is stays your decision.")
        }
    }

    private let layout: [(String, String)] = [
        ("PROJECT.md", "the question, why this area, and how the folder is kept"),
        ("METHODOLOGY.md", "how searches are done here, and lessons learned"),
        ("RESEARCH.md", "every tile looked at, every find and its checks, every source, what is left"),
        ("candidates/", "a page for each find, with its pictures and decision"),
        ("notes/", "every step, dated, and a summary of each run"),
        ("sources/", "every source, read or could not be opened"),
        ("reports/", "the search report, and drafts only you send"),
        ("private/, data/", "locations and downloads, which never leave this Mac"),
    ]

    private var record: some View {
        VStack(alignment: .leading, spacing: 14) {
            line("Each project is its own folder and git repository, in ~/Dighouse. A person or an agent can open it and carry on without asking what was done.", strong: true)
            VStack(alignment: .leading, spacing: 5) {
                ForEach(layout, id: \.0) { item in
                    HStack(alignment: .firstTextBaseline, spacing: 12) {
                        Text(item.0).font(.system(size: 12.5 * Theme.scale, design: .monospaced)).foregroundStyle(Theme.tan).frame(width: 130, alignment: .leading)
                        Text(item.1).font(.system(size: 13 * Theme.scale)).foregroundStyle(Theme.dim).fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            .padding(12).frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 10).fill(Theme.ink.opacity(0.04)))
            VStack(alignment: .leading, spacing: 4) {
                Text("The top of a real RESEARCH.md, from a blind test at Angel Mounds").font(.system(size: 12 * Theme.scale, weight: .semibold)).foregroundStyle(Theme.faint)
                Text("“So far 9 of 9 squares of ground have been looked at, and 6 features that looked built were marked. A person has decided 0 of 6. 3 published sources were read, and 4 could not be opened.”")
                    .font(.system(size: 13 * Theme.scale)).italic().foregroundStyle(Theme.text.opacity(0.85)).lineSpacing(2).fixedSize(horizontal: false, vertical: true)
            }
            line("A search that finds nothing is still written down, so nobody looks at the same ground twice. Publish to GitHub is there when you want to share it, and only privately.")
        }
    }

    private var reach: some View {
        VStack(alignment: .leading, spacing: 12) {
            CoverageMap(surveys: app.surveys.map(\.box))
            VStack(alignment: .leading, spacing: 8) {
                legend(.dot(Theme.tan), "Lidar, the United States", "raw laser points from USGS 3DEP")
                legend(.dot(Theme.green), "Lidar, national ground models",
                       Reach.national.map { $0.name.replacingOccurrences(of: ", Spain", with: " (Spain)") }.joined(separator: ", ") + ", and Denmark with a free token")
                legend(.dot(Theme.amber), "Lidar, surveys worldwide", "flown for archaeology and published on OpenTopography")
                legend(.icon("water.waves"), "Sonar, the seafloor", "NOAA's surveys of US waters and the Great Lakes, and INFOMAR's of Irish waters, for wrecks")
                legend(.icon("plus.circle"), "Anywhere else", "give the agent your own ground model or point cloud, and it searches that")
            }
            Button("Every source, and whether it answers now") {
                UserDefaults.standard.set(ToolboxView.Tab.data.rawValue, forKey: "toolboxTab")
                app.show(.toolbox)
            }
            .buttonStyle(SecondaryButton())
        }
    }

    private enum Mark { case dot(Color), icon(String) }

    /// A row of the legend: a dot in the map's colour for a layer drawn on it, an icon for one that is not.
    private func legend(_ mark: Mark, _ title: String, _ text: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Group {
                switch mark {
                case .dot(let color): Circle().fill(color).frame(width: 9, height: 9)
                case .icon(let name): Image(systemName: name).font(.system(size: 10.5 * Theme.scale, weight: .semibold)).foregroundStyle(Theme.dim)
                }
            }
            .frame(width: 14)
            (Text(title).font(.system(size: 13 * Theme.scale, weight: .semibold)) + Text(": " + text).font(.system(size: 13 * Theme.scale)).foregroundColor(Theme.dim))
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

/// What a chat app does and what Dighouse does, one question at a time.
private struct CompareBoard: View {
    private struct Row {
        let topic: String, icon: String, chat: String, dig: String, image: String?
    }

    private let rows = [
        Row(topic: "Getting the data", icon: "dig.mound", chat: "Can describe lidar, but cannot download a survey.",
            dig: "Downloads the raw laser points from open archives and builds the bare ground itself.", image: "reveal"),
        Row(topic: "Looking", icon: "dig.grid", chat: "Given the Mound City area with no tools, it said it could not find or place any features.",
            dig: "Found all 19 mounds there in a blind test, by looking at every tile in several renderings.", image: "tile"),
        Row(topic: "Checking a find", icon: "dig.layers", chat: "One model, one opinion.",
            dig: "Cuts a slice through the raw points, asks a second model, checks open maps, and opens the literature.", image: "section"),
        Row(topic: "Keeping a record", icon: "dig.brush", chat: "A conversation that scrolls away.",
            dig: "A project folder with a page per find: its pictures, measurements, checks and sources.", image: "record-relief"),
        Row(topic: "Making claims", icon: "hand.raised", chat: "May call something a discovery with nothing behind it.",
            dig: "Cannot mark a find as unmatched until the checks are on its record, and then only you can.", image: nil),
        Row(topic: "Choosing a model", icon: "cpu", chat: "The models one company sells.",
            dig: "Any model set up on this Mac, with a different one for the second opinion.", image: nil),
    ]
    @State private var picked = 0

    var body: some View {
        PageSection(title: "Why not just ask ChatGPT?",
                    caption: "A chat app can talk about archaeology. Dighouse gives the same kind of model the tools to do it, and we tested the difference with the same model on both sides. Pick a task.") {
            VStack(alignment: .leading, spacing: 0) {
                Flow(spacing: 6) {
                    ForEach(rows.indices, id: \.self) { i in
                        Button { withAnimation(.easeOut(duration: 0.15)) { picked = i } } label: {
                            Label(rows[i].topic, glyph: rows[i].icon).font(.system(size: 12.5 * Theme.scale, weight: .medium))
                                .foregroundStyle(picked == i ? .black : Theme.dim)
                                .padding(.horizontal, 12).frame(height: 30)
                                .background(Capsule().fill(picked == i ? Theme.tan : Theme.ink.opacity(0.06)))
                                .contentShape(Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(14)
                Hairline()
                let row = rows[picked]
                ViewThatFits(in: .horizontal) {
                    HStack(alignment: .center, spacing: 18) {
                        answers(row).frame(minWidth: 340, idealWidth: 340, maxWidth: .infinity, alignment: .leading)
                        if row.image != nil { picture(row).frame(width: 250) }
                    }
                    VStack(alignment: .leading, spacing: 14) {
                        answers(row)
                        if row.image != nil { picture(row).frame(maxWidth: 320) }
                    }
                }
                .padding(16).frame(minHeight: 150, alignment: .center)
            }
            .panel()
        }
    }

    private func answers(_ row: Row) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "bubble.left").font(.system(size: 14 * Theme.scale)).foregroundStyle(Theme.faint).frame(width: 22).padding(.top, 2)
                VStack(alignment: .leading, spacing: 2) {
                    Text("A chat app").font(.system(size: 12 * Theme.scale, weight: .semibold)).foregroundStyle(Theme.faint)
                    Text(row.chat).font(.system(size: 14 * Theme.scale)).foregroundStyle(Theme.dim).fixedSize(horizontal: false, vertical: true)
                }
            }
            HStack(alignment: .top, spacing: 12) {
                MoundMark().frame(width: 22, height: 12).padding(.top, 5)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Dighouse").font(.system(size: 12 * Theme.scale, weight: .semibold)).foregroundStyle(Theme.tan)
                    Text(row.dig).font(.system(size: 15 * Theme.scale, weight: .medium)).lineSpacing(3).fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    @ViewBuilder private func picture(_ row: Row) -> some View {
        if row.image == "reveal" {
            ForestReveal(animateIn: false)
        } else if let name = row.image, let image = Tour.image(name) {
            Image(nsImage: image).resizable().aspectRatio(contentMode: .fit).frame(maxHeight: 170)
                .clipShape(RoundedRectangle(cornerRadius: 10))
        }
    }
}

/// For someone coming back: a greeting by name, the project they last had open, and what it is waiting for.
private struct WelcomeBack: View {
    @EnvironmentObject var app: AppState
    @EnvironmentObject var store: ProjectStore
    @State private var waiting = ""
    @State private var totals = ""
    @State private var project: ProjectRef?

    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        let part = (5..<12).contains(hour) ? "Good morning" : (12..<18).contains(hour) ? "Good afternoon" : "Good evening"
        return app.firstName.isEmpty ? part + "." : "\(part), \(app.firstName)."
    }

    var body: some View {
        Group {
            if let project {
                PathCard(icon: "dig.trowel", title: greeting, text: "You left off at \(project.name). \(waiting)", foot: totals) { app.open(project) }
                    .help("Open \(project.name)")
                    .arrives()
            }
        }
        // The folders are read off the main thread: a project kept in iCloud can take a long time to answer.
        .task(id: store.projects.map(\.path)) { await read() }
    }

    private func read() async {
        let refs = store.projects
        let found: (ProjectRef, (tiles: Int, unscreened: Int, finds: Int, undecided: Int), [(tiles: Int, unscreened: Int, finds: Int, undecided: Int)])? = await Task.detached {
            func written(_ ref: ProjectRef) -> Date {
                ["/RESEARCH.md", "/PROJECT.md"].lazy.compactMap { FileInfo.modified(ref.path + $0) }.first ?? .distantPast
            }
            guard let last = refs.max(by: { written($0) < written($1) }) else { return nil }
            return (last, ProjectStore.glance(last.path), refs.map { ProjectStore.glance($0.path) })
        }.value
        guard let (last, it, all) = found else { project = nil; return }
        func count(_ n: Int, _ word: String) -> String { "\(n) \(word)\(n == 1 ? "" : "s")" }
        project = last
        waiting = it.tiles == 0 && it.finds == 0 ? "Its search has not started."
            : it.unscreened > 0 ? "\(count(it.unscreened, "tile")) \(it.unscreened == 1 ? "is" : "are") still to be looked at."
            : it.undecided > 0 ? "\(count(it.undecided, "find")) \(it.undecided == 1 ? "is" : "are") not decided yet."
            : it.finds == 0 ? "Every tile was looked at and nothing was marked."
            : "Every find is decided."
        let finds = all.reduce(0) { $0 + $1.finds }
        let decided = finds - all.reduce(0) { $0 + $1.undecided }
        totals = "\(count(all.count, "project")) · \(count(finds, "find")) · \(decided) decided"
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
            .background(RoundedRectangle(cornerRadius: 14).fill(Theme.ink.opacity(hover ? 0.07 : 0.035)))
            .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(hover ? Theme.ink.opacity(0.22) : Theme.line))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hover = $0 }
        .animation(.easeOut(duration: 0.12), value: hover)
    }
}

/// A place to begin, with a picture of its bare ground.
struct StartCard: View {
    let point: StartingPoint
    let action: () -> Void
    @State private var hover = false

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 0) {
                ZStack(alignment: .topTrailing) {
                    Theme.ink.opacity(0.04).aspectRatio(16 / 9, contentMode: .fit)
                        .overlay {
                            if let image = StartingPoints.image(point) {
                                Image(nsImage: image).resizable().aspectRatio(contentMode: .fill).scaleEffect(hover ? 1.04 : 1)
                            }
                        }
                        .clipped()
                    if !point.source.isEmpty {
                        Text(point.source).font(.system(size: 11 * Theme.scale, weight: .medium)).foregroundStyle(.white)
                            .padding(.horizontal, 7).frame(height: 20)
                            .background(Capsule().fill(.black.opacity(0.62))).padding(8)
                    }
                }
                VStack(alignment: .leading, spacing: 5) {
                    Text(point.title).font(.system(size: 14.5 * Theme.scale, weight: .semibold))
                    Text(point.place).font(.system(size: 12 * Theme.scale)).foregroundStyle(Theme.faint)
                    Text(point.about).font(.system(size: 12.5 * Theme.scale)).foregroundStyle(Theme.dim).lineSpacing(2)
                        .multilineTextAlignment(.leading).fixedSize(horizontal: false, vertical: true).padding(.top, 2)
                }
                .padding(14)
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, minHeight: 270, alignment: .topLeading)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .background(RoundedRectangle(cornerRadius: 14).fill(Theme.ink.opacity(hover ? 0.07 : 0.035)))
            .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(hover ? Theme.ink.opacity(0.22) : Theme.line))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
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

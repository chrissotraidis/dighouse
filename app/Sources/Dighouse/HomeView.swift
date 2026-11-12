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
            source: "USGS 3DEP", name: "Cahokia control run",
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
            id: "yucatan", kind: .search, title: "Yucatán lowlands", place: "Quintana Roo, Mexico",
            about: "A NASA G-LiHT strip over forest and limestone. A 2026 catalog lists structures detected in this data, so the work is checking each feature against it.",
            source: "OpenTopography", name: "Yucatan strip",
            question: "Which built features show in this G-LiHT strip, and which are already in the published catalog?",
            box: ["-88.9132", "19.6082", "-88.9085", "19.6128"]),
    ]

    static func image(_ point: StartingPoint) -> NSImage? {
        guard let folder = Bundle.main.resourceURL?.appendingPathComponent("starts/\(point.id).jpg") else { return nil }
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

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 34) {
                hero
                LazyVGrid(columns: paths, spacing: 12) {
                    PathCard(icon: "binoculars", title: "Help me choose a place",
                             text: "The agent asks what interests you, compares open surveys with what is already recorded, and suggests areas where a search can add something.") {
                        if let flow = ToolGuide.workflows.first(where: { $0.id == "choose" }) { app.run(flow) }
                    }
                    PathCard(icon: "mappin.and.ellipse", title: "I know where to look",
                             text: "Pick an area on the map, see which open lidar covers it, and create the project.") {
                        app.startProject()
                    }
                }
                if !store.projects.isEmpty { projects }
                surveys
                PageSection(title: "Places with terrain ready to fetch",
                            caption: "Seven published sites to learn on, and one strip of Yucatán forest where a 2026 catalog lists what was detected. Each was fetched from the live data service before it was listed here.") {
                    LazyVGrid(columns: cards, alignment: .leading, spacing: 12) {
                        ForEach(StartingPoints.all) { point in StartCard(point: point) { app.startProject(from: point) } }
                    }
                }
                PageSection(title: "Work on someone else's project",
                            caption: "A project is a folder of Markdown records, notes and source logs, so it can be shared like any folder. Locations are kept out of what is shared.") {
                    Button("Open a project folder…") { app.chooseProjectFolder() }.buttonStyle(SecondaryButton())
                }
            }
            .padding(.horizontal, 32).padding(.top, 44).padding(.bottom, 40)
            .frame(maxWidth: 860, alignment: .leading).frame(maxWidth: .infinity)
        }
        .background(Theme.bg)
        .task(id: engine.ready) { await app.loadSurveys() }
    }

    private var hero: some View {
        VStack(spacing: 14) {
            Text("Where do you want to look?").font(.system(size: 30, weight: .bold)).multilineTextAlignment(.center)
            Text("Dighouse runs AI agents with archaeology tools built in. They find and fetch open lidar (laser scans that map the ground beneath the trees), look for what people built, and check every find before you decide on it.")
                .font(.system(size: 14.5)).foregroundStyle(Theme.dim).multilineTextAlignment(.center).lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true).frame(maxWidth: 640)
            Composer().frame(maxWidth: 720).padding(.top, 8)
            Button { app.show(.toolbox) } label: {
                HStack(spacing: 6) {
                    Text("\(ToolGuide.packs.map(\.tools.count).reduce(0, +)) archaeology tools")
                    Text("·")
                    Text("\(ToolGuide.sources.count) open data sources")
                    Text("·")
                    Text("\(engine.models.count) models")
                    Image(systemName: "chevron.right").font(.system(size: 9, weight: .semibold))
                }
                .font(.system(size: 12.5)).foregroundStyle(Theme.faint).contentShape(Rectangle())
            }
            .buttonStyle(.plain).help("Open the Toolbox")
        }
        .frame(maxWidth: .infinity)
    }

    private var projects: some View {
        PageSection(title: "Your projects") {
            VStack(spacing: 0) {
                ForEach(Array(store.projects.enumerated()), id: \.element.id) { index, project in
                    if index > 0 { Hairline() }
                    Button { app.open(project) } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "folder").foregroundStyle(Theme.tan).frame(width: 20)
                            Text(project.name).font(.system(size: 13.5, weight: .medium)).lineLimit(1)
                            Spacer()
                            Image(systemName: "chevron.right").font(.system(size: 10, weight: .semibold)).foregroundStyle(Theme.faint)
                        }
                        .padding(.vertical, 6)
                    }
                    .buttonStyle(RowButton())
                }
            }
            .padding(4).panel()
        }
    }

    private var surveys: some View {
        PageSection(title: "Open surveys to search",
                    caption: "Lidar flown for archaeology and published openly, read from OpenTopography's live catalog. A survey is listed once its points were fetched and built into terrain by Dighouse.") {
            if app.surveysLoading {
                HStack(spacing: 8) {
                    ProgressView().controlSize(.small)
                    Text("Reading the catalog").font(.system(size: 13)).foregroundStyle(Theme.dim)
                }
            } else if let problem = app.surveysProblem {
                HStack(spacing: 10) {
                    Text("The catalog did not answer. \(problem)").font(.system(size: 13)).foregroundStyle(Theme.amber)
                        .fixedSize(horizontal: false, vertical: true)
                    Button("Try again") { Task { await app.loadSurveys() } }.buttonStyle(SecondaryButton())
                }
            } else {
                VStack(spacing: 0) {
                    ForEach(app.surveys) { survey in
                        HStack(alignment: .top, spacing: 12) {
                            IconTile(name: "airplane", size: 30)
                            VStack(alignment: .leading, spacing: 3) {
                                Text(survey.title).font(.system(size: 13.5, weight: .medium)).fixedSize(horizontal: false, vertical: true)
                                Text((survey.collected.isEmpty ? "" : "Flown \(survey.collected) · ") + "OpenTopography")
                                    .font(.system(size: 12)).foregroundStyle(Theme.faint)
                            }
                            Spacer(minLength: 8)
                            Button("Ask about it") {
                                app.ask("Tell me about the open lidar survey \"\(survey.title)\" (\(survey.id)): where it is, what it was flown for, what has been published from it, and what a search there could add.")
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
                            Text("Ask the agent for every survey in the catalog").font(.system(size: 13))
                            Spacer()
                            Image(systemName: "arrow.up.right").font(.system(size: 10, weight: .semibold)).foregroundStyle(Theme.faint)
                        }
                        .padding(.vertical, 5)
                    }
                    .buttonStyle(RowButton()).padding(4)
                }
                .panel()
            }
        }
    }
}

/// One of the two ways in from Home.
private struct PathCard: View {
    let icon: String, title: String, text: String
    let action: () -> Void
    @State private var hover = false

    var body: some View {
        Button(action: action) {
            HStack(alignment: .top, spacing: 14) {
                IconTile(name: icon, size: 38)
                VStack(alignment: .leading, spacing: 4) {
                    Text(title).font(.system(size: 15, weight: .semibold))
                    Text(text).font(.system(size: 12.5)).foregroundStyle(Theme.dim).lineSpacing(2)
                        .multilineTextAlignment(.leading).fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
                Image(systemName: "arrow.right").font(.system(size: 12, weight: .semibold)).foregroundStyle(hover ? Theme.text : Theme.faint)
            }
            .padding(16).frame(maxWidth: .infinity, minHeight: 104, alignment: .topLeading)
            .background(RoundedRectangle(cornerRadius: 14).fill(Color.white.opacity(hover ? 0.07 : 0.035)))
            .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(hover ? Color.white.opacity(0.22) : Theme.line))
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
                    Color.white.opacity(0.04).aspectRatio(16 / 9, contentMode: .fit)
                        .overlay {
                            if let image = StartingPoints.image(point) {
                                Image(nsImage: image).resizable().aspectRatio(contentMode: .fill)
                            }
                        }
                        .clipped()
                    if !point.source.isEmpty {
                        Text(point.source).font(.system(size: 11, weight: .medium)).foregroundStyle(.white)
                            .padding(.horizontal, 7).frame(height: 20)
                            .background(Capsule().fill(.black.opacity(0.62))).padding(8)
                    }
                }
                VStack(alignment: .leading, spacing: 5) {
                    Text(point.title).font(.system(size: 14.5, weight: .semibold))
                    Text(point.place).font(.system(size: 12)).foregroundStyle(Theme.faint)
                    Text(point.about).font(.system(size: 12.5)).foregroundStyle(Theme.dim).lineSpacing(2)
                        .multilineTextAlignment(.leading).fixedSize(horizontal: false, vertical: true).padding(.top, 2)
                }
                .padding(14)
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, minHeight: 270, alignment: .topLeading)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .background(RoundedRectangle(cornerRadius: 14).fill(Color.white.opacity(hover ? 0.07 : 0.035)))
            .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(hover ? Color.white.opacity(0.22) : Theme.line))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hover = $0 }
        .animation(.easeOut(duration: 0.12), value: hover)
    }
}


import AppKit
import SwiftUI

/// Places to begin. Every box here was fetched from the live data service before it was listed.
enum StartingPoints {
    static let own = StartingPoint(
        id: "own", kind: .own, title: "Your own area", place: "Anywhere with open lidar",
        about: "Enter the corners of an area you know. The agent will tell you which open surveys cover it.",
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

/// The Explore page: where to begin, what you already have, and how to work on someone else's project.
struct StartView: View {
    @EnvironmentObject var app: AppState
    @EnvironmentObject var store: ProjectStore

    private let columns = [GridItem(.adaptive(minimum: 250), spacing: 12, alignment: .top)]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 30) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Start a search").font(.system(size: 30, weight: .bold))
                    Text("A project is one question about one area. Pick a place to begin, and the agent will fetch its lidar, strip the trees away and start looking.")
                        .font(.system(size: 14.5)).foregroundStyle(Theme.dim).fixedSize(horizontal: false, vertical: true)
                }

                if !store.projects.isEmpty {
                    group("Continue", "Your projects on this Mac.") {
                        VStack(spacing: 0) {
                            ForEach(Array(store.projects.enumerated()), id: \.element.id) { index, project in
                                if index > 0 { Hairline() }
                                Button { app.open(project) } label: {
                                    HStack(spacing: 12) {
                                        Image(systemName: "folder").foregroundStyle(Theme.tan).frame(width: 20)
                                        Text(project.name).font(.system(size: 13.5, weight: .medium))
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

                group("Learn on a known site",
                      "These places are published. A run on one shows what real earthworks look like in lidar, and whether the agents find them again.") {
                    LazyVGrid(columns: columns, alignment: .leading, spacing: 12) {
                        ForEach(StartingPoints.all.filter { $0.kind == .learn }) { card($0) }
                    }
                }

                group("Search and check",
                      "Areas where the lidar is open and the published record can be checked feature by feature.") {
                    LazyVGrid(columns: columns, alignment: .leading, spacing: 12) {
                        ForEach(StartingPoints.all.filter { $0.kind == .search }) { card($0) }
                        card(StartingPoints.own)
                    }
                }

                group("Work on someone else's project",
                      "A project is a folder of Markdown records, notes and source logs, so it can be shared like any folder. Locations are kept out of what is shared.") {
                    Button("Open a project folder…") { app.chooseProjectFolder() }.buttonStyle(SecondaryButton())
                }
            }
            .padding(.horizontal, 32).padding(.vertical, 28)
            .frame(maxWidth: 900, alignment: .leading).frame(maxWidth: .infinity)
        }
        .background(Theme.bg)
    }

    private func group(_ title: String, _ caption: String, @ViewBuilder _ content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.system(size: 16, weight: .semibold))
                Text(caption).font(.system(size: 13)).foregroundStyle(Theme.dim).fixedSize(horizontal: false, vertical: true)
            }
            content()
        }
    }

    private func card(_ point: StartingPoint) -> some View {
        StartCard(point: point) { app.newProject = point }
    }
}

private struct StartCard: View {
    let point: StartingPoint
    let action: () -> Void
    @State private var hover = false

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 0) {
                ZStack(alignment: .topTrailing) {
                    if let image = StartingPoints.image(point) {
                        Color.clear.aspectRatio(16 / 9, contentMode: .fit)
                            .overlay(Image(nsImage: image).resizable().aspectRatio(contentMode: .fill))
                            .clipped()
                    } else {
                        Color.white.opacity(0.04).aspectRatio(16 / 9, contentMode: .fit)
                            .overlay(Image(systemName: "plus").font(.system(size: 26, weight: .light)).foregroundStyle(Theme.faint))
                    }
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
            .frame(maxWidth: .infinity, minHeight: 290, alignment: .topLeading)
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

/// Name, question and area for a new project, filled in from the starting point that was picked.
struct NewProjectSheet: View {
    @Environment(\.dismiss) private var dismiss
    let point: StartingPoint

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text("New project").font(.system(size: 20, weight: .semibold))
                if point.kind != .own {
                    Text("Starting from \(point.title), \(point.place). You can change anything below.")
                        .font(.system(size: 13)).foregroundStyle(Theme.dim)
                }
            }
            ProjectForm(point: point, actionTitle: "Create project", cancel: { dismiss() }) { dismiss() }
        }
        .padding(26).frame(width: 580)
        .background(Theme.bg).foregroundStyle(Theme.text)
    }
}

struct ProjectForm: View {
    @EnvironmentObject var app: AppState
    let actionTitle: String
    let cancel: (() -> Void)?
    let done: () -> Void

    @State private var name: String
    @State private var question: String
    @State private var box: [String]
    @State private var busy = false
    @State private var problem: String?

    init(point: StartingPoint, actionTitle: String, cancel: (() -> Void)? = nil, done: @escaping () -> Void) {
        self.actionTitle = actionTitle
        self.cancel = cancel
        self.done = done
        _name = State(initialValue: point.name)
        _question = State(initialValue: point.question)
        _box = State(initialValue: point.box)
    }

    private var valid: Bool {
        let n = box.compactMap(Double.init)
        return !name.trimmingCharacters(in: .whitespaces).isEmpty && n.count == 4 && n[0] < n[2] && n[1] < n[3]
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            labeled("Name") { TextField("Project name", text: $name).field() }
            labeled("Question") {
                TextField("What should this search answer?", text: $question, axis: .vertical).lineLimit(2...3).field()
            }
            labeled("Area") {
                HStack(spacing: 8) {
                    ForEach(Array(["West", "South", "East", "North"].enumerated()), id: \.offset) { i, label in
                        TextField(label, text: $box[i]).field()
                    }
                }
            }
            Text("The area is its west, south, east and north edges in degrees. It is stored privately in the project. Keep it under 6 square km to begin with.")
                .font(.system(size: 12)).foregroundStyle(Theme.faint).padding(.leading, 82)
                .fixedSize(horizontal: false, vertical: true)
            if let problem { Text(problem).foregroundStyle(Theme.amber).font(.system(size: 12.5)) }
            HStack(spacing: 8) {
                if busy { ProgressView().controlSize(.small) }
                Spacer()
                if let cancel { Button("Cancel", action: cancel).buttonStyle(SecondaryButton()) }
                Button(actionTitle) { create() }
                    .buttonStyle(PrimaryButton()).disabled(busy || !valid || !app.engine.ready)
            }
            .padding(.top, 4)
        }
        .font(.system(size: 13))
    }

    private func labeled(_ label: String, @ViewBuilder _ content: () -> some View) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text(label).foregroundStyle(Theme.dim).frame(width: 70, alignment: .leading)
            content()
        }
    }

    private func create() {
        busy = true
        problem = nil
        Task { @MainActor in
            do {
                try await app.createProject(name: name, question: question, box: box.compactMap(Double.init))
                done()
            } catch {
                problem = error.localizedDescription
            }
            busy = false
        }
    }
}

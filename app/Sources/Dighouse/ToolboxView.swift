import SwiftUI

/// The Toolbox: what Dighouse gives the agent that a chat app does not. A walk through one real search, the workflows
/// that run each part, where the data comes from, and other tools the agent can use.
struct ToolboxView: View {
    enum Tab: String, CaseIterable {
        case how = "How a search works", workflows = "Workflows", data = "Open data", more = "More tools"
    }

    @EnvironmentObject var app: AppState
    @EnvironmentObject var engine: Engine
    @AppStorage("toolboxTab") private var tab = Tab.how

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 14) {
                    VStack(alignment: .leading, spacing: 5) {
                        Text("Toolbox").font(.system(size: 26, weight: .bold))
                        Text("\(ToolGuide.toolCount) archaeology tools come built in. Here is what they do, how to run them, and where the data comes from.")
                            .font(.system(size: 14)).foregroundStyle(Theme.dim).lineSpacing(2).fixedSize(horizontal: false, vertical: true)
                    }
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 4) {
                            ForEach(Tab.allCases, id: \.self) { item in
                                Button { tab = item } label: {
                                    Text(item.rawValue).font(.system(size: 13, weight: .medium))
                                        .foregroundStyle(tab == item ? Theme.text : Theme.dim)
                                        .padding(.horizontal, 12).frame(height: 30)
                                        .background(Capsule().fill(tab == item ? Theme.ink.opacity(0.1) : .clear))
                                        .contentShape(Capsule())
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    Hairline()
                }
                switch tab {
                case .how: HowTab()
                case .workflows: WorkflowsTab()
                case .data: DataTab()
                case .more: MoreTab()
                }
            }
            .padding(.horizontal, 32).padding(.top, 26).padding(.bottom, 32)
            .frame(maxWidth: 940, alignment: .leading).frame(maxWidth: .infinity)
        }
        .background(Theme.bg)
        .task(id: engine.ready) { await engine.loadConnections() }
    }
}

// MARK: - How a search works

/// One real search, stage by stage: Monks Mound at Cahokia, run as a test on a site everyone knows.
private struct HowTab: View {
    @EnvironmentObject var app: AppState
    @EnvironmentObject var setup: Setup
    @AppStorage("tourStage") private var stage = 0

    var body: some View {
        let packs = ToolGuide.packs
        let at = min(max(stage, 0), packs.count - 1)
        if !setup.toolsReady { SetupChecklist() }
        Text("Follow one real search from start to finish. This is a test run at Cahokia, Illinois, on a mound everyone knows, so you can see what the agents did and what they wrote down. Step through the six stages.")
            .font(.system(size: 13.5)).foregroundStyle(Theme.dim).lineSpacing(3).fixedSize(horizontal: false, vertical: true)

        StageRail(stage: at) { stage = $0 }

        VStack(alignment: .leading, spacing: 0) {
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .top, spacing: 22) {
                    StageArt(stage: at).frame(width: 400)
                    StageWords(number: at + 1, pack: packs[at]).frame(minWidth: 340, idealWidth: 340, maxWidth: .infinity, alignment: .leading)
                }
                VStack(alignment: .leading, spacing: 18) {
                    StageArt(stage: at).frame(maxWidth: 460)
                    StageWords(number: at + 1, pack: packs[at])
                }
            }
            .padding(18)
            Hairline()
            HStack(spacing: 10) {
                Button("Back") { stage = at - 1 }.buttonStyle(SecondaryButton()).disabled(at == 0)
                Text("Stage \(at + 1) of \(packs.count)").font(.system(size: 12.5)).foregroundStyle(Theme.faint)
                Spacer()
                if at < packs.count - 1 {
                    Button("Next: \(packs[at + 1].title)") { stage = at + 1 }.buttonStyle(PrimaryButton())
                } else {
                    Button("Try it yourself") { app.startProject(from: StartingPoints.all[0]) }.buttonStyle(PrimaryButton())
                }
            }
            .padding(.horizontal, 18).padding(.vertical, 12)
        }
        .panel()

        PageSection(title: "Rules the tools enforce", caption: "These are built into the tools, so they hold whichever model is running.") {
            VStack(alignment: .leading, spacing: 9) {
                ForEach(ToolGuide.rules, id: \.self) { rule in
                    HStack(alignment: .firstTextBaseline, spacing: 9) {
                        Image(systemName: "lock").font(.system(size: 11)).foregroundStyle(Theme.tan)
                        Text(rule).font(.system(size: 13)).foregroundStyle(Theme.dim).fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading).panel(padding: 14)
        }
    }
}

/// The six stages as a row of numbered stops. Click one to go to it.
private struct StageRail: View {
    let stage: Int
    let pick: (Int) -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            ForEach(Array(ToolGuide.packs.enumerated()), id: \.offset) { index, pack in
                Button { pick(index) } label: {
                    VStack(spacing: 7) {
                        ZStack {
                            // The line to the neighbouring stops runs behind the number.
                            HStack(spacing: 0) {
                                Rectangle().fill(index == 0 ? Color.clear : index <= stage ? Theme.tan : Theme.line).frame(height: 2)
                                Rectangle().fill(index == ToolGuide.packs.count - 1 ? Color.clear : index < stage ? Theme.tan : Theme.line).frame(height: 2)
                            }
                            ZStack {
                                Circle().fill(index == stage ? Theme.tan : index < stage ? Theme.raised : Theme.bg)
                                Circle().strokeBorder(index <= stage ? Theme.tan : Theme.line, lineWidth: 1.5)
                                if index < stage {
                                    Image(systemName: "checkmark").font(.system(size: 10, weight: .bold)).foregroundStyle(Theme.tan)
                                } else {
                                    Text("\(index + 1)").font(.system(size: 12.5, weight: .bold)).foregroundStyle(index == stage ? .black : Theme.dim)
                                }
                            }
                            .frame(width: 28, height: 28)
                        }
                        Text(pack.short).font(.system(size: 12, weight: index == stage ? .semibold : .regular))
                            .foregroundStyle(index == stage ? Theme.text : Theme.dim).lineLimit(1)
                    }
                    .frame(maxWidth: .infinity).contentShape(Rectangle())
                }
                .buttonStyle(.plain).help(pack.title)
            }
        }
    }
}

/// What a stage does, why it matters, its tools, and the button that runs it.
private struct StageWords: View {
    let number: Int
    let pack: ToolGuide.Pack
    @EnvironmentObject var app: AppState

    var body: some View {
        let flow = ToolGuide.workflows.first { $0.id == pack.flow }
        let state = flow.map { app.state(of: $0) }
        VStack(alignment: .leading, spacing: 12) {
            Text(pack.title).font(.system(size: 20, weight: .bold))
            Text(pack.summary).font(.system(size: 13.5)).foregroundStyle(Theme.text.opacity(0.88)).lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
            HStack(alignment: .firstTextBaseline, spacing: 7) {
                Image(systemName: "lightbulb").font(.system(size: 11)).foregroundStyle(Theme.tan)
                Text(pack.why).font(.system(size: 12.5)).foregroundStyle(Theme.dim).lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            VStack(alignment: .leading, spacing: 0) {
                Text("The tools for this stage").font(.system(size: 12, weight: .semibold)).foregroundStyle(Theme.faint).padding(.bottom, 6)
                ForEach(pack.tools) { tool in
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Image(systemName: "wrench.adjustable").font(.system(size: 10)).foregroundStyle(Theme.tan)
                        (Text(tool.title).fontWeight(.medium).foregroundColor(Theme.text) + Text("  " + tool.does).foregroundColor(Theme.dim))
                            .font(.system(size: 12.5)).lineSpacing(2).fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.vertical, 3).help("The agent calls this tool \(tool.name)")
                }
            }
            if let flow {
                HStack(spacing: 10) {
                    Button("Run this stage") { app.run(flow) }.buttonStyle(SecondaryButton()).disabled(state?.ready != true)
                    Text(state?.ready == true ? (flow.scope == .project ? "Runs on the open project." : "Starts a chat.")
                         : (state?.note ?? "") == "Needs a project" ? "Open a project from the sidebar first." : (state?.note ?? ""))
                        .font(.system(size: 12)).foregroundStyle(Theme.faint)
                }
                .padding(.top, 2)
            }
        }
    }
}

/// The picture for each stage, made from the Cahokia run and the open data behind it.
private struct StageArt: View {
    let stage: Int

    var body: some View {
        switch stage {
        case 0: captioned("data-wikidata", "Sites already on record within about 24 km of Cahokia, from Wikidata. The agent weighs this against which lidar is open.")
        case 1:
            VStack(alignment: .leading, spacing: 6) {
                ForestReveal(animateIn: false)
                Text("Drag the handle. Serpent Mound, Ohio: the same laser points, first the highest returns, then only the ground.")
                    .font(.system(size: 11.5)).foregroundStyle(Theme.faint).lineSpacing(2).fixedSize(horizontal: false, vertical: true)
            }
        case 2: TileBoard()
        case 3: ChecksArt()
        case 4: PapersArt(caption: "What the search returns for Monks Mound. The agent opens the ones with open copies and logs every one.")
        default: RecordArt()
        }
    }

    private func captioned(_ name: String, _ caption: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            if let image = Tour.image(name) {
                Image(nsImage: image).resizable().aspectRatio(contentMode: .fit).clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Theme.line))
            }
            Text(caption).font(.system(size: 11.5)).foregroundStyle(Theme.faint).lineSpacing(2).fixedSize(horizontal: false, vertical: true)
        }
    }
}

/// The six tiles of the Cahokia run. Click one to read what the agent wrote about it.
private struct TileBoard: View {
    private struct Spot: Identifiable {
        let id: String, wide: CGFloat, verdict: String, note: String
    }

    private let rows: [[Spot]] = [
        [Spot(id: "r000c000", wide: 500, verdict: "built", note: "Corner of a large terraced platform mound. Also a modern path and track, and a natural channel across the top."),
         Spot(id: "r000c001", wide: 500, verdict: "built", note: "North face of the mound: flat rectangular summit and gullied slopes. A small round mound at lower right."),
         Spot(id: "r000c002", wide: 175, verdict: "nothing", note: "Plough striping only. The black strip is outside the survey, which is not the same as empty ground.")],
        [Spot(id: "r001c000", wide: 500, verdict: "built", note: "West side of the mound and its lower terrace. A modern road runs along the bottom."),
         Spot(id: "r001c001", wide: 500, verdict: "built", note: "South part of the mound: the broad first terrace, and a dotted line up the centre that looks like modern stairs."),
         Spot(id: "r001c002", wide: 175, verdict: "possible", note: "A broad low rise with no clear edges. A modern path and road cross it.")],
    ]
    @State private var picked = "r001c001"

    private func color(_ verdict: String) -> Color {
        verdict == "built" ? Theme.accent : verdict == "possible" ? Theme.amber : Theme.faint
    }

    var body: some View {
        let spot = rows.joined().first { $0.id == picked } ?? rows[0][0]
        VStack(alignment: .leading, spacing: 8) {
            GeometryReader { geo in
                let unit = (geo.size.width - 6) / 1175
                VStack(spacing: 3) {
                    ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                        HStack(spacing: 3) {
                            ForEach(row) { tile in
                                Button { picked = tile.id } label: {
                                    Group {
                                        if let image = Tour.image("tile-" + tile.id) { Image(nsImage: image).resizable() } else { Theme.side }
                                    }
                                    .frame(width: tile.wide * unit, height: 500 * unit)
                                    .overlay(Rectangle().strokeBorder(picked == tile.id ? Color.white : color(tile.verdict),
                                                                      lineWidth: picked == tile.id ? 3 : 1.5))
                                }
                                .buttonStyle(.plain).help("Tile \(tile.id): \(tile.verdict)")
                            }
                        }
                    }
                }
            }
            .aspectRatio(1175.0 / 1003.0, contentMode: .fit)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 8) {
                    Text("Tile \(spot.id)").font(.system(size: 12.5, weight: .semibold))
                    Badge(text: spot.verdict.capitalized, color: color(spot.verdict))
                }
                Text(spot.note).font(.system(size: 12.5)).foregroundStyle(Theme.dim).lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, minHeight: 62, alignment: .topLeading)
            Text("Click a tile. These are the agent's own notes from the run.").font(.system(size: 11.5)).foregroundStyle(Theme.faint)
        }
    }
}

/// The three tests on a flag, one at a time.
private struct ChecksArt: View {
    @State private var check = 0
    private let names = ["Section", "Second look", "Open maps"]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 4) {
                ForEach(names.indices, id: \.self) { i in
                    Button { check = i } label: {
                        Text(names[i]).font(.system(size: 12.5, weight: .medium))
                            .foregroundStyle(check == i ? .black : Theme.dim)
                            .padding(.horizontal, 11).frame(height: 27)
                            .background(Capsule().fill(check == i ? Theme.tan : Theme.ink.opacity(0.06)))
                            .contentShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
            switch check {
            case 0:
                picture("section")
                result("In the ground", "The slice measured the mound at 27.6 m high, with 79 ground returns within 5 m of its peak. A shape made of treetops would have none.")
            case 1:
                HStack(alignment: .top, spacing: 10) {
                    if let tile = Tour.image("tile-r001c001") {
                        Image(nsImage: tile).resizable().aspectRatio(contentMode: .fit).frame(width: 130).clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                    Text("“The feature exhibits distinct rectilinear terraces, sharp artificial slope breaks, and flat platforms characteristic of a monumental earthen mound.”")
                        .font(.system(size: 13)).italic().foregroundStyle(Theme.text.opacity(0.9)).lineSpacing(3)
                        .fixedSize(horizontal: false, vertical: true)
                }
                result("A different model agrees", "Gemini 3.8 Flash was shown the tile, without the first model's note. The tools refuse a second look from the model that raised the flag.")
            default:
                picture("data-osm")
                result("Already on the map", "OpenStreetMap has 14 modern features within 150 m, and lists Monks Mound among the historic places nearby. So this find is already known.")
            }
        }
    }

    @ViewBuilder private func picture(_ name: String) -> some View {
        if let image = Tour.image(name) {
            Image(nsImage: image).resizable().aspectRatio(contentMode: .fit).clipShape(RoundedRectangle(cornerRadius: 10))
                .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(Theme.line))
        }
    }

    private func result(_ title: String, _ text: String) -> some View {
        HStack(alignment: .top, spacing: 9) {
            Image(systemName: "checkmark.circle.fill").font(.system(size: 14)).foregroundStyle(Theme.green).padding(.top, 1)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.system(size: 13, weight: .semibold))
                Text(text).font(.system(size: 12.5)).foregroundStyle(Theme.dim).lineSpacing(2).fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

/// What a literature search returns, drawn as the list the agent sees.
struct PapersArt: View {
    var caption = ""
    var papers: [(String, String, Bool)] = [
        ("Building Monks Mound, Cahokia, Illinois, A.D. 800–1400", "T. M. Schilling · 2012", false),
        ("Cahokia or Monks Mound Not of Artificial Origin", "A. R. Crook · 1914", true),
        ("Cahokia or Monk's Mound", "Cyrus Thomas · 1907", false),
        ("Antiquities of Cahokia, or Monks' Mound, in Madison County, Illinois", "William McAdams · 1883", true),
    ]
    var yes = "Open copy", no = "No open copy"

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            VStack(spacing: 0) {
                ForEach(Array(papers.enumerated()), id: \.offset) { index, paper in
                    if index > 0 { Hairline() }
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: "doc.text").font(.system(size: 13)).foregroundStyle(Theme.tan).padding(.top, 2)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(paper.0).font(.system(size: 12.5, weight: .medium)).fixedSize(horizontal: false, vertical: true)
                            Text(paper.1).font(.system(size: 11.5)).foregroundStyle(Theme.faint)
                        }
                        Spacer(minLength: 6)
                        Text(paper.2 ? yes : no).font(.system(size: 11, weight: .medium))
                            .foregroundStyle(paper.2 ? Theme.green : Theme.faint).fixedSize()
                    }
                    .padding(.horizontal, 12).padding(.vertical, 9)
                }
            }
            .background(RoundedRectangle(cornerRadius: 12).fill(Theme.side))
            .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Theme.line))
            if !caption.isEmpty {
                Text(caption).font(.system(size: 11.5)).foregroundStyle(Theme.faint).lineSpacing(2).fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

/// The record the run ended with.
private struct RecordArt: View {
    private let lines: [(String, String)] = [
        ("In the ground returns", "27.6 m high"),
        ("A second model agrees", "Gemini 3.8 Flash"),
        ("Modern features checked", "Paths and stairs on it; already mapped"),
        ("Decided by a person", "“This is Monks Mound at Cahokia Mounds State Historic Site.”"),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            VStack(alignment: .leading, spacing: 10) {
                Text("candidates/C-001.md").font(.system(size: 11, design: .monospaced)).foregroundStyle(Theme.faint)
                HStack(alignment: .top, spacing: 12) {
                    if let relief = Tour.image("record-relief") {
                        Image(nsImage: relief).resizable().aspectRatio(contentMode: .fit).frame(width: 110).clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                    VStack(alignment: .leading, spacing: 6) {
                        Text("C-001 Large terraced platform mound").font(.system(size: 14.5, weight: .bold)).fixedSize(horizontal: false, vertical: true)
                        Badge(text: "Already published", color: Theme.tan)
                    }
                }
                ForEach(lines, id: \.0) { line in
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "checkmark.circle.fill").font(.system(size: 13)).foregroundStyle(Theme.green).padding(.top, 1)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(line.0).font(.system(size: 12.5, weight: .medium))
                            Text(line.1).font(.system(size: 12)).foregroundStyle(Theme.dim).fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
            }
            .padding(14).frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 12).fill(Theme.side))
            .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Theme.line))
            Text("Finding a known site again is the right answer for a test. The same page is written for every find.")
                .font(.system(size: 11.5)).foregroundStyle(Theme.faint).lineSpacing(2).fixedSize(horizontal: false, vertical: true)
        }
    }
}

// MARK: - Workflows

private struct WorkflowsTab: View {
    @EnvironmentObject var app: AppState
    @EnvironmentObject var store: ProjectStore

    private let roles: [(String, String, String)] = [
        ("cpu", "Agent", "The model you chose. It runs the search, calls the tools and keeps the plan."),
        ("person.2", "Helper agents", "Copies it starts on long screening runs, each given a batch of tiles."),
        ("eye", "Second model", "A different model that gives its own opinion on each flag."),
        ("person", "You", "You decide what each find is, and you send any report."),
    ]

    var body: some View {
        Text("A workflow is a ready-made request. Press Run and the agent carries it out with the tools, in a chat you can watch and steer. Each one shows who does which part.")
            .font(.system(size: 13.5)).foregroundStyle(Theme.dim).lineSpacing(3).fixedSize(horizontal: false, vertical: true)
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 190), spacing: 10, alignment: .top)], alignment: .leading, spacing: 10) {
            ForEach(roles, id: \.1) { role in
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: role.0).font(.system(size: 14)).foregroundStyle(role.1 == "You" ? Theme.accent : Theme.tan).frame(width: 20)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(role.1).font(.system(size: 13, weight: .semibold))
                        Text(role.2).font(.system(size: 12)).foregroundStyle(Theme.dim).lineSpacing(2).fixedSize(horizontal: false, vertical: true)
                    }
                }
                .frame(maxWidth: .infinity, minHeight: 66, alignment: .topLeading)
                .panel(padding: 12, radius: 12)
            }
        }
        group("To find a place", "These start a chat. No project is needed.", ToolGuide.workflows.filter { $0.scope == .general })
        group("To search a project",
              store.current.map { "These run on \($0.name), the open project, in the order a search goes. Each picks up where the project stands." }
                ?? "Open a project from the sidebar to run these. They are listed in the order a search goes.",
              ToolGuide.workflows.filter { $0.scope == .project })
    }

    private func group(_ title: String, _ caption: String, _ flows: [ToolGuide.Workflow]) -> some View {
        PageSection(title: title, caption: caption) {
            VStack(spacing: 0) {
                ForEach(Array(flows.enumerated()), id: \.element.id) { index, flow in
                    if index > 0 { Hairline() }
                    WorkflowLine(flow: flow)
                }
            }
            .panel()
        }
    }
}

/// One workflow: where it stands, what it does, who does each part, and the button that runs it.
private struct WorkflowLine: View {
    let flow: ToolGuide.Workflow
    @EnvironmentObject var app: AppState

    var body: some View {
        let state = app.state(of: flow)
        let done = state.note == "Done"
        HStack(alignment: .top, spacing: 14) {
            Group {
                if done {
                    Image(systemName: "checkmark.circle.fill").font(.system(size: 20)).foregroundStyle(Theme.green)
                } else {
                    IconTile(name: flow.icon).opacity(state.ready ? 1 : 0.55)
                }
            }
            .frame(width: 34, height: 34)
            VStack(alignment: .leading, spacing: 7) {
                Text(flow.title).font(.system(size: 14, weight: .semibold))
                Text(flow.summary).font(.system(size: 12.5)).foregroundStyle(Theme.dim).lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)
                Flow(spacing: 5) {
                    ForEach(Array(flow.steps.enumerated()), id: \.offset) { index, step in
                        HStack(spacing: 5) {
                            if index > 0 { Image(systemName: "arrow.right").font(.system(size: 8, weight: .bold)).foregroundStyle(Theme.faint) }
                            (Text(step.who).fontWeight(.semibold).foregroundColor(step.who == "You" ? Theme.accent : Theme.tan)
                             + Text("  " + step.does).foregroundColor(Theme.dim))
                                .font(.system(size: 11.5)).lineLimit(1)
                        }
                    }
                }
            }
            Spacer(minLength: 10)
            VStack(alignment: .trailing, spacing: 6) {
                Button(done ? "Run again" : "Run") { app.run(flow) }.buttonStyle(SecondaryButton()).disabled(!state.ready)
                if !state.note.isEmpty {
                    Text(state.note).font(.system(size: 11.5, weight: .medium))
                        .foregroundStyle(done ? Theme.green : state.ready ? Theme.tan : Theme.faint).lineLimit(1).fixedSize()
                }
            }
        }
        .padding(14).frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Open data

private struct DataTab: View {
    @EnvironmentObject var app: AppState
    @State private var online: [String: Bool] = [:]
    @State private var checked: Date?
    @State private var checking = false
    @State private var open: String?
    @State private var asking: ToolGuide.DataSource?

    /// Where each service's data covers, so a person can see at a glance which ones matter for their place.
    private static let regions: [(title: String, note: String, names: [String])] = [
        ("Anywhere", "Used for every project, wherever it is.", ["OpenTopography", "Wikidata", "OpenStreetMap", "OpenAlex", "Open Context"]),
        ("United States", "Lidar and records for places in the US.", ["USGS 3DEP", "National Register of Historic Places"]),
        ("England, the Netherlands and France", "Ready-made national ground models, used only for places in these countries.",
         ["Environment Agency lidar (England)", "AHN (Netherlands)", "IGN LiDAR HD (France)"]),
        ("The ancient Mediterranean and Near East", "Ancient places on record, used only for places in that region.", ["Pleiades"]),
    ]

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text("Everything Dighouse searches is public, and none of it needs an account or a key. Click a service to see what it gives and a picture made from its data.")
                .font(.system(size: 13.5)).foregroundStyle(Theme.dim).lineSpacing(3).fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 8)
            VStack(alignment: .trailing, spacing: 4) {
                Button { Task { await probe() } } label: { Label(checking ? "Checking…" : "Check status", systemImage: "arrow.clockwise") }
                    .buttonStyle(SecondaryButton()).disabled(checking)
                    .help("Sends a small test request to each service from this Mac.")
                if let checked {
                    let up = online.values.filter { $0 }.count
                    Text("\(up) of \(ToolGuide.allSources.count) online at \(checked.formatted(date: .omitted, time: .shortened))")
                        .font(.system(size: 11.5)).foregroundStyle(up == ToolGuide.allSources.count ? Theme.faint : Theme.amber)
                }
            }
        }
        ForEach(Self.regions, id: \.title) { region in
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(region.title).font(.system(size: 15, weight: .semibold))
                    Text(region.note).font(.system(size: 12.5)).foregroundStyle(Theme.faint)
                }
                VStack(spacing: 0) {
                    let sources = region.names.compactMap { name in ToolGuide.allSources.first { $0.name == name } }
                    ForEach(Array(sources.enumerated()), id: \.element.id) { i, source in
                        if i > 0 { Hairline() }
                        row(source)
                    }
                }
                .panel()
            }
        }
        .task { await probe() }
        .confirmationDialog(asking.map { "Ask the agent about \($0.name)?" } ?? "", isPresented: Binding(get: { asking != nil }, set: { if !$0 { asking = nil } }),
                            titleVisibility: .visible) {
            Button("Start a chat") { if let asking { app.askGeneral(asking.ask) }; asking = nil }
            Button("Cancel", role: .cancel) { asking = nil }
        } message: {
            Text(asking.map { "This starts a new chat in which the agent uses \($0.name) to answer: \"\($0.ask)\" It uses your AI model." } ?? "")
        }
    }

    private func row(_ source: ToolGuide.DataSource) -> some View {
        let expanded = open == source.name
        return VStack(alignment: .leading, spacing: 12) {
            Button { withAnimation(.easeOut(duration: 0.15)) { open = expanded ? nil : source.name } } label: {
                HStack(spacing: 12) {
                    thumb(source).frame(width: 64, height: 44).clipShape(RoundedRectangle(cornerRadius: 6))
                    VStack(alignment: .leading, spacing: 2) {
                        Text(source.name).font(.system(size: 13.5, weight: .semibold))
                        Text(source.what).font(.system(size: 12.5)).foregroundStyle(Theme.dim).lineLimit(1)
                    }
                    Spacer(minLength: 8)
                    status(source)
                    Image(systemName: "chevron.right").font(.system(size: 10, weight: .semibold)).foregroundStyle(Theme.faint)
                        .rotationEffect(.degrees(expanded ? 90 : 0))
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            if expanded {
                HStack(alignment: .top, spacing: 16) {
                    art(source).frame(width: 260)
                    VStack(alignment: .leading, spacing: 9) {
                        Text(source.what).font(.system(size: 13)).foregroundStyle(Theme.text.opacity(0.9)).fixedSize(horizontal: false, vertical: true)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("What Dighouse takes from it").font(.system(size: 12, weight: .semibold)).foregroundStyle(Theme.faint)
                            Text(source.gives).font(.system(size: 13)).foregroundStyle(Theme.dim).fixedSize(horizontal: false, vertical: true)
                        }
                        Flow(spacing: 6) {
                            ForEach(source.usedFor.components(separatedBy: " · "), id: \.self) { Badge(text: $0, color: Theme.tan) }
                        }
                        HStack(spacing: 10) {
                            Button { asking = source } label: { Label("Ask the agent…", systemImage: "sparkles") }
                                .buttonStyle(SecondaryButton())
                                .help("Starts a chat in which the agent uses this service. It asks you first.")
                            if let url = URL(string: source.url) {
                                Link(destination: url) { Label(url.host ?? source.url, systemImage: "arrow.up.right") }
                                    .font(.system(size: 12.5)).foregroundStyle(Theme.accent)
                            }
                        }
                    }
                }
                .padding(.leading, 76)
            }
        }
        .padding(.horizontal, 14).padding(.vertical, 10)
    }

    private func status(_ source: ToolGuide.DataSource) -> some View {
        let state = online[source.name]
        return HStack(spacing: 6) {
            Circle().fill(state == true ? Theme.green : state == false ? Theme.amber : Theme.faint).frame(width: 7, height: 7)
            Text(state == true ? "Online" : state == false ? "Not answering" : "Checking")
                .font(.system(size: 12)).foregroundStyle(state == false ? Theme.amber : Theme.dim)
        }
        .help(state == false ? "This service did not reply. Tools that use it will fail until it is back, or until this Mac is online."
              : "This service replied to a test request from this Mac.")
    }

    @ViewBuilder private func thumb(_ source: ToolGuide.DataSource) -> some View {
        if let image = source.image.hasPrefix("start:") ? StartingPoints.image(named: String(source.image.dropFirst(6)))
                                                        : (source.image.isEmpty ? nil : Tour.image(source.image)) {
            Image(nsImage: image).resizable().aspectRatio(contentMode: .fill)
        } else {
            Rectangle().fill(Theme.side).overlay(
                Image(systemName: source.image == "papers" ? "books.vertical" : source.image == "records" ? "doc.text" : "building.columns")
                    .font(.system(size: 16)).foregroundStyle(Theme.tan.opacity(0.85)))
        }
    }

    @ViewBuilder private func art(_ source: ToolGuide.DataSource) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            if source.image == "papers" {
                PapersArt()
            } else if source.image == "records" {
                PapersArt(papers: [("11Ms136", "Site · Illinois Site Files · Madison County", true), ("11Ms99", "Site · Illinois Site Files · Madison County", true),
                                   ("11S1232", "Site · Illinois Site Files · Saint Clair County", true), ("11Ms1672", "Site · Illinois Site Files · Madison County", true)],
                          yes: "Open record", no: "")
            } else if source.image.isEmpty {
                RoundedRectangle(cornerRadius: 10).fill(Theme.side).frame(height: 120)
                    .overlay(Image(systemName: "building.columns").font(.system(size: 36, weight: .light)).foregroundStyle(Theme.tan.opacity(0.8)))
            } else if let image = source.image.hasPrefix("start:")
                        ? StartingPoints.image(named: String(source.image.dropFirst(6))) : Tour.image(source.image) {
                Image(nsImage: image).resizable().aspectRatio(contentMode: .fit).clipShape(RoundedRectangle(cornerRadius: 10))
                    .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(Theme.line))
            }
            Text(source.caption).font(.system(size: 11.5)).foregroundStyle(Theme.faint).lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func probe() async {
        checking = true
        online = [:]
        await withTaskGroup(of: (String, Bool).self) { group in
            for source in ToolGuide.allSources {
                group.addTask {
                    guard let url = URL(string: source.probe) else { return (source.name, false) }
                    var request = URLRequest(url: url)
                    request.timeoutInterval = 12
                    request.setValue("dighouse/0.2 (https://github.com/chrissotraidis/dighouse)", forHTTPHeaderField: "User-Agent")
                    let code = ((try? await URLSession.shared.data(for: request))?.1 as? HTTPURLResponse)?.statusCode ?? 0
                    return (source.name, (200..<400).contains(code))
                }
            }
            for await (name, ok) in group { online[name] = ok }
        }
        checked = Date()
        checking = false
    }
}


// MARK: - More tools

private struct MoreTab: View {
    @EnvironmentObject var app: AppState
    @EnvironmentObject var engine: Engine
    @State private var name = ""
    @State private var command = ""
    @State private var showServers = false

    private var known: [(String, ToolGuide.Addon)] {
        engine.plugins.compactMap { id in ToolGuide.addons[id].map { (id, $0) } }
    }
    private var others: [String] { engine.plugins.filter { ToolGuide.addons[$0] == nil } }

    var body: some View {
        Text("The archaeology tools are built in. The agent can also use other tools, in two ways: the ones your Codex app already has, and ones you add here.")
            .font(.system(size: 13.5)).foregroundStyle(Theme.dim).lineSpacing(3).fixedSize(horizontal: false, vertical: true)

        PageSection(title: "Already on this Mac",
                    caption: "Dighouse runs on the same engine as the Codex app, so whatever you connected there works here too. Ask for it in plain words, for example \"copy these records into Notion\". These come from your Codex setup, and Dighouse has not tested each one.") {
            if engine.plugins.isEmpty && engine.connections.isEmpty {
                Text("Nothing else is connected in Codex on this Mac.").font(.system(size: 13)).foregroundStyle(Theme.faint)
            }
            if !known.isEmpty {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 250), spacing: 10, alignment: .top)], alignment: .leading, spacing: 10) {
                    ForEach(known, id: \.0) { _, addon in
                        HStack(alignment: .top, spacing: 12) {
                            IconTile(name: addon.icon, size: 32)
                            VStack(alignment: .leading, spacing: 3) {
                                Text(addon.title).font(.system(size: 13.5, weight: .semibold))
                                Text(addon.use).font(.system(size: 12.5)).foregroundStyle(Theme.dim).lineSpacing(2)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            Spacer(minLength: 0)
                        }
                        .frame(maxWidth: .infinity, minHeight: 64, alignment: .topLeading)
                        .panel(padding: 12, radius: 12)
                    }
                }
            }
            if !others.isEmpty {
                Text("Also connected").font(.system(size: 12.5, weight: .semibold)).padding(.top, 4)
                Flow(spacing: 6) { ForEach(others, id: \.self) { Badge(text: $0) } }
            }
            if !engine.connections.isEmpty {
                Button { showServers.toggle() } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "chevron.right").font(.system(size: 8.5, weight: .bold)).rotationEffect(.degrees(showServers ? 90 : 0))
                        Text("Technical details: \(engine.connections.count) tool servers").font(.system(size: 12.5))
                    }
                    .foregroundStyle(Theme.dim).contentShape(Rectangle())
                }
                .buttonStyle(.plain).padding(.top, 4)
                if showServers {
                    VStack(spacing: 0) {
                        ForEach(Array(engine.connections.enumerated()), id: \.element.id) { index, server in
                            if index > 0 { Hairline() }
                            HStack(spacing: 12) {
                                Text(server.name).font(.system(size: 12.5, design: .monospaced))
                                Spacer()
                                Text(server.tools == 0 ? "Starts when used" : "\(server.tools) tools").font(.system(size: 12.5)).foregroundStyle(Theme.dim)
                            }
                            .padding(.horizontal, 14).padding(.vertical, 9)
                        }
                    }
                    .panel(radius: 10)
                }
            }
        }

        PageSection(title: "Add your own",
                    caption: "A tool server is a small program that gives the agent a new ability, such as a mapping package, a museum's site database, or a reader for a file type. It speaks an open standard called MCP, and many are free to download. Give it a name and the command that starts it. The engine restarts to load it, which stops any running work.") {
            ForEach(app.toolServers) { server in
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(server.name).font(.system(size: 13, weight: .medium))
                        Text(server.command).font(.system(size: 12, design: .monospaced)).foregroundStyle(Theme.dim).lineLimit(1)
                    }
                    Spacer()
                    if let found = engine.connections.first(where: { $0.name == server.key }) {
                        Badge(text: found.tools == 0 ? "No tools found" : "\(found.tools) tools", color: found.tools == 0 ? Theme.amber : Theme.green)
                    }
                    Button("Remove") {
                        app.toolServers.removeAll { $0 == server }
                        Task { await app.boot() }
                    }
                    .buttonStyle(SecondaryButton())
                }
                .panel(padding: 12, radius: 12)
            }
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 8) { fields }
                VStack(alignment: .leading, spacing: 8) { fields }
            }
            .font(.system(size: 13))
        }
    }

    @ViewBuilder private var fields: some View {
        TextField("Name", text: $name).field().frame(minWidth: 120, maxWidth: 170)
        TextField("Command, for example: uvx my-gis-server (quote a path that has spaces)", text: $command).field().frame(minWidth: 260)
        Button("Add") {
            app.toolServers.append(ToolServer(name: name.trimmingCharacters(in: .whitespaces), command: command.trimmingCharacters(in: .whitespaces)))
            name = ""
            command = ""
            Task { await app.boot() }
        }
        .buttonStyle(PrimaryButton())
        .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty || command.trimmingCharacters(in: .whitespaces).isEmpty
                  || app.toolServers.contains { $0.name == name.trimmingCharacters(in: .whitespaces) })
    }
}

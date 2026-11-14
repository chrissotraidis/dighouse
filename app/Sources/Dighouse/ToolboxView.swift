import SwiftUI

/// The Toolbox: what Dighouse gives the agent that a chat app does not. A walk through one real search, the workflows
/// that run each part, where the data comes from, and other tools the agent can use.
/// Each tab is a picture to press or drag first, and words second.
struct ToolboxView: View {
    enum Tab: String, CaseIterable {
        case how = "How a search works", workflows = "Workflows", data = "Open data", more = "More tools"
    }

    @EnvironmentObject var app: AppState
    @EnvironmentObject var engine: Engine
    @AppStorage("toolboxTab") private var tab = Tab.how

    var body: some View {
        // The page is always a little taller than the window, so the scroll bar never comes and goes and nothing shifts sideways.
        GeometryReader { geo in
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 14) {
                    VStack(alignment: .leading, spacing: 5) {
                        Text("Toolbox").font(.system(size: 26 * Theme.scale, weight: .bold))
                        Text("\(ToolGuide.toolCount) built-in tools, the workflows that run them, and the open data behind them.")
                            .font(.system(size: 14 * Theme.scale)).foregroundStyle(Theme.dim).fixedSize(horizontal: false, vertical: true)
                    }
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 4) {
                            ForEach(Tab.allCases, id: \.self) { item in
                                Button { tab = item } label: {
                                    Text(item.rawValue).font(.system(size: 13 * Theme.scale, weight: .medium))
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
            .frame(maxWidth: 940, alignment: .leading).frame(maxWidth: .infinity, minHeight: geo.size.height + 1, alignment: .top)
        }
        }
        .background(Theme.bg)
        .task(id: engine.ready) { await engine.loadConnections() }
    }
}

/// A row of small pills, one of them chosen. Used wherever a picture has more than one side to show.
private struct Chips: View {
    let names: [String]
    @Binding var pick: Int

    var body: some View {
        HStack(spacing: 4) {
            ForEach(names.indices, id: \.self) { i in
                Button { pick = i } label: {
                    Text(names[i]).font(.system(size: 12.5 * Theme.scale, weight: .medium))
                        .foregroundStyle(pick == i ? .black : Theme.dim)
                        .padding(.horizontal, 11).frame(height: 27)
                        .background(Capsule().fill(pick == i ? Theme.tan : Theme.ink.opacity(0.06)))
                        .contentShape(Capsule())
                }
                .buttonStyle(.plain)
            }
        }
    }
}

/// A line that opens and closes what is under it.
private struct Disclosure<Content: View>: View {
    let title: String
    @State private var open = false
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Button { withAnimation(.easeOut(duration: 0.15)) { open.toggle() } } label: {
                HStack(spacing: 6) {
                    Image(systemName: "chevron.right").font(.system(size: 8.5 * Theme.scale, weight: .bold)).rotationEffect(.degrees(open ? 90 : 0))
                    Text(title).font(.system(size: 12.5 * Theme.scale, weight: .medium))
                }
                .foregroundStyle(Theme.dim).contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            if open { content() }
        }
    }
}

private func caption(_ text: String) -> some View {
    Text(text).font(.system(size: 12 * Theme.scale)).foregroundStyle(Theme.faint).fixedSize(horizontal: false, vertical: true)
}

// MARK: - How a search works

/// One real search, stage by stage: Monks Mound at Cahokia, run as a test on a site everyone knows.
private struct HowTab: View {
    @EnvironmentObject var app: AppState
    @EnvironmentObject var setup: Setup
    @AppStorage("tourStage") private var stage = 0
    @State private var showTools = false

    var body: some View {
        let packs = ToolGuide.packs
        let at = min(max(stage, 0), packs.count - 1)
        let pack = packs[at]
        let flow = ToolGuide.workflows.first { $0.id == pack.flow }
        if !setup.toolsReady { SetupChecklist() }
        Text("One real search, at Cahokia in Illinois. Step through it and try each picture.")
            .font(.system(size: 13.5 * Theme.scale)).foregroundStyle(Theme.dim)

        StageRail(stage: at) { stage = $0 }

        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 14) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(pack.title).font(.system(size: 20 * Theme.scale, weight: .bold))
                    Text(pack.summary).font(.system(size: 14 * Theme.scale)).foregroundStyle(Theme.text.opacity(0.86))
                        .fixedSize(horizontal: false, vertical: true)
                }
                StageArt(stage: at).frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(18)
            Hairline()
            HStack(spacing: 10) {
                Button("Back") { stage = at - 1 }.buttonStyle(SecondaryButton()).disabled(at == 0)
                Text("Stage \(at + 1) of \(packs.count)").font(.system(size: 12.5 * Theme.scale)).foregroundStyle(Theme.faint)
                Spacer()
                Button { showTools = true } label: { Label("\(pack.tools.count) tools", systemImage: "wrench.and.screwdriver") }
                    .buttonStyle(SecondaryButton()).help("The tools the agent uses at this stage")
                    .popover(isPresented: $showTools, arrowEdge: .top) { ToolList(pack: pack).popoverSurface() }
                if let flow, app.state(of: flow).ready {
                    Button("Run this stage") { app.run(flow) }.buttonStyle(SecondaryButton())
                        .help(flow.scope == .project ? "Runs on the open project." : "Starts a chat.")
                }
                if at < packs.count - 1 {
                    Button("Next: \(packs[at + 1].short)") { stage = at + 1 }.buttonStyle(PrimaryButton()).help(packs[at + 1].title)
                } else {
                    Button("Try it yourself") { app.startProject(from: StartingPoints.all[0]) }.buttonStyle(PrimaryButton())
                }
            }
            .padding(.horizontal, 18).padding(.vertical, 12)
        }
        .panel()

        Disclosure(title: "\(ToolGuide.rules.count) rules the tools enforce") {
            VStack(alignment: .leading, spacing: 9) {
                ForEach(ToolGuide.rules, id: \.self) { rule in
                    HStack(alignment: .firstTextBaseline, spacing: 9) {
                        Image(systemName: "lock").font(.system(size: 11 * Theme.scale)).foregroundStyle(Theme.tan)
                        Text(rule).font(.system(size: 13 * Theme.scale)).foregroundStyle(Theme.dim).fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading).panel(padding: 14)
        }
    }
}

/// The tools of one stage, in a small panel.
private struct ToolList: View {
    let pack: ToolGuide.Pack

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            ForEach(pack.tools) { tool in
                VStack(alignment: .leading, spacing: 1) {
                    Text(tool.title).font(.system(size: 13 * Theme.scale, weight: .medium))
                    Text(tool.does).font(.system(size: 12 * Theme.scale)).foregroundStyle(Theme.dim).fixedSize(horizontal: false, vertical: true)
                }
                .help("The agent calls this tool \(tool.name)")
            }
        }
        .padding(16).frame(width: 340, alignment: .leading).foregroundStyle(Theme.text)
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
                                // Each stop carries its stage's drawing: dark on the current stop, tan on the ones behind it.
                                Glyph(name: pack.icon, size: 14 * Theme.scale, weight: .medium)
                                    .foregroundStyle(index == stage ? Color.black : index < stage ? Theme.tan : Theme.faint)
                            }
                            .frame(width: 34, height: 34)
                        }
                        Text("\(index + 1). \(pack.short)").font(.system(size: 12 * Theme.scale, weight: index == stage ? .semibold : .regular))
                            .foregroundStyle(index == stage ? Theme.text : Theme.dim).lineLimit(1)
                    }
                    .frame(maxWidth: .infinity).contentShape(Rectangle())
                }
                .buttonStyle(.plain).help(pack.title)
            }
        }
    }
}

/// The picture for each stage, made from the Cahokia run and the open data behind it. Each has something to press or drag.
private struct StageArt: View {
    let stage: Int

    var body: some View {
        switch stage {
        case 0: ChooseArt()
        case 1:
            VStack(alignment: .leading, spacing: 8) {
                ForestReveal(animateIn: false).frame(maxWidth: 640)
                caption("Drag the handle. The same laser points at Serpent Mound, Ohio: first the treetops, then only the ground.")
            }
        case 2: TileBoard()
        case 3: ChecksArt()
        case 4: PapersArt().frame(maxWidth: 640)
        default: RecordArt().frame(maxWidth: 640)
        }
    }
}

/// Where a search can go: the places open lidar reaches, and what is already on record at one of them.
private struct ChooseArt: View {
    @EnvironmentObject var app: AppState
    @State private var side = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Chips(names: ["Where lidar is open", "What is on record"], pick: $side)
            if side == 0 {
                CoverageMap(surveys: app.surveys.map(\.box))
                caption("Lidar the tools can fetch with no account. The dots are surveys flown for archaeology.")
            } else {
                if let image = Tour.image("data-wikidata") {
                    Image(nsImage: image).resizable().aspectRatio(contentMode: .fit).clipShape(RoundedRectangle(cornerRadius: 12))
                        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Theme.line)).frame(maxWidth: 640)
                }
                caption("Each dot is a site already on record within about 24 km of Cahokia.")
            }
        }
        .task { await app.loadSurveys() }
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
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .top, spacing: 20) {
                board.frame(width: 470)
                note(spot).frame(minWidth: 230, idealWidth: 300, maxWidth: .infinity, alignment: .leading)
            }
            VStack(alignment: .leading, spacing: 12) {
                board.frame(maxWidth: 470)
                note(spot)
            }
        }
    }

    private var board: some View {
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
                            .buttonStyle(.plain).help("Tile \(tile.id): \(tile.verdict)").accessibilityLabel("Tile \(tile.id)")
                        }
                    }
                }
            }
        }
        .aspectRatio(1175.0 / 1003.0, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func note(_ spot: Spot) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            caption("Press a tile to read the agent's note.")
            Badge(text: spot.verdict == "built" ? "Looks built" : spot.verdict.capitalized, color: color(spot.verdict))
            Text("“\(spot.note)”").font(.system(size: 15 * Theme.scale)).foregroundStyle(Theme.text.opacity(0.92)).lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

/// The three tests on a find, one at a time.
private struct ChecksArt: View {
    @State private var check = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Chips(names: ["Slice", "Second opinion", "Open maps"], pick: $check)
            switch check {
            case 0: SliceBoard()
            case 1:
                HStack(alignment: .top, spacing: 16) {
                    if let tile = Tour.image("tile-r001c001") {
                        Image(nsImage: tile).resizable().aspectRatio(contentMode: .fit).frame(width: 240).clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                    VStack(alignment: .leading, spacing: 12) {
                        Text("“…distinct rectilinear terraces, sharp artificial slope breaks, and flat platforms…”")
                            .font(.system(size: 15 * Theme.scale)).italic().foregroundStyle(Theme.text.opacity(0.92)).lineSpacing(4)
                            .fixedSize(horizontal: false, vertical: true)
                        result("A different model agrees", "Gemini 3.8 Flash saw the tile, and not the first model's note.")
                    }
                }
            default:
                VStack(alignment: .leading, spacing: 10) {
                    if let image = Tour.image("data-osm") {
                        Image(nsImage: image).resizable().aspectRatio(contentMode: .fit).clipShape(RoundedRectangle(cornerRadius: 10))
                            .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(Theme.line)).frame(maxWidth: 560)
                    }
                    result("Already on the map", "Open maps show 14 modern features within 150 m, and Monks Mound itself.")
                }
            }
        }
    }

    private func result(_ title: String, _ text: String) -> some View {
        HStack(alignment: .top, spacing: 9) {
            Image(systemName: "checkmark.circle.fill").font(.system(size: 14 * Theme.scale)).foregroundStyle(Theme.green).padding(.top, 1)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.system(size: 13 * Theme.scale, weight: .semibold))
                Text(text).font(.system(size: 12.5 * Theme.scale)).foregroundStyle(Theme.dim).fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

/// The ground at Monks Mound and the highest laser returns above it, on a 2 m grid, so a slice can be cut anywhere.
private enum SliceData {
    static let grid: (cols: Int, rows: Int, cell: Double, base: Double, ground: [UInt16], top: [UInt16])? = {
        guard let url = Bundle.main.resourceURL?.appendingPathComponent("tour/slice.bin"), let data = try? Data(contentsOf: url), data.count > 8 else { return nil }
        let words = data.withUnsafeBytes { Array($0.bindMemory(to: UInt16.self)) }.map { UInt16(littleEndian: $0) }
        let cols = Int(words[0]), rows = Int(words[1]), n = cols * rows
        guard words.count >= 4 + 2 * n else { return nil }
        return (cols, rows, Double(words[2]) / 100, Double(words[3]) / 10, Array(words[4..<4 + n]), Array(words[4 + n..<4 + 2 * n]))
    }()

    /// Heights of the ground and of the highest return along a line, in metres above the lowest ground, and the line's length.
    static func cut(from a: CGPoint, to b: CGPoint, samples: Int = 140) -> (ground: [Double], top: [Double], length: Double)? {
        guard let g = grid else { return nil }
        func at(_ values: [UInt16], _ x: Double, _ y: Double) -> Double {
            let c = min(max(Int(x * Double(g.cols - 1)), 0), g.cols - 1), r = min(max(Int(y * Double(g.rows - 1)), 0), g.rows - 1)
            return Double(values[r * g.cols + c]) / 100
        }
        var ground: [Double] = [], top: [Double] = []
        for i in 0..<samples {
            let t = Double(i) / Double(samples - 1)
            let x = Double(a.x) + (Double(b.x) - Double(a.x)) * t, y = Double(a.y) + (Double(b.y) - Double(a.y)) * t
            ground.append(at(g.ground, x, y))
            top.append(at(g.top, x, y))
        }
        let dx = Double(b.x - a.x) * Double(g.cols) * g.cell, dy = Double(b.y - a.y) * Double(g.rows) * g.cell
        return (ground, top, (dx * dx + dy * dy).squareRoot())
    }
}

/// Cut your own slice: drag a line across the mound, and the ground under it is drawn beside the picture.
private struct SliceBoard: View {
    @State private var from = CGPoint(x: 0.12, y: 0.52)
    @State private var to = CGPoint(x: 0.9, y: 0.5)

    var body: some View {
        let cut = SliceData.cut(from: from, to: to)
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .top, spacing: 20) {
                picture.frame(width: 400)
                profile(cut).frame(minWidth: 300, idealWidth: 340, maxWidth: .infinity, alignment: .leading)
            }
            VStack(alignment: .leading, spacing: 12) {
                picture.frame(maxWidth: 400)
                profile(cut)
            }
        }
    }

    private var picture: some View {
        GeometryReader { geo in
            let size = geo.size
            ZStack {
                if let image = Tour.image("slice-ground") { Image(nsImage: image).resizable() } else { Theme.side }
                Path { p in
                    p.move(to: CGPoint(x: from.x * size.width, y: from.y * size.height))
                    p.addLine(to: CGPoint(x: to.x * size.width, y: to.y * size.height))
                }
                .stroke(Theme.tan, style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
                ForEach([from, to], id: \.x) { end in
                    Circle().fill(.white).frame(width: 11, height: 11).shadow(color: .black.opacity(0.6), radius: 2)
                        .position(x: end.x * size.width, y: end.y * size.height)
                }
            }
            .contentShape(Rectangle())
            .gesture(DragGesture(minimumDistance: 0)
                .onChanged { drag in
                    func unit(_ p: CGPoint) -> CGPoint { CGPoint(x: min(max(p.x / size.width, 0), 1), y: min(max(p.y / size.height, 0), 1)) }
                    from = unit(drag.startLocation)
                    to = unit(drag.location)
                })
        }
        .aspectRatio(747.0 / 711.0, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Theme.line))
        .accessibilityElement()
        .accessibilityLabel("Monks Mound from above. Drag across it to cut a slice.")
        .accessibilityAddTraits(.allowsDirectInteraction)
    }

    private func profile(_ cut: (ground: [Double], top: [Double], length: Double)?) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            caption("Drag across the mound to cut a slice.")
            if let cut, cut.length > 4 {
                let low = cut.ground.min() ?? 0, high = cut.ground.max() ?? 0
                let trees = zip(cut.top, cut.ground).filter { $0 - $1 > 2 }.count
                Canvas { context, size in
                    let ceiling = max(high - low, 4) * 1.5
                    func point(_ i: Int, _ height: Double) -> CGPoint {
                        CGPoint(x: size.width * CGFloat(i) / CGFloat(cut.ground.count - 1),
                                y: size.height - 6 - (size.height - 12) * CGFloat(min(max(height - low, 0), ceiling) / ceiling))
                    }
                    // Treetops and anything else above the ground: dots, as the laser saw them.
                    for i in cut.top.indices where cut.top[i] - cut.ground[i] > 2 {
                        let p = point(i, cut.top[i])
                        context.fill(Path(ellipseIn: CGRect(x: p.x - 1.5, y: p.y - 1.5, width: 3, height: 3)), with: .color(Theme.green.opacity(0.8)))
                    }
                    var line = Path()
                    for i in cut.ground.indices { i == 0 ? line.move(to: point(i, cut.ground[i])) : line.addLine(to: point(i, cut.ground[i])) }
                    var fill = line
                    fill.addLine(to: CGPoint(x: size.width, y: size.height))
                    fill.addLine(to: CGPoint(x: 0, y: size.height))
                    fill.closeSubpath()
                    context.fill(fill, with: .color(Theme.tan.opacity(0.16)))
                    context.stroke(line, with: .color(Theme.tan), lineWidth: 2)
                }
                .frame(height: 170)
                .background(RoundedRectangle(cornerRadius: 10).fill(Theme.side))
                .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(Theme.line))
                Text("\(Int(cut.length.rounded())) m long. The ground rises \(String(format: "%.1f", high - low)) m.")
                    .font(.system(size: 15 * Theme.scale, weight: .semibold))
                HStack(spacing: 14) {
                    key(Theme.tan, "Ground")
                    key(Theme.green, trees > 0 ? "Treetops" : "No trees on this line")
                }
                caption("A mound is in the ground line. A shape made of treetops is not.")
            } else {
                caption("That line is too short to measure.")
            }
        }
    }

    private func key(_ color: Color, _ text: String) -> some View {
        HStack(spacing: 6) {
            Circle().fill(color).frame(width: 8, height: 8)
            Text(text).font(.system(size: 12.5 * Theme.scale)).foregroundStyle(Theme.dim)
        }
    }
}

/// What a literature search returns, drawn as the list the agent sees. Press a source to see what the agent does with it.
struct PapersArt: View {
    var papers: [(String, String, Bool)] = [
        ("Building Monks Mound, Cahokia, Illinois, A.D. 800–1400", "T. M. Schilling · 2012", false),
        ("Cahokia or Monks Mound Not of Artificial Origin", "A. R. Crook · 1914", true),
        ("Cahokia or Monk's Mound", "Cyrus Thomas · 1907", false),
        ("Antiquities of Cahokia, or Monks' Mound, in Madison County, Illinois", "William McAdams · 1883", true),
    ]
    var yes = "Free to read", no = "No free copy"
    /// What happens to a source of each kind. Empty when the rows are not sources to open.
    var then = ("The agent opens it, reads it and logs what it says about this place.",
                "Logged as could not open. You can open it yourself and hand the page over.")
    @State private var picked: Int?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if !then.0.isEmpty { caption("What the search returned for Monks Mound. Press a source.") }
            VStack(spacing: 0) {
                ForEach(Array(papers.enumerated()), id: \.offset) { index, paper in
                    if index > 0 { Hairline() }
                    Button { picked = picked == index ? nil : index } label: {
                        HStack(alignment: .top, spacing: 10) {
                            Image(systemName: "doc.text").font(.system(size: 13 * Theme.scale)).foregroundStyle(Theme.tan).padding(.top, 2)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(paper.0).font(.system(size: 13 * Theme.scale, weight: .medium)).fixedSize(horizontal: false, vertical: true)
                                    .multilineTextAlignment(.leading)
                                Text(paper.1).font(.system(size: 11.5 * Theme.scale)).foregroundStyle(Theme.faint)
                                if !(paper.2 ? yes : no).isEmpty {
                                    Label(paper.2 ? yes : no, systemImage: paper.2 ? "checkmark" : "minus")
                                        .font(.system(size: 11 * Theme.scale, weight: .medium))
                                        .foregroundStyle(paper.2 ? Theme.green.opacity(0.85) : Theme.faint)
                                }
                                if picked == index, !then.0.isEmpty {
                                    Text(paper.2 ? then.0 : then.1).font(.system(size: 12.5 * Theme.scale)).foregroundStyle(Theme.text.opacity(0.9))
                                        .fixedSize(horizontal: false, vertical: true).multilineTextAlignment(.leading).padding(.top, 4)
                                }
                            }
                            Spacer(minLength: 0)
                        }
                        .padding(.horizontal, 12).padding(.vertical, 9).contentShape(Rectangle())
                    }
                    .buttonStyle(.plain).disabled(then.0.isEmpty)
                }
            }
            .background(RoundedRectangle(cornerRadius: 12).fill(Theme.side))
            .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Theme.line))
        }
    }
}

/// The record the run ended with.
private struct RecordArt: View {
    private let lines: [(String, String)] = [
        ("In the ground", "27.6 m high"),
        ("Second opinion", "Gemini 3.8 Flash agrees"),
        ("Open maps", "Paths and stairs on it; already mapped"),
        ("Decided by a person", "“This is Monks Mound at Cahokia Mounds State Historic Site.”"),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .top, spacing: 12) {
                    if let relief = Tour.image("record-relief") {
                        Image(nsImage: relief).resizable().aspectRatio(contentMode: .fit).frame(width: 150).clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                    VStack(alignment: .leading, spacing: 8) {
                        Text("C-001 Large terraced platform mound").font(.system(size: 15 * Theme.scale, weight: .bold)).fixedSize(horizontal: false, vertical: true)
                        Badge(text: "Already published", color: Theme.tan)
                        ForEach(lines, id: \.0) { line in
                            HStack(alignment: .top, spacing: 8) {
                                Image(systemName: "checkmark.circle.fill").font(.system(size: 13 * Theme.scale)).foregroundStyle(Theme.green).padding(.top, 1)
                                (Text(line.0).fontWeight(.medium) + Text("  " + line.1).foregroundColor(Theme.dim))
                                    .font(.system(size: 12.5 * Theme.scale)).fixedSize(horizontal: false, vertical: true)
                            }
                        }
                    }
                }
            }
            .padding(14).frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 12).fill(Theme.side))
            .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Theme.line))
            caption("Finding a known site again is the right answer for a test run.")
        }
    }
}

// MARK: - Where the data reaches

/// The world, with the places each kind of open data reaches, and Europe drawn larger beside it.
struct CoverageMap: View {
    /// The layer to bring forward: "us", "national", "surveys" or "ancient". Nil shows all of them alike.
    var highlight: String? = nil
    /// The boxes of the open surveys flown for archaeology, as west, south, east, north.
    var surveys: [[Double]] = []

    private static let land: [[Double]] = {
        guard let url = Bundle.main.resourceURL?.appendingPathComponent("tour/world.json"), let data = try? Data(contentsOf: url) else { return [] }
        return (try? JSONSerialization.jsonObject(with: data)) as? [[Double]] ?? []
    }()

    private struct Frame {
        let west: Double, east: Double, south: Double, north: Double
        let rect: CGRect
        func point(_ lon: Double, _ lat: Double) -> CGPoint {
            CGPoint(x: rect.minX + rect.width * CGFloat((lon - west) / (east - west)),
                    y: rect.minY + rect.height * CGFloat((north - lat) / (north - south)))
        }
    }

    var body: some View {
        Canvas { context, size in
            let gap: CGFloat = 10, inset = size.height * 1.05
            let world = Frame(west: -168, east: 180, south: -57, north: 76, rect: CGRect(x: 0, y: 0, width: size.width - inset - gap, height: size.height))
            let europe = Frame(west: -12, east: 33, south: 41.5, north: 66, rect: CGRect(x: size.width - inset, y: 0, width: inset, height: size.height))
            for frame in [world, europe] {
                var layer = context
                layer.clip(to: Path(roundedRect: frame.rect, cornerRadius: 10))
                layer.fill(Path(frame.rect), with: .color(Theme.side))
                for ring in Self.land { layer.fill(path(ring, frame), with: .color(Theme.ink.opacity(0.16))) }
                func shade(_ id: String) -> Double { highlight == nil || highlight == id ? 1 : 0.18 }
                // Ancient places on record: a region, drawn as an outline so the lidar shows through it.
                layer.stroke(path(Reach.ancient, frame), with: .color(Theme.dim.opacity(0.9 * shade("ancient"))), style: StrokeStyle(lineWidth: 1.2, dash: [4, 3]))
                layer.fill(path(Reach.unitedStates, frame), with: .color(Theme.tan.opacity(0.75 * shade("us"))))
                for country in Reach.national {
                    let shape = path(country.ring, frame)
                    layer.fill(shape, with: .color(Theme.green.opacity(0.8 * shade("national"))))
                    layer.stroke(shape, with: .color(Theme.green.opacity(shade("national"))), lineWidth: 1)
                }
                for box in surveys where box.count == 4 {
                    let p = frame.point((box[0] + box[2]) / 2, (box[1] + box[3]) / 2)
                    layer.fill(Path(ellipseIn: CGRect(x: p.x - 3.5, y: p.y - 3.5, width: 7, height: 7)), with: .color(Theme.amber.opacity(shade("surveys"))))
                    layer.stroke(Path(ellipseIn: CGRect(x: p.x - 3.5, y: p.y - 3.5, width: 7, height: 7)), with: .color(.black.opacity(0.5 * shade("surveys"))), lineWidth: 0.8)
                }
                context.stroke(Path(roundedRect: frame.rect, cornerRadius: 10), with: .color(Theme.line), lineWidth: 1)
            }
            // Where the larger picture of Europe sits on the world.
            let a = world.point(europe.west, europe.north), b = world.point(europe.east, europe.south)
            context.stroke(Path(CGRect(x: a.x, y: a.y, width: b.x - a.x, height: b.y - a.y)), with: .color(Theme.faint), lineWidth: 0.8)
        }
        .aspectRatio(3.7, contentMode: .fit)
        .accessibilityElement()
        .accessibilityLabel("A map of the world showing where open lidar reaches: the United States, \(Reach.national.map(\.name).joined(separator: ", ")), and \(surveys.count) surveys flown for archaeology.")
    }

    private func path(_ ring: [Double], _ frame: Frame) -> Path {
        var p = Path()
        var i = 0
        while i + 1 < ring.count {
            let point = frame.point(ring[i], ring[i + 1])
            i == 0 ? p.move(to: point) : p.addLine(to: point)
            i += 2
        }
        p.closeSubpath()
        return p
    }
}

/// Rough outlines of where each kind of open data reaches, as longitude and latitude pairs in a row.
enum Reach {
    static let unitedStates: [Double] = [-124.6, 48.4, -95.1, 49.0, -88.0, 48.0, -82.5, 45.3, -82.4, 41.7, -79.0, 43.3, -76.5, 44.2, -71.5, 45.0, -69.2, 47.4,
                                         -67.0, 44.8, -70.7, 41.6, -74.0, 40.5, -75.5, 35.3, -81.0, 31.5, -80.0, 25.3, -81.8, 25.0, -82.8, 29.0, -85.5, 29.8,
                                         -89.5, 29.2, -94.0, 29.5, -97.3, 26.0, -101.5, 29.8, -103.2, 29.0, -106.5, 31.8, -111.0, 31.3, -114.8, 32.5,
                                         -117.1, 32.5, -120.6, 34.5, -123.8, 39.5, -124.3, 42.0]
    static let ancient: [Double] = [-10, 35, -9, 44, 2, 51.5, 12, 54, 30, 48, 42, 44, 52, 40, 62, 36, 60, 25, 45, 14, 34, 20, 25, 30, 10, 30, -8, 28]
    /// Countries whose national ground model the tools can fetch, in the order they were added.
    static let national: [(name: String, ring: [Double])] = [
        ("England", [-5.8, 50.0, -4.2, 50.3, -3.0, 50.6, -1.0, 50.7, 1.4, 51.1, 1.8, 52.6, 0.3, 53.5, -0.1, 54.5, -1.6, 55.65, -2.1, 55.85, -3.1, 55.05,
                     -3.6, 54.5, -3.1, 53.35, -2.95, 52.0, -2.65, 51.6, -3.6, 51.2, -4.6, 51.1]),
        ("the Netherlands", [3.3, 51.4, 3.4, 51.2, 5.8, 51.0, 6.0, 50.75, 6.2, 51.4, 6.9, 51.9, 7.25, 53.2, 6.9, 53.6, 4.8, 53.4, 4.5, 52.5, 3.9, 51.9]),
        ("France", [-4.9, 48.4, -1.6, 48.7, -1.4, 49.75, 1.6, 50.95, 2.55, 51.1, 4.2, 49.95, 6.4, 49.5, 8.25, 48.95, 7.6, 47.55, 6.9, 47.35, 6.0, 46.2,
                    7.05, 45.9, 6.6, 45.1, 7.6, 43.8, 6.2, 43.05, 3.1, 43.0, 3.2, 42.4, -1.8, 43.35, -1.2, 46.0, -2.6, 47.3]),
        ("Flanders", [2.55, 51.09, 3.37, 51.37, 4.24, 51.37, 5.04, 51.49, 5.85, 51.16, 5.9, 50.75, 5.1, 50.71, 4.3, 50.69, 3.2, 50.71, 2.6, 50.8]),
        ("Norway", [4.6, 58.0, 7.0, 57.9, 11.8, 58.9, 12.6, 60.0, 12.2, 63.5, 14.5, 65.5, 16.5, 68.5, 20.5, 69.0, 26.0, 69.9, 31.2, 70.4, 28.0, 71.2,
                    20.0, 70.3, 13.5, 68.3, 10.5, 64.5, 4.8, 62.0]),
        ("Estonia", [21.7, 57.9, 23.3, 57.5, 26.5, 57.5, 27.4, 57.5, 28.2, 59.4, 26.0, 59.7, 23.4, 59.5, 21.7, 58.9]),
        ("Switzerland", [5.95, 46.13, 6.8, 45.83, 7.9, 45.9, 9.0, 45.82, 10.5, 46.5, 10.45, 46.95, 9.5, 47.55, 8.6, 47.82, 7.5, 47.6, 6.0, 46.6]),
    ]
}

// MARK: - Workflows

/// A search from left to right: who does each part, where the open project stands, and a button for each.
private struct WorkflowsTab: View {
    @EnvironmentObject var app: AppState
    @EnvironmentObject var store: ProjectStore
    @State private var picked: String?

    /// The parts of a search in order, and the lane each sits in: 0 the agent, 1 a second model, 2 you.
    private let parts: [(id: String, lane: Int)] = [("terrain", 0), ("screen", 0), ("check", 0), ("second", 1), ("prior", 0), ("decide", 0), ("review", 2), ("report", 0)]
    private let lanes: [(icon: String, name: String)] = [("dig.trowel", "Agent"), ("eye", "Second model"), ("person", "You")]

    private func flow(_ id: String) -> ToolGuide.Workflow? { ToolGuide.workflows.first { $0.id == id } }
    private var waiting: Int { store.candidates.filter { $0.status == "flagged" || $0.status == "ground_confirmed" }.count }

    /// A part's short name, where it stands, and whether it can run now.
    private func facts(_ id: String) -> (title: String, icon: String, note: String, ready: Bool, done: Bool) {
        if id == "review" {
            let note = store.current == nil ? "Needs a project" : store.candidates.isEmpty ? "Needs finds" : waiting == 0 ? "Done" : "\(waiting) waiting"
            return ("Decide", "dig.brush", note, waiting > 0, note == "Done")
        }
        guard let flow = flow(id) else { return (id, "questionmark", "", false, false) }
        let state = app.state(of: flow)
        let done = state.note == "Done" || state.note == "All decided" || state.note == "Prepared"
        return (id == "second" ? "Second opinion" : id == "prior" ? "What is published" : flow.title, flow.icon, state.note, state.ready, done)
    }

    var body: some View {
        let general = ToolGuide.workflows.filter { $0.scope == .general }
        let chosen = picked ?? app.nextStep?.id ?? "full"
        Text("A workflow is a ready-made request. Press one to see what it does, then Run.")
            .font(.system(size: 13.5 * Theme.scale)).foregroundStyle(Theme.dim)

        PageSection(title: "Before a project") {
            Flow(spacing: 8) {
                ForEach(general) { flow in
                    chip(flow.id, flow.icon, flow.title, chosen == flow.id)
                }
            }
        }

        PageSection(title: store.current.map { "In \($0.name)" } ?? "In a project") {
            VStack(alignment: .leading, spacing: 12) {
                if let whole = flow("full") {
                    HStack(spacing: 12) {
                        Button { app.run(whole) } label: { Label(whole.title, glyph: whole.icon) }
                            .buttonStyle(PrimaryButton()).disabled(!app.state(of: whole).ready)
                        Text(store.current == nil ? "Open a project from the sidebar to run these." : "Every step below, in one press.")
                            .font(.system(size: 12.5 * Theme.scale)).foregroundStyle(Theme.faint)
                    }
                }
                // The lanes need room. In a narrow window they keep their width and scroll sideways.
                GeometryReader { geo in
                    ScrollView(.horizontal, showsIndicators: false) { picture(chosen).frame(width: max(geo.size.width, 760)) }
                }
                .frame(height: 3 * 92 + 3 * 6 + 16)
            }
        }

        detail(chosen)
    }

    /// The lanes: one row for each of the three who take part, one column for each part of the search.
    private func picture(_ chosen: String) -> some View {
        Grid(alignment: .topLeading, horizontalSpacing: 6, verticalSpacing: 6) {
            GridRow {
                Color.clear.frame(width: 116, height: 1)
                ForEach(parts.indices, id: \.self) { i in
                    HStack(spacing: 4) {
                        Text("\(i + 1)").font(.system(size: 11 * Theme.scale, weight: .semibold)).foregroundStyle(Theme.faint)
                        Rectangle().fill(Theme.line).frame(height: 1)
                        if i < parts.count - 1 {
                            Image(systemName: "chevron.right").font(.system(size: 7 * Theme.scale, weight: .bold)).foregroundStyle(Theme.faint)
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            ForEach(lanes.indices, id: \.self) { lane in
                GridRow {
                    HStack(spacing: 7) {
                        Glyph(name: lanes[lane].icon, size: 13 * Theme.scale).foregroundStyle(lane == 2 ? Theme.accent : Theme.tan).frame(width: 18)
                        Text(lanes[lane].name).font(.system(size: 12.5 * Theme.scale, weight: .semibold))
                    }
                    .frame(width: 116, height: 92, alignment: .leading)
                    ForEach(parts.indices, id: \.self) { i in
                        if parts[i].lane == lane {
                            card(parts[i].id, chosen == parts[i].id)
                        } else if lane == 2, parts[i].id == "report" {
                            Text("You send it").font(.system(size: 11.5 * Theme.scale)).foregroundStyle(Theme.accent)
                                .frame(maxWidth: .infinity, minHeight: 92)
                        } else {
                            RoundedRectangle(cornerRadius: 10).fill(Theme.ink.opacity(0.02)).frame(maxWidth: .infinity, minHeight: 92)
                        }
                    }
                }
            }
        }
    }

    private func card(_ id: String, _ on: Bool) -> some View {
        let part = facts(id)
        return Button { picked = id } label: {
            VStack(alignment: .leading, spacing: 5) {
                HStack {
                    Glyph(name: part.icon, size: 14 * Theme.scale).foregroundStyle(id == "review" ? Theme.accent : Theme.tan)
                    Spacer(minLength: 0)
                    if part.done { Image(systemName: "checkmark").font(.system(size: 10 * Theme.scale, weight: .bold)).foregroundStyle(Theme.green) }
                }
                Text(part.title).font(.system(size: 12 * Theme.scale, weight: .semibold)).lineLimit(2).multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
                if !part.note.isEmpty, part.ready, !part.done {
                    Text(part.note).font(.system(size: 10.5 * Theme.scale)).foregroundStyle(part.ready ? Theme.tan : Theme.faint).lineLimit(2)
                        .multilineTextAlignment(.leading)
                }
            }
            .padding(9).frame(maxWidth: .infinity, minHeight: 92, alignment: .topLeading)
            .background(RoundedRectangle(cornerRadius: 10).fill(Theme.ink.opacity(on ? 0.1 : 0.045)))
            .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(on ? Theme.tan : Theme.line, lineWidth: on ? 1.5 : 1))
            .opacity(part.ready || part.done || on ? 1 : 0.7)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(part.title), \(lanes[parts.first { $0.id == id }?.lane ?? 0].name)\(part.note.isEmpty ? "" : ", \(part.note)")")
    }

    private func chip(_ id: String, _ icon: String, _ title: String, _ on: Bool) -> some View {
        Button { picked = id } label: {
            HStack(spacing: 7) {
                Glyph(name: icon, size: 13 * Theme.scale).foregroundStyle(Theme.tan)
                Text(title).font(.system(size: 12.5 * Theme.scale, weight: .medium))
            }
            .padding(.horizontal, 12).frame(height: 34)
            .background(RoundedRectangle(cornerRadius: 10).fill(Theme.ink.opacity(on ? 0.1 : 0.045)))
            .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(on ? Theme.tan : Theme.line, lineWidth: on ? 1.5 : 1))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    /// The chosen workflow: one sentence, who does it, and the button that runs it.
    @ViewBuilder private func detail(_ id: String) -> some View {
        let lane = parts.first { $0.id == id }?.lane ?? 0
        HStack(alignment: .center, spacing: 14) {
            if id == "review" {
                IconTile(name: "dig.brush", size: 38)
                words("Decide the finds", "You look at each find and decide what it is. Nothing is final before that.", lanes[2].name)
                Spacer(minLength: 10)
                Button("Review") { app.reviewing = true; app.route = .chat }.buttonStyle(SecondaryButton()).disabled(waiting == 0)
            } else if let flow = flow(id) {
                let state = app.state(of: flow)
                IconTile(name: flow.icon, size: 38)
                words(flow.title, flow.summary, flow.scope == .general ? "Agent, then you" : id == "report" ? "Agent, then you" : lanes[lane].name)
                Spacer(minLength: 10)
                VStack(alignment: .trailing, spacing: 5) {
                    Button(state.note == "Done" ? "Run again" : "Run") { app.run(flow) }.buttonStyle(SecondaryButton()).disabled(!state.ready)
                    if !state.note.isEmpty {
                        Text(state.note).font(.system(size: 11.5 * Theme.scale, weight: .medium))
                            .foregroundStyle(state.note == "Done" ? Theme.green : state.ready ? Theme.tan : Theme.faint).lineLimit(1).fixedSize()
                    }
                }
            }
        }
        .panel(padding: 14)
    }

    private func words(_ title: String, _ text: String, _ who: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 8) {
                Text(title).font(.system(size: 15 * Theme.scale, weight: .semibold))
                Badge(text: who, color: who == "You" ? Theme.accent : Theme.tan)
            }
            Text(text).font(.system(size: 13 * Theme.scale)).foregroundStyle(Theme.dim).fixedSize(horizontal: false, vertical: true)
        }
    }
}

// MARK: - Open data

private struct DataTab: View {
    @EnvironmentObject var app: AppState
    @State private var online: [String: Bool] = [:]
    /// Services whose main address answers while a second part some tools need does not.
    @State private var partly: Set<String> = []
    @State private var checked: Date?
    @State private var checking = false
    @State private var open: String?
    @State private var layer: String?
    @State private var asking: ToolGuide.DataSource?

    private let layers: [(id: String, name: String)] = [("us", "United States"), ("national", "National ground models"),
                                                         ("surveys", "Surveys flown for archaeology"), ("ancient", "Ancient places on record")]

    var body: some View {
        Group {
            if let source = ToolGuide.allSources.first(where: { $0.name == open }) {
                page(source)
            } else {
                overview
            }
        }
        .task { await app.loadSurveys(); await probe() }
        .confirmationDialog(asking.map { "Ask the agent about \($0.name)?" } ?? "", isPresented: Binding(get: { asking != nil }, set: { if !$0 { asking = nil } }),
                            titleVisibility: .visible) {
            Button("Start a chat") { if let asking { app.askGeneral(asking.ask) }; asking = nil }
            Button("Cancel", role: .cancel) { asking = nil }
        } message: {
            Text(asking.map { "This starts a new chat that asks: \"\($0.ask)\" It uses your AI model." } ?? "")
        }
    }

    @ViewBuilder private var overview: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text("All of it is public and needs no account. Press a service to see what it gives.")
                .font(.system(size: 13.5 * Theme.scale)).foregroundStyle(Theme.dim).fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 8)
            if let checked {
                let up = online.filter { $0.value && !partly.contains($0.key) }.count
                Text("\(up) of \(ToolGuide.allSources.count) online at \(checked.formatted(date: .omitted, time: .shortened))")
                    .font(.system(size: 11.5 * Theme.scale)).foregroundStyle(up == ToolGuide.allSources.count ? Theme.faint : Theme.amber)
            }
            Button { Task { await probe() } } label: { Label(checking ? "Checking…" : "Check status", systemImage: "arrow.clockwise") }
                .buttonStyle(SecondaryButton()).disabled(checking)
                .help("Sends a small test request to each service from this Mac.")
        }
        VStack(alignment: .leading, spacing: 10) {
            CoverageMap(highlight: layer, surveys: app.surveys.map(\.box))
            Flow(spacing: 6) {
                ForEach(layers, id: \.id) { item in
                    Button { layer = layer == item.id ? nil : item.id } label: {
                        HStack(spacing: 6) {
                            mark(item.id)
                            Text(item.name).font(.system(size: 12 * Theme.scale, weight: .medium)).foregroundStyle(layer == item.id ? Theme.text : Theme.dim)
                        }
                        .padding(.horizontal, 10).frame(height: 26)
                        .background(Capsule().fill(Theme.ink.opacity(layer == item.id ? 0.12 : 0.05))).contentShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
            caption("Lidar is open in few places. Maps, site lists and papers are read worldwide.")
        }
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 250), spacing: 10, alignment: .top)], alignment: .leading, spacing: 10) {
            ForEach(ToolGuide.allSources) { source in tile(source) }
        }
        Disclosure(title: "Not read yet, and why (\(ToolGuide.notYet.count))") {
            VStack(alignment: .leading, spacing: 7) {
                ForEach(ToolGuide.notYet, id: \.0) { item in
                    (Text(item.0).fontWeight(.medium).foregroundColor(Theme.text) + Text("  " + item.1).foregroundColor(Theme.dim))
                        .font(.system(size: 12.5 * Theme.scale)).fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading).panel(padding: 14)
        }
    }

    @ViewBuilder private func mark(_ id: String) -> some View {
        switch id {
        case "us": RoundedRectangle(cornerRadius: 2).fill(Theme.tan).frame(width: 10, height: 10)
        case "national": RoundedRectangle(cornerRadius: 2).fill(Theme.green).frame(width: 10, height: 10)
        case "surveys": Circle().fill(Theme.amber).frame(width: 9, height: 9)
        default: RoundedRectangle(cornerRadius: 2).strokeBorder(Theme.dim, style: StrokeStyle(lineWidth: 1.2, dash: [3, 2])).frame(width: 10, height: 10)
        }
    }

    private func tile(_ source: ToolGuide.DataSource) -> some View {
        Button { open = source.name } label: {
            HStack(spacing: 10) {
                thumb(source).frame(width: 52, height: 40).clipShape(RoundedRectangle(cornerRadius: 6))
                VStack(alignment: .leading, spacing: 2) {
                    Text(source.name).font(.system(size: 12.5 * Theme.scale, weight: .semibold)).lineLimit(2).multilineTextAlignment(.leading)
                    Text(source.reach).font(.system(size: 11 * Theme.scale)).foregroundStyle(Theme.faint).lineLimit(1)
                }
                Spacer(minLength: 0)
                dot(source)
            }
            .padding(9).frame(maxWidth: .infinity, minHeight: 58, alignment: .leading)
            .panel(radius: 12).contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(source.name), \(source.reach), \(word(source))")
    }

    private func word(_ source: ToolGuide.DataSource) -> String {
        let state = online[source.name]
        return state == true && partly.contains(source.name) ? "Partly online" : state == true ? "Online" : state == false ? "Not answering" : "Checking"
    }

    private func dot(_ source: ToolGuide.DataSource) -> some View {
        let state = online[source.name]
        let part = state == true && partly.contains(source.name)
        return Circle().fill(part || state == false ? Theme.amber : state == true ? Theme.green : Theme.faint).frame(width: 8, height: 8)
            .help(part ? source.alsoNote
                  : state == false ? "This service did not reply. Tools that use it will fail until it is back, or until this Mac is online."
                  : state == true ? "This service replied to a test request from this Mac."
                  : "Waiting for this service to reply to a test request.")
    }

    /// One service: a large picture made from its data, what Dighouse takes, where it reaches, and one thing to try.
    @ViewBuilder private func page(_ source: ToolGuide.DataSource) -> some View {
        Button { open = nil } label: { Label("All open data", systemImage: "chevron.left") }.buttonStyle(SecondaryButton())
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .top, spacing: 24) {
                art(source).frame(width: 440)
                facts(source).frame(minWidth: 280, idealWidth: 340, maxWidth: .infinity, alignment: .leading)
            }
            VStack(alignment: .leading, spacing: 16) {
                art(source).frame(maxWidth: 440)
                facts(source)
            }
        }
    }

    private func facts(_ source: ToolGuide.DataSource) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 5) {
                Text(source.name).font(.system(size: 22 * Theme.scale, weight: .bold)).fixedSize(horizontal: false, vertical: true)
                Text(source.what).font(.system(size: 14 * Theme.scale)).foregroundStyle(Theme.text.opacity(0.86)).fixedSize(horizontal: false, vertical: true)
            }
            HStack(spacing: 7) {
                dot(source)
                Text(word(source)).font(.system(size: 12.5 * Theme.scale)).foregroundStyle(Theme.dim)
                if online[source.name] == true, partly.contains(source.name) {
                    Text(source.alsoNote).font(.system(size: 12 * Theme.scale)).foregroundStyle(Theme.faint).fixedSize(horizontal: false, vertical: true)
                }
            }
            fact("Dighouse takes", source.gives)
            fact("It reaches", source.reach)
            fact("Used for", source.usedFor.components(separatedBy: " · ").joined(separator: ", "))
            if !source.ask.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Try it").font(.system(size: 12 * Theme.scale, weight: .semibold)).foregroundStyle(Theme.faint)
                    Text("“\(source.ask)”").font(.system(size: 13.5 * Theme.scale)).italic().foregroundStyle(Theme.text.opacity(0.9))
                        .fixedSize(horizontal: false, vertical: true)
                    HStack(spacing: 12) {
                        Button { asking = source } label: { Label("Ask the agent…", glyph: "dig.trowel") }.buttonStyle(PrimaryButton())
                        if let url = URL(string: source.url) {
                            Link(destination: url) { Label(url.host ?? source.url, systemImage: "arrow.up.right") }
                                .font(.system(size: 12.5 * Theme.scale)).foregroundStyle(Theme.accent)
                        }
                    }
                }
                .padding(.top, 2)
            }
        }
    }

    private func fact(_ title: String, _ text: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title).font(.system(size: 12 * Theme.scale, weight: .semibold)).foregroundStyle(Theme.faint)
            Text(text).font(.system(size: 13.5 * Theme.scale)).foregroundStyle(Theme.dim).fixedSize(horizontal: false, vertical: true)
        }
    }

    @ViewBuilder private func thumb(_ source: ToolGuide.DataSource) -> some View {
        if let image = source.image.hasPrefix("start:") ? StartingPoints.image(named: String(source.image.dropFirst(6)))
                                                        : (source.image.isEmpty ? nil : Tour.image(source.image)) {
            Image(nsImage: image).resizable().aspectRatio(contentMode: .fill)
        } else {
            Rectangle().fill(Theme.side).overlay(
                Image(systemName: source.image == "papers" ? "books.vertical" : source.image == "records" ? "doc.text" : "building.columns")
                    .font(.system(size: 16 * Theme.scale)).foregroundStyle(Theme.tan.opacity(0.85)))
        }
    }

    @ViewBuilder private func art(_ source: ToolGuide.DataSource) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            if source.image == "papers" {
                PapersArt(then: ("", ""))
            } else if source.image == "records" {
                PapersArt(papers: [("11Ms136", "Site · Illinois Site Files · Madison County", true), ("11Ms99", "Site · Illinois Site Files · Madison County", true),
                                   ("11S1232", "Site · Illinois Site Files · Saint Clair County", true), ("11Ms1672", "Site · Illinois Site Files · Madison County", true)],
                          yes: "Public record", no: "", then: ("", ""))
            } else if source.image.isEmpty {
                RoundedRectangle(cornerRadius: 12).fill(Theme.side).frame(height: 220)
                    .overlay(Image(systemName: "building.columns").font(.system(size: 54 * Theme.scale, weight: .light)).foregroundStyle(Theme.tan.opacity(0.8)))
            } else if let image = source.image.hasPrefix("start:")
                        ? StartingPoints.image(named: String(source.image.dropFirst(6))) : Tour.image(source.image) {
                Image(nsImage: image).resizable().aspectRatio(contentMode: .fit).clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Theme.line))
            }
            if !source.caption.isEmpty { caption(source.caption) }
        }
    }

    private func probe() async {
        guard !checking else { return }
        checking = true
        online = [:]
        partly = []
        /// Whether an address answers a small request within twelve seconds.
        @Sendable func answers(_ address: String) async -> Bool {
            guard let url = URL(string: address) else { return false }
            var request = URLRequest(url: url)
            request.timeoutInterval = 12
            request.setValue("dighouse/0.2 (https://github.com/chrissotraidis/dighouse)", forHTTPHeaderField: "User-Agent")
            let code = ((try? await URLSession.shared.data(for: request))?.1 as? HTTPURLResponse)?.statusCode ?? 0
            return (200..<400).contains(code)
        }
        await withTaskGroup(of: (String, Bool, Bool).self) { group in
            for source in ToolGuide.allSources {
                group.addTask {
                    async let main = answers(source.probe)
                    // The second part is up when any of its addresses answers.
                    var second = source.alsoProbe.isEmpty
                    for address in source.alsoProbe where !second { second = await answers(address) }
                    return (source.name, await main, second)
                }
            }
            for await (name, ok, second) in group {
                online[name] = ok
                if ok, !second { partly.insert(name) }
            }
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
    @State private var adding = false

    private var known: [(String, ToolGuide.Addon)] {
        engine.plugins.compactMap { id in ToolGuide.addons[id].map { (id, $0) } }
    }
    private var others: [String] { engine.plugins.filter { ToolGuide.addons[$0] == nil } }

    var body: some View {
        Text("The agent can also use what your Codex app has. Press one to put a request in a new chat.")
            .font(.system(size: 13.5 * Theme.scale)).foregroundStyle(Theme.dim).fixedSize(horizontal: false, vertical: true)

        if known.isEmpty {
            Text("Nothing else is connected in Codex on this Mac.").font(.system(size: 13 * Theme.scale)).foregroundStyle(Theme.faint)
        } else {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 250), spacing: 10, alignment: .top)], alignment: .leading, spacing: 10) {
                ForEach(known, id: \.0) { _, addon in
                    Button { app.draft(addon.tryIt) } label: {
                        HStack(alignment: .top, spacing: 12) {
                            IconTile(name: addon.icon, size: 32)
                            VStack(alignment: .leading, spacing: 3) {
                                Text(addon.title).font(.system(size: 13.5 * Theme.scale, weight: .semibold))
                                Text("“\(addon.tryIt)”").font(.system(size: 12.5 * Theme.scale)).foregroundStyle(Theme.dim)
                                    .fixedSize(horizontal: false, vertical: true).multilineTextAlignment(.leading)
                            }
                            Spacer(minLength: 0)
                        }
                        .padding(11).frame(maxWidth: .infinity, minHeight: 62, alignment: .topLeading)
                        .panel(radius: 12).contentShape(Rectangle())
                    }
                    .buttonStyle(.plain).help(addon.use)
                }
            }
        }

        ForEach(app.toolServers) { server in
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(server.name).font(.system(size: 13 * Theme.scale, weight: .medium))
                    Text(server.command).font(.system(size: 12 * Theme.scale, design: .monospaced)).foregroundStyle(Theme.dim).lineLimit(1)
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

        HStack(spacing: 12) {
            Button { adding = true } label: { Label("Add a tool server…", systemImage: "plus") }.buttonStyle(SecondaryButton())
                .popover(isPresented: $adding, arrowEdge: .top) { addForm.popoverSurface() }
            if !engine.connections.isEmpty || !others.isEmpty {
                Disclosure(title: "\(others.count) other plugins, \(engine.connections.count) tool servers") {
                    VStack(alignment: .leading, spacing: 8) {
                        if !others.isEmpty {
                            Text(others.joined(separator: ", ")).font(.system(size: 12.5 * Theme.scale)).foregroundStyle(Theme.dim).fixedSize(horizontal: false, vertical: true)
                        }
                        VStack(spacing: 0) {
                            ForEach(Array(engine.connections.enumerated()), id: \.element.id) { index, server in
                                if index > 0 { Hairline() }
                                HStack(spacing: 12) {
                                    Text(server.name).font(.system(size: 12.5 * Theme.scale, design: .monospaced))
                                    Spacer()
                                    Text(server.tools == 0 ? "Starts when used" : "\(server.tools) tools").font(.system(size: 12.5 * Theme.scale)).foregroundStyle(Theme.dim)
                                }
                                .padding(.horizontal, 14).padding(.vertical, 9)
                            }
                        }
                        .panel(radius: 10)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }

    /// A tool server's name and the command that starts it.
    private var addForm: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("A tool server is a small program that gives the agent a new ability. Adding one restarts the engine, which stops running work.")
                .font(.system(size: 12.5 * Theme.scale)).foregroundStyle(Theme.dim).fixedSize(horizontal: false, vertical: true)
            TextField("Name", text: $name).field()
            TextField("Command, such as: uvx my-gis-server", text: $command).field()
            HStack {
                Spacer()
                Button("Add") {
                    app.toolServers.append(ToolServer(name: name.trimmingCharacters(in: .whitespaces), command: command.trimmingCharacters(in: .whitespaces)))
                    name = ""
                    command = ""
                    adding = false
                    Task { await app.boot() }
                }
                .buttonStyle(PrimaryButton())
                .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty || command.trimmingCharacters(in: .whitespaces).isEmpty
                          || app.toolServers.contains { $0.name == name.trimmingCharacters(in: .whitespaces) })
            }
        }
        .font(.system(size: 13 * Theme.scale)).padding(16).frame(width: 380).foregroundStyle(Theme.text)
    }
}

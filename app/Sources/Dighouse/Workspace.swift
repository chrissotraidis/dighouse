import SwiftUI
import WebKit

/// The archaeology side of the window: the terrain, the candidate records, and the project's notes.
struct WorkspaceView: View {
    @EnvironmentObject var app: AppState
    @EnvironmentObject var store: ProjectStore

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 4) {
                ForEach(WorkTab.allCases, id: \.self) { tab in
                    Button { app.tab = tab } label: {
                        HStack(spacing: 6) {
                            Text(tab.rawValue)
                            if tab == .records, !store.candidates.isEmpty {
                                Text("\(store.candidates.count)").foregroundStyle(Theme.faint)
                            }
                            if tab == .sources, store.candidates.contains(where: { !$0.sources.isEmpty }) {
                                Text("\(Set(store.candidates.flatMap(\.sources).map(\.title)).count)").foregroundStyle(Theme.faint)
                            }
                        }
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(app.tab == tab ? Theme.text : Theme.dim)
                        .padding(.horizontal, 12).frame(height: 30)
                        .background(Capsule().fill(app.tab == tab ? Theme.ink.opacity(0.1) : .clear))
                        .contentShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
                Spacer()
            }
            .padding(.horizontal, 12).frame(height: 46)
            Hairline()
            switch app.tab {
            case .map: MapView()
            case .records: RecordsView()
            case .notes: NotesView()
            case .sources: SourcesView()
            case .data: DataView()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.bg)
    }
}

/// A centred message for a pane with nothing in it yet.
private struct EmptyPane<Action: View>: View {
    let icon: String, title: String, text: String
    @ViewBuilder let action: () -> Action

    var body: some View {
        VStack(spacing: 12) {
            IconTile(name: icon, size: 52)
            Text(title).font(.system(size: 18, weight: .semibold)).padding(.top, 4)
            Text(text).font(.system(size: 13.5)).foregroundStyle(Theme.dim)
                .multilineTextAlignment(.center).frame(maxWidth: 380)
            action().padding(.top, 6)
        }
        .padding(24).frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Map

/// The terrain as a mosaic of its tiles, with what was found on each and where the candidates sit.
struct MapView: View {
    @EnvironmentObject var app: AppState
    @EnvironmentObject var store: ProjectStore
    @State private var terrain: String?
    @State private var zoom = 1.0

    /// The terrain picked from the menu, or the first one with tiles. With no pick, every tiled terrain in the same
    /// coordinate system is shown together, so fetching more of an area adds its tiles beside the old ones.
    private var current: String? {
        terrain ?? store.terrains.first { t in store.tiles.contains { $0.terrain == t.id } }?.id ?? store.terrains.first?.id
    }

    private var shownTerrains: [Terrain] {
        if let terrain { return store.terrains.filter { $0.id == terrain } }
        guard let first = store.terrains.first(where: { $0.id == current }) else { return [] }
        // Terrains near each other only: a far-off one would shrink everything else to specks.
        func near(_ t: Terrain) -> Bool {
            guard t.box.count == 4, first.box.count == 4 else { return t.id == first.id }
            return abs(t.box[0] - first.box[0]) < 5000 && abs(t.box[1] - first.box[1]) < 5000
        }
        return store.terrains.filter { t in t.epsg == first.epsg && near(t) && store.tiles.contains { $0.terrain == t.id } }
    }

    private var shown: [Tile] {
        let ids = Set(shownTerrains.map(\.id))
        return store.tiles.filter { ids.contains($0.terrain) }
    }

    /// Where each tile sits, in metres from the top-left corner of everything shown.
    private struct Placed { let tile: Tile; let x, y, w, h: Double }

    private var placed: [Placed] {
        let byID = Dictionary(uniqueKeysWithValues: store.terrains.map { ($0.id, $0) })
        let raw: [Placed] = shown.compactMap { tile in
            guard let t = byID[tile.terrain] else { return nil }
            let left = t.box.count == 4 ? t.box[0] : 0, top = t.box.count == 4 ? t.box[3] : 0
            return Placed(tile: tile, x: left + Double(tile.col) * t.res, y: top - Double(tile.row) * t.res,
                          w: Double(tile.cols) * t.res, h: Double(tile.rows) * t.res)
        }
        guard let minX = raw.map(\.x).min(), let maxY = raw.map(\.y).max() else { return [] }
        return raw.map { Placed(tile: $0.tile, x: $0.x - minX, y: maxY - $0.y, w: $0.w, h: $0.h) }
    }

    /// A terrain's name in the menu: its survey, its size, and whether it has been cut into tiles yet.
    private func label(_ t: Terrain) -> String {
        let name = t.dataset.split(separator: ":").last.map(String.init) ?? t.id
        let cut = store.tiles.contains { $0.terrain == t.id }
        return "\(name), \(String(format: "%.1f", t.areaKm2)) sq km" + (cut ? "" : ", not cut into tiles")
    }

    var body: some View {
        if store.tiles.isEmpty, let ready = store.terrains.max(by: { $0.areaKm2 < $1.areaKm2 }) {
            EmptyPane(icon: "mountain.2", title: "Terrain ready",
                      text: ready.groundPerM2 > 0
                        ? "The bare ground is built: \(String(format: "%.1f", ready.areaKm2)) sq km at \(String(format: "%.1f", ready.groundPerM2)) ground returns per square metre. Cut it into tiles to look at it here."
                        : "The bare ground is built: \(String(format: "%.1f", ready.areaKm2)) sq km from a national agency's ready-made ground model. Cut it into tiles to look at it here.") {
                Button("Cut into tiles") {
                    app.ask("Cut the terrain \(ready.id) into tiles with make_tiles, then tell me how many tiles there are and how many have too little ground data to read.")
                }
                .buttonStyle(PrimaryButton())
            }
        } else if store.tiles.isEmpty {
            EmptyPane(icon: "mountain.2", title: "No terrain yet",
                      text: "Ask the agent to find open lidar for the project's area. The bare ground appears here as it is fetched.") {
                Button("Find and fetch lidar") {
                    if let flow = ToolGuide.workflows.first(where: { $0.id == "terrain" }) { app.run(flow) }
                }
                .buttonStyle(PrimaryButton())
            }
        } else {
            GeometryReader { geo in
                let tiles = shown
                if tiles.isEmpty, let id = current {
                    // A terrain picked from the menu that has not been cut yet.
                    EmptyPane(icon: "square.grid.3x3", title: "Not cut into tiles yet",
                              text: "This terrain is built but has no tiles, so there is nothing to show here yet.") {
                        Button("Cut into tiles") {
                            app.ask("Cut the terrain \(id) into tiles with make_tiles, then tell me how many tiles there are and how many have too little ground data to read.")
                        }
                        .buttonStyle(PrimaryButton())
                    }
                    .frame(width: geo.size.width, height: geo.size.height)
                }
                let spots = placed
                let width = max(spots.map { $0.x + $0.w }.max() ?? 1, 1)
                let height = max(spots.map { $0.y + $0.h }.max() ?? 1, 1)
                let scale = min((geo.size.width - 32) / width, (geo.size.height - 72) / height) * zoom
                ScrollView([.horizontal, .vertical]) {
                    ZStack(alignment: .topLeading) {
                        ForEach(spots, id: \.tile.id) { spot in
                            TileView(tile: spot.tile, selected: store.selectedTile == spot.tile.id)
                                .frame(width: spot.w * scale, height: spot.h * scale)
                                .offset(x: spot.x * scale, y: spot.y * scale)
                                .onTapGesture {
                                    store.selectedTile = spot.tile.id
                                    store.selectedCandidate = nil
                                }
                        }
                        ForEach(store.candidates) { c in
                            if let spot = spots.first(where: { $0.tile.id == c.tile }) {
                                Pin(label: c.id, selected: store.selectedCandidate == c.id)
                                    .offset(x: (spot.x + c.x * spot.w) * scale - 8,
                                            y: (spot.y + c.y * spot.h) * scale - 8)
                                    .onTapGesture {
                                        store.selectedCandidate = c.id
                                        store.selectedTile = c.tile
                                    }
                            }
                        }
                    }
                    .frame(width: width * scale, height: height * scale, alignment: .topLeading)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .padding(.horizontal, 16).padding(.top, 56).padding(.bottom, 16)
                    .frame(minWidth: geo.size.width, minHeight: geo.size.height, alignment: .top)
                }
            }
            .overlay(alignment: .topLeading) { controls.padding(12) }
            .overlay(alignment: .topTrailing) { legend.padding(12) }
            .overlay(alignment: .bottomLeading) { selection.padding(12) }
        }
    }

    private var controls: some View {
        HStack(spacing: 2) {
            Button { zoom = max(1, zoom / 1.5) } label: { Image(systemName: "minus") }
                .buttonStyle(IconButton(size: 28)).disabled(zoom <= 1).help("Zoom out")
            Button { zoom = min(8, zoom * 1.5) } label: { Image(systemName: "plus") }
                .buttonStyle(IconButton(size: 28)).help("Zoom in")
            if store.terrains.count > 1 {
                PillMenu(title: terrain == nil && shownTerrains.count > 1 ? "All terrain"
                         : store.terrains.first { $0.id == current }?.name ?? "Terrain", quiet: true) {
                    Button("All terrain, side by side") { terrain = nil }
                    ForEach(store.terrains) { t in
                        Button(label(t)) { terrain = t.id }
                    }
                }
            }
        }
        .padding(3).background(RoundedRectangle(cornerRadius: 11).fill(Theme.bg.opacity(0.92)))
        .overlay(RoundedRectangle(cornerRadius: 11).strokeBorder(Theme.line))
    }

    private var legend: some View {
        HStack(spacing: 12) {
            key(Theme.accent, "Looks built")
            key(Theme.amber, "Possible")
            key(Theme.faint, "Not screened")
        }
        .font(.system(size: 11.5)).foregroundStyle(Theme.dim)
        .padding(.horizontal, 10).frame(height: 28)
        .background(RoundedRectangle(cornerRadius: 9).fill(Theme.bg.opacity(0.92)))
        .overlay(RoundedRectangle(cornerRadius: 9).strokeBorder(Theme.line))
    }

    private func key(_ color: Color, _ label: String) -> some View {
        HStack(spacing: 5) {
            RoundedRectangle(cornerRadius: 2).strokeBorder(color, lineWidth: 1.5).frame(width: 10, height: 10)
            Text(label)
        }
    }

    @ViewBuilder private var selection: some View {
        let tile = store.tiles.first { $0.id == store.selectedTile }
        let candidate = store.candidates.first { $0.id == store.selectedCandidate }
        if tile != nil || candidate != nil {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    if let candidate {
                        Text("\(candidate.id) \(candidate.name)").font(.system(size: 13.5, weight: .semibold)).lineLimit(1)
                        Badge(text: candidate.statusLabel, color: candidate.statusColor)
                    } else if let tile {
                        Text("Tile \(tile.short)").font(.system(size: 13.5, weight: .semibold))
                        if let verdict = tile.verdict { Badge(text: verdict.capitalized, color: verdict == "built" ? Theme.accent : Theme.dim) }
                    }
                    Spacer(minLength: 4)
                    Button {
                        store.selectedTile = nil
                        store.selectedCandidate = nil
                    } label: { Image(systemName: "xmark") }.buttonStyle(IconButton(size: 22))
                }
                if let candidate {
                    if let section = Images.load(candidate.section) {
                        Image(nsImage: section).resizable().aspectRatio(contentMode: .fit)
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                    }
                    Button("Open record") { app.showRecords(candidate.id) }.buttonStyle(SecondaryButton())
                } else if let tile {
                    Text(tile.status == "unreadable" ? "Unreadable: the laser did not reach the ground here."
                         : tile.status == "screened" ? (tile.note ?? "") : "Nobody has looked at this tile yet.")
                        .font(.system(size: 12.5)).foregroundStyle(Theme.dim).lineLimit(4)
                        .fixedSize(horizontal: false, vertical: true)
                    if tile.status != "unreadable" {
                        Button("Ask the agent to look here") {
                            app.ask("Look at tile \(tile.id) in two renderings and tell me what you see. Record your verdict.")
                        }.buttonStyle(SecondaryButton())
                    }
                }
            }
            .padding(12).frame(width: 340, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 14).fill(Theme.raised))
            .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(Theme.line))
            .shadow(color: .black.opacity(0.35), radius: 14, y: 4)
        }
    }
}

private struct TileView: View {
    @EnvironmentObject var store: ProjectStore
    let tile: Tile
    let selected: Bool

    var body: some View {
        let path = "\(store.current?.path ?? "")/data/tiles/\(tile.id)-composite.png"
        ZStack {
            if let image = Images.load(path) {
                Image(nsImage: image).resizable().interpolation(.medium)
            } else {
                Rectangle().fill(Theme.side)
            }
            if tile.status == "unreadable" {
                Rectangle().fill(.black.opacity(0.5))
                Image(systemName: "eye.slash").foregroundStyle(Theme.dim)
            } else if tile.status == "unscreened" {
                Rectangle().fill(.black.opacity(0.3))
            }
            Rectangle().strokeBorder(outline, lineWidth: selected ? 2 : (tile.verdict == "built" || tile.verdict == "possible" ? 1.5 : 0.5))
        }
        .contentShape(Rectangle())
    }

    private var outline: Color {
        if selected { return .white }
        switch tile.verdict {
        case "built": return Theme.accent
        case "possible": return Theme.amber
        default: return .white.opacity(0.1)
        }
    }
}

private struct Pin: View {
    let label: String
    let selected: Bool

    var body: some View {
        HStack(spacing: 4) {
            Circle().fill(selected ? Theme.accent : .white).frame(width: 16, height: 16)
                .overlay(Circle().strokeBorder(.black.opacity(0.55), lineWidth: 1.5))
            Text(label).font(.system(size: 11, weight: .semibold)).foregroundStyle(.white)
                .padding(.horizontal, 6).frame(height: 18)
                .background(Capsule().fill(selected ? Theme.accent : .black.opacity(0.78)))
        }
        .fixedSize().contentShape(Rectangle())
    }
}

// MARK: - Records

private struct Decision: Identifiable {
    let candidate: Candidate
    let status: String
    var id: String { candidate.id + status }
}

struct RecordsView: View {
    @EnvironmentObject var app: AppState
    @EnvironmentObject var store: ProjectStore
    @EnvironmentObject var engine: Engine
    @State private var deciding: Decision?

    private var current: Candidate? {
        store.candidates.first { $0.id == store.selectedCandidate } ?? store.candidates.first
    }

    var body: some View {
        if store.candidates.isEmpty {
            EmptyPane(icon: "doc.text", title: "No candidates yet",
                      text: "When the agent flags something that looks built, its record appears here with its evidence and checks.") {
                if let next = app.nextStep {
                    Button(next.title) { app.run(next) }.buttonStyle(PrimaryButton())
                }
            }
        } else {
            GeometryReader { geo in
                HStack(spacing: 0) {
                    if geo.size.width >= 760 {
                        ScrollView {
                            VStack(spacing: 2) {
                                ForEach(store.candidates) { c in listRow(c) }
                            }.padding(8)
                        }
                        .frame(width: 236)
                        Hairline(vertical: true)
                    }
                    ScrollView {
                        VStack(alignment: .leading, spacing: 0) {
                            if geo.size.width < 760, let c = current {
                                PillMenu(title: "\(c.id) \(c.name)") {
                                    ForEach(store.candidates) { other in
                                        Button("\(other.id) \(other.name)") { store.selectedCandidate = other.id }
                                    }
                                }
                                .padding(.bottom, 16)
                            }
                            if let c = current { record(c) }
                        }
                        .padding(24).frame(maxWidth: 720, alignment: .leading).frame(maxWidth: .infinity)
                    }
                }
            }
            .sheet(item: $deciding) { decision in
                DecisionSheet(decision: decision).withApp(app)
            }
        }
    }

    private func listRow(_ c: Candidate) -> some View {
        Button { store.selectedCandidate = c.id } label: {
            HStack(spacing: 10) {
                Circle().fill(c.statusColor).frame(width: 7, height: 7)
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(c.id) \(c.name)").font(.system(size: 13)).lineLimit(1)
                    Text(c.statusLabel).font(.system(size: 11.5)).foregroundStyle(Theme.faint).lineLimit(1)
                }
            }
            .padding(.vertical, 5)
        }
        .buttonStyle(RowButton(selected: current?.id == c.id))
    }

    @ViewBuilder private func record(_ c: Candidate) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("candidates/\(c.id).md").font(.system(size: 11.5, design: .monospaced)).foregroundStyle(Theme.faint)
                Spacer()
                Label("Location kept on this Mac", systemImage: "lock").font(.system(size: 11.5)).foregroundStyle(Theme.faint)
            }
            VStack(alignment: .leading, spacing: 8) {
                Text("\(c.id) \(c.name)").font(.system(size: 24, weight: .bold)).fixedSize(horizontal: false, vertical: true)
                HStack(spacing: 8) {
                    Badge(text: c.statusLabel, color: c.statusColor)
                    Text("Flagged \(c.flaggedOn) by \(c.flaggedBy)").font(.system(size: 12.5)).foregroundStyle(Theme.dim).lineLimit(1)
                }
            }
            HStack(alignment: .top, spacing: 12) {
                figure(c.relief, "Bare-ground relief")
                figure(c.section, "Section through the feature")
            }
            if !c.evidence.isEmpty {
                section("Evidence") {
                    ForEach(c.evidence, id: \.self) { line in
                        Text(line).font(.system(size: 13.5)).foregroundStyle(Theme.dim).lineSpacing(3)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            section("Checks") { checks(c) }
            if !c.sources.isEmpty {
                section("Sources") {
                    ForEach(c.sources) { s in
                        VStack(alignment: .leading, spacing: 2) {
                            Text(s.title).font(.system(size: 13))
                            Text("\(s.status.replacingOccurrences(of: "_", with: " ").capitalized) · \(s.finding)")
                                .font(.system(size: 12.5)).foregroundStyle(Theme.dim).fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
            }
            if !c.decisions.isEmpty {
                section("Decisions") {
                    ForEach(c.decisions, id: \.self) { Text($0).font(.system(size: 12.5)).foregroundStyle(Theme.dim) }
                }
            }
            section("Your decision") {
                Text("You decide what this is. Your name and reason are written into the record.")
                    .font(.system(size: 12.5)).foregroundStyle(Theme.dim)
                Flow(spacing: 8) {
                    Button("Already published") { deciding = Decision(candidate: c, status: "already_published") }
                    Button("Natural feature") { deciding = Decision(candidate: c, status: "natural") }
                    Button("Modern feature") { deciding = Decision(candidate: c, status: "modern") }
                    Button("No match in sources read") { deciding = Decision(candidate: c, status: "no_match_in_sources_read") }
                    Button("Show file") { NSWorkspace.shared.selectFile(c.file, inFileViewerRootedAtPath: c.folder) }
                }
                .buttonStyle(SecondaryButton())
            }
        }
        .textSelection(.enabled)
    }

    private func section(_ title: String, @ViewBuilder _ content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.system(size: 14, weight: .semibold))
            content()
        }
        .padding(.top, 4)
    }

    @ViewBuilder private func checks(_ c: Candidate) -> some View {
        let cut = c.checks["section"] as? JSON
        let look = c.checks["second_look"] as? JSON
        let modern = c.checks["modern"] as? JSON
        let read = c.sources.filter { $0.status == "read" }.count
        let unread = c.sources.filter { $0.status == "could_not_open" }.count
        VStack(spacing: 0) {
            CheckRow(done: cut?["in_ground"] as? Bool, title: "Feature is in the ground returns",
                     detail: cut.map { "\($0["feature_height_m"] ?? "?") m high, \($0["ground_returns_within_5m_of_peak"] ?? "?") ground returns at its peak" }
                        ?? "A slice through the raw points shows whether it is ground or canopy.") {
                Button(cut == nil ? "Cut section" : "Cut again") {
                    app.ask("Cut a section through \(c.id), starting and ending on the surrounding ground, and file it on its record.")
                }.buttonStyle(SecondaryButton())
            }
            Hairline()
            CheckRow(done: look?["agrees"] as? Bool, title: "A second model agrees it looks built",
                     detail: app.secondLookProblem[c.id].map { "The second look did not run. " + $0 }
                        ?? look.map { "\($0["model"] as? String ?? ""): \($0["note"] as? String ?? "")" }
                        ?? "A different model looks at the tile without seeing the first opinion.") {
                HStack(spacing: 6) {
                    if app.secondLookBusy == c.id { ProgressView().controlSize(.small) }
                    ModelPicker(title: app.secondModelName, models: engine.models.filter { $0.readsImages },
                                current: app.secondModelID) { app.secondModelID = $0.id }
                    Button("Ask") { app.secondLook(c) }.buttonStyle(SecondaryButton())
                        .disabled(app.secondLookBusy != nil || app.secondModelID == nil)
                }
            }
            Hairline()
            CheckRow(done: modern.map { $0["likely_modern"] as? Bool != true }, title: "Not a modern feature",
                     detail: modern?["summary"] as? String ?? "Open maps are checked for roads, buildings and sites already mapped nearby.") {
                Button(modern == nil ? "Check" : "Check again") {
                    app.ask("Check for modern features near \(c.id) and tell me what the map shows.")
                }.buttonStyle(SecondaryButton())
            }
            Hairline()
            CheckRow(done: c.sources.isEmpty ? nil : (read > 0 && unread == 0), title: "Sources searched",
                     detail: c.sources.isEmpty ? "The literature is searched, and every source is logged as read or not opened."
                        : "\(read) read, \(unread) could not be opened") {
                Button("Search") {
                    app.ask("Search the literature for \(c.id), starting with studies of this dataset. Read what you find and log every source on its record.")
                }.buttonStyle(SecondaryButton())
            }
        }
        .panel()
    }

    @ViewBuilder private func figure(_ path: String, _ caption: String) -> some View {
        if let image = Images.load(path) {
            VStack(alignment: .leading, spacing: 5) {
                Image(nsImage: image).resizable().aspectRatio(contentMode: .fit).frame(maxHeight: 230)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    // Drag a record's picture onto the message box to attach it.
                    .onDrag { NSItemProvider(contentsOf: URL(fileURLWithPath: path)) ?? NSItemProvider() }
                Text(caption).font(.system(size: 11.5)).foregroundStyle(Theme.faint)
            }
        }
    }
}

/// One check on a record: whether it passed, what it found, and the action that runs it.
private struct CheckRow<Action: View>: View {
    let done: Bool?
    let title: String
    let detail: String
    @ViewBuilder let action: () -> Action

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: done == true ? "checkmark.circle.fill" : done == false ? "exclamationmark.circle.fill" : "circle")
                .font(.system(size: 16))
                .foregroundStyle(done == true ? Theme.green : done == false ? Theme.amber : Theme.faint)
                .frame(width: 20).padding(.top, 1)
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.system(size: 13.5, weight: .medium))
                Text(detail).font(.system(size: 12.5)).foregroundStyle(Theme.dim).fixedSize(horizontal: false, vertical: true)
                action().padding(.top, 7)
            }
            Spacer(minLength: 0)
        }
        .padding(14)
    }
}

/// Confirms a decision the person makes about a candidate, with their reason.
private struct DecisionSheet: View {
    @EnvironmentObject var app: AppState
    @Environment(\.dismiss) private var dismiss
    let decision: Decision
    @State private var reason = ""
    @State private var problem: String?
    @State private var busy = false

    private var open: [String] {
        guard decision.status == "no_match_in_sources_read" else { return [] }
        let c = decision.candidate
        var items: [String] = []
        if (c.checks["section"] as? JSON)?["in_ground"] as? Bool != true { items.append("No section shows the feature in the ground returns.") }
        if (c.checks["second_look"] as? JSON)?["agrees"] as? Bool != true { items.append("No second model has agreed that it looks built.") }
        if c.checks["modern"] == nil { items.append("Modern features have not been checked.") }
        if !c.sources.contains(where: { $0.status == "read" }) { items.append("No source has been read.") }
        let unread = c.sources.filter { $0.status == "could_not_open" }.count
        if unread > 0 { items.append("\(unread) source\(unread == 1 ? "" : "s") could not be opened.") }
        return items
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Mark \(decision.candidate.id) as \((Candidate.labels[decision.status] ?? "").lowercased())")
                .font(.system(size: 18, weight: .semibold))
            if !open.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Still open on this record").font(.system(size: 12.5, weight: .medium)).foregroundStyle(Theme.amber)
                    ForEach(open, id: \.self) { Text("• " + $0).font(.system(size: 12.5)).foregroundStyle(Theme.dim) }
                    Text("You can still decide. These are written into the record beside your decision.")
                        .font(.system(size: 12)).foregroundStyle(Theme.faint)
                }
                .frame(maxWidth: .infinity, alignment: .leading).panel(padding: 12, radius: 10)
            }
            TextField(decision.status == "already_published" ? "Where is it published?" : "Your reason", text: $reason, axis: .vertical)
                .lineLimit(2...4).field().font(.system(size: 13))
            Text("Recorded as decided by \(app.userName). Change your name in Settings.")
                .font(.system(size: 12)).foregroundStyle(Theme.faint)
            if let problem { Text(problem).font(.system(size: 12.5)).foregroundStyle(Theme.amber) }
            HStack(spacing: 8) {
                Spacer()
                Button("Cancel") { dismiss() }.buttonStyle(SecondaryButton())
                Button("Record decision") {
                    busy = true
                    Task { @MainActor in
                        do {
                            try await app.decide(decision.candidate, status: decision.status, reason: reason)
                            dismiss()
                        } catch {
                            problem = error.localizedDescription
                        }
                        busy = false
                    }
                }
                .buttonStyle(PrimaryButton()).disabled(busy || reason.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .padding(24).frame(width: 480)
        .background(Theme.bg).foregroundStyle(Theme.text)
    }
}

// MARK: - Notes

/// The project's own Markdown: the brief, the run notes, the log of sources read, and any draft reports.
struct NotesView: View {
    @EnvironmentObject var store: ProjectStore
    @State private var picked: String?

    private var files: [String] {
        guard let root = store.current?.path else { return [] }
        let fm = FileManager.default
        func folder(_ name: String) -> [String] {
            ((try? fm.contentsOfDirectory(atPath: root + "/" + name)) ?? []).filter { $0.hasSuffix(".md") }.sorted().reversed().map { name + "/" + $0 }
        }
        return (["PROJECT.md"] + folder("notes") + ["sources/read-log.md"] + folder("reports")).filter { fm.fileExists(atPath: root + "/" + $0) }
    }

    var body: some View {
        let all = files
        let file = picked.flatMap { all.contains($0) ? $0 : nil } ?? all.first
        let root = store.current?.path ?? ""
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 4) {
                        ForEach(all, id: \.self) { name in
                            Button { picked = name } label: {
                                Text(name).font(.system(size: 12, design: .monospaced)).lineLimit(1)
                                    .foregroundStyle(name == file ? Theme.text : Theme.dim)
                                    .padding(.horizontal, 10).frame(height: 26)
                                    .background(Capsule().fill(name == file ? Theme.ink.opacity(0.1) : .clear))
                                    .contentShape(Capsule())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                Button { NSWorkspace.shared.selectFile(file.map { root + "/" + $0 }, inFileViewerRootedAtPath: root) } label: {
                    Image(systemName: "folder")
                }
                .buttonStyle(IconButton(size: 26)).help("Show the project folder in Finder")
            }
            .padding(.horizontal, 12).frame(height: 40)
            Hairline()
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    if let file, let text = try? String(contentsOfFile: root + "/" + file, encoding: .utf8) {
                        MarkdownText(text: text)
                    }
                    Text("A project is a folder of Markdown, so it can be shared or kept in Git. Locations stay in private/ and are left out.")
                        .font(.system(size: 12)).foregroundStyle(Theme.faint).fixedSize(horizontal: false, vertical: true).padding(.top, 8)
                }
                .padding(24).frame(maxWidth: 720, alignment: .leading).frame(maxWidth: .infinity)
            }
        }
    }
}

// MARK: - Sources

/// A web page inside the app.
/// Lets the Sources tab read the page the browser is showing.
final class WebHandle: ObservableObject {
    weak var view: WKWebView?

    /// The visible text of the page, after any sign-in or check the person passed.
    func text() async -> String? {
        guard let view else { return nil }
        return try? await view.evaluateJavaScript("document.body ? document.body.innerText : ''") as? String
    }
}

struct WebPage: NSViewRepresentable {
    let url: URL?
    var handle: WebHandle?

    func makeNSView(context: Context) -> WKWebView {
        let view = WKWebView()
        view.allowsBackForwardNavigationGestures = true
        handle?.view = view
        return view
    }

    func updateNSView(_ view: WKWebView, context: Context) {
        if let url, view.url != url, context.coordinator.last != url {
            context.coordinator.last = url
            view.load(URLRequest(url: url))
        }
    }

    func makeCoordinator() -> Memory { Memory() }
    final class Memory { var last: URL? }
}

/// What the agent has read for this project, and a browser to open any of it yourself.
struct SourcesView: View {
    @EnvironmentObject var app: AppState
    @EnvironmentObject var store: ProjectStore
    @State private var address = ""
    @State private var handing = false
    @State private var handProblem: String?
    @StateObject private var web = WebHandle()

    /// Save what the person can see, then ask the agent to read it and log it.
    private func handOver(_ url: URL) {
        guard let root = store.current?.path else { return }
        handing = true
        handProblem = nil
        Task { @MainActor in
            defer { handing = false }
            guard let text = await web.text(), text.trimmingCharacters(in: .whitespacesAndNewlines).count > 200 else {
                handProblem = "This page shows almost no text yet. If it is asking you to sign in or prove you are human, do that first."
                return
            }
            let folder = URL(fileURLWithPath: root).appendingPathComponent("sources/pages")
            try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            let slug = (url.host ?? "page").replacingOccurrences(of: ".", with: "-")
            let name = "page-\(slug)-\(Int(Date().timeIntervalSince1970)).txt"
            do {
                try ("Address: \(url.absoluteString)\n" + text).write(to: folder.appendingPathComponent(name), atomically: true, encoding: .utf8)
            } catch {
                handProblem = error.localizedDescription
                return
            }
            app.ask("I opened \(url.absoluteString) myself and saved the text I could see. Read it with read_source using the name \(name), "
                    + "say what it shows about this project's candidates, and log it with log_source on the records it bears on, "
                    + "with its real title and status read. If it was logged before as could not open, logging it again under the same title replaces that entry.")
        }
    }

    private var sources: [Source] {
        var seen = Set<String>()
        return store.candidates.flatMap(\.sources).filter { seen.insert($0.title).inserted }
    }

    private func color(_ status: String) -> Color {
        status == "read" ? Theme.green : status == "could_not_open" ? Theme.amber : Theme.faint
    }

    private func go(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        let full = trimmed.contains("://") ? trimmed : trimmed.contains(".") && !trimmed.contains(" ")
            ? "https://" + trimmed : "https://duckduckgo.com/?q=" + (trimmed.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")
        app.browserURL = URL(string: full)
        address = full
    }

    var body: some View {
        let all = sources
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Image(systemName: "globe").font(.system(size: 12)).foregroundStyle(Theme.faint)
                TextField("Open a web address, or search", text: $address).textFieldStyle(.plain).font(.system(size: 13)).onSubmit { go(address) }
                if let url = app.browserURL {
                    Button { NSWorkspace.shared.open(url) } label: { Image(systemName: "arrow.up.forward.square") }
                        .buttonStyle(IconButton(size: 26)).help("Open in your browser")
                    if handing { ProgressView().controlSize(.small) }
                    Button { handOver(url) } label: {
                        Text("Give this page to the agent").font(.system(size: 12))
                    }
                    .buttonStyle(SecondaryButton()).disabled(handing)
                    .help("Saves the text you can see into the project, so the agent can read a page that refused it, and log it on the records.")
                }
            }
            .padding(.horizontal, 12).frame(height: 42)
            Hairline()
            if app.browserURL != nil {
                WebPage(url: app.browserURL, handle: web)
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        Text(all.isEmpty ? "No sources yet" : "\(all.count) sources on this project's records").font(.system(size: 18, weight: .semibold))
                        Text("Each source the agent logs appears here as read, could not open, or not relevant. Click one to open it. Publishers often refuse a program and let a person in, so the ones marked could not open are worth opening yourself.")
                            .font(.system(size: 13)).foregroundStyle(Theme.dim).lineSpacing(2).fixedSize(horizontal: false, vertical: true)
                        list(all)
                    }
                    .padding(24).frame(maxWidth: 720, alignment: .leading).frame(maxWidth: .infinity)
                }
            }
        }
        .onChange(of: app.browserURL) { address = app.browserURL?.absoluteString ?? "" }
        .overlay(alignment: .bottomLeading) {
            if app.browserURL != nil {
                HStack(spacing: 10) {
                    Button("Back to the list") { app.browserURL = nil }.buttonStyle(SecondaryButton())
                        .background(Capsule().fill(Theme.bg))
                    if let handProblem {
                        Text(handProblem).font(.system(size: 12)).foregroundStyle(Theme.amber)
                            .padding(.horizontal, 10).padding(.vertical, 6)
                            .background(RoundedRectangle(cornerRadius: 8).fill(Theme.bg))
                    }
                }
                .padding(12)
            }
        }
    }

    private func list(_ all: [Source]) -> some View {
        VStack(spacing: 0) {
            ForEach(Array(all.enumerated()), id: \.element.id) { index, source in
                if index > 0 { Hairline() }
                Button { if !source.link.isEmpty { go(source.link) } } label: {
                    HStack(alignment: .top, spacing: 10) {
                        Circle().fill(color(source.status)).frame(width: 7, height: 7).padding(.top, 6)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(source.title).font(.system(size: 13, weight: .medium)).multilineTextAlignment(.leading)
                            Text("\(source.status.replacingOccurrences(of: "_", with: " ").capitalized) · \(source.finding)")
                                .font(.system(size: 12)).foregroundStyle(Theme.dim).lineLimit(3).multilineTextAlignment(.leading)
                        }
                        Spacer(minLength: 6)
                        if !source.link.isEmpty { Image(systemName: "chevron.right").font(.system(size: 10, weight: .semibold)).foregroundStyle(Theme.faint) }
                    }
                    .padding(.vertical, 5)
                }
                .buttonStyle(RowButton()).disabled(source.link.isEmpty)
            }
        }
        .padding(4).panel(radius: 12)
    }
}

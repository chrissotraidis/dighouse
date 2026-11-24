import SwiftUI
import WebKit

/// The archaeology side of the window: the terrain, the candidate records, and the project's notes.
struct WorkspaceView: View {
    @EnvironmentObject var app: AppState
    @EnvironmentObject var store: ProjectStore

    var body: some View {
        VStack(spacing: 0) {
            // Words when there is room; icons with their counts when the workspace is narrow, never "M… N…".
            ViewThatFits(in: .horizontal) {
                tabBar(icons: false)
                tabBar(icons: true)
            }
            .animation(Motion.ease(0.15), value: app.tab)
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

extension WorkspaceView {
    private static let icons: [WorkTab: String] = [.map: "map", .records: "list.bullet.rectangle", .notes: "doc.text",
                                                     .sources: "books.vertical", .data: "externaldrive"]

    private func count(_ tab: WorkTab) -> Int? {
        if tab == .records, !store.candidates.isEmpty { return store.candidates.count }
        if tab == .sources, case let n = store.allSources.count, n > 0 { return n }
        return nil
    }

    fileprivate func tabBar(icons: Bool) -> some View {
        HStack(spacing: 4) {
            ForEach(WorkTab.allCases, id: \.self) { tab in
                Button { app.tab = tab } label: {
                    HStack(spacing: 5) {
                        if icons { Image(systemName: Self.icons[tab] ?? "circle") } else { Text(tab.rawValue) }
                        if let n = count(tab) { Text("\(n)").foregroundStyle(Theme.faint) }
                    }
                    .font(.system(size: 13 * Theme.scale, weight: .medium))
                    .foregroundStyle(app.tab == tab ? Theme.text : Theme.dim)
                    .padding(.horizontal, icons ? 9 : 12).frame(height: 30)
                    .background(Capsule().fill(app.tab == tab ? Theme.ink.opacity(0.1) : .clear))
                    .contentShape(Capsule())
                    .fixedSize()
                }
                .buttonStyle(.plain)
                .help(tab.rawValue)
                .accessibilityLabel(tab.rawValue + (count(tab).map { ", \($0)" } ?? ""))
                .coach(tab == .records ? .records : tab == .notes ? .notes : nil, radius: 15)
            }
            Spacer(minLength: 0)
        }
    }
}

/// A centred message for a pane with nothing in it yet.
private struct EmptyPane<Action: View>: View {
    let icon: String, title: String, text: String
    @ViewBuilder let action: () -> Action

    var body: some View {
        VStack(spacing: 12) {
            EmptyDrawing(name: icon, size: 76)
            Text(title).font(.system(size: 18 * Theme.scale, weight: .semibold)).padding(.top, 4)
            Text(text).font(.system(size: 13.5 * Theme.scale)).foregroundStyle(Theme.dim)
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
    /// The area picked from the menu (Area.id); nil shows the first area with tiles.
    @State private var areaChoice: String?
    @State private var zoom = 1.0
    @State private var pinchStart: Double?
    /// How far the map is moved from where it starts, in screen points, and where a drag began.
    @State private var pan = CGSize.zero
    @State private var dragStart: CGSize?
    /// The pointer over the map, and the map's size, for zooming toward the pointer.
    @State private var pointer: CGPoint?
    @State private var mapSize = CGSize.zero
    @State private var wheel: Any?
    /// How the tiles are drawn, and whether their outlines and the candidates show.
    @AppStorage("mapStyle") private var style = "composite"
    @State private var rendering = false
    @State private var showTiles = true
    @State private var showPins = true
    /// Drawing a line to cut a section: the mode, the line in map points, and the result.
    @State private var drawing = false
    @State private var line: (CGPoint, CGPoint)?
    @State private var cut: Cut?
    @State private var cutting = false
    /// Marking a spot by hand: the mode, the place clicked (a tile and where on it), the note, and what is happening.
    @State private var marking = false
    @State private var markAt: (tile: String, x: Double, y: Double)?
    @State private var markNote = ""
    @State private var markBusy: String?
    /// Or an area dragged out while marking: the box as drawn, and the tiles it covers.
    @State private var markBox: (CGPoint, CGPoint)?
    @State private var markTiles: [String] = []

    private struct Cut {
        let image: String
        let text: String
    }

    static let styles: [(id: String, name: String, icon: String)] = [
        ("composite", "Composite", "square.3.layers.3d"), ("hillshade", "Hillshade", "sun.max"),
        ("local_relief", "Local relief", "water.waves"), ("sky_view", "Sky view", "circle.dotted")]

    /// One area of the project's ground: everything fetched under one area name, or else one survey's ground that lies
    /// close together. Areas far apart are shown one at a time, so neither shrinks to specks.
    private struct Area: Identifiable {
        let id: String
        let name: String
        var terrains: [Terrain]
    }

    private static func near(_ a: Terrain, _ b: Terrain) -> Bool {
        a.epsg == b.epsg && a.box.count == 4 && b.box.count == 4 && abs(a.box[0] - b.box[0]) < 5000 && abs(a.box[1] - b.box[1]) < 5000
    }

    /// Two pieces of ground that cover much the same place, such as two flights over one site: shown apart, never on top
    /// of each other.
    private static func overlap(_ a: Terrain, _ b: Terrain) -> Bool {
        guard a.box.count == 4, b.box.count == 4 else { return false }
        let w = min(a.box[2], b.box[2]) - max(a.box[0], b.box[0]), h = min(a.box[3], b.box[3]) - max(a.box[1], b.box[1])
        guard w > 0, h > 0 else { return false }
        let smaller = min((a.box[2] - a.box[0]) * (a.box[3] - a.box[1]), (b.box[2] - b.box[0]) * (b.box[3] - b.box[1]))
        return w * h > 0.25 * smaller
    }

    private var areas: [Area] {
        var out: [Area] = []
        for t in store.terrains {
            if let name = t.area, !name.isEmpty {
                if let i = out.firstIndex(where: { $0.id == "named:" + name }) { out[i].terrains.append(t) }
                else { out.append(Area(id: "named:" + name, name: name, terrains: [t])) }
            } else if let i = out.firstIndex(where: { a in
                a.id.hasPrefix("ground:") && Self.near(a.terrains[0], t) && !a.terrains.contains { Self.overlap($0, t) && $0.dataset != t.dataset }
            }) {
                out[i].terrains.append(t)
            } else {
                out.append(Area(id: "ground:" + t.id, name: t.name, terrains: [t]))
            }
        }
        return out
    }

    /// A name short enough for the map's controls; the menu shows it whole.
    private static func shortName(_ name: String) -> String { name.count > 22 ? String(name.prefix(21)) + "…" : name }

    private func tiled(_ t: Terrain) -> Bool { store.tiles.contains { $0.terrain == t.id } }

    private var currentArea: Area? {
        let all = areas
        return all.first { $0.id == areaChoice } ?? all.first { $0.terrains.contains(where: tiled) } ?? all.first
    }

    /// The ground the map shows first: the current area's tiled ground, or its first if none is cut yet.
    private var current: String? { (currentArea?.terrains.first(where: tiled) ?? currentArea?.terrains.first)?.id }

    private var shownTerrains: [Terrain] { currentArea?.terrains.filter(tiled) ?? [] }

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

    /// An area's name in the menu: its name, its size, and whether it has been cut into tiles yet.
    private func label(_ a: Area) -> String {
        let km2 = a.terrains.reduce(0) { $0 + $1.areaKm2 }
        return "\(a.name), \(String(format: "%.1f", km2)) sq km" + (a.terrains.contains(where: tiled) ? "" : ", not cut into tiles")
    }

    var body: some View {
        if store.tiles.isEmpty, let ready = store.terrains.max(by: { $0.areaKm2 < $1.areaKm2 }) {
            EmptyPane(icon: "dig.mound", title: "The ground is ready",
                      text: ready.groundPerM2 > 0
                        ? "The bare ground is built: \(String(format: "%.1f", ready.areaKm2)) sq km at \(String(format: "%.1f", ready.groundPerM2)) ground returns per square metre. Cut it into tiles to look at it here."
                        : "The bare ground is built: \(String(format: "%.1f", ready.areaKm2)) sq km from a national agency's ready-made ground model. Cut it into tiles to look at it here.") {
                Button("Cut into tiles") {
                    app.ask("Cut \(ready.id) into tiles with make_tiles, then tell me how many tiles there are and how many have too little ground data to read.")
                }
                .buttonStyle(PrimaryButton())
            }
        } else if store.tiles.isEmpty, store.screenedBefore != nil {
            // A shared project: nothing to draw, and the record is the place to look.
            EmptyPane(icon: "dig.mound", title: "The ground stayed on the other Mac",
                      text: "A shared project comes without its downloads and locations. The research record says what the ground showed, tile by tile. Get the ground again only if you want to look at it yourself.") {
                Button("Research record") { app.showNotes("record") }.buttonStyle(PrimaryButton())
            }
        } else if store.tiles.isEmpty {
            EmptyPane(icon: "dig.mound", title: "No ground yet",
                      text: "Ask the agent to find open lidar for the project's area. The bare ground appears here as it is fetched.") {
                Button("Get the ground") {
                    if let flow = ToolGuide.workflows.first(where: { $0.id == "terrain" }) { app.run(flow) }
                }
                .buttonStyle(PrimaryButton())
                // One control wears the tutorial's ring: the overview's button, or this one when only the workspace shows.
                .coach(app.layout == .workspace ? .getTerrain : nil)
            }
        } else {
            GeometryReader { geo in
                let tiles = shown
                if tiles.isEmpty, let id = current {
                    // A terrain picked from the menu that has not been cut yet.
                    EmptyPane(icon: "dig.grid", title: "Not cut into tiles yet",
                              text: "This ground is built but has no tiles, so there is nothing to show here yet.") {
                        Button("Cut into tiles") {
                            app.ask("Cut \(id) into tiles with make_tiles, then tell me how many tiles there are and how many have too little ground data to read.")
                        }
                        .buttonStyle(PrimaryButton())
                    }
                    .frame(width: geo.size.width, height: geo.size.height)
                }
                let spots = placed
                let (width, height, fit, origin) = frame(spots, in: geo.size)
                let scale = fit * zoom
                ZStack(alignment: .topLeading) {
                    ZStack(alignment: .topLeading) {
                        ForEach(spots, id: \.tile.id) { spot in
                            TileView(tile: spot.tile, selected: store.selectedTile == spot.tile.id, style: style, outlined: showTiles)
                                .frame(width: spot.w * scale, height: spot.h * scale)
                                .offset(x: spot.x * scale, y: spot.y * scale)
                                .onTapGesture {
                                    guard !drawing else { return }
                                    store.selectedTile = spot.tile.id
                                    store.selectedCandidate = nil
                                }
                        }
                        if showPins {
                            // With many finds, labels show on the one pointed at or chosen, or once zoomed in.
                            let quiet = store.candidates.filter { !$0.inLayer }.count > 15 && zoom < 2
                            // Looked up by tile once, not searched for each pin: a sweep leaves over a thousand finds.
                            let byTile = Dictionary(spots.map { ($0.tile.id, $0) }, uniquingKeysWith: { a, _ in a })
                            // Hundreds of finds kept on the map would each be one more element for VoiceOver to read
                            // (and they stalled the accessibility tree at 1,246); the finds put to a person stay.
                            let quietLayer = store.candidates.filter(\.inLayer).count > 50
                            ForEach(store.candidates) { c in
                                if let spot = byTile[c.tile] {
                                    Pin(label: c.id, selected: store.selectedCandidate == c.id, onMap: c.inLayer, quiet: quiet)
                                        .offset(x: (spot.x + c.x * spot.w) * scale - 8,
                                                y: (spot.y + c.y * spot.h) * scale - 8)
                                        .onTapGesture(count: 2) { app.showRecords(c.id) }
                                        .onTapGesture {
                                            store.selectedCandidate = c.id
                                            store.selectedTile = c.tile
                                        }
                                        .help("Click to see it, double-click to open its record")
                                        .accessibilityHidden(quietLayer && c.inLayer)
                                }
                            }
                        }
                        if let line {
                            Path { p in p.move(to: line.0); p.addLine(to: line.1) }
                                .stroke(Theme.accent, style: StrokeStyle(lineWidth: 2.5, lineCap: .round, dash: cutting ? [6, 4] : []))
                            ForEach([line.0, line.1].indices, id: \.self) { i in
                                Circle().fill(Theme.accent).frame(width: 9, height: 9)
                                    .position(i == 0 ? line.0 : line.1)
                            }
                        }
                        if drawing {
                            // Catches the drag while drawing; the tiles underneath keep their clicks otherwise.
                            Color.white.opacity(0.001)
                                .gesture(DragGesture(minimumDistance: 4)
                                    .onChanged { g in line = (g.startLocation, g.location) }
                                    .onEnded { g in cutSection(from: g.startLocation, to: g.location, spots: spots, scale: scale) })
                        }
                        if marking {
                            // Catches one click while marking (the place becomes a tile and a point on it), or a drag
                            // that boxes an area (the tiles it covers).
                            Color.white.opacity(0.001)
                                .gesture(DragGesture(minimumDistance: 6)
                                    .onChanged { g in markBox = (g.startLocation, g.location); markAt = nil; markTiles = [] }
                                    .onEnded { g in
                                        let a = g.startLocation, b = g.location
                                        let box = CGRect(x: min(a.x, b.x) / scale, y: min(a.y, b.y) / scale,
                                                         width: abs(a.x - b.x) / scale, height: abs(a.y - b.y) / scale)
                                        markTiles = spots.filter { CGRect(x: $0.x, y: $0.y, width: $0.w, height: $0.h).intersects(box) }.map(\.tile.id)
                                        if markTiles.isEmpty { markBox = nil }
                                    }
                                    .exclusively(before: SpatialTapGesture().onEnded { e in
                                        markBox = nil
                                        markTiles = []
                                        let m = (x: e.location.x / scale, y: e.location.y / scale)
                                        if let s = spots.first(where: { m.x >= $0.x && m.x <= $0.x + $0.w && m.y >= $0.y && m.y <= $0.y + $0.h }) {
                                            markAt = (s.tile.id, (m.x - s.x) / s.w, (m.y - s.y) / s.h)
                                        }
                                    }))
                        }
                        if let box = markBox {
                            Path { p in p.addRect(CGRect(x: min(box.0.x, box.1.x), y: min(box.0.y, box.1.y),
                                                         width: abs(box.0.x - box.1.x), height: abs(box.0.y - box.1.y))) }
                                .stroke(Theme.accent, style: StrokeStyle(lineWidth: 2, dash: [6, 4]))
                                .allowsHitTesting(false)
                        }
                        if let at = markAt, let s = spots.first(where: { $0.tile.id == at.tile }) {
                            Circle().strokeBorder(Theme.accent, lineWidth: 2.5).frame(width: 18, height: 18)
                                .position(x: (s.x + at.x * s.w) * scale, y: (s.y + at.y * s.h) * scale)
                                .allowsHitTesting(false)
                        }
                    }
                    .frame(width: width * scale, height: height * scale, alignment: .topLeading)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .offset(x: origin.x + pan.width, y: origin.y + pan.height)
                }
                .frame(width: geo.size.width, height: geo.size.height, alignment: .topLeading)
                .contentShape(Rectangle())
                .clipped()
                // Drag the ground to move it. While drawing a slice, the drag draws instead.
                .simultaneousGesture(DragGesture(minimumDistance: 3)
                    .onChanged { g in
                        guard !drawing, !marking else { return }
                        if dragStart == nil { dragStart = pan }
                        pan = clamped(CGSize(width: (dragStart?.width ?? 0) + g.translation.width, height: (dragStart?.height ?? 0) + g.translation.height))
                    }
                    .onEnded { _ in dragStart = nil })
                .onContinuousHover(coordinateSpace: .local) { phase in
                    if case .active(let p) = phase { pointer = p } else { pointer = nil }
                }
                .onAppear { mapSize = geo.size }
                .onChange(of: geo.size) { _, size in mapSize = size }
            }
            .gesture(MagnifyGesture()
                .onChanged { g in
                    if pinchStart == nil { pinchStart = zoom }
                    zoom(to: (pinchStart ?? 1) * g.magnification, at: pointer)
                }
                .onEnded { _ in pinchStart = nil })
            .onAppear(perform: listenToWheel)
            .onDisappear {
                if let wheel { NSEvent.removeMonitor(wheel) }
                wheel = nil
            }
            .overlay(alignment: .top) {
                // The key sits beside the controls when there is room, and under them when the pane is narrow.
                ViewThatFits(in: .horizontal) {
                    HStack(alignment: .top, spacing: 12) { controls(); Spacer(minLength: 0); legend }
                    VStack(alignment: .leading, spacing: 8) { fittedControls; legend }.frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(12)
            }
            .overlay(alignment: .bottomLeading) {
                markAt != nil || !markTiles.isEmpty ? AnyView(markPanel) : cut == nil && !cutting ? AnyView(selection) : AnyView(cutCard)
            }
            .overlay(alignment: .top) {
                if drawing && line == nil && !cutting {
                    Text(store.selectedCandidate.map { "Drag a line across the ground. The slice goes on \($0)'s record." }
                         ?? "Drag a line across the ground, starting and ending on the ground around the shape.")
                        .font(.system(size: 12.5 * Theme.scale)).padding(.horizontal, 12).frame(height: 30)
                        .background(Capsule().fill(Theme.raised)).overlay(Capsule().strokeBorder(Theme.line))
                        .padding(.top, 56)
                }
            }
            .task(id: style) { await render() }
            // Another area, or another project, starts whole and centred.
            .onChange(of: "\(store.current?.path ?? "") \(currentArea?.id ?? "")") { _, _ in zoom = 1; pan = .zero }
            // A find chosen elsewhere (Records, Decide) on another area brings that area onto the map.
            .onChange(of: store.selectedTile) { _, tile in
                guard let tile, let terrain = store.tiles.first(where: { $0.id == tile })?.terrain,
                      let area = areas.first(where: { $0.terrains.contains { $0.id == terrain } }), area.id != currentArea?.id else { return }
                areaChoice = area.id
            }
        }
    }

    /// The controls in one row with full names, then with short names, then in two rows: never cut off.
    private var fittedControls: some View {
        ViewThatFits(in: .horizontal) {
            controls()
            controls(short: true)
            VStack(alignment: .leading, spacing: 6) { controls(short: true, part: 1); controls(short: true, part: 2) }
        }
    }

    /// part 0 is the whole row; 1 is zoom and how the ground is drawn; 2 is the rest.
    private func controls(short: Bool = false, part: Int = 0) -> some View {
        HStack(spacing: 2) {
            if part != 2 { zoomAndStyle(short: short) }
            if part != 1 { overlays(short: short) }
        }
        .padding(3).background(RoundedRectangle(cornerRadius: 11).fill(Theme.bg.opacity(0.92)))
        .overlay(RoundedRectangle(cornerRadius: 11).strokeBorder(Theme.line))
        .fixedSize()
    }

    @ViewBuilder private func zoomAndStyle(short: Bool) -> some View {
            Button { zoom(to: zoom / 1.5, at: nil) } label: { Image(systemName: "minus") }
                .buttonStyle(IconButton(size: 28)).disabled(zoom <= 1).help("Zoom out. The scroll wheel zooms too.")
            Button { zoom(to: zoom * 1.5, at: nil) } label: { Image(systemName: "plus") }
                .buttonStyle(IconButton(size: 28)).help("Zoom in. The scroll wheel zooms toward the pointer.")
            Button { withAnimation(.easeOut(duration: 0.2)) { zoom = 1; pan = .zero } } label: {
                Image(systemName: "arrow.down.right.and.arrow.up.left")
            }
            .buttonStyle(IconButton(size: 28)).disabled(zoom == 1 && pan == .zero).help("Fit the whole area")
            PillMenu(title: short ? "View" : Self.styles.first { $0.id == style }?.name ?? "View", quiet: true, width: 200) {
                [.header("How the ground is drawn")]
                    + Self.styles.map { s in MenuEntry(title: s.name, icon: s.icon, checked: s.id == style) { style = s.id } }
            }
            .help("How the ground is drawn: sky view shows low banks and ditches best")
            if rendering { DigIndicator().padding(.horizontal, 4) }
    }

    @ViewBuilder private func overlays(short: Bool) -> some View {
            Button { showTiles.toggle() } label: { Glyph(name: "dig.grid", size: 14 * Theme.scale) }
                .buttonStyle(IconButton(size: 28, active: showTiles)).help(showTiles ? "Hide the tile outlines" : "Show the tile outlines")
            Button { showPins.toggle() } label: { Image(systemName: "mappin") }
                .buttonStyle(IconButton(size: 28, active: showPins)).help(showPins ? "Hide the finds" : "Show the finds")
            Button {
                drawing.toggle()
                marking = false
                line = nil
                cut = nil
            } label: { Image(systemName: "line.diagonal") }
                .buttonStyle(IconButton(size: 28, active: drawing)).help("Draw a line to cut a slice through the ground")
            Button {
                marking.toggle()
                drawing = false
                markAt = nil
                markBox = nil
                markTiles = []
            } label: { Image(systemName: "mappin.and.ellipse") }
                .buttonStyle(IconButton(size: 28, active: marking))
                .help("Mark what you see: click a spot and it gets the usual checks, or drag a box and the agent looks closely at that area")
            let all = areas
            if all.count > 1 {
                PillMenu(title: (short ? "" : "Show: ") + Self.shortName(currentArea?.name ?? "Ground"), quiet: true, width: 340) {
                    [.header("\(all.count) areas in this project")]
                        + all.map { a in MenuEntry(title: label(a), icon: "dig.mound", checked: a.id == currentArea?.id) { areaChoice = a.id } }
                }
                .help("Which area of the project the map shows")
            }
    }

    /// Render every tile in the chosen style, once, through the tools.
    /// The ground's size in metres, the scale that fits it in the pane, and where it sits at that scale, under the controls.
    private func frame(_ spots: [Placed], in size: CGSize) -> (Double, Double, Double, CGPoint) {
        let width = max(spots.map { $0.x + $0.w }.max() ?? 1, 1)
        let height = max(spots.map { $0.y + $0.h }.max() ?? 1, 1)
        let fit = max(0.0001, min((size.width - 32) / width, (size.height - 72) / height))
        let origin = CGPoint(x: (size.width - width * fit) / 2, y: 56 + max(0, (size.height - 72 - height * fit) / 2))
        return (width, height, fit, origin)
    }

    /// Zoom to a level between the whole area and eight times closer, keeping the ground under the pointer (or the
    /// middle of the pane) where it is.
    private func zoom(to level: Double, at point: CGPoint?) {
        let next = min(8, max(1, level))
        guard next != zoom else { return }
        let origin = frame(placed, in: mapSize).3
        let p = point ?? CGPoint(x: mapSize.width / 2, y: mapSize.height / 2)
        let k = next / zoom
        pan = next == 1 ? .zero : CGSize(width: p.x - origin.x - (p.x - origin.x - pan.width) * k,
                                         height: p.y - origin.y - (p.y - origin.y - pan.height) * k)
        zoom = next
        pan = clamped(pan)
    }

    /// Scrolling up and down zooms toward the pointer, with a mouse wheel, a Magic Mouse or two fingers on a trackpad;
    /// scrolling sideways and dragging move the map; a pinch zooms. Only while the pointer is over the map, so the rest
    /// of the window scrolls as usual.
    private func listenToWheel() {
        guard wheel == nil else { return }
        wheel = NSEvent.addLocalMonitorForEvents(matching: .scrollWheel) { event in
            guard let p = pointer, event.window?.isKeyWindow == true else { return event }
            // Pushing the wheel away, or two fingers up, zooms in, whichever way the Mac is set to scroll.
            let flip: CGFloat = event.isDirectionInvertedFromDevice ? -1 : 1
            let dx = event.scrollingDeltaX * flip, dy = event.scrollingDeltaY * flip
            if abs(dy) >= abs(dx), dy != 0 {
                // A wheel notch is about one line; a trackpad or Magic Mouse reports points, many to a gesture.
                let step = event.hasPreciseScrollingDeltas ? exp(Double(dy) * 0.006) : pow(1.15, Double(dy))
                zoom(to: zoom * step, at: p)
            } else if dx != 0 {
                pan = clamped(CGSize(width: pan.width + dx * (event.hasPreciseScrollingDeltas ? 1 : 12), height: pan.height))
            }
            return nil
        }
    }

    /// Keep some of the ground in view, however far it is dragged.
    private func clamped(_ offset: CGSize) -> CGSize {
        let (width, height, fit, origin) = frame(placed, in: mapSize)
        let w = width * fit * zoom, h = height * fit * zoom, keep = 80.0
        let x = min(max(offset.width, keep - origin.x - w), mapSize.width - keep - origin.x)
        let y = min(max(offset.height, keep - origin.y - h), mapSize.height - keep - origin.y)
        return CGSize(width: x, height: y)
    }

    private func render() async {
        guard style != "composite", let root = store.current?.path else { return }
        rendering = true
        _ = try? await app.engine.callTool("render_tiles", ["project": root, "style": style])
        rendering = false
        store.objectWillChange.send()
    }

    /// Turn a line drawn on the map into a section through the tile under its start, filed on a candidate's record
    /// when one is selected or sits close to the line.
    private func cutSection(from a: CGPoint, to b: CGPoint, spots: [Placed], scale: Double) {
        guard let root = store.current?.path, hypot(b.x - a.x, b.y - a.y) > 8 else { line = nil; return }
        let am = (x: a.x / scale, y: a.y / scale), bm = (x: b.x / scale, y: b.y / scale)
        guard let spot = spots.first(where: { am.x >= $0.x && am.x <= $0.x + $0.w && am.y >= $0.y && am.y <= $0.y + $0.h }) else {
            cut = Cut(image: "", text: "Start the line on a tile.")
            return
        }
        func fraction(_ p: (x: Double, y: Double)) -> (Double, Double) { ((p.x - spot.x) / spot.w, (p.y - spot.y) / spot.h) }
        let (x1, y1) = fraction(am), (x2, y2) = fraction(bm)
        // The record it belongs to: the selected candidate, or one whose pin is within 25 m of the line's middle.
        let mid = (x: (am.x + bm.x) / 2, y: (am.y + bm.y) / 2)
        let near = store.candidates.first { c in
            guard let s = spots.first(where: { $0.tile.id == c.tile }) else { return false }
            return hypot(s.x + c.x * s.w - mid.x, s.y + c.y * s.h - mid.y) < 25
        }
        let candidate = store.selectedCandidate ?? near?.id
        var args: JSON = ["project": root, "tile": spot.tile.id, "x1": x1, "y1": y1, "x2": x2, "y2": y2]
        if let candidate { args["candidate"] = candidate }
        cutting = true
        cut = nil
        Task { @MainActor in
            defer { cutting = false; drawing = false }
            do {
                let reply = try await app.engine.callTool("cut_section", args)
                let info = (try? JSONSerialization.jsonObject(with: Data(reply.utf8))) as? JSON
                    ?? (((try? JSONSerialization.jsonObject(with: Data(reply.utf8))) as? [Any])?.first as? JSON) ?? [:]
                let height = info["feature_height_m"] as? Double
                let length = info["length_m"] as? Double
                var words = [String]()
                if let length { words.append("\(Int(length.rounded())) m long") }
                if let height { words.append("rises \(String(format: "%.2f", height)) m above the line between its ends") }
                if let inGround = info["in_ground"] as? Bool { words.append(inGround ? "in the ground returns" : "not dense in the ground returns") }
                let filed = candidate.map { "Filed on \($0)'s record." } ?? "Not filed on a record; select a find first to file it."
                let image = candidate.map { "\(root)/candidates/img/\($0)-section.png" } ?? "\(root)/data/tiles/\(spot.tile.id)-section.png"
                cut = Cut(image: image, text: (words.isEmpty ? "" : words.joined(separator: ", ").prefix(1).uppercased() + words.joined(separator: ", ").dropFirst() + ". ") + filed)
                store.reloadIfChanged()
            } catch {
                cut = Cut(image: "", text: "Could not cut the slice: \(error.localizedDescription)")
            }
        }
    }

    @ViewBuilder private var cutCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(cutting ? "Cutting the slice…" : "Slice").font(.system(size: 13.5 * Theme.scale, weight: .semibold))
                if cutting { DigIndicator() }
                Spacer()
                Button { cut = nil; line = nil } label: { Image(systemName: "xmark").accessibilityLabel("Close") }.buttonStyle(IconButton(size: 22))
            }
            if let cut {
                if !cut.image.isEmpty, let img = Images.load(cut.image) {
                    Image(nsImage: img).resizable().aspectRatio(contentMode: .fit).clipShape(RoundedRectangle(cornerRadius: 6))
                }
                Text(cut.text).font(.system(size: 12.5 * Theme.scale)).foregroundStyle(Theme.dim).fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(12).frame(width: 360, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 14).fill(Theme.raised))
        .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(Theme.line))
        .shadow(color: .black.opacity(0.35), radius: 14, y: 4)
        .padding(12)
    }

    private var legend: some View {
        HStack(spacing: 12) {
            key(Theme.green, "Looks built")
            key(Theme.amber, "Possible")
            key(Theme.faint, "Not looked at")
        }
        .font(.system(size: 11.5 * Theme.scale)).foregroundStyle(Theme.dim)
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

    /// What a person says about a spot they clicked, before it becomes a find.
    @ViewBuilder private var markPanel: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(area ? "Mark an area" : "Mark a spot").font(.system(size: 13.5 * Theme.scale, weight: .semibold))
                Spacer()
                Button { markAt = nil; markBox = nil; markTiles = [] } label: { Image(systemName: "xmark").accessibilityLabel("Close") }
                    .buttonStyle(IconButton(size: 22)).disabled(markBusy != nil)
            }
            Text(!area ? "Say what you see. It becomes a find in your name; a slice and the open maps are checked now, and the agent adds a second opinion and the records."
                 : tooBig ? "\(markTiles.count) tiles. Draw a smaller box, at most \(Self.areaLimit) tiles, so the agent can look at each closely."
                 : "\(markTiles.count) \(markTiles.count == 1 ? "tile" : "tiles"). Say what you see. The agent looks closely at each in two views, marks what it finds, checks it and suggests what it is.")
                .font(.system(size: 12.5 * Theme.scale)).foregroundStyle(Theme.dim).fixedSize(horizontal: false, vertical: true)
            TextField(area ? "Banks along the ridge, maybe an enclosure" : "A low round mound by the stream", text: $markNote)
                .textFieldStyle(.plain).font(.system(size: 13 * Theme.scale))
                .padding(8).background(RoundedRectangle(cornerRadius: 8).fill(Theme.side))
                .onSubmit { if !markNote.trimmingCharacters(in: .whitespaces).isEmpty, !tooBig { area ? markArea() : markSpot() } }
            HStack(spacing: 8) {
                Button(area ? "Ask the agent to look" : "Mark it and check") { area ? markArea() : markSpot() }
                    .buttonStyle(PrimaryButton())
                    .disabled(markBusy != nil || tooBig || markNote.trimmingCharacters(in: .whitespaces).isEmpty || !app.engine.ready)
                if let markBusy {
                    DigIndicator(size: 12)
                    Text(markBusy).font(.system(size: 12 * Theme.scale)).foregroundStyle(Theme.faint)
                }
            }
        }
        .padding(12).frame(width: 340, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 14).fill(Theme.raised))
        .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(Theme.line))
        .shadow(color: .black.opacity(0.35), radius: 14, y: 4)
    }

    private var area: Bool { markAt == nil && !markTiles.isEmpty }
    private var tooBig: Bool { area && markTiles.count > Self.areaLimit }
    /// The most tiles one marked area asks the agent to look at closely, as many as a timed session's close look.
    static let areaLimit = 24

    /// Ask the agent to look closely at the tiles under a box the person drew, by their names (no places).
    private func markArea() {
        let note = markNote.trimmingCharacters(in: .whitespacesAndNewlines), tiles = markTiles
        app.ask("A person marked an area of \(tiles.count) \(tiles.count == 1 ? "tile" : "tiles") by hand: \"\(note)\". "
                + "Look closely at each in two views (view_tile), record a verdict and mark every feature you see; then add_measured_rises "
                + "and check_finds once, and suggest a decision on each new find. Tiles: \(tiles.joined(separator: ", ")).",
                title: "A look at a marked area")
        markBox = nil
        markTiles = []
        marking = false
        markNote = ""
    }

    /// Open a find at the clicked spot in the person's name, slice it and check open maps, then ask the agent for the
    /// checks that need a model: a second opinion, the records, the literature and a suggested decision.
    private func markSpot() {
        guard let root = store.current?.path, let at = markAt else { return }
        let note = markNote.trimmingCharacters(in: .whitespacesAndNewlines)
        let who = app.userName.isEmpty ? "a person" : "a person, \(app.userName)"
        markBusy = "Marking…"
        Task { @MainActor in
            defer { markBusy = nil }
            let args: JSON = ["project": root, "tile": at.tile, "x": at.x, "y": at.y,
                              "name": "Marked by hand: " + String(note.prefix(48)), "note": note, "model": who]
            guard let reply = try? await app.engine.callTool("flag_candidate", args) else { return }
            let info = (try? JSONSerialization.jsonObject(with: Data(reply.utf8))) as? JSON
                ?? (((try? JSONSerialization.jsonObject(with: Data(reply.utf8))) as? [Any])?.first as? JSON) ?? [:]
            guard let id = info["candidate"] as? String else { return }
            markBusy = "Cutting a slice and checking open maps…"
            _ = try? await app.engine.callTool("check_finds", ["project": root, "candidates": id])
            markAt = nil
            marking = false
            markNote = ""
            store.selectedCandidate = id
            store.selectedTile = at.tile
            app.ask("A person marked \(id) by hand: \"\(note)\". Its slice and the open maps are checked. Add the checks still missing: a second opinion from a different model, the records check and a literature search, then suggest a decision. Leave its place and name as they are.",
                    title: "Checks for \(id)")
        }
    }

    @ViewBuilder private var selection: some View {
        let tile = store.tiles.first { $0.id == store.selectedTile }
        let candidate = store.candidates.first { $0.id == store.selectedCandidate }
        if tile != nil || candidate != nil {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    if let candidate {
                        Text("\(candidate.id) \(candidate.name)").font(.system(size: 13.5 * Theme.scale, weight: .semibold)).lineLimit(1)
                        Badge(text: candidate.statusLabel, color: candidate.statusColor)
                    } else if let tile {
                        Text("Tile \(tile.short)").font(.system(size: 13.5 * Theme.scale, weight: .semibold))
                        if let verdict = tile.verdict { Badge(text: verdict.capitalized, color: verdict == "built" ? Theme.accent : Theme.dim) }
                    }
                    Spacer(minLength: 4)
                    Button {
                        store.selectedTile = nil
                        store.selectedCandidate = nil
                    } label: { Image(systemName: "xmark").accessibilityLabel("Close") }.buttonStyle(IconButton(size: 22))
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
                        .font(.system(size: 12.5 * Theme.scale)).foregroundStyle(Theme.dim).lineLimit(4)
                        .fixedSize(horizontal: false, vertical: true)
                    if tile.status != "unreadable" {
                        Button {
                            app.ask("Look at tile \(tile.id) in two renderings and tell me what you see. Record your verdict.")
                        } label: { Label("Ask the agent", glyph: "dig.trowel") }
                        .buttonStyle(SecondaryButton())
                        .help("Starts a chat in which the agent looks at this tile in two renderings and records a verdict.")
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
    var style = "composite"
    var outlined = true

    var body: some View {
        let base = "\(store.current?.path ?? "")/data/tiles/\(tile.id)-"
        ZStack {
            if let image = Images.load(base + style + ".png") ?? Images.load(base + "composite.png") {
                Image(nsImage: image).resizable().interpolation(.medium)
            } else {
                Rectangle().fill(Theme.side)
            }
            if tile.status == "unreadable" {
                Rectangle().fill(.black.opacity(0.5))
                Image(systemName: "eye.slash").foregroundStyle(Theme.dim)
            } else if tile.status == "unscreened", outlined {
                Rectangle().fill(.black.opacity(0.3))
            }
            if outlined || selected {
                Rectangle().strokeBorder(outline, lineWidth: selected ? 2 : (tile.verdict == "built" || tile.verdict == "possible" ? 1.5 : 0.5))
            }
        }
        .contentShape(Rectangle())
    }

    private var outline: Color {
        if selected { return .white }
        switch tile.verdict {
        case "built": return Theme.green   // not the accent, which is tan in Canopy and too close to "possible"
        case "possible": return Theme.amber
        default: return .white.opacity(0.1)
        }
    }
}

private struct Pin: View {
    let label: String
    let selected: Bool
    /// A measured rise kept on the map: a small dot with no label, so it does not crowd the finds put to a person.
    var onMap = false
    /// Many finds and zoomed out: the label shows only when pointed at.
    var quiet = false
    @State private var hovering = false

    var body: some View {
        Group {
            if onMap && !selected && !hovering {
                Circle().fill(.white.opacity(0.75)).frame(width: 7, height: 7)
                    .overlay(Circle().strokeBorder(.black.opacity(0.5), lineWidth: 1))
                    .frame(width: 16, height: 16).contentShape(Rectangle())
            } else if quiet && !selected && !hovering {
                Circle().fill(.white).frame(width: 12, height: 12)
                    .overlay(Circle().strokeBorder(.black.opacity(0.55), lineWidth: 1.5))
                    .frame(width: 16, height: 16).contentShape(Rectangle())
            } else {
                labelled
            }
        }
        .onHover { hovering = $0 }
        .accessibilityLabel(label)
    }

    private var labelled: some View {
        HStack(spacing: 4) {
            Circle().fill(selected ? Theme.accent : .white).frame(width: 16, height: 16)
                .overlay(Circle().strokeBorder(.black.opacity(0.55), lineWidth: 1.5))
            Text(label).font(.system(size: 11 * Theme.scale, weight: .semibold)).foregroundStyle(.white)
                .padding(.horizontal, 6).frame(height: 18)
                .background(Capsule().fill(selected ? Theme.accent : .black.opacity(0.78)))
        }
        .fixedSize().contentShape(Rectangle())
    }
}

// MARK: - Records

struct RecordsView: View {
    @EnvironmentObject var app: AppState
    @EnvironmentObject var store: ProjectStore
    @EnvironmentObject var engine: Engine
    /// Tiles whose folded measured rises are open in the list.
    @State private var openTiles = Set<String>()

    /// The chosen find, or else the first that needs a person, in the order the list shows them.
    private var current: Candidate? {
        store.candidates.first { $0.id == store.selectedCandidate }
            ?? Candidate.Group.allCases.lazy.compactMap { g in store.candidates.first { $0.group == g } }.first
    }

    var body: some View {
        if store.candidates.isEmpty {
            EmptyPane(icon: "dig.brush", title: "No finds yet",
                      text: "When the agent marks something that looks built, its record appears here with its pictures and checks.") {
                if let next = app.nextStep {
                    Button(next.title) { app.run(next) }.buttonStyle(PrimaryButton())
                }
            }
        } else {
            GeometryReader { geo in
                HStack(spacing: 0) {
                    if geo.size.width >= 760 {
                        ScrollView {
                            list.padding(8)
                        }
                        .frame(width: 256)
                        Hairline(vertical: true)
                    }
                    ScrollView {
                        VStack(alignment: .leading, spacing: 0) {
                            if geo.size.width < 760, let c = current {
                                PillMenu(title: "\(c.id) \(c.name)", width: 340) {
                                    store.candidates.map { other in
                                        MenuEntry(title: "\(other.id) \(other.name)", icon: "mappin", checked: other.id == c.id) {
                                            store.selectedCandidate = other.id
                                        }
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
        }
    }

    /// The finds, grouped by what they probably are. A blind test lists them plainly, since it is scored, not decided.
    @ViewBuilder private var list: some View {
        VStack(alignment: .leading, spacing: 2) {
            if store.isBlindTest {
                Text("A blind test. Its finds are scored against the published features, so none needs a decision.")
                    .font(.system(size: 11.5 * Theme.scale)).foregroundStyle(Theme.faint)
                    .fixedSize(horizontal: false, vertical: true).padding(.horizontal, 10).padding(.vertical, 6)
                ForEach(store.candidates) { c in listRow(c) }
            } else {
                ForEach(Candidate.Group.allCases, id: \.self) { group in
                    let items = store.candidates.filter { $0.group == group }
                    if !items.isEmpty {
                        groupHeader(group, count: items.count)
                        if group == .notAncient || group == .layer { routineRows(items) } else { ForEach(items) { c in listRow(c) } }
                    }
                }
            }
        }
    }

    private func groupHeader(_ group: Candidate.Group, count: Int) -> some View {
        // The title keeps its whole line, so its count always shows; the group's button sits under it.
        VStack(alignment: .leading, spacing: 3) {
            Text("\(group.title) · \(count)").font(.system(size: 11.5 * Theme.scale, weight: .semibold)).foregroundStyle(Theme.faint)
                .lineLimit(1)
            if group.confirmable {
                Button("Agree in bulk") { app.openDecide() }
                    .buttonStyle(.plain).font(.system(size: 11.5 * Theme.scale, weight: .semibold)).foregroundStyle(Theme.tan)
                    .help("Look over their pictures in Decide and agree with them together. Your name and each find's reason go into its record.")
            } else if group == .open, let flow = ToolGuide.workflows.first(where: { $0.id == "decide" }), app.state(of: flow).ready {
                Button("Suggest") { app.run(flow) }
                    .buttonStyle(.plain).font(.system(size: 11.5 * Theme.scale, weight: .semibold)).foregroundStyle(Theme.tan)
                    .help("The agent reads each record and its sources and says what each find probably is, and why.")
            }
        }
        .padding(.horizontal, 10).padding(.top, 12).padding(.bottom, 4)
    }

    /// The routine group: finds a model marked, one row each, then the measured rises folded into one row per tile.
    @ViewBuilder private func routineRows(_ items: [Candidate]) -> some View {
        let seen = items.filter { !$0.flaggedBy.hasPrefix("measured") }
        let rises = Dictionary(grouping: items.filter { $0.flaggedBy.hasPrefix("measured") }, by: \.tile)
        ForEach(seen) { c in listRow(c) }
        ForEach(rises.keys.sorted(), id: \.self) { tile in
            let group = rises[tile] ?? []
            if group.count == 1, let only = group.first {
                listRow(only)
            } else {
                Button { if openTiles.contains(tile) { openTiles.remove(tile) } else { openTiles.insert(tile) } } label: {
                    HStack(spacing: 10) {
                        Image(systemName: openTiles.contains(tile) ? "chevron.down" : "chevron.right")
                            .font(.system(size: 9 * Theme.scale, weight: .semibold)).foregroundStyle(Theme.faint).frame(width: 7)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("\(group.count) measured rises").font(.system(size: 13 * Theme.scale)).lineLimit(1)
                            Text("Tile \(tile.split(separator: "-").last.map(String.init) ?? tile)").font(.system(size: 11.5 * Theme.scale))
                                .foregroundStyle(Theme.faint).lineLimit(1)
                        }
                    }
                    .padding(.vertical, 5)
                }
                .buttonStyle(RowButton(selected: false))
                if openTiles.contains(tile) {
                    ForEach(group) { c in listRow(c).padding(.leading, 12) }
                }
            }
        }
    }

    private func listRow(_ c: Candidate) -> some View {
        Button { store.selectedCandidate = c.id } label: {
            HStack(spacing: 10) {
                Circle().fill(c.statusColor).frame(width: 7, height: 7)
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(c.id) \(c.name)").font(.system(size: 13 * Theme.scale)).lineLimit(1)
                    Text(c.statusLabel).font(.system(size: 11.5 * Theme.scale)).foregroundStyle(Theme.faint).lineLimit(1)
                }
            }
            .padding(.vertical, 5)
        }
        .buttonStyle(RowButton(selected: current?.id == c.id))
    }

    @ViewBuilder private func record(_ c: Candidate) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("candidates/\(c.id).md").font(.system(size: 11.5 * Theme.scale, design: .monospaced)).foregroundStyle(Theme.faint)
                Spacer()
                Label("Location kept on this Mac", systemImage: "lock").font(.system(size: 11.5 * Theme.scale)).foregroundStyle(Theme.faint)
            }
            VStack(alignment: .leading, spacing: 8) {
                Text("\(c.id) \(c.name)").font(.system(size: 24 * Theme.scale, weight: .bold)).fixedSize(horizontal: false, vertical: true)
                HStack(spacing: 8) {
                    Badge(text: c.statusLabel, color: c.statusColor)
                    Spacer(minLength: 8)
                    if !store.isBlindTest {
                        Button("Decide") { app.openDecide(on: c.id) }.buttonStyle(SecondaryButton())
                            .help("Decide this find, then the others that wait for you")
                            .coach(.review)
                    }
                }
                // On a line of its own, so a narrow pane wraps it rather than cutting it to "Marke…".
                Text("Marked \(c.flaggedOn)" + (c.flaggedBy.hasPrefix("seen in bulk") || c.flaggedBy.hasPrefix("measured") ? ", " : " by ") + c.flaggedBy)
                    .font(.system(size: 12.5 * Theme.scale)).foregroundStyle(Theme.dim)
                    .fixedSize(horizontal: false, vertical: true)
            }
            HStack(alignment: .top, spacing: 12) {
                figure(c.relief, "Bare-ground relief")
                figure(c.section, "Slice through the feature")
            }
            summary(c)
            if !c.evidence.isEmpty {
                section("Evidence") {
                    Text(c.evidence[0]).font(.system(size: 13.5 * Theme.scale)).foregroundStyle(Theme.dim).lineSpacing(3)
                        .fixedSize(horizontal: false, vertical: true)
                    if c.evidence.count > 1 {
                        DisclosureGroup("All the evidence (\(c.evidence.count) notes)") {
                            VStack(alignment: .leading, spacing: 8) {
                                ForEach(c.evidence.dropFirst(), id: \.self) { line in
                                    Text(line).font(.system(size: 13 * Theme.scale)).foregroundStyle(Theme.dim).lineSpacing(3)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                            }
                            .padding(.top, 6)
                        }
                        .font(.system(size: 12.5 * Theme.scale)).foregroundStyle(Theme.faint)
                    }
                }
            }
            section("Checks") { checks(c) }
            if !c.sources.isEmpty {
                section("Sources") {
                    ForEach(c.sources) { s in
                        Button { open(s) } label: {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(s.title).font(.system(size: 13 * Theme.scale)).multilineTextAlignment(.leading)
                                Text("\(s.statusLabel)\(s.host.isEmpty ? "" : " · " + s.host) · \(s.finding)")
                                    .font(.system(size: 12.5 * Theme.scale)).foregroundStyle(Theme.dim).lineLimit(3)
                                    .multilineTextAlignment(.leading).fixedSize(horizontal: false, vertical: true)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .buttonStyle(.plain).disabled(s.link.isEmpty)
                        .help(s.link.isEmpty ? "No address was logged for this source." : "Open it in the Sources tab")
                    }
                }
            }
            if !c.decisions.isEmpty {
                section("Decisions") {
                    ForEach(c.decisions, id: \.self) { Text($0).font(.system(size: 12.5 * Theme.scale)).foregroundStyle(Theme.dim) }
                }
            }
            if !store.isBlindTest, !c.waiting {
                section("Change the decision") {
                    Flow(spacing: 8) {
                        Button("Change it") { app.openDecide(on: c.id) }
                        Button("Show file") { NSWorkspace.shared.selectFile(c.file, inFileViewerRootedAtPath: c.folder) }
                    }
                    .buttonStyle(SecondaryButton())
                }
            }
        }
        .textSelection(.enabled)
    }

    /// The two sentences a record starts with: what the find probably is, and why, with the one step that settles it.
    @ViewBuilder private func summary(_ c: Candidate) -> some View {
        if store.isBlindTest {
            Text("Part of a blind test. It is scored against the published features when the test ends.")
                .font(.system(size: 13 * Theme.scale)).foregroundStyle(Theme.dim)
                .frame(maxWidth: .infinity, alignment: .leading).panel(padding: 14, radius: 12)
        } else if c.inLayer {
            VStack(alignment: .leading, spacing: 6) {
                Text("Kept on the map").font(.system(size: 15 * Theme.scale, weight: .semibold))
                Text(c.flaggedBy.hasPrefix("seen in bulk")
                     ? "A shape the bulk look pointed at, which the agent did not mark on its closer look and the second model did not call built, so it is not put to you. It stays on the map and counts in blind tests."
                     : c.secondSaysBuilt == true
                     ? "A measured rise. The second model calls it built, but its shape ranks in the lower half of this project's rises, so it is not put to you."
                     : "A measured rise the second model did not call built, so it is not put to you. It stays on the map and counts in blind tests.")
                    .font(.system(size: 13 * Theme.scale)).foregroundStyle(Theme.dim).fixedSize(horizontal: false, vertical: true)
                Button("Raise it") {
                    Task { @MainActor in
                        try? await app.raiseRise(c.id)
                        app.openDecide(on: c.id)
                    }
                }
                .buttonStyle(SecondaryButton()).padding(.top, 4)
                .help("Put it with the finds you decide, and open it in Decide")
            }
            .frame(maxWidth: .infinity, alignment: .leading).panel(padding: 14, radius: 12)
        } else if c.waiting {
            VStack(alignment: .leading, spacing: 6) {
                if let s = c.likely, let label = Candidate.labels[s.status] {
                    Text("Probably \(label.lowercased())").font(.system(size: 15 * Theme.scale, weight: .semibold))
                    Text(s.reason).font(.system(size: 13 * Theme.scale)).foregroundStyle(Theme.dim).lineLimit(5)
                        .fixedSize(horizontal: false, vertical: true)
                    Text("Suggested by \(s.by). Look at the pictures, then agree or decide yourself.")
                        .font(.system(size: 12 * Theme.scale)).foregroundStyle(Theme.faint)
                    Button("Decide") { app.openDecide(on: c.id) }
                        .buttonStyle(PrimaryButton()).padding(.top, 4)
                } else {
                    Text("No suggestion yet").font(.system(size: 15 * Theme.scale, weight: .semibold))
                    Text("The agent reads the record and its sources, then says what the find probably is and why.")
                        .font(.system(size: 13 * Theme.scale)).foregroundStyle(Theme.dim).fixedSize(horizontal: false, vertical: true)
                    if let flow = ToolGuide.workflows.first(where: { $0.id == "decide" }), app.state(of: flow).ready {
                        Button("Suggest decisions") { app.run(flow) }.buttonStyle(PrimaryButton()).padding(.top, 4)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14)
            .background(RoundedRectangle(cornerRadius: 12).fill(Theme.tan.opacity(0.08)))
            .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Theme.tan.opacity(0.25)))
        }
    }

    /// Open a source in the Sources tab.
    private func open(_ s: Source) {
        guard let url = URL(string: s.link) else { return }
        app.browserURL = url
        app.tab = .sources
    }

    private func section(_ title: String, @ViewBuilder _ content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.system(size: 14 * Theme.scale, weight: .semibold))
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
            CheckRow(done: cut?["in_ground"] as? Bool, title: "In the ground",
                     detail: cut.map { cut in
                        let height = Candidate.heightWords(c.checks).capitalizedFirst
                        if cut["in_ground"] as? Bool != true { return "\(height). The slice shows no clear rise in the ground, so it may be trees, a gap in the data, or nothing." }
                        return cut["from_ground_model_only"] as? Bool == true
                            ? "\(height), measured on a ready-made ground model. That shows the shape but has no treetops to compare."
                            : "\(height). \(cut["ground_returns_within_5m_of_peak"] ?? "?") laser points reached the ground at its top, so it is a shape in the ground, not trees." }
                        ?? "A slice, straight down through the laser points, shows whether the shape is ground or treetops.") {
                Button(cut == nil ? "Cut a slice" : "Cut again") {
                    app.ask("Cut a slice through \(c.id), starting and ending on the ground around it, and file it on its record.")
                }.buttonStyle(SecondaryButton())
            }
            Hairline()
            CheckRow(done: look?["agrees"] as? Bool, title: "Second opinion",
                     detail: app.secondLookProblem[c.id].map { "The second opinion did not run: " + ProjectOverview.shortReason($0) + " Choose another model in Settings, Models." }
                        ?? look.map { "\($0["model"] as? String ?? ""): \($0["note"] as? String ?? "") " + Self.secondMeaning($0["agrees"] as? Bool == true) }
                        ?? (c.checks["second_look_tried"] as? JSON).map { "\($0["model"] as? String ?? "The second model") could not answer: \($0["reason"] as? String ?? ""). Choose another in Settings, Models." }
                        ?? "A different model looks at the tile without seeing the first opinion.") {
                HStack(spacing: 6) {
                    if app.secondLookBusy == c.id { DigIndicator() }
                    ModelPicker(title: app.secondModelName, models: engine.models.filter { $0.readsImages },
                                current: app.secondModelID) { app.secondModelID = $0.id }
                    Button("Ask") { app.secondLook(c) }.buttonStyle(SecondaryButton())
                        .disabled(app.secondLookBusy != nil || app.secondOpinionModels.isEmpty)
                }
            }
            Hairline()
            CheckRow(done: modern.map { $0["likely_modern"] as? Bool != true }, title: "Open maps",
                     detail: modern.map { Self.mapMeaning($0) } ?? "Roads, buildings and sites already mapped nearby.") {
                VStack(alignment: .leading, spacing: 6) {
                    if let summary = modern?["summary"] as? String, !summary.isEmpty {
                        DisclosureGroup("What the maps show") {
                            Text(summary.prefix(1).uppercased() + summary.dropFirst()).font(.system(size: 12 * Theme.scale)).foregroundStyle(Theme.dim)
                                .fixedSize(horizontal: false, vertical: true).padding(.top, 4)
                        }
                        .font(.system(size: 12 * Theme.scale)).foregroundStyle(Theme.faint)
                    }
                    Button(modern == nil ? "Check" : "Check again") {
                        app.ask("Check open maps for modern features near \(c.id) and tell me what they show.")
                    }.buttonStyle(SecondaryButton())
                }
            }
            Hairline()
            if let old = c.checks["old_maps"] as? JSON, let finding = old["finding"] as? String {
                CheckRow(done: old["explains"] as? Bool == true ? false : true, title: "Old maps",
                         detail: (old["explains"] as? Bool == true ? "Explained by old maps: " : "Old maps show nothing here that explains it. ") + finding) { EmptyView() }
                Hairline()
            }
            if let shape = c.checks["shape"] as? JSON, shape["rise_m"] != nil {
                let hints = (shape["hints"] as? [String]) ?? []
                let said = hints.joined(separator: "; ")
                CheckRow(done: hints == ["a coherent, round rise"], title: "Shape",
                         detail: "Rises \(shape["rise_m"] ?? "?") m above the ground around it, \(shape["width_ew_m"] ?? "?") by \(shape["width_ns_m"] ?? "?") m: "
                            + said + ". This ranks finds; it rules none out.") { EmptyView() }
                Hairline()
            }
            // What the open records hold here, and which were read: a register where one is open, the open lists elsewhere.
            if let rec = c.checks["records"] as? JSON, let words = rec["summary"] as? String {
                let near = (rec["near"] as? [JSON]) ?? []
                CheckRow(done: near.isEmpty, title: near.isEmpty ? "Not on the records read" : "On record", detail: words.capitalizedFirst) {
                    if let link = near.first?["record"] as? String, link.hasPrefix("http"), let url = URL(string: link) {
                        Button("Open the record") { NSWorkspace.shared.open(url) }.buttonStyle(SecondaryButton())
                    } else { EmptyView() }
                }
                Hairline()
            }
            CheckRow(done: c.sources.isEmpty ? nil : (read > 0 && unread == 0), title: "What is published",
                     detail: c.sources.isEmpty ? "Books, papers and site records, each logged as read or not opened."
                        : unread == 0 ? "\(read) read. Each says what it shows about this find, below."
                        : "\(read) read. \(unread) would not open for the agent. Publishers often let a person in: open \(unread == 1 ? "it" : "them") yourself, then press Give this page to the agent.") {
                HStack(spacing: 8) {
                    if let first = c.sources.first(where: { $0.status == "could_not_open" && !$0.link.isEmpty }) {
                        Button(unread == 1 ? "Open the page" : "Open the first page") { open(first) }.buttonStyle(PrimaryButton())
                    }
                    Button(c.sources.isEmpty ? "Search" : "Search again") {
                        app.ask("Search the literature for \(c.id), starting with studies of this dataset. Read what you find and log every source on its record.")
                    }.buttonStyle(SecondaryButton())
                }
            }
        }
        .panel()
    }

    /// What the open-maps check means for a person, in one or two sentences.
    /// What a second opinion is worth, from testing the reviewers on known ground (SECOND_OPINION_LOOP S3): a "no" was
    /// right nine times in ten, a "yes" only four in ten, since they call much plain or modern ground built.
    static func secondMeaning(_ agrees: Bool) -> String {
        agrees ? "A yes is a weak check: on known ground these models also said yes to much that was not built."
               : "A no counts: on known ground these models were right nine times in ten when they said no."
    }

    static func mapMeaning(_ modern: JSON) -> String {
        let summary = modern["summary"] as? String ?? ""
        var known = ""
        if let range = summary.range(of: "historic places mapped within 2 km:") {
            let names = summary[range.upperBound...].trimmingCharacters(in: .whitespacesAndNewlines.union(.init(charactersIn: ".")))
            if !names.isEmpty { known = " Known places mapped within 2 km: \(names)." }
        }
        if modern["likely_modern"] as? Bool == true {
            return "Roads or buildings are on or beside it, so it may be modern. The slice and the sources settle it." + known
        }
        return "Nothing modern is mapped on it." + known
    }

    @ViewBuilder private func figure(_ path: String, _ caption: String) -> some View {
        if let image = Images.load(path) {
            VStack(alignment: .leading, spacing: 5) {
                Image(nsImage: image).resizable().aspectRatio(contentMode: .fit).frame(maxHeight: 230)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    // Drag a record's picture onto the message box to attach it.
                    .onDrag { NSItemProvider(contentsOf: URL(fileURLWithPath: path)) ?? NSItemProvider() }
                Text(caption).font(.system(size: 11.5 * Theme.scale)).foregroundStyle(Theme.faint)
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
                .font(.system(size: 16 * Theme.scale))
                .foregroundStyle(done == true ? Theme.green : done == false ? Theme.amber : Theme.faint)
                .frame(width: 20).padding(.top, 1)
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.system(size: 13.5 * Theme.scale, weight: .medium))
                Text(detail).font(.system(size: 12.5 * Theme.scale)).foregroundStyle(Theme.dim).fixedSize(horizontal: false, vertical: true)
                action().padding(.top, 7)
            }
            Spacer(minLength: 0)
        }
        .padding(14)
    }
}

// MARK: - Notes

/// The project's own Markdown: the brief, the run notes, the log of sources read, and any draft reports.
struct NotesView: View {
    @EnvironmentObject var app: AppState
    @EnvironmentObject var store: ProjectStore
    @State private var picked: String?
    private var part: String { app.notesPart }

    /// The project's notes in three parts: the method the agent follows, the run summaries, and the running log.
    private func files(_ part: String) -> [String] {
        guard let root = store.current?.path else { return [] }
        let fm = FileManager.default
        let notes = ((try? fm.contentsOfDirectory(atPath: root + "/notes")) ?? []).filter { $0.hasSuffix(".md") }.sorted().reversed()
        switch part {
        case "record": return ["RESEARCH.md"].filter { fm.fileExists(atPath: root + "/" + $0) }
        case "method": return ["METHODOLOGY.md", "PROJECT.md"].filter { fm.fileExists(atPath: root + "/" + $0) }
        case "runs": return notes.filter { $0.contains("-run-") }.map { "notes/" + $0 }
        default:
            let reports = ((try? fm.contentsOfDirectory(atPath: root + "/reports")) ?? []).filter { $0.hasSuffix(".md") }.sorted().map { "reports/" + $0 }
            return notes.filter { !$0.contains("-run-") && $0 != "INDEX.md" }.map { "notes/" + $0 }
                + ["sources/read-log.md"].filter { fm.fileExists(atPath: root + "/" + $0) } + reports
        }
    }

    private func label(_ file: String) -> String {
        let name = URL(fileURLWithPath: file).deletingPathExtension().lastPathComponent
        if name == "METHODOLOGY" { return "Method" }
        if name == "RESEARCH" { return "Research record" }
        if name == "PROJECT" { return "Question and rules" }
        if name == "read-log" { return "Sources read" }
        if name.contains("-run-") {
            let p = name.components(separatedBy: "-run-")
            return p[0] + " " + (p.count > 1 && p[1].count == 4 ? String(p[1].prefix(2)) + ":" + String(p[1].suffix(2)) : "")
        }
        return name
    }

    var body: some View {
        let list = files(part)
        let file = picked.flatMap { list.contains($0) ? $0 : nil } ?? app.notesFile.flatMap { list.contains($0) ? $0 : nil } ?? list.first
        let root = store.current?.path ?? ""
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                HStack(spacing: 2) {
                    ForEach([("record", "Record"), ("runs", "Runs"), ("method", "Method"), ("log", "Log")], id: \.0) { item in
                        Button { app.notesPart = item.0; picked = nil } label: {
                            Text(item.1).font(.system(size: 12.5 * Theme.scale, weight: part == item.0 ? .semibold : .medium))
                                .foregroundStyle(part == item.0 ? Theme.text : Theme.dim)
                                .padding(.horizontal, 12).frame(height: 26)
                                .background(RoundedRectangle(cornerRadius: 6).fill(part == item.0 ? Theme.raised : .clear))
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(2).background(RoundedRectangle(cornerRadius: 8).fill(Theme.ink.opacity(0.06)))
                if list.count > 1 {
                    PillMenu(title: file.map(label) ?? "", quiet: true) {
                        list.map { f in MenuEntry(title: label(f), icon: "doc.text", checked: f == file) { picked = f } }
                    }
                }
                Spacer()
                Button { NSWorkspace.shared.selectFile(file.map { root + "/" + $0 }, inFileViewerRootedAtPath: root) } label: {
                    Image(systemName: "folder")
                }
                .buttonStyle(IconButton(size: 26)).help("Show the file in Finder")
            }
            .padding(.horizontal, 12).frame(height: 44)
            Hairline()
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    // The record introduces itself, so it needs no line from the app above it.
                    if part != "record" {
                        Text(part == "runs" ? "What each run did and found, newest first."
                             : file == "PROJECT.md" ? "The project's question, why this area, the rules agents follow, and how the folder is kept."
                             : part == "method" ? "How searches in this project are done. The agent reads this before every run and follows it; edit it to change the method."
                             : "The running log the tools write as work happens, the sources read, and report drafts.")
                            .font(.system(size: 12.5 * Theme.scale)).foregroundStyle(Theme.faint).fixedSize(horizontal: false, vertical: true)
                    }
                    if let file, let text = try? String(contentsOfFile: root + "/" + file, encoding: .utf8) {
                        MarkdownText(text: text)
                    } else if part == "record" {
                        EmptyLine(icon: "dig.layers", text: "The record is written the next time this project opens, when a run ends, or when a decision is recorded.")
                    } else if part == "method" {
                        Text("This project was made before projects had a method file.").font(.system(size: 13 * Theme.scale)).foregroundStyle(Theme.dim)
                        Button { app.ask("Write METHODOLOGY.md for this project: the order of work Dighouse follows (read, get the ground, look at the tiles, mark finds, check, search what is published, suggest decisions, summarise), the rules, and a Lessons section with anything the notes so far have taught. No coordinates.") } label: {
                            Label("Ask the agent to write it", glyph: "dig.trowel")
                        }
                        .buttonStyle(SecondaryButton())
                    } else {
                        EmptyLine(icon: "dig.layers", text: part == "runs" ? "No run summaries yet. A run writes one when it ends." : "Nothing logged yet.")
                    }
                }
                .padding(24).frame(maxWidth: 720, alignment: .leading).frame(maxWidth: .infinity)
            }
            // A link to a candidate opens its record here; a link to another of the project's files opens that file.
            .environment(\.openURL, OpenURLAction { url in
                guard url.scheme == nil || url.isFileURL else { return .systemAction }
                let path = url.relativePath
                if path.hasPrefix("candidates/"), path.hasSuffix(".md") {
                    app.showRecords(URL(fileURLWithPath: path).deletingPathExtension().lastPathComponent)
                } else if path.hasPrefix("reports/"), path.hasSuffix("-search-report.md") {
                    app.reportShown = root + "/" + path
                } else if FileManager.default.fileExists(atPath: root + "/" + path) {
                    let part = path.hasPrefix("notes/") ? (path.contains("-run-") ? "runs" : "log") : path == "RESEARCH.md" ? "record" : "method"
                    app.notesPart = part
                    picked = path
                }
                return .handled
            })
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
        view.navigationDelegate = context.coordinator
        handle?.view = view
        return view
    }

    func updateNSView(_ view: WKWebView, context: Context) {
        if let url, Memory.allowed(url), view.url != url, context.coordinator.last != url {
            context.coordinator.last = url
            view.load(URLRequest(url: url))
        }
    }

    func makeCoordinator() -> Memory { Memory() }

    /// Remembers the last page asked for, and keeps the browser on the web: links written into a record or a page can
    /// name a file on this Mac or another app, and those are not followed.
    final class Memory: NSObject, WKNavigationDelegate {
        var last: URL?

        static func allowed(_ url: URL) -> Bool { ["http", "https", "about"].contains(url.scheme?.lowercased() ?? "") }

        func webView(_ webView: WKWebView, decidePolicyFor action: WKNavigationAction, decisionHandler: @escaping @MainActor (WKNavigationActionPolicy) -> Void) {
            decisionHandler(action.request.url.map(Self.allowed) ?? false ? .allow : .cancel)
        }
    }
}

/// What the agent has read for this project, and a browser to open any of it yourself.
struct SourcesView: View {
    @EnvironmentObject var app: AppState
    @EnvironmentObject var store: ProjectStore
    @State private var address = ""
    @State private var handing = false
    @State private var handProblem: String?
    @State private var showUnrelated = false
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
                    + "say what it shows about this project's finds, and log it with log_source on the records it bears on, "
                    + "with its real title and status read. If it was logged before as could not open, logging it again under the same title replaces that entry.")
        }
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
        let all = store.allSources
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Image(systemName: "globe").font(.system(size: 12 * Theme.scale)).foregroundStyle(Theme.faint)
                TextField("Open a web address, or search", text: $address).textFieldStyle(.plain).font(.system(size: 13 * Theme.scale)).onSubmit { go(address) }
                if let url = app.browserURL {
                    Button { NSWorkspace.shared.open(url) } label: { Image(systemName: "arrow.up.forward.square") }
                        .buttonStyle(IconButton(size: 26)).help("Open in your browser")
                    if handing { DigIndicator() }
                    Button { handOver(url) } label: {
                        Text("Give this page to the agent").font(.system(size: 12 * Theme.scale))
                    }
                    .buttonStyle(SecondaryButton()).disabled(handing)
                    .help("Saves the text you can see into the project, so the agent can read a page that refused it, and log it on the records.")
                }
            }
            .padding(.horizontal, 12).frame(height: 42)
            Hairline()
            if app.browserURL != nil {
                WebPage(url: app.browserURL, handle: web)
            } else if all.isEmpty {
                EmptyPane(icon: "dig.sieve", title: "No sources yet",
                          text: "Each source the agent logs appears here as read, could not open, or not relevant. You can also open a web address above and give the page to the agent.") {
                    if let flow = ToolGuide.workflows.first(where: { $0.id == "prior" }), app.state(of: flow).ready {
                        Button(flow.title) { app.run(flow) }.buttonStyle(PrimaryButton())
                    }
                }
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        Text("\(all.count) source\(all.count == 1 ? "" : "s") for this project").font(.system(size: 18 * Theme.scale, weight: .semibold))
                        Text("Each source the agent logs appears here as read, could not open, or not relevant. Click one to open it. Publishers often refuse a program and let a person in, so the ones marked could not open are worth opening yourself.")
                            .font(.system(size: 13 * Theme.scale)).foregroundStyle(Theme.dim).lineSpacing(2).fixedSize(horizontal: false, vertical: true)
                        // What was read first, then what a person may open themselves; the off-topic ones fold away.
                        let order = ["read": 0, "could_not_open": 1]
                        let useful = all.filter { $0.status != "not_relevant" }.enumerated()
                            .sorted { (order[$0.element.status] ?? 2, $0.offset) < (order[$1.element.status] ?? 2, $1.offset) }.map(\.element)
                        let unrelated = all.filter { $0.status == "not_relevant" }
                        if !useful.isEmpty { list(useful) }
                        if !unrelated.isEmpty {
                            Button { showUnrelated.toggle() } label: {
                                HStack(spacing: 6) {
                                    Image(systemName: "chevron.right").font(.system(size: 9 * Theme.scale, weight: .bold))
                                        .rotationEffect(.degrees(showUnrelated ? 90 : 0))
                                    Text("\(unrelated.count) not relevant: about another place or topic")
                                }
                                .font(.system(size: 12.5 * Theme.scale)).foregroundStyle(Theme.dim).contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            if showUnrelated { list(unrelated) }
                        }
                    }
                    .padding(24).frame(maxWidth: 720, alignment: .leading).frame(maxWidth: .infinity)
                }
            }
        }
        .onChange(of: app.browserURL) { address = app.browserURL?.absoluteString ?? "" }
        .onAppear { address = app.browserURL?.absoluteString ?? "" }
        .overlay(alignment: .bottomLeading) {
            if app.browserURL != nil {
                HStack(spacing: 10) {
                    Button("Back to the list") { app.browserURL = nil }.buttonStyle(SecondaryButton())
                        .background(Capsule().fill(Theme.bg))
                    if let handProblem {
                        Text(handProblem).font(.system(size: 12 * Theme.scale)).foregroundStyle(Theme.amber)
                            .padding(.horizontal, 10).padding(.vertical, 6)
                            .background(RoundedRectangle(cornerRadius: 8).fill(Theme.bg))
                    }
                }
                .padding(12)
            }
        }
    }

    private func list(_ all: [Source]) -> some View {
        LazyVStack(spacing: 0) {
            ForEach(Array(all.enumerated()), id: \.element.id) { index, source in
                if index > 0 { Hairline() }
                Button { if !source.link.isEmpty { go(source.link) } } label: {
                    HStack(alignment: .top, spacing: 10) {
                        Circle().fill(color(source.status)).frame(width: 7, height: 7).padding(.top, 6)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(source.title).font(.system(size: 13 * Theme.scale, weight: .medium)).multilineTextAlignment(.leading)
                            Text("\(source.statusLabel) · \(source.finding)")
                                .font(.system(size: 12 * Theme.scale)).foregroundStyle(Theme.dim).lineLimit(3).multilineTextAlignment(.leading)
                        }
                        Spacer(minLength: 6)
                        if !source.link.isEmpty { Image(systemName: "chevron.right").font(.system(size: 10 * Theme.scale, weight: .semibold)).foregroundStyle(Theme.faint) }
                    }
                    .padding(.vertical, 5)
                }
                .buttonStyle(RowButton()).disabled(source.link.isEmpty)
            }
        }
        .padding(4).panel(radius: 12)
    }
}

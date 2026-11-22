import MapKit
import SwiftUI

/// The New project page: a name, a question, and an area picked on the map, with the open lidar that covers it.
struct NewProjectView: View {
    let point: StartingPoint
    @EnvironmentObject var app: AppState
    @EnvironmentObject var engine: Engine

    private struct Place: Identifiable {
        let name: String
        let lat: Double, lon: Double
        let span: Double
        var id: String { "\(name)\(lat)\(lon)" }
    }

    private struct Coverage: Identifiable {
        let id: String, title: String, source: String, collected: String
        /// Set when the service asks for a free token that is not on this Mac yet, with what to do about it.
        var needs = ""
    }

    @State private var name: String
    @State private var question: String
    @State private var box: [String]
    @State private var size: Double
    @State private var camera: MapCameraPosition
    /// How much of the world the map shows, in degrees of latitude. Zoomed out, it shows where open data reaches.
    @State private var span: Double
    @State private var query = ""
    @State private var places: [Place] = []
    @State private var searching = false
    @State private var searchProblem: String?
    @State private var coverage: [Coverage]?
    @State private var coverageProblem: String?
    @State private var showEdges = false
    @State private var busy = false
    @State private var problem: String?
    @State private var inGitHub: Bool
    /// The name Dighouse suggested from the map, replaced while the person has not typed their own.
    @State private var suggested = ""
    /// Where the map is looking, for the layer of how much is on open record.
    @State private var center = CLLocationCoordinate2D(latitude: 0, longitude: 0)
    @State private var gapsOn = false
    /// The search boxes of the person's own projects, shaded on the map.
    @State private var searched: [[Double]] = []
    @State private var gaps: [Gap] = []
    @State private var gapsBusy = false
    @State private var gapsNote: String?

    /// A cell of the coarse grid: how many sites are on open record in it, and whether open lidar reaches it.
    private struct Gap: Identifiable {
        let id: String
        let west, south, east, north: Double
        let sites: Int
        let lidar: Bool
    }

    private static let sizes: [Double] = [0.3, 0.6, 1, 1.5, 2]

    init(point: StartingPoint) {
        self.point = point
        _name = State(initialValue: point.name)
        _question = State(initialValue: point.question)
        _box = State(initialValue: point.box)
        _inGitHub = State(initialValue: point.inGitHub && Paths.githubProblem == nil)
        let n = point.box.compactMap(Double.init)
        if n.count == 4 {
            let km = (n[3] - n[1]) * 110.54
            _size = State(initialValue: Self.sizes.min { abs($0 - km) < abs($1 - km) } ?? 0.6)
            _camera = State(initialValue: Self.region(lat: (n[1] + n[3]) / 2, lon: (n[0] + n[2]) / 2, span: (n[3] - n[1]) * 5))
            _span = State(initialValue: (n[3] - n[1]) * 5)
        } else if let look = point.look, look.count == 3 {
            _size = State(initialValue: 0.6)
            _camera = State(initialValue: Self.region(lat: look[0], lon: look[1], span: look[2]))
            _span = State(initialValue: look[2])
        } else {
            _size = State(initialValue: 0.6)
            // Wide enough to show the United States and Europe together, even in a narrow window.
            _camera = State(initialValue: Self.world)
            _span = State(initialValue: 100)
        }
    }

    /// Zoomed out past this, a click zooms in on the spot; closer in, a click places the search area.
    private static let wide = 1.5
    private var zoomedOut: Bool { span > Self.wide }
    /// Close enough in to count what is on record: the grid is at most 2 degrees across.
    private var countable: Bool { span <= 3 }

    /// From the western United States to eastern Europe, fitted to the map's width: where most of the open lidar is.
    private static let world: MapCameraPosition = {
        let a = MKMapPoint(CLLocationCoordinate2D(latitude: 62, longitude: -128))
        let b = MKMapPoint(CLLocationCoordinate2D(latitude: 12, longitude: 32))
        return .rect(MKMapRect(x: min(a.x, b.x), y: min(a.y, b.y), width: abs(b.x - a.x), height: abs(b.y - a.y)))
    }()

    private static func region(lat: Double, lon: Double, span: Double) -> MapCameraPosition {
        .region(MKCoordinateRegion(center: CLLocationCoordinate2D(latitude: lat, longitude: lon),
                                   span: MKCoordinateSpan(latitudeDelta: span, longitudeDelta: span)))
    }

    private var numbers: [Double]? {
        let n = box.compactMap(Double.init)
        return n.count == 4 && n[0] < n[2] && n[1] < n[3] ? n : nil
    }

    private var areaKm2: Double? {
        guard let n = numbers else { return nil }
        return (n[2] - n[0]) * 111.32 * cos((n[1] + n[3]) / 2 * .pi / 180) * (n[3] - n[1]) * 110.54
    }

    private var valid: Bool { !name.trimmingCharacters(in: .whitespaces).isEmpty && numbers != nil }

    var body: some View {
        GeometryReader { geo in
            if geo.size.width >= 820 {
                HStack(spacing: 0) {
                    ScrollView { form.padding(24) }.frame(width: 400)
                    Hairline(vertical: true)
                    map
                }
            } else {
                ScrollView {
                    VStack(spacing: 0) {
                        map.frame(height: 300)
                        form.padding(20)
                    }
                }
            }
        }
        .background(Theme.bg)
        .task(id: box.joined(separator: ",")) {
            async let named: Void = suggestName()
            await checkCoverage()
            await named
        }
        .task { await app.loadSurveys() }
        .task {
            // Started from a typed place name: look it up and take the best match.
            guard let place = point.search, numbers == nil else { return }
            query = place
            search(pickFirst: true)
        }
    }

    // MARK: map

    private var map: some View {
        MapReader { proxy in
            Map(position: $camera) {
                if zoomedOut {
                    // Where open data reaches, roughly: enough to choose a region by. The list beside the map is exact.
                    MapPolygon(coordinates: Self.coordinates(Reach.unitedStates)).foregroundStyle(Theme.tan.opacity(0.35)).stroke(Theme.tan, lineWidth: 1)
                    ForEach(Reach.national.indices, id: \.self) { i in
                        MapPolygon(coordinates: Self.coordinates(Reach.national[i].ring)).foregroundStyle(Theme.green.opacity(0.35)).stroke(Theme.green, lineWidth: 1)
                    }
                    ForEach(Reach.sonar.indices, id: \.self) { i in
                        MapPolygon(coordinates: Self.coordinates(Reach.sonar[i])).foregroundStyle(Theme.water.opacity(0.35)).stroke(Theme.water, lineWidth: 1)
                    }
                    ForEach(Array(app.surveys.enumerated()), id: \.offset) { _, survey in
                        if survey.box.count == 4 {
                            Annotation("", coordinate: CLLocationCoordinate2D(latitude: (survey.box[1] + survey.box[3]) / 2, longitude: (survey.box[0] + survey.box[2]) / 2)) {
                                Circle().fill(Theme.amber).frame(width: 9, height: 9).overlay(Circle().stroke(.black.opacity(0.5), lineWidth: 0.8))
                                    .help(survey.title)
                            }
                        }
                    }
                }
                if gapsOn {
                    // Counts on a coarse grid, never a site's name or place. Cells without open lidar stay clear.
                    ForEach(gaps) { g in
                        let most = Double(gaps.map(\.sites).max() ?? 0)
                        let fewest = g.lidar && most > 0 ? 1 - log(1 + Double(g.sites)) / log(1 + most) : (g.lidar ? 1 : 0)
                        MapPolygon(coordinates: [
                            CLLocationCoordinate2D(latitude: g.south, longitude: g.west), CLLocationCoordinate2D(latitude: g.south, longitude: g.east),
                            CLLocationCoordinate2D(latitude: g.north, longitude: g.east), CLLocationCoordinate2D(latitude: g.north, longitude: g.west),
                        ])
                        .foregroundStyle(Theme.amber.opacity(0.08 + 0.4 * fewest))
                        .stroke(.white.opacity(0.35), lineWidth: 0.6)
                        Annotation("", coordinate: CLLocationCoordinate2D(latitude: (g.south + g.north) / 2, longitude: (g.west + g.east) / 2)) {
                            Text(g.lidar ? "\(g.sites)" : "no lidar").font(.system(size: 11 * Theme.scale, weight: .semibold)).foregroundStyle(.white)
                                .padding(.horizontal, 5).frame(height: 18).background(Capsule().fill(.black.opacity(0.6)))
                                .help(g.lidar ? "\(g.sites) site\(g.sites == 1 ? "" : "s") on open record in this cell" : "No open lidar the tools read covers this cell")
                        }
                    }
                }
                // Ground your own projects have searched (not blind tests), so a new search can go elsewhere.
                ForEach(Array(searched.enumerated()), id: \.offset) { _, n in
                    MapPolygon(coordinates: [
                        CLLocationCoordinate2D(latitude: n[1], longitude: n[0]), CLLocationCoordinate2D(latitude: n[1], longitude: n[2]),
                        CLLocationCoordinate2D(latitude: n[3], longitude: n[2]), CLLocationCoordinate2D(latitude: n[3], longitude: n[0]),
                    ])
                    .foregroundStyle(.white.opacity(0.25))
                    .stroke(.white, lineWidth: 1.5)
                    if zoomedOut {
                        // A square km is invisible across a continent, so each searched area is also a dot.
                        Annotation("", coordinate: CLLocationCoordinate2D(latitude: (n[1] + n[3]) / 2, longitude: (n[0] + n[2]) / 2)) {
                            Circle().fill(.white).frame(width: 7, height: 7).overlay(Circle().stroke(.black.opacity(0.6), lineWidth: 0.8))
                                .allowsHitTesting(false)
                        }
                    }
                }
                if let n = numbers {
                    MapPolygon(coordinates: [
                        CLLocationCoordinate2D(latitude: n[1], longitude: n[0]), CLLocationCoordinate2D(latitude: n[1], longitude: n[2]),
                        CLLocationCoordinate2D(latitude: n[3], longitude: n[2]), CLLocationCoordinate2D(latitude: n[3], longitude: n[0]),
                    ])
                    .foregroundStyle(Theme.accent.opacity(0.2))
                    .stroke(Theme.accent, lineWidth: 2)
                }
            }
            .mapStyle(.hybrid)
            .onMapCameraChange(frequency: .onEnd) { context in
                span = context.region.span.latitudeDelta
                center = context.region.center
            }
            .task(id: gapsOn ? "\(Int(center.latitude * 2)),\(Int(center.longitude * 2)),\(countable)" : "off") { await loadGaps() }
            .task(id: app.store.projects.count) { await loadSearched() }
            .onTapGesture { spot in
                guard let place = proxy.convert(spot, from: .local) else { return }
                if zoomedOut {
                    withAnimation(.easeInOut(duration: 0.6)) { camera = Self.region(lat: place.latitude, lon: place.longitude, span: 0.12) }
                    span = 0.12
                } else {
                    setCentre(lat: place.latitude, lon: place.longitude)
                }
            }
        }
        .overlay(alignment: .bottomLeading) {
            VStack(alignment: .leading, spacing: 8) {
                if zoomedOut {
                    VStack(alignment: .leading, spacing: 5) {
                        legend(Theme.tan, "Lidar, the United States")
                        legend(Theme.green, "Lidar, national ground models")
                        legend(Theme.amber, "Surveys flown for archaeology")
                        legend(Theme.water, "Sonar, the seafloor, for wrecks")
                        if !searched.isEmpty { legend(.white, "Ground you have searched") }
                    }
                    .padding(10).background(RoundedRectangle(cornerRadius: 10).fill(.black.opacity(0.7)))
                    .allowsHitTesting(false)
                }
                VStack(alignment: .leading, spacing: 6) {
                    Toggle(isOn: $gapsOn) {
                        Text("Show how much is on record").font(.system(size: 12 * Theme.scale, weight: .medium)).foregroundStyle(.white)
                    }
                    .toggleStyle(.switch).controlSize(.small)
                    .help("Counts the sites already on open record (Wikidata, OpenStreetMap and national registers) on a coarse grid. Brighter cells have fewer.")
                    if gapsOn {
                        if !countable {
                            Text("Zoom in to a region, a couple of hundred kilometres across, to count what is on record there.")
                                .font(.system(size: 11.5 * Theme.scale)).foregroundStyle(.white.opacity(0.8))
                                .frame(maxWidth: 300, alignment: .leading).fixedSize(horizontal: false, vertical: true)
                        } else if gapsBusy {
                            Text("Counting the sites on record…").font(.system(size: 11.5 * Theme.scale)).foregroundStyle(.white.opacity(0.8))
                        } else if let gapsNote {
                            Text(gapsNote).font(.system(size: 11.5 * Theme.scale)).foregroundStyle(.white.opacity(0.8))
                                .frame(maxWidth: 300, alignment: .leading).fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
                .padding(10).background(RoundedRectangle(cornerRadius: 10).fill(.black.opacity(0.7)))
            }
            .padding(12)
        }
        .overlay(alignment: .top) {
            Text(zoomedOut ? "Shaded areas have open lidar. Click where you want to look."
                 : numbers == nil ? "Click the map to place the search area" : "Click the map to move the search area")
                .font(.system(size: 12.5 * Theme.scale, weight: .medium))
                .padding(.horizontal, 12).frame(height: 28)
                .background(Capsule().fill(.black.opacity(0.7))).padding(12)
                .allowsHitTesting(false)
        }
    }

    /// The search boxes of the person's projects, read off the main thread. Blind tests are left out: they are known sites.
    private func loadSearched() async {
        let refs = app.store.projects
        searched = await Task.detached {
            refs.flatMap { ref -> [[Double]] in
                guard !FileManager.default.fileExists(atPath: ref.path + "/private/state/test.json") else { return [] }
                // Each area's own box where the project kept it: a region project's box is far bigger than what was searched.
                if let data = FileManager.default.contents(atPath: ref.path + "/private/state/terrains.json"),
                   let all = (try? JSONSerialization.jsonObject(with: data)) as? [String: JSON] {
                    let boxes = all.values.compactMap { $0["lonlat"] as? [Double] }.filter { $0.count == 4 }
                    if !boxes.isEmpty { return boxes }
                }
                guard let data = FileManager.default.contents(atPath: ref.path + "/private/state/project.json"),
                      let info = (try? JSONSerialization.jsonObject(with: data)) as? JSON,
                      let box = info["bbox"] as? [Double], box.count == 4 else { return [] }
                return [box]
            }
        }.value
    }

    /// Count the sites on open record on a 4 by 4 grid around the middle of the map, at least a degree across, so a cell
    /// is tens of kilometres wide and points at no single place.
    private func loadGaps() async {
        guard gapsOn, countable, engine.ready else { gaps = []; return }
        let side = min(2, max(1, span))
        let box = [center.longitude - side / 2, center.latitude - side / 2, center.longitude + side / 2, center.latitude + side / 2]
        gapsBusy = true
        defer { gapsBusy = false }
        do {
            let reply = try await engine.callTool("find_gaps", ["west": box[0], "south": box[1], "east": box[2], "north": box[3]])
            guard let info = (try? JSONSerialization.jsonObject(with: Data(reply.utf8))) as? JSON, let cells = info["cells"] as? [JSON] else {
                gapsNote = "The count did not come back. Try again in a moment."
                return
            }
            gaps = cells.compactMap { c in
                guard let w = c["west"] as? Double, let s = c["south"] as? Double, let e = c["east"] as? Double, let n = c["north"] as? Double else { return nil }
                return Gap(id: c["cell"] as? String ?? "\(w),\(s)", west: w, south: s, east: e, north: n,
                           sites: c["recorded_sites"] as? Int ?? 0, lidar: (c["open_lidar_datasets"] as? Int ?? 0) > 0)
            }
            // Show the whole grid, so a person zoomed in on one field sees the cells around it.
            if span < side * 0.7 {
                withAnimation(.easeInOut(duration: 0.6)) { camera = Self.region(lat: center.latitude, lon: center.longitude, span: side * 1.15) }
            }
            gapsNote = "Brighter cells have fewer sites on open record. Few on record can mean few looked, or few wrote it down; it is not proof that nothing is there."
        } catch {
            gapsNote = "The count failed: " + error.localizedDescription
        }
    }

    private func legend(_ color: Color, _ title: String) -> some View {
        HStack(spacing: 7) {
            Circle().fill(color).frame(width: 8, height: 8)
            Text(title).font(.system(size: 11.5 * Theme.scale)).foregroundStyle(.white.opacity(0.9))
        }
    }

    private static func coordinates(_ ring: [Double]) -> [CLLocationCoordinate2D] {
        stride(from: 0, to: ring.count - 1, by: 2).map { CLLocationCoordinate2D(latitude: ring[$0 + 1], longitude: ring[$0]) }
    }

    private func setCentre(lat: Double, lon: Double) {
        let dLat = size / 110.54 / 2, dLon = size / (111.32 * cos(lat * .pi / 180)) / 2
        box = [lon - dLon, lat - dLat, lon + dLon, lat + dLat].map { String(format: "%.5f", $0) }
    }

    // MARK: form

    private var form: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 4) {
                Text("New project").font(.system(size: 22 * Theme.scale, weight: .bold))
                Text(point.kind == .own ? "A project is one question about one area."
                     : point.kind == .chat ? "Filled in from the chat “\(point.title)”. Once the project is made, the chat moves into it"
                        + (point.searchNow ? " and the whole search starts." : ".")
                     : "Starting from \(point.title). You can change anything below.")
                    .font(.system(size: 13 * Theme.scale)).foregroundStyle(Theme.dim).fixedSize(horizontal: false, vertical: true)
            }

            labeled("Name") { TextField("Project name", text: $name).field() }
            labeled("Question") {
                TextField("What should this search answer?", text: $question, axis: .vertical).lineLimit(2...4).field()
            }

            labeled("Area") {
                HStack(spacing: 8) {
                    TextField("Find a place by name", text: $query).field().onSubmit(search)
                    Button("Find", action: search).buttonStyle(SecondaryButton())
                        .disabled(searching || query.trimmingCharacters(in: .whitespaces).isEmpty)
                }
                if searching { DigIndicator() }
                if let searchProblem { Text(searchProblem).font(.system(size: 12.5 * Theme.scale)).foregroundStyle(Theme.amber) }
                if !places.isEmpty {
                    VStack(spacing: 0) {
                        ForEach(places) { place in
                            Button {
                                camera = Self.region(lat: place.lat, lon: place.lon, span: place.span)
                                span = place.span
                                setCentre(lat: place.lat, lon: place.lon)
                                places = []
                            } label: {
                                Text(place.name).font(.system(size: 12.5 * Theme.scale)).lineLimit(2).multilineTextAlignment(.leading).padding(.vertical, 4)
                            }
                            .buttonStyle(RowButton())
                        }
                    }
                    .padding(4).panel(radius: 10)
                }
                HStack(spacing: 8) {
                    Text("Size").font(.system(size: 12.5 * Theme.scale)).foregroundStyle(Theme.dim)
                    ForEach(Self.sizes, id: \.self) { km in
                        Button {
                            size = km
                            if let n = numbers { setCentre(lat: (n[1] + n[3]) / 2, lon: (n[0] + n[2]) / 2) }
                        } label: {
                            Text(km < 1 ? "\(Int(km * 1000)) m" : "\(km.formatted()) km").font(.system(size: 12 * Theme.scale))
                                .foregroundStyle(size == km ? Theme.text : Theme.dim)
                                .padding(.horizontal, 9).frame(height: 24)
                                .background(Capsule().fill(size == km ? Theme.ink.opacity(0.12) : .clear))
                                .contentShape(Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                }
                Button { showEdges.toggle() } label: {
                    HStack(spacing: 5) {
                        Image(systemName: "chevron.right").font(.system(size: 8.5 * Theme.scale, weight: .bold)).rotationEffect(.degrees(showEdges ? 90 : 0))
                        Text("Edges in degrees")
                        if let km = areaKm2 { Text("· \(km.formatted(.number.precision(.fractionLength(2)))) square km").foregroundStyle(Theme.faint) }
                    }
                    .font(.system(size: 12.5 * Theme.scale)).foregroundStyle(Theme.dim).contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                if showEdges {
                    HStack(spacing: 6) {
                        ForEach(Array(["West", "South", "East", "North"].enumerated()), id: \.offset) { i, label in
                            TextField(label, text: $box[i]).field().font(.system(size: 12 * Theme.scale))
                        }
                    }
                }
                if let km = areaKm2, km > 6 {
                    Text("This is a large area. The ground is fetched in pieces under 6 square km, so a first project is quicker when it is small.")
                        .font(.system(size: 12 * Theme.scale)).foregroundStyle(Theme.amber).fixedSize(horizontal: false, vertical: true)
                }
                Text("The area is stored privately in the project and stays on this Mac.")
                    .font(.system(size: 12 * Theme.scale)).foregroundStyle(Theme.faint).fixedSize(horizontal: false, vertical: true)
            }

            labeled("Open data here") { coverageList }

            labeled("Folder") {
                HStack(spacing: 6) {
                    folderChoice(Paths.short(Paths.projectsHome.path), selected: !inGitHub) { inGitHub = false }
                    folderChoice("Work out of my GitHub folder", selected: inGitHub) { inGitHub = true }
                        .disabled(Paths.githubProblem != nil)
                        .help(Paths.githubProblem ?? "Makes the project in \(Paths.short(Paths.githubHome.path)), for people who keep their work there.")
                }
                Text("Makes \(Paths.short(AppState.folder(for: name.trimmingCharacters(in: .whitespaces), inGitHub: inGitHub))), its own folder with its own history.")
                    .font(.system(size: 12 * Theme.scale)).foregroundStyle(Theme.faint).fixedSize(horizontal: false, vertical: true)
                if let reason = Paths.githubProblem {
                    Text(reason).font(.system(size: 12 * Theme.scale)).foregroundStyle(Theme.faint).fixedSize(horizontal: false, vertical: true)
                }
            }

            if let problem { Text(problem).foregroundStyle(Theme.amber).font(.system(size: 12.5 * Theme.scale)).fixedSize(horizontal: false, vertical: true) }
            HStack(spacing: 8) {
                Button("Cancel") { app.goHome() }.buttonStyle(SecondaryButton())
                Spacer()
                if busy { DigIndicator() }
                Button(point.searchNow ? "Create and search" : "Create project", action: create).buttonStyle(PrimaryButton()).disabled(busy || !valid || !engine.ready)
                    .help("Creates the project and starts fetching its open lidar straight away.")
                    .coach(.create)
            }
            if !valid {
                Text(numbers == nil ? "Click the map to place the area first." : "Give the project a name.")
                    .font(.system(size: 12 * Theme.scale)).foregroundStyle(Theme.faint).frame(maxWidth: .infinity, alignment: .trailing)
            }
        }
        .font(.system(size: 13 * Theme.scale))
    }

    private func labeled(_ label: String, @ViewBuilder _ content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label).font(.system(size: 12.5 * Theme.scale, weight: .semibold))
            content()
        }
    }

    private func folderChoice(_ title: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title).font(.system(size: 12 * Theme.scale))
                .foregroundStyle(selected ? Theme.text : Theme.dim)
                .padding(.horizontal, 10).frame(height: 26)
                .background(Capsule().fill(selected ? Theme.ink.opacity(0.12) : .clear))
                .overlay(Capsule().strokeBorder(Theme.line))
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder private var coverageList: some View {
        if numbers == nil {
            Text("Click the map to see which open surveys cover the area.").font(.system(size: 12.5 * Theme.scale)).foregroundStyle(Theme.faint)
        } else if let coverageProblem {
            Text(coverageProblem).font(.system(size: 12.5 * Theme.scale)).foregroundStyle(Theme.amber).fixedSize(horizontal: false, vertical: true)
        } else if let coverage {
            if coverage.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("No open data Dighouse reads covers this spot. Try one of the shaded areas, or add your own ground model to a project later.")
                        .font(.system(size: 12.5 * Theme.scale)).foregroundStyle(Theme.amber).fixedSize(horizontal: false, vertical: true)
                    Button("Show where there is data") {
                        withAnimation(.easeInOut(duration: 0.6)) { camera = Self.world }
                        span = 100
                    }
                    .buttonStyle(SecondaryButton())
                }
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(coverage.enumerated()), id: \.element.id) { index, item in
                        if index > 0 { Hairline() }
                        HStack(alignment: .top, spacing: 10) {
                            Image(systemName: item.needs.isEmpty ? "checkmark.circle.fill" : "key.fill")
                                .foregroundStyle(item.needs.isEmpty ? Theme.green : Theme.amber).font(.system(size: 13 * Theme.scale)).padding(.top, 1)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(item.title).font(.system(size: 12.5 * Theme.scale)).fixedSize(horizontal: false, vertical: true)
                                Text([item.source, item.collected].filter { !$0.isEmpty }.joined(separator: " · "))
                                    .font(.system(size: 11.5 * Theme.scale)).foregroundStyle(Theme.faint)
                                if !item.needs.isEmpty {
                                    Text(item.needs).font(.system(size: 11.5 * Theme.scale)).foregroundStyle(Theme.amber).fixedSize(horizontal: false, vertical: true)
                                }
                            }
                            Spacer(minLength: 0)
                        }
                        .padding(10)
                    }
                }
                .panel(radius: 10)
            }
        } else {
            HStack(spacing: 8) {
                DigIndicator()
                Text("Checking the open catalogs").font(.system(size: 12.5 * Theme.scale)).foregroundStyle(Theme.dim)
            }
        }
    }

    // MARK: actions

    private func search() { search(pickFirst: false) }

    private func search(pickFirst: Bool) {
        let text = query.trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty, !searching else { return }
        searching = true
        searchProblem = nil
        Task { @MainActor in
            do {
                let reply = try await engine.callTool("find_place", ["query": text])
                places = Engine.rows(reply).compactMap { row in
                    guard let name = row["name"] as? String, let lat = row["lat"] as? Double, let lon = row["lon"] as? Double else { return nil }
                    let span = max(((row["north"] as? Double ?? lat) - (row["south"] as? Double ?? lat)) * 1.4, 0.03)
                    return Place(name: name, lat: lat, lon: lon, span: min(span, 20))
                }
                if places.isEmpty { searchProblem = "No place by that name was found." }
                else if pickFirst, let place = places.first {
                    camera = Self.region(lat: place.lat, lon: place.lon, span: place.span)
                    setCentre(lat: place.lat, lon: place.lon)
                    if places.count == 1 { places = [] }   // more than one: leave the others to choose from
                }
            } catch {
                searchProblem = error.localizedDescription
            }
            searching = false
        }
    }

    /// Name an unnamed project after the nearest place to its area, and give it a first question, so a click on the
    /// map is enough to start. A name the person typed is never replaced.
    private func suggestName() async {
        let typed = name.trimmingCharacters(in: .whitespaces)
        guard typed.isEmpty || typed == suggested, let n = numbers else { return }
        let spot = CLLocation(latitude: (n[1] + n[3]) / 2, longitude: (n[0] + n[2]) / 2)
        guard let mark = try? await CLGeocoder().reverseGeocodeLocation(spot).first, !Task.isCancelled else { return }
        guard let place = mark.locality ?? mark.subAdministrativeArea ?? mark.inlandWater ?? mark.ocean ?? mark.administrativeArea else { return }
        let now = name.trimmingCharacters(in: .whitespaces)
        guard now.isEmpty || now == suggested else { return }
        suggested = "\(place) area"
        name = suggested
        if question.trimmingCharacters(in: .whitespaces).isEmpty {
            question = "What built features show in the ground here, and which of them are already published?"
        }
    }

    private func checkCoverage() async {
        coverage = nil
        coverageProblem = nil
        guard let n = numbers, engine.ready else { return }
        try? await Task.sleep(for: .milliseconds(600))
        guard !Task.isCancelled else { return }
        do {
            let reply = try await engine.callTool("find_data", ["west": n[0], "south": n[1], "east": n[2], "north": n[3]])
            guard !Task.isCancelled else { return }
            let rows = Engine.rows(reply)
            coverage = rows.compactMap { row in
                guard let id = row["id"] as? String else { return nil }
                return Coverage(id: id, title: row["title"] as? String ?? id, source: row["source"] as? String ?? "",
                                collected: String((row["collected"] as? String ?? "").prefix(4)),
                                needs: row["needs_token"] as? Bool == true ? "Needs a free token: paste it in Settings, Data and privacy." : "")
            }
            if let errors = rows.compactMap({ $0["errors"] as? [String] }).first, coverage?.isEmpty == true {
                coverageProblem = "A catalog did not answer: " + errors.joined(separator: "; ")
            }
        } catch {
            if !Task.isCancelled { coverageProblem = error.localizedDescription }
        }
    }

    private func create() {
        guard let n = numbers else { return }
        busy = true
        problem = nil
        // In the tutorial, getting the terrain is the person's own next step, so the project starts without it.
        let tutorial = app.tutorialOn && point.id == Tutorial.point.id
        Task { @MainActor in
            do {
                try await app.createProject(name: name.trimmingCharacters(in: .whitespaces), question: question, box: n,
                                            fetch: !tutorial, from: point.chat == nil ? nil : point, inGitHub: inGitHub)
                if tutorial { app.tutorialProject = app.store.current?.path }
            } catch {
                problem = error.localizedDescription
            }
            busy = false
        }
    }
}


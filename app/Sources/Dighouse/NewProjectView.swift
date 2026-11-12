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
    }

    @State private var name: String
    @State private var question: String
    @State private var box: [String]
    @State private var size: Double
    @State private var camera: MapCameraPosition
    @State private var query = ""
    @State private var places: [Place] = []
    @State private var searching = false
    @State private var searchProblem: String?
    @State private var coverage: [Coverage]?
    @State private var coverageProblem: String?
    @State private var showEdges = false
    @State private var busy = false
    @State private var problem: String?

    private static let sizes: [Double] = [0.3, 0.6, 1, 1.5, 2]

    init(point: StartingPoint) {
        self.point = point
        _name = State(initialValue: point.name)
        _question = State(initialValue: point.question)
        _box = State(initialValue: point.box)
        let n = point.box.compactMap(Double.init)
        if n.count == 4 {
            let km = (n[3] - n[1]) * 110.54
            _size = State(initialValue: Self.sizes.min { abs($0 - km) < abs($1 - km) } ?? 0.6)
            _camera = State(initialValue: Self.region(lat: (n[1] + n[3]) / 2, lon: (n[0] + n[2]) / 2, span: (n[3] - n[1]) * 5))
        } else {
            _size = State(initialValue: 0.6)
            _camera = State(initialValue: Self.region(lat: 25, lon: -40, span: 110))
        }
    }

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
        .task(id: box.joined(separator: ",")) { await checkCoverage() }
    }

    // MARK: map

    private var map: some View {
        MapReader { proxy in
            Map(position: $camera) {
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
            .onTapGesture { spot in
                if let place = proxy.convert(spot, from: .local) { setCentre(lat: place.latitude, lon: place.longitude) }
            }
        }
        .overlay(alignment: .top) {
            Text(numbers == nil ? "Click the map to place the search area" : "Click the map to move the search area")
                .font(.system(size: 12.5, weight: .medium))
                .padding(.horizontal, 12).frame(height: 28)
                .background(Capsule().fill(.black.opacity(0.7))).padding(12)
                .allowsHitTesting(false)
        }
    }

    private func setCentre(lat: Double, lon: Double) {
        let dLat = size / 110.54 / 2, dLon = size / (111.32 * cos(lat * .pi / 180)) / 2
        box = [lon - dLon, lat - dLat, lon + dLon, lat + dLat].map { String(format: "%.5f", $0) }
    }

    // MARK: form

    private var form: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 4) {
                Text("New project").font(.system(size: 22, weight: .bold))
                Text(point.kind == .own ? "A project is one question about one area."
                     : "Starting from \(point.title). You can change anything below.")
                    .font(.system(size: 13)).foregroundStyle(Theme.dim).fixedSize(horizontal: false, vertical: true)
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
                if searching { ProgressView().controlSize(.small) }
                if let searchProblem { Text(searchProblem).font(.system(size: 12.5)).foregroundStyle(Theme.amber) }
                if !places.isEmpty {
                    VStack(spacing: 0) {
                        ForEach(places) { place in
                            Button {
                                camera = Self.region(lat: place.lat, lon: place.lon, span: place.span)
                                setCentre(lat: place.lat, lon: place.lon)
                                places = []
                            } label: {
                                Text(place.name).font(.system(size: 12.5)).lineLimit(2).multilineTextAlignment(.leading).padding(.vertical, 4)
                            }
                            .buttonStyle(RowButton())
                        }
                    }
                    .padding(4).panel(radius: 10)
                }
                HStack(spacing: 8) {
                    Text("Size").font(.system(size: 12.5)).foregroundStyle(Theme.dim)
                    ForEach(Self.sizes, id: \.self) { km in
                        Button {
                            size = km
                            if let n = numbers { setCentre(lat: (n[1] + n[3]) / 2, lon: (n[0] + n[2]) / 2) }
                        } label: {
                            Text(km < 1 ? "\(Int(km * 1000)) m" : "\(km.formatted()) km").font(.system(size: 12))
                                .foregroundStyle(size == km ? Theme.text : Theme.dim)
                                .padding(.horizontal, 9).frame(height: 24)
                                .background(Capsule().fill(size == km ? Color.white.opacity(0.12) : .clear))
                                .contentShape(Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                }
                Button { showEdges.toggle() } label: {
                    HStack(spacing: 5) {
                        Image(systemName: "chevron.right").font(.system(size: 8.5, weight: .bold)).rotationEffect(.degrees(showEdges ? 90 : 0))
                        Text("Edges in degrees")
                        if let km = areaKm2 { Text("· \(km.formatted(.number.precision(.fractionLength(2)))) square km").foregroundStyle(Theme.faint) }
                    }
                    .font(.system(size: 12.5)).foregroundStyle(Theme.dim).contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                if showEdges {
                    HStack(spacing: 6) {
                        ForEach(Array(["West", "South", "East", "North"].enumerated()), id: \.offset) { i, label in
                            TextField(label, text: $box[i]).field().font(.system(size: 12))
                        }
                    }
                }
                if let km = areaKm2, km > 6 {
                    Text("This is a large area. Terrain is fetched in pieces under 6 square km, so a first project is quicker when it is small.")
                        .font(.system(size: 12)).foregroundStyle(Theme.amber).fixedSize(horizontal: false, vertical: true)
                }
                Text("The area is stored privately in the project and stays on this Mac.")
                    .font(.system(size: 12)).foregroundStyle(Theme.faint).fixedSize(horizontal: false, vertical: true)
            }

            labeled("Open lidar here") { coverageList }

            if let problem { Text(problem).foregroundStyle(Theme.amber).font(.system(size: 12.5)).fixedSize(horizontal: false, vertical: true) }
            HStack(spacing: 8) {
                Button("Cancel") { app.goHome() }.buttonStyle(SecondaryButton())
                Spacer()
                if busy { ProgressView().controlSize(.small) }
                Button("Create project", action: create).buttonStyle(PrimaryButton()).disabled(busy || !valid || !engine.ready)
            }
        }
        .font(.system(size: 13))
    }

    private func labeled(_ label: String, @ViewBuilder _ content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label).font(.system(size: 12.5, weight: .semibold))
            content()
        }
    }

    @ViewBuilder private var coverageList: some View {
        if numbers == nil {
            Text("Place the area to see which open surveys cover it.").font(.system(size: 12.5)).foregroundStyle(Theme.faint)
        } else if let coverageProblem {
            Text(coverageProblem).font(.system(size: 12.5)).foregroundStyle(Theme.amber).fixedSize(horizontal: false, vertical: true)
        } else if let coverage {
            if coverage.isEmpty {
                Text("None of the open catalogs Dighouse reads (OpenTopography and USGS 3DEP) cover this area. Try another place, or ask the agent about other sources.")
                    .font(.system(size: 12.5)).foregroundStyle(Theme.amber).fixedSize(horizontal: false, vertical: true)
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(coverage.enumerated()), id: \.element.id) { index, item in
                        if index > 0 { Hairline() }
                        HStack(alignment: .top, spacing: 10) {
                            Image(systemName: "checkmark.circle.fill").foregroundStyle(Theme.green).font(.system(size: 13)).padding(.top, 1)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(item.title).font(.system(size: 12.5)).fixedSize(horizontal: false, vertical: true)
                                Text([item.source, item.collected].filter { !$0.isEmpty }.joined(separator: " · "))
                                    .font(.system(size: 11.5)).foregroundStyle(Theme.faint)
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
                ProgressView().controlSize(.small)
                Text("Checking the open catalogs").font(.system(size: 12.5)).foregroundStyle(Theme.dim)
            }
        }
    }

    // MARK: actions

    private func search() {
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
            } catch {
                searchProblem = error.localizedDescription
            }
            searching = false
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
                                collected: String((row["collected"] as? String ?? "").prefix(4)))
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
        Task { @MainActor in
            do {
                try await app.createProject(name: name.trimmingCharacters(in: .whitespaces), question: question, box: n)
            } catch {
                problem = error.localizedDescription
            }
            busy = false
        }
    }
}


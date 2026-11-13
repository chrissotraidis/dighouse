import Foundation

/// The projects this app knows about, and everything on disk for the one that is open.
@MainActor
final class ProjectStore: ObservableObject {
    @Published var projects: [ProjectRef] = []
    @Published var current: ProjectRef?
    @Published var terrains: [Terrain] = []
    @Published var tiles: [Tile] = []
    @Published var candidates: [Candidate] = []
    @Published var status = RunStatus()
    @Published var selectedTile: String?
    @Published var selectedCandidate: String?
    /// A download in progress, from the file the tools write while they fetch terrain.
    @Published var download: Download?

    struct Download: Equatable {
        let dataset: String
        let done: Int, total: Int
        let started: Date

        /// "about 3 minutes left", once a few parts have come in to judge by.
        var left: String? {
            guard done >= 2, total > done else { return nil }
            let each = Date().timeIntervalSince(started) / Double(done)
            let seconds = each * Double(total - done)
            if seconds < 60 { return "under a minute left" }
            let minutes = Int((seconds / 60).rounded())
            return "about \(minutes) minute\(minutes == 1 ? "" : "s") left"
        }
    }

    var fetchStatus: ((String) async -> RunStatus?)?
    private var signature = ""
    private var timer: Timer?

    init() {
        if let data = UserDefaults.standard.data(forKey: "projects"),
           let saved = try? JSONDecoder().decode([ProjectRef].self, from: data) {
            projects = saved.filter { FileManager.default.fileExists(atPath: $0.path + "/PROJECT.md") }
        }
        if let last = UserDefaults.standard.string(forKey: "currentProject") {
            current = projects.first { $0.path == last }
        }
        timer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.reloadIfChanged() }
        }
        reloadIfChanged()
    }

    /// Add a project folder to the list without opening it.
    func register(path: String) {
        guard FileManager.default.fileExists(atPath: path + "/PROJECT.md"), !projects.contains(where: { $0.path == path }) else { return }
        let state = json(path + "/private/state/project.json") as? JSON
        projects.append(ProjectRef(path: path, name: state?["name"] as? String ?? URL(fileURLWithPath: path).lastPathComponent))
        if let data = try? JSONEncoder().encode(projects) { UserDefaults.standard.set(data, forKey: "projects") }
    }

    /// Leave the open project, back to the general chat.
    func close() {
        current = nil
        selectedTile = nil
        selectedCandidate = nil
        UserDefaults.standard.removeObject(forKey: "currentProject")
        signature = ""
        reloadIfChanged()
    }

    func remove(_ ref: ProjectRef) {
        projects.removeAll { $0 == ref }
        if let data = try? JSONEncoder().encode(projects) { UserDefaults.standard.set(data, forKey: "projects") }
        if current == ref { close() }
    }

    func open(_ ref: ProjectRef) {
        current = ref
        selectedTile = nil
        selectedCandidate = nil
        UserDefaults.standard.set(ref.path, forKey: "currentProject")
        signature = ""
        reloadIfChanged()
    }

    func reloadIfChanged() {
        guard let root = current?.path else {
            terrains = []; tiles = []; candidates = []; status = RunStatus(); download = nil
            return
        }
        readDownload(root)
        let fm = FileManager.default
        let records = ((try? fm.contentsOfDirectory(atPath: root + "/candidates")) ?? []).filter { $0.hasSuffix(".md") }.sorted()
        let watched = ["terrains", "tiles", "locations", "controls"].map { root + "/private/state/\($0).json" }
            + records.map { root + "/candidates/" + $0 }
        let now = watched.map { path -> String in
            let date = (try? fm.attributesOfItem(atPath: path)[.modificationDate]) as? Date
            return "\(path)@\(date?.timeIntervalSince1970 ?? 0)"
        }.joined(separator: "|")
        guard now != signature else { return }
        signature = now
        load(root, records)
        Task {
            if let fresh = await fetchStatus?(root), current?.path == root { status = fresh }
        }
    }

    private func load(_ root: String, _ records: [String]) {
        let terrainState = json(root + "/private/state/terrains.json") as? [String: JSON] ?? [:]
        terrains = terrainState.map { id, t in
            Terrain(id: id, dataset: t["dataset"] as? String ?? "", areaKm2: t["area_km2"] as? Double ?? 0,
                    groundPerM2: t["ground_points_per_m2"] as? Double ?? 0, res: t["res"] as? Double ?? 0.5,
                    box: (t["box"] as? [Double]) ?? [], epsg: t["epsg"] as? Int ?? 0,
                    source: t["source"] as? String ?? "", collected: t["collected"] as? String ?? "",
                    file: t["file"] as? String ?? "", points: t["points"] as? String)
        }.sorted { $0.id < $1.id }

        let tileState = json(root + "/private/state/tiles.json") as? [String: JSON] ?? [:]
        tiles = tileState.compactMap { id, t in
            guard let w = t["window"] as? [Int], w.count == 4 else { return nil }
            return Tile(id: id, terrain: t["terrain"] as? String ?? "", row: w[0], col: w[1], rows: w[2], cols: w[3],
                        status: t["status"] as? String ?? "", verdict: t["verdict"] as? String,
                        note: t["note"] as? String, model: t["model"] as? String)
        }.sorted { $0.id < $1.id }

        let places = json(root + "/private/state/locations.json") as? [String: JSON] ?? [:]
        candidates = records.compactMap { file in
            guard let text = try? String(contentsOfFile: root + "/candidates/" + file, encoding: .utf8) else { return nil }
            let parts = text.components(separatedBy: "---\n")
            guard parts.count >= 3 else { return nil }
            var meta: JSON = [:]
            for line in parts[1].split(separator: "\n") {
                guard let split = line.range(of: ": ") else { continue }
                let value = String(line[split.upperBound...])
                meta[String(line[..<split.lowerBound])] = try? JSONSerialization.jsonObject(with: Data(value.utf8), options: .fragmentsAllowed)
            }
            guard let id = meta["id"] as? String else { return nil }
            let decisions = (meta["decisions"] as? [JSON] ?? []).map {
                "\($0["date"] as? String ?? "") · \($0["by"] as? String ?? "") · \(Candidate.labels[$0["status"] as? String ?? ""] ?? ""): \($0["reason"] as? String ?? "")"
            }
            var c = Candidate(
                id: id, name: meta["name"] as? String ?? "", status: meta["status"] as? String ?? "",
                flagged: meta["flagged"] as? String ?? "", flaggedBy: meta["flagged_by"] as? String ?? "",
                tile: meta["tile"] as? String ?? "", evidence: meta["evidence"] as? [String] ?? [],
                checks: meta["checks"] as? JSON ?? [:],
                sources: (meta["sources"] as? [JSON] ?? []).map {
                    Source(title: $0["title"] as? String ?? "", status: $0["status"] as? String ?? "", finding: $0["finding"] as? String ?? "", link: $0["link"] as? String ?? "")
                },
                decisions: decisions, folder: root + "/candidates")
            if let sug = meta["suggestion"] as? JSON, let st = sug["status"] as? String, let why = sug["reason"] as? String {
                c.suggestion = (st, why, sug["by"] as? String ?? "the agent")
            }
            if let place = places[id] {
                c.x = place["x"] as? Double ?? 0.5
                c.y = place["y"] as? Double ?? 0.5
            }
            return c
        }
    }

    private func json(_ path: String) -> Any? {
        guard let data = FileManager.default.contents(atPath: path) else { return nil }
        return try? JSONSerialization.jsonObject(with: data)
    }

    /// The tools write private/state/progress.json while a fetch runs and remove it when it ends.
    /// A file not touched for ten minutes is left over from a fetch that was cut off, so it is ignored.
    private func readDownload(_ root: String) {
        guard let p = json(root + "/private/state/progress.json") as? JSON,
              let updated = p["updated"] as? Double, Date().timeIntervalSince1970 - updated < 600 else {
            if download != nil { download = nil }
            return
        }
        let next = Download(dataset: p["dataset"] as? String ?? "lidar", done: p["done"] as? Int ?? 0, total: p["total"] as? Int ?? 0,
                            started: Date(timeIntervalSince1970: p["started"] as? Double ?? updated))
        if next != download { download = next }
    }

    static func status(from text: String) -> RunStatus? {
        guard let root = try? JSONSerialization.jsonObject(with: Data(text.utf8)) as? JSON else { return nil }
        let coverage = root["coverage"] as? JSON ?? [:]
        let controls = root["controls"] as? JSON ?? [:]
        var s = RunStatus()
        s.tiles = coverage["tiles"] as? Int ?? 0
        s.unscreened = coverage["unscreened"] as? Int ?? 0
        s.screened = coverage["screened"] as? Int ?? 0
        s.unreadable = coverage["unreadable"] as? Int ?? 0
        s.candidates = (root["candidates"] as? [String: Int] ?? [:]).values.reduce(0, +)
        s.controls = controls["registered"] as? Int ?? 0
        s.controlsFound = controls["found_again"] as? Int ?? 0
        s.needsPerson = root["needs_a_person"] as? [String] ?? []
        return s
    }
}

import Foundation

/// The projects this app knows about, and everything on disk for the one that is open.
@MainActor
final class ProjectStore: ObservableObject {
    @Published var projects: [ProjectRef] = [] {
        didSet { blindTests = Set(projects.map(\.path).filter { FileManager.default.fileExists(atPath: $0 + "/private/state/test.json") }) }
    }
    /// The projects that are blind tests, so the sidebar can keep them in a group of their own.
    @Published private(set) var blindTests: Set<String> = []
    @Published var current: ProjectRef?
    @Published var terrains: [Terrain] = []
    @Published var tiles: [Tile] = []
    @Published var candidates: [Candidate] = []
    /// Sources logged for the project as a whole, such as a survey's metadata or a search that found nothing of use.
    @Published var projectSources: [Source] = []
    @Published var status = RunStatus()
    @Published var selectedTile: String?
    @Published var selectedCandidate: String?
    /// A download in progress, from the file the tools write while they fetch terrain.
    @Published var download: Download?
    /// How many tiles were screened before this project was handed over, when it arrived without its downloads.
    /// Nil for a project that has its own data, or none yet.
    @Published var screenedBefore: Int?

    /// A blind test (or a calibration) is scored against a published key, before and after scoring, so its finds wait
    /// for no decision.
    var isBlindTest: Bool {
        guard let root = current?.path else { return false }
        return FileManager.default.fileExists(atPath: root + "/private/state/test.json")
    }

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
            // A project can be renamed while the app is closed (name_project), so names are read again at launch.
            projects = saved.filter { FileManager.default.fileExists(atPath: $0.path + "/PROJECT.md") }
                .map { ProjectRef(path: $0.path, name: Self.savedName(of: $0.path) ?? $0.name) }
            for i in projects.indices { projects[i].name = listed(projects[i].name, for: projects[i].path, among: projects[..<i]) }
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
        // A project someone shared has no private state, so its name comes from the heading of PROJECT.md.
        let heading = (try? String(contentsOfFile: path + "/PROJECT.md", encoding: .utf8))?.split(separator: "\n").first
            .flatMap { $0.hasPrefix("# ") ? String($0.dropFirst(2)).trimmingCharacters(in: .whitespaces) : nil }
        let name = state?["name"] as? String ?? heading ?? URL(fileURLWithPath: path).lastPathComponent
        projects.append(ProjectRef(path: path, name: listed(name, for: path, among: projects[...])))
        if let data = try? JSONEncoder().encode(projects) { UserDefaults.standard.set(data, forKey: "projects") }
    }

    /// The name a project is listed under: its own, or numbered like a chat when another project in the list
    /// already has it (Find something can search the same region twice). Only the list changes; the project's files keep their name.
    private func listed(_ name: String, for path: String, among others: ArraySlice<ProjectRef>) -> String {
        let taken = Set(others.lazy.filter { $0.path != path }.map(\.name))
        guard taken.contains(name) else { return name }
        var n = 2
        while taken.contains("\(name) \(n)") { n += 1 }
        return "\(name) \(n)"
    }

    /// Projects kept in an iCloud folder, whose files can go offline.
    var cloudProjects: [ProjectRef] { projects.filter { Paths.inCloud($0.path) } }
    /// While projects move out of iCloud: which one, of how many. Nil when nothing is moving.
    @Published var moving: (done: Int, of: Int, name: String)?
    @Published var moveProblem: String?

    /// Copy each project kept in iCloud to this Mac, check the copy, then put the original in the Trash.
    /// The copy is made by ditto, which waits for iCloud to download each offline file; that can take minutes.
    func moveOutOfCloud() async {
        let todo = cloudProjects
        guard moving == nil, !todo.isEmpty else { return }
        let home = Paths.localProjectsHome
        try? FileManager.default.createDirectory(at: home, withIntermediateDirectories: true)
        moveProblem = nil
        for (i, ref) in todo.enumerated() {
            moving = (i, todo.count, ref.name)
            let name = URL(fileURLWithPath: ref.path).lastPathComponent
            var target = home.appendingPathComponent(name).path
            var n = 2
            while FileManager.default.fileExists(atPath: target) { target = home.appendingPathComponent("\(name)-\(n)").path; n += 1 }
            let copy = await Shell.run("/usr/bin/ditto", [ref.path, target])
            let same = await Task.detached { Self.sameFiles(ref.path, target) }.value
            guard copy.code == 0, same else {
                moveProblem = "\(ref.name) could not be copied, so it was left where it is. " + String(copy.out.prefix(200))
                continue
            }
            try? FileManager.default.trashItem(at: URL(fileURLWithPath: ref.path), resultingItemURL: nil)
            if let at = projects.firstIndex(of: ref) { projects[at].path = target }
            if current == ref { current = ProjectRef(path: target, name: ref.name); UserDefaults.standard.set(target, forKey: "currentProject") }
            if let data = try? JSONEncoder().encode(projects) { UserDefaults.standard.set(data, forKey: "projects") }
        }
        if !Paths.inCloud(home.path) { UserDefaults.standard.set(home.path, forKey: "projectsHome") }
        moving = nil
        signature = ""
        reloadIfChanged()
    }

    /// Whether two folders hold the same files at the same sizes.
    nonisolated static func sameFiles(_ a: String, _ b: String) -> Bool {
        func list(_ root: String) -> [String: Int] {
            var out: [String: Int] = [:]
            let url = URL(fileURLWithPath: root)
            guard let walk = FileManager.default.enumerator(at: url, includingPropertiesForKeys: [.fileSizeKey, .isRegularFileKey]) else { return out }
            for case let file as URL in walk {
                guard let v = try? file.resourceValues(forKeys: [.fileSizeKey, .isRegularFileKey]), v.isRegularFile == true else { continue }
                out[String(file.path.dropFirst(url.path.count))] = v.fileSize ?? 0
            }
            return out
        }
        let (x, y) = (list(a), list(b))
        return !x.isEmpty && x == y
    }

    /// Leave the open project, back to the general chat.
    func close() {
        current = nil
        screenedBefore = nil
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
        screenedBefore = nil
        selectedTile = nil
        selectedCandidate = nil
        status = RunStatus()   // the last project's counts must not show beside this one's ground
        UserDefaults.standard.set(ref.path, forKey: "currentProject")
        signature = ""
        reloadIfChanged()
    }

    /// The project that was open last, for Home to offer again. Opening a project brings its research record
    /// up to date, so the newest record marks it.
    var recent: ProjectRef? {
        func written(_ ref: ProjectRef) -> Date {
            return ["/RESEARCH.md", "/PROJECT.md"].lazy.compactMap { FileInfo.modified(ref.path + $0) }.first ?? .distantPast
        }
        return projects.max { written($0) < written($1) }
    }

    /// What a project holds, read from its folder without opening it.
    nonisolated static func glance(_ root: String) -> (tiles: Int, unscreened: Int, finds: Int, undecided: Int, needsYou: Int, toAgree: Int) {
        let fm = FileManager.default
        let tiles = (fm.contents(atPath: root + "/private/state/tiles.json").flatMap { try? JSONSerialization.jsonObject(with: $0) } as? [String: JSON] ?? [:]).values
        let records = ((try? fm.contentsOfDirectory(atPath: root + "/candidates")) ?? []).filter { $0.hasSuffix(".md") }.sorted()
        let finds = readCandidates(root, records)
        let test = fm.fileExists(atPath: root + "/private/state/test.json")
        let needs = test ? 0 : finds.filter { [.closer, .lookAgain, .open].contains($0.group) }.count
        let agree = test ? 0 : finds.filter { $0.group.confirmable }.count
        return (tiles.count, tiles.filter { $0["status"] as? String == "unscreened" }.count, finds.count, finds.filter(\.waiting).count, needs, agree)
    }

    /// The finds a person decides one at a time: leads, disagreements, and finds with no suggestion. The one count
    /// the header, the overview and Decide all show.
    var needsYou: [Candidate] { isBlindTest ? [] : candidates.filter { [.closer, .lookAgain, .open].contains($0.group) } }
    /// The routine finds a person can agree with together, from their pictures.
    var toAgree: [Candidate] { isBlindTest ? [] : candidates.filter { $0.group.confirmable } }
    /// Measured rises kept on the map rather than put to a person.
    var onMap: Int { isBlindTest ? 0 : candidates.filter { $0.group == .layer }.count }

    /// "6 need you · 70 to agree", or whichever part there is.
    var decideWords: String {
        let n = needsYou.count, m = toAgree.count
        return [n > 0 ? "\(n) need\(n == 1 ? "s" : "") you" : nil, m > 0 ? "\(m) to agree with" : nil].compactMap { $0 }.joined(separator: " · ")
    }

    /// About how long deciding takes: some 20 seconds a find looked at alone, a few seconds each in the grid.
    var decideMinutes: Int { max(1, Int((Double(needsYou.count) * 20 + Double(toAgree.count) * 3) / 60 + 0.5)) }

    /// How many named areas the project's ground is in (unnamed ground counts as one).
    var areaCount: Int { Set(terrains.map { $0.area ?? "" }).count }

    /// How wide the close view of a find is, the same for every find so sizes can be compared by eye.
    static let closeMetres = 60.0

    /// How wide a find's tile is on the ground, from its window and its ground model's resolution.
    func tileMetres(_ c: Candidate) -> Double {
        guard let tile = tiles.first(where: { $0.id == c.tile }) else { return 250 }
        let res = terrains.first(where: { $0.id == tile.terrain })?.res ?? 0.5
        return Double(tile.cols) * res
    }

    /// The close view's side as a fraction of the tile picture.
    func closeSide(_ c: Candidate) -> Double { Self.closeMetres / max(tileMetres(c), 1) }

    /// Read the open project again even if nothing changed (for measuring).
    func reloadNow() { signature = ""; reloadIfChanged() }

    func reloadIfChanged() {
        guard let root = current?.path else {
            terrains = []; tiles = []; candidates = []; projectSources = []; status = RunStatus(); download = nil
            return
        }
        readDownload(root)
        let fm = FileManager.default
        let records = ((try? fm.contentsOfDirectory(atPath: root + "/candidates")) ?? []).filter { $0.hasSuffix(".md") }.sorted()
        let watched = ["terrains", "tiles", "locations", "controls", "project"].map { root + "/private/state/\($0).json" }
            + records.map { root + "/candidates/" + $0 } + [root + "/sources/read-log.md"]
        let now = watched.map { path -> String in
            let date = FileInfo.modified(path)
            return "\(path)@\(date?.timeIntervalSince1970 ?? 0)"
        }.joined(separator: "|")
        guard now != signature else { return }
        signature = now
        if Perf.on { Perf.label = "reading the open project (\(records.count) finds)" }
        load(root, records)
        Task {
            if let fresh = await fetchStatus?(root), current?.path == root { status = fresh }
        }
    }

    /// The name in a project's own state, which name_project changes.
    nonisolated static func savedName(of path: String) -> String? {
        guard let data = FileManager.default.contents(atPath: path + "/private/state/project.json"),
              let info = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any],
              let name = info["name"] as? String, !name.isEmpty else { return nil }
        return name
    }

    /// Show a project under its new name everywhere, as soon as the agent renames it.
    private func followName(_ root: String) {
        guard let saved = Self.savedName(of: root), let i = projects.firstIndex(where: { $0.path == root }) else { return }
        let name = projects[i].name == saved || projects[i].name.hasPrefix(saved + " ") && Int(projects[i].name.dropFirst(saved.count + 1)) != nil
            ? projects[i].name : listed(saved, for: root, among: projects[...])
        guard projects[i].name != name else { return }
        projects[i].name = name
        if current?.path == root { current = projects[i] }
        if let data = try? JSONEncoder().encode(projects) { UserDefaults.standard.set(data, forKey: "projects") }
    }

    private func load(_ root: String, _ records: [String]) {
        followName(root)
        let terrainState = json(root + "/private/state/terrains.json") as? [String: JSON] ?? [:]
        terrains = terrainState.map { id, t in
            Terrain(id: id, dataset: t["dataset"] as? String ?? "", areaKm2: t["area_km2"] as? Double ?? 0,
                    groundPerM2: t["ground_points_per_m2"] as? Double ?? 0, res: t["res"] as? Double ?? 0.5,
                    box: (t["box"] as? [Double]) ?? [], epsg: t["epsg"] as? Int ?? 0,
                    source: t["source"] as? String ?? "", collected: t["collected"] as? String ?? "",
                    file: t["file"] as? String ?? "", points: t["points"] as? String,
                    area: t["area"] as? String, lonlat: (t["lonlat"] as? [Double]) ?? [])
        }.sorted { $0.id < $1.id }

        let tileState = json(root + "/private/state/tiles.json") as? [String: JSON] ?? [:]
        tiles = tileState.compactMap { id, t in
            guard let w = t["window"] as? [Int], w.count == 4 else { return nil }
            return Tile(id: id, terrain: t["terrain"] as? String ?? "", row: w[0], col: w[1], rows: w[2], cols: w[3],
                        status: t["status"] as? String ?? "", verdict: t["verdict"] as? String,
                        note: t["note"] as? String, model: t["model"] as? String)
        }.sorted { $0.id < $1.id }

        candidates = Self.readCandidates(root, records)
        projectSources = Self.readProjectSources(root)
        // Until the tools answer with the run status, the header counts what was just read: a large project took a few
        // seconds and showed "Ground ready, not cut into tiles · 1 find" meanwhile.
        if status.tiles == 0, status.candidates == 0 {
            status.tiles = tiles.count
            status.unreadable = tiles.filter { $0.status == "unreadable" }.count
            status.unscreened = tiles.filter { $0.status == "unscreened" }.count
            status.screened = status.tiles - status.unreadable - status.unscreened
            status.candidates = candidates.count
        }
    }

    /// The read log's lines for the project as a whole: "- date · project · status · title · link · what it says".
    nonisolated static func readProjectSources(_ root: String) -> [Source] {
        let log = (try? String(contentsOfFile: root + "/sources/read-log.md", encoding: .utf8)) ?? ""
        var seen = Set<String>()
        return log.split(separator: "\n").compactMap { line -> Source? in
            guard line.hasPrefix("- ") else { return nil }
            let parts = line.dropFirst(2).components(separatedBy: " · ")
            guard parts.count >= 5, parts[1] == "project", seen.insert(parts[3]).inserted else { return nil }
            return Source(title: parts[3], status: parts[2], finding: parts.dropFirst(5).joined(separator: " · "), link: parts[4])
        }
    }

    /// Every source the project logged, each title once: those on its records first, then those for the whole project.
    var allSources: [Source] {
        var seen = Set<String>()
        return (candidates.flatMap(\.sources) + projectSources).filter { seen.insert($0.title).inserted }
    }

    /// The measured rises kept on the map rather than put to a person. The same rule as ledger.layer in the tools:
    /// a rise goes to a person when the second model calls it built and its shape ranks in the top half of this
    /// project's measured rises, or when a person raises it.
    /// The open finds worth a second opinion, best first. A measured rise reaches a person only when the second model
    /// calls it built and its shape ranks in the top half of the project's rises (see layer), so a rise below that cut is
    /// never asked: the same finds reach a person, for some 40% fewer opinions (EASE_LOOP E1, run 18: 4,777 of 8,065).
    /// Finds the agent marked come first, then the rest by how well their shape ranks.
    nonisolated static func worthAsking(_ all: [Candidate]) -> [String] {
        let rank: (Candidate) -> Double = { c in
            let r = (c.checks["shape"] as? JSON)?["rank"]
            return (r as? Double) ?? (r as? Int).map(Double.init) ?? 0
        }
        let ranks = all.filter { $0.flaggedBy.hasPrefix("measured") }.map(rank).sorted()
        let cut = ranks.isEmpty ? 0 : ranks[min(Int(Double(ranks.count) * 0.5), ranks.count - 1)]
        let open = all.filter { $0.waiting && $0.checks["second_look"] == nil && ($0.raised || !$0.flaggedBy.hasPrefix("measured") || rank($0) >= cut) }
        let byAgent = { (c: Candidate) in !c.flaggedBy.hasPrefix("measured") && !c.flaggedBy.hasPrefix("seen in bulk") }
        return open.sorted { a, b in byAgent(a) != byAgent(b) ? byAgent(a) : rank(a) > rank(b) }.map(\.id)
    }

    nonisolated static func layer(_ all: [Candidate]) -> Set<String> {
        let rank: (Candidate) -> Double = { c in
            let r = (c.checks["shape"] as? JSON)?["rank"]
            return (r as? Double) ?? (r as? Int).map(Double.init) ?? 0
        }
        let rises = all.filter { $0.flaggedBy.hasPrefix("measured") }
        let ranks = rises.map(rank).sorted()
        let cut = ranks.isEmpty ? 0 : ranks[min(Int(Double(ranks.count) * 0.5), ranks.count - 1)]
        let keptRises = rises.filter { $0.waiting && !$0.raised && !($0.secondSaysBuilt == true && rank($0) >= cut) }
        // Shapes the bulk look pointed at that the agent did not mark wait on the map unless the second model calls them built.
        let keptBulk = all.filter { $0.flaggedBy.hasPrefix("seen in bulk") && $0.waiting && !$0.raised && $0.secondSaysBuilt != true }
        return Set((keptRises + keptBulk).map(\.id))
    }

    /// Every find of a project, read from its candidates/ folder, with the measured rises kept on the map marked.
    nonisolated static func readCandidates(_ root: String, _ records: [String]) -> [Candidate] {
        let places = (FileManager.default.contents(atPath: root + "/private/state/locations.json")
            .flatMap { try? JSONSerialization.jsonObject(with: $0) } as? [String: JSON]) ?? [:]
        var found: [Candidate] = records.compactMap { file in
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
            c.raised = meta["raised"] != nil
            if let place = places[id] {
                c.x = place["x"] as? Double ?? 0.5
                c.y = place["y"] as? Double ?? 0.5
            }
            return c
        }
        let kept = Self.layer(found)
        for i in found.indices where kept.contains(found[i].id) { found[i].inLayer = true }
        return found
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

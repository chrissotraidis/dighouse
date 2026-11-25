import AppKit

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

    /// Counts the pages ask for on every redraw, made once whenever the finds are read: counting 8,065 finds five
    /// times a redraw, each reading its checks, took a good part of a second.
    struct Tally {
        var open = 0, toCheck = 0, toAsk = 0, toSearch = 0, unprepared = 0, reportReady = 0
        var checked = 0, seconded = 0, sourced = 0
    }
    private(set) var tally = Tally()
    /// The finds sorted for Decide, worked out with the reading: the overview, the header and the map ask for them on
    /// every redraw, and filtering 8,065 finds each time made opening ⌘K over a sweep take half a second.
    struct Groups: Sendable {
        var needsYou: [Candidate] = [], toAgree: [Candidate] = [], onMap = 0
    }
    private(set) var groups = Groups()
    /// Where each find is in candidates, by its id: Decide looks up hundreds of finds on every redraw, and searching
    /// 8,065 for each took millions of comparisons.
    private var place: [String: Int] = [:]
    func candidate(_ id: String?) -> Candidate? {
        guard let id, let i = place[id], candidates.indices.contains(i), candidates[i].id == id else { return nil }
        return candidates[i]
    }
    /// Every source the project logged, each title once: those on its records first, then those for the whole project.
    private(set) var allSources: [Source] = []

    /// The counts and the sources, worked out with the reading (in the background for a large project).
    nonisolated static func count(_ candidates: [Candidate], _ projectSources: [Source]) -> (Tally, [Source], Groups) {
        var t = Tally(), g = Groups()
        for c in candidates {
            switch c.group {
            case .closer, .lookAgain, .open: g.needsYou.append(c)
            case .layer: g.onMap += 1
            case let group where group.confirmable: g.toAgree.append(c)
            default: break
            }
            let section = c.checks["section"] != nil, modern = c.checks["modern"] != nil, second = c.checks["second_look"] != nil
            if section && modern { t.checked += 1 }
            if second { t.seconded += 1 }
            if !c.sources.isEmpty { t.sourced += 1 }
            if c.status == "no_match_in_sources_read" { t.reportReady += 1 }
            guard c.waiting else { continue }
            t.open += 1
            if !section || !modern { t.toCheck += 1 }
            if !second { t.toAsk += 1 }
            if c.sources.isEmpty { t.toSearch += 1 }
            if c.suggestion == nil && !c.inLayer { t.unprepared += 1 }
        }
        var seen = Set<String>()
        return (t, (candidates.flatMap(\.sources) + projectSources).filter { seen.insert($0.title).inserted }, g)
    }
    @Published var status = RunStatus()
    @Published var selectedTile: String?
    @Published var selectedCandidate: String?
    /// True while an agent works in this project, so the map shows the search as it goes (EASE_LOOP E8).
    @Published var watching = false
    /// Finds that appeared since the project was opened, for a few seconds, so the map can show them arriving.
    @Published private(set) var fresh: Set<String> = []
    private var knownRoot = ""
    private var known: Set<String> = []
    /// A download in progress, from the file the tools write while they fetch terrain.
    @Published var download: Download?
    /// How many tiles were screened before this project was handed over, when it arrived without its downloads.
    /// Nil for a project that has its own data, or none yet.
    @Published var screenedBefore: Int?

    /// A blind test (or a calibration) is scored against a published key, before and after scoring, so its finds wait
    /// for no decision.
    /// Read with the project rather than asked of the disk: the overview and the header ask many times a redraw.
    private(set) var isBlindTest = false

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
        var ticks = 0
        timer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] _ in
            ticks += 1
            let look = ticks % 5 == 0
            Task { @MainActor in
                self?.reloadIfChanged()
                // Every ten seconds, any project another harness has made since.
                if look { self?.adoptNew() }
            }
        }
        reloadIfChanged()
        adoptNew()
        // Projects made outside the app (from Claude Code, or the tools in another harness) are listed when it comes forward.
        NotificationCenter.default.addObserver(forName: NSApplication.didBecomeActiveNotification, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.adoptNew() }
        }
    }

    /// List the projects in the projects folder that the list does not have yet: those made outside the app, by Claude
    /// Code or the tools in another harness. A project the person removed from the list stays off it.
    func adoptNew() {
        let home = Paths.projectsHome.path
        let removed = Set(UserDefaults.standard.stringArray(forKey: "removedProjects") ?? [])
        // Only folders made since this was added: before, a project taken off the list was not remembered, and it
        // should not come back.
        let since = UserDefaults.standard.object(forKey: "adoptSince") as? Date ?? {
            UserDefaults.standard.set(Date(), forKey: "adoptSince")
            return Date()
        }()
        let fm = FileManager.default
        for name in ((try? fm.contentsOfDirectory(atPath: home)) ?? []).sorted() where !name.hasPrefix(".") {
            let path = home + "/" + name
            guard !removed.contains(path), !projects.contains(where: { $0.path == path }),
                  fm.fileExists(atPath: path + "/PROJECT.md"), fm.fileExists(atPath: path + "/private/state/project.json"),
                  let made = (try? fm.attributesOfItem(atPath: path + "/PROJECT.md"))?[.creationDate] as? Date, made > since else { continue }
            register(path: path)
        }
    }

    /// Add a project folder to the list without opening it.
    func register(path: String) {
        guard FileManager.default.fileExists(atPath: path + "/PROJECT.md"), !projects.contains(where: { $0.path == path }) else { return }
        // Opened on purpose, so it is no longer one the person removed.
        UserDefaults.standard.set((UserDefaults.standard.stringArray(forKey: "removedProjects") ?? []).filter { $0 != path }, forKey: "removedProjects")
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
        UserDefaults.standard.set((UserDefaults.standard.stringArray(forKey: "removedProjects") ?? []) + [ref.path], forKey: "removedProjects")
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

    typealias Glance = (tiles: Int, unscreened: Int, finds: Int, undecided: Int, needsYou: Int, toAgree: Int, leads: [Lead])

    /// One of a project's strongest finds that wait for a person, for Home's short list.
    struct Lead: Codable, Sendable, Hashable {
        var id: String, name: String, agreement: Int
        var rank: String { agreement >= 3 ? "A" : agreement == 2 ? "B" : "C" }
    }

    /// What glance found for a project, kept with a mark of its files' last changes.
    private struct Kept: Codable, Sendable {
        var mark: String
        var counts: [Int]
        var leads: [Lead]?
    }

    /// Where the glances are kept between launches.
    static var glanceFile: URL { Paths.support.appendingPathComponent("glances.json") }

    /// glance for many projects. A project whose files have not changed since the last time is not read again (Home
    /// read all 27,000 finds of 104 projects after every launch: 5.5 s), and those that have are read side by side.
    nonisolated static func glances(_ roots: [String], keptIn file: URL) -> [Glance] {
        // The version is in the key, so a new build that counts differently reads everything again.
        let version = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "?"
        var kept = (try? JSONDecoder().decode([String: Kept].self, from: Data(contentsOf: file))) ?? [:]
        var out = [Glance](repeating: (0, 0, 0, 0, 0, 0, []), count: roots.count)
        var changed = false
        let lock = NSLock()
        DispatchQueue.concurrentPerform(iterations: roots.count) { i in
            let root = roots[i], mark = version + "|" + glanceMark(root)
            lock.lock(); let hit = kept[root]; lock.unlock()
            if let hit, hit.mark == mark, hit.counts.count == 6, let leads = hit.leads {
                let c = hit.counts
                lock.lock(); out[i] = (c[0], c[1], c[2], c[3], c[4], c[5], leads); lock.unlock()
                return
            }
            let g = glance(root)
            lock.lock()
            out[i] = g
            kept[root] = Kept(mark: mark, counts: [g.tiles, g.unscreened, g.finds, g.undecided, g.needsYou, g.toAgree], leads: g.leads)
            changed = true
            lock.unlock()
        }
        if changed, let data = try? JSONEncoder().encode(kept) { try? data.write(to: file, options: .atomic) }
        return out
    }

    /// The boxes of ground the person's projects searched, as west, south, east, north, read from each project's private
    /// state. Blind tests are left out: they are known sites. Shown only on this Mac's maps.
    nonisolated static func searchedBoxes(_ roots: [String]) -> [[Double]] {
        // A box never set (all zero, or 0°, 0° in the sea off Africa) is no search, and is left off the map.
        func real(_ b: [Double]) -> Bool { b.count == 4 && b[2] > b[0] && b[3] > b[1] && (abs(b[0] + b[2]) > 0.02 || abs(b[1] + b[3]) > 0.02) }
        return roots.flatMap { root -> [[Double]] in
            guard !FileManager.default.fileExists(atPath: root + "/private/state/test.json") else { return [] }
            // Each area's own box where the project kept it: a region project's box is far bigger than what was searched.
            if let data = FileManager.default.contents(atPath: root + "/private/state/terrains.json"),
               let all = (try? JSONSerialization.jsonObject(with: data)) as? [String: JSON] {
                let boxes = all.values.compactMap { $0["lonlat"] as? [Double] }.filter(real)
                if !boxes.isEmpty { return boxes }
            }
            guard let data = FileManager.default.contents(atPath: root + "/private/state/project.json"),
                  let info = (try? JSONSerialization.jsonObject(with: data)) as? JSON,
                  let box = info["bbox"] as? [Double], real(box) else { return [] }
            return [box]
        }
    }

    /// Changes whenever a file glance reads changes: how many find records there are, the newest of them, the tiles,
    /// and whether the project is a blind test.
    nonisolated static func glanceMark(_ root: String) -> String {
        let fm = FileManager.default
        let dir = root + "/candidates"
        let records = ((try? fm.contentsOfDirectory(atPath: dir)) ?? []).filter { $0.hasSuffix(".md") }
        let newest = records.compactMap { FileInfo.modified(dir + "/" + $0)?.timeIntervalSince1970 }.max() ?? 0
        let tiles = FileInfo.modified(root + "/private/state/tiles.json")?.timeIntervalSince1970 ?? 0
        let test = fm.fileExists(atPath: root + "/private/state/test.json")
        return "\(records.count)|\(newest)|\(tiles)|\(test)"
    }

    /// What a project holds, read from its folder without opening it.
    nonisolated static func glance(_ root: String) -> Glance {
        let fm = FileManager.default
        let tiles = (fm.contents(atPath: root + "/private/state/tiles.json").flatMap { try? JSONSerialization.jsonObject(with: $0) } as? [String: JSON] ?? [:]).values
        let records = ((try? fm.contentsOfDirectory(atPath: root + "/candidates")) ?? []).filter { $0.hasSuffix(".md") }.sorted()
        let finds = readCandidates(root, records)
        let test = fm.fileExists(atPath: root + "/private/state/test.json")
        let waiting = test ? [] : finds.filter { [.closer, .lookAgain, .open].contains($0.group) }
        let agree = test ? 0 : finds.filter { $0.group.confirmable }.count
        // The three most checks agree on, the lowest number first among equals.
        let leads = waiting.sorted { $0.agreement != $1.agreement ? $0.agreement > $1.agreement : $0.id < $1.id }
            .prefix(3).map { Lead(id: $0.id, name: $0.name, agreement: $0.agreement) }
        return (tiles.count, tiles.filter { $0["status"] as? String == "unscreened" }.count, finds.count, finds.filter(\.waiting).count,
                waiting.count, agree, leads)
    }

    /// The finds a person decides one at a time: leads, disagreements, and finds with no suggestion. The one count
    /// the header, the overview and Decide all show.
    var needsYou: [Candidate] { isBlindTest ? [] : groups.needsYou }
    /// The routine finds a person can agree with together, from their pictures.
    var toAgree: [Candidate] { isBlindTest ? [] : groups.toAgree }
    /// Measured rises kept on the map rather than put to a person.
    var onMap: Int { isBlindTest ? 0 : groups.onMap }

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
            tally = Tally(); allSources = []; groups = Groups(); isBlindTest = false; place = [:]
            return
        }
        readDownload(root)
        // Polling a large open project looks at every find's file, 8,065 of them in a sweep: 29 ms each time, every
        // 2 seconds of a run, so that look is taken in the background. Opening a project still looks at once.
        if knownRoot == root, candidates.count > 400 {
            guard looking == nil else { return }
            looking = Task.detached(priority: .utility) { [weak self] in
                let (now, records) = Self.look(root)
                await MainActor.run { [weak self] in
                    guard let self else { return }
                    self.looking = nil
                    if self.current?.path == root { self.changed(root, now, records) }
                }
            }
            return
        }
        let (now, records) = Self.look(root)
        changed(root, now, records)
    }

    private var looking: Task<Void, Never>?

    /// The project's find records and a line that changes whenever any file the window shows changes.
    nonisolated static func look(_ root: String) -> (signature: String, records: [String]) {
        let fm = FileManager.default
        let records = ((try? fm.contentsOfDirectory(atPath: root + "/candidates")) ?? []).filter { $0.hasSuffix(".md") }.sorted()
        let watched = ["terrains", "tiles", "locations", "controls", "project", "test"].map { root + "/private/state/\($0).json" }
            + records.map { root + "/candidates/" + $0 } + [root + "/sources/read-log.md"]
        let now = watched.map { path -> String in
            let date = FileInfo.modified(path)
            return "\(path)@\(date?.timeIntervalSince1970 ?? 0)"
        }.joined(separator: "|")
        return (now, records)
    }

    private func changed(_ root: String, _ now: String, _ records: [String]) {
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

    /// The strongest finds, the ones that wait for a person first, then by how many checks say built, then the oldest:
    /// picked in one pass over light keys, since sorting thousands of whole finds on every redraw took over a second.
    func strongest(_ n: Int, among finds: [Candidate]? = nil, first: Set<String> = []) -> [Candidate] {
        let pool = finds ?? candidates
        let keys = pool.indices.map { i in (first: first.contains(pool[i].id) ? 0 : 1, strength: -pool[i].agreement, id: pool[i].id, i: i) }
        return keys.sorted { ($0.first, $0.strength, $0.id) < ($1.first, $1.strength, $1.id) }.prefix(n).map { pool[$0.i] }
    }

    /// What a project's folder holds, read without touching the window, so a large project can be read in the background.
    struct Snapshot: Sendable {
        var terrains: [Terrain] = [], tiles: [Tile] = [], candidates: [Candidate] = [], sources: [Source] = []
        var tally = Tally(), allSources: [Source] = [], groups = Groups(), blindTest = false
        var place: [String: Int] = [:]
    }
    private var reading: Task<Void, Never>?

    nonisolated static func read(_ root: String, _ records: [String]) -> Snapshot {
        func json(_ path: String) -> Any? { FileManager.default.contents(atPath: path).flatMap { try? JSONSerialization.jsonObject(with: $0) } }
        var out = Snapshot()
        let terrainState = json(root + "/private/state/terrains.json") as? [String: JSON] ?? [:]
        out.terrains = terrainState.map { id, t in
            Terrain(id: id, dataset: t["dataset"] as? String ?? "", areaKm2: t["area_km2"] as? Double ?? 0,
                    groundPerM2: t["ground_points_per_m2"] as? Double ?? 0, res: t["res"] as? Double ?? 0.5,
                    box: (t["box"] as? [Double]) ?? [], epsg: t["epsg"] as? Int ?? 0,
                    source: t["source"] as? String ?? "", collected: t["collected"] as? String ?? "",
                    file: t["file"] as? String ?? "", points: t["points"] as? String,
                    area: t["area"] as? String, lonlat: (t["lonlat"] as? [Double]) ?? [])
        }.sorted { $0.id < $1.id }
        let tileState = json(root + "/private/state/tiles.json") as? [String: JSON] ?? [:]
        out.tiles = tileState.compactMap { id, t in
            guard let w = t["window"] as? [Int], w.count == 4 else { return nil }
            return Tile(id: id, terrain: t["terrain"] as? String ?? "", row: w[0], col: w[1], rows: w[2], cols: w[3],
                        status: t["status"] as? String ?? "", verdict: t["verdict"] as? String,
                        note: t["note"] as? String, model: t["model"] as? String)
        }.sorted { $0.id < $1.id }
        out.candidates = readCandidates(root, records)
        out.sources = readProjectSources(root)
        (out.tally, out.allSources, out.groups) = count(out.candidates, out.sources)
        out.blindTest = FileManager.default.fileExists(atPath: root + "/private/state/test.json")
        out.place = Dictionary(out.candidates.enumerated().map { ($1.id, $0) }, uniquingKeysWith: { a, _ in a })
        return out
    }

    /// Read the open project. A small one is read at once; a large one (a sweep leaves thousands of finds, and reading
    /// 8,065 took 1.4 s) is read in the background while the window keeps answering, and shown when it is ready.
    private func load(_ root: String, _ records: [String]) {
        followName(root)
        reading?.cancel()
        guard records.count > 400 else { apply(root, Self.read(root, records)); return }
        if knownRoot != root { terrains = []; tiles = []; candidates = []; projectSources = []; tally = Tally(); allSources = []; groups = Groups() }
        reading = Task.detached(priority: .userInitiated) { [weak self] in
            let snapshot = Self.read(root, records)
            guard !Task.isCancelled else { return }
            await MainActor.run { [weak self] in
                guard let self, self.current?.path == root else { return }
                self.apply(root, snapshot)
            }
        }
    }

    private func apply(_ root: String, _ snapshot: Snapshot) {
        let started = Date()
        defer { if Perf.on { Perf.log("showed \(snapshot.candidates.count) finds in \(Int(Date().timeIntervalSince(started) * 1000)) ms") } }
        tally = snapshot.tally
        allSources = snapshot.allSources
        groups = snapshot.groups
        isBlindTest = snapshot.blindTest
        place = snapshot.place
        terrains = snapshot.terrains
        tiles = snapshot.tiles
        candidates = snapshot.candidates
        // Finds that were not there at the last reading of the same project arrive on the map with a pulse.
        let ids = Set(candidates.map(\.id))
        if knownRoot == root {
            let added = ids.subtracting(known)
            if !added.isEmpty {
                fresh.formUnion(added)
                Task { @MainActor [weak self] in
                    try? await Task.sleep(for: .seconds(8))
                    self?.fresh.subtract(added)
                }
            }
        } else {
            fresh = []
        }
        knownRoot = root
        known = ids
        projectSources = snapshot.sources
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
        let parse: (String) -> Candidate? = { file in
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
            c.progress = (meta["progress"] as? [JSON] ?? []).map {
                ($0["date"] as? String ?? "", $0["step"] as? String ?? "", $0["by"] as? String ?? "", $0["note"] as? String ?? "")
            }
            if let place = places[id] {
                c.x = place["x"] as? Double ?? 0.5
                c.y = place["y"] as? Double ?? 0.5
            }
            return c
        }
        // Read side by side, each record into its own slot so the order stays: one after another, a sweep's 8,065
        // records took 1.4 s.
        var slots = [Candidate?](repeating: nil, count: records.count)
        let chunk = max(64, records.count / (ProcessInfo.processInfo.activeProcessorCount * 4))
        slots.withUnsafeMutableBufferPointer { buf in
            let out = Slots(buf: buf)
            DispatchQueue.concurrentPerform(iterations: (records.count + chunk - 1) / chunk) { k in
                for i in k * chunk ..< min(records.count, (k + 1) * chunk) { out.buf[i] = parse(records[i]) }
            }
        }
        var found = slots.compactMap { $0 }
        let kept = Self.layer(found)
        found.withUnsafeMutableBufferPointer { buf in
            let out = Slots(buf: buf)
            DispatchQueue.concurrentPerform(iterations: (buf.count + chunk - 1) / chunk) { k in
                for i in k * chunk ..< min(out.buf.count, (k + 1) * chunk) {
                    if kept.contains(out.buf[i].id) { out.buf[i].inLayer = true }
                    out.buf[i].settle()
                }
            }
        }
        return found
    }

    /// A buffer that several threads write at once, each at its own places.
    private struct Slots<T>: @unchecked Sendable { let buf: UnsafeMutableBufferPointer<T> }

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

import SwiftUI

/// Blind tests on known sites: the sites a newcomer can try, starting one, and the scorecard it ends with.
enum TestSites {
    struct Site: Identifiable {
        let id: String, title: String, place: String, about: String, image: String
        /// What kind of feature the site tests, in a few words.
        var tests = ""
        var underwater = false
    }

    static let all: [Site] = [
        Site(id: "mound-city", title: "Mound City Group", place: "Ohio, United States",
             about: "About two dozen Hopewell mounds inside an earthen wall.", image: "mound-city", tests: "round mounds and an enclosing wall"),
        Site(id: "angel-mounds", title: "Angel Mounds", place: "Indiana, United States",
             about: "Mississippian platform mounds beside the Ohio River.", image: "angel-mounds", tests: "large platform mounds"),
        Site(id: "serpent-mound", title: "Serpent Mound", place: "Ohio, United States",
             about: "An effigy mound about 411 m long, and burial mounds near it.", image: "serpent-mound", tests: "a long, low effigy"),
        Site(id: "cahokia", title: "Cahokia", place: "Illinois, United States",
             about: "Monks Mound, the largest earthwork north of Mexico.", image: "cahokia", tests: "big mounds among roads and fields"),
        Site(id: "maiden-castle", title: "Maiden Castle", place: "Dorset, England",
             about: "An Iron Age hillfort with rings of ramparts and two entrances.", image: "maiden-castle", tests: "ramparts and ditches"),
        Site(id: "borre", title: "Borre", place: "Vestfold, Norway",
             about: "A Viking Age cemetery of more than fifty burial mounds.", image: "borre", tests: "many small, low mounds, the hardest"),
        Site(id: "oberhaching", title: "Oberhaching", place: "Bavaria, Germany",
             about: "Late Iron Age square enclosures in woodland and at a field edge.", image: "oberhaching", tests: "square enclosures under trees"),
        Site(id: "lauske", title: "Lauske ring forts", place: "Saxony, Germany",
             about: "Three ring forts in Upper Lusatia, one on a wooded spur.", image: "lauske", tests: "ring forts on wooded ground"),
        Site(id: "puketapu", title: "Puketapu Pā", place: "Auckland, New Zealand",
             about: "A pā on a ridge, with ditches, terraces and storage pits.", image: "puketapu", tests: "terraces, ditches and pits"),
        Site(id: "thunder-bay-east", title: "Thunder Bay wrecks", place: "Lake Huron, United States",
             about: "Wrecks on the lake bed in a marine sanctuary, from NOAA's sonar surveys.", image: "thunder-bay", tests: "wrecks on the lake bed", underwater: true),
    ]
}

extension AppState {
    /// Start a blind test: the tools make a project whose name says nothing about the place, then the whole search runs.
    func startTest(_ site: TestSites.Site) {
        guard placeBusy == nil, let flow = ToolGuide.workflows.first(where: { $0.id == "full" }) else { return }
        placeBusy = site.title
        placeProblem = nil
        testPicking = false
        Task { @MainActor in
            defer { placeBusy = nil }
            do {
                let reply = try await engine.callTool("start_test", ["folder": Paths.projectsHome.path, "site": site.id])
                guard let info = (try? JSONSerialization.jsonObject(with: Data(reply.utf8))) as? JSON, let path = info["project"] as? String else {
                    placeProblem = "The test could not start: \(reply.prefix(200))"
                    return
                }
                store.register(path: path)
                if let project = store.projects.first(where: { $0.path == path }) { open(project) }
                try? await Task.sleep(for: .milliseconds(400))   // let the project's chat list open first
                run(flow)
            } catch {
                placeProblem = error.localizedDescription
            }
        }
    }
}

extension AppState {
    /// For benchmark runs: open Dighouse.app --args -startBlindTests borre,mound-city runs the listed answer keys one after
    /// another, each until it is scored or its run stops, and logs each score line to the session notes.
    func runBlindTests(_ ids: [String]) async {
        for id in ids {
            let site = TestSites.all.first { $0.id == id } ?? TestSites.Site(id: id, title: id, place: "", about: "", image: "")
            let before = Set(store.projects.map(\.path))
            startTest(site)
            // Wait for the test's project, then for its score or for its run to stop, at most 90 minutes.
            var project: String?
            for _ in 0..<120 where project == nil {
                try? await Task.sleep(for: .seconds(1))
                project = store.projects.map(\.path).first { !before.contains($0) }
            }
            guard let project else { continue }
            var quiet = 0
            for _ in 0..<(90 * 6) {
                try? await Task.sleep(for: .seconds(10))
                if FileManager.default.fileExists(atPath: project + "/private/state/score.json") { break }
                quiet = chat.live.isEmpty && chat.goals.isEmpty ? quiet + 1 : 0
                if quiet >= 18 { break }   // three minutes with nothing running: the run stopped without a score
            }
            try? await Task.sleep(for: .seconds(20))   // let the report and record finish
        }
    }
}

/// The list of known sites, one press each.
struct TestPicker: View {
    @EnvironmentObject var app: AppState
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Glyph(name: "dig.grid", size: 16 * Theme.scale).foregroundStyle(Theme.tan)
                Text("Test it on a known site").font(.system(size: 17 * Theme.scale, weight: .semibold))
                Spacer()
                Button("Cancel") { dismiss() }.buttonStyle(SecondaryButton()).keyboardShortcut(.cancelAction)
            }
            Text("The agent is not told which site it is. It looks at the ground, marks what it finds, then is scored against what is published. A test takes about five minutes.")
                .font(.system(size: 13 * Theme.scale)).foregroundStyle(Theme.dim).fixedSize(horizontal: false, vertical: true)
            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    ForEach([(false, "On land"), (true, "Under water")], id: \.1) { group in
                        Text(group.1).font(.system(size: 12.5 * Theme.scale, weight: .semibold)).foregroundStyle(Theme.dim)
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 330), spacing: 10, alignment: .top)], spacing: 10) {
                            ForEach(TestSites.all.filter { $0.underwater == group.0 }) { site in card(site) }
                        }
                        .padding(.bottom, 6)
                    }
                }
            }
            .frame(maxHeight: max(320, app.windowSize.height - 260))
        }
        .padding(24)
        .frame(width: min(860, max(520, app.windowSize.width - 40)))
        .background(Theme.bg).foregroundStyle(Theme.text)
        .closesOnOutsideClick { dismiss() }
        .onAppear { scores = Self.lastScores(app.store.projects.map(\.path)) }
    }

    @State private var scores: [String: String] = [:]

    /// The last score on each site, from the blind tests on this Mac: "19 of 19 found".
    static func lastScores(_ paths: [String]) -> [String: String] {
        var out: [String: (Date, String)] = [:]
        for path in paths {
            guard let t = FileManager.default.contents(atPath: path + "/private/state/test.json"),
                  let test = (try? JSONSerialization.jsonObject(with: t)) as? JSON, let key = test["key"] as? String,
                  let s = FileManager.default.contents(atPath: path + "/private/state/score.json"),
                  let score = (try? JSONSerialization.jsonObject(with: s)) as? JSON,
                  let found = score["found"] as? Int, let known = score["known"] as? Int else { continue }
            let when = FileInfo.modified(path + "/private/state/score.json") ?? .distantPast
            if (out[key]?.0 ?? .distantPast) < when { out[key] = (when, "Last run here: \(found) of \(known) found") }
        }
        return out.mapValues(\.1)
    }

    private func card(_ site: TestSites.Site) -> some View {
        Button { app.startTest(site) } label: {
            HStack(alignment: .top, spacing: 0) {
                Theme.ink.opacity(0.04).frame(width: 112, height: 96)
                    .overlay {
                        if let image = StartingPoints.image(named: site.image) {
                            Image(nsImage: image).resizable().aspectRatio(contentMode: .fill)
                        }
                    }
                    .clipped()
                VStack(alignment: .leading, spacing: 2) {
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text(site.title).font(.system(size: 13.5 * Theme.scale, weight: .semibold)).lineLimit(1)
                        Text(site.place).font(.system(size: 11.5 * Theme.scale)).foregroundStyle(Theme.faint).lineLimit(1)
                    }
                    Text(site.about).font(.system(size: 12 * Theme.scale)).foregroundStyle(Theme.dim).lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                    if !site.tests.isEmpty {
                        Text("Tests: " + site.tests).font(.system(size: 11.5 * Theme.scale, weight: .medium)).foregroundStyle(Theme.tan)
                            .lineLimit(1).padding(.top, 2)
                    }
                    if let score = scores[site.id] {
                        Text(score).font(.system(size: 11.5 * Theme.scale)).foregroundStyle(Theme.faint)
                    }
                }
                .padding(10).frame(maxWidth: .infinity, alignment: .leading)
            }
            .background(RoundedRectangle(cornerRadius: 12).fill(Theme.ink.opacity(0.035)))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Theme.line))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help("Start a blind test on \(site.title)")
    }
}

/// What a blind test scored: found, missed and extra, a map with both, and a close look at each miss and extra.
struct Scorecard: View {
    let root: String
    @EnvironmentObject var app: AppState

    private var score: JSON? {
        guard let data = FileManager.default.contents(atPath: root + "/private/state/score.json") else { return nil }
        return (try? JSONSerialization.jsonObject(with: data)) as? JSON
    }

    var body: some View {
        if let s = score {
            let key = s["key"] as? JSON ?? [:]
            let found = s["found"] as? Int ?? 0, known = s["known"] as? Int ?? 0
            let missed = s["missed"] as? [JSON] ?? []
            let extra = s["extra"] as? [String] ?? []
            let names = s["finds"] as? [String: String] ?? [:]
            let pictures = s["pictures"] as? JSON ?? [:]
            let close = pictures["close"] as? [String: String] ?? [:]
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .firstTextBaseline, spacing: 10) {
                    Text("It was \(key["name"] as? String ?? "a known site")").font(.system(size: 18 * Theme.scale, weight: .semibold))
                    Text(key["place"] as? String ?? "").font(.system(size: 13 * Theme.scale)).foregroundStyle(Theme.faint)
                }
                HStack(spacing: 12) {
                    tally("\(found) of \(known)", "found", Theme.green)
                    tally("\(missed.count)", "missed", missed.isEmpty ? Theme.faint : Theme.amber)
                    tally("\(extra.count)", "not in the key", Theme.tan)
                    if let area = s["area_km2"] as? Double, area > 0 {
                        let toReview = s["finds_to_review"] as? Int ?? names.count
                        tally(String(format: "%.0f", Double(toReview) / area), "to look over per sq km", Theme.dim)
                    }
                    Spacer()
                    if let minutes = s["minutes"] as? Int {
                        Text("\(minutes) min · \(s["model"] as? String ?? "")").font(.system(size: 12 * Theme.scale)).foregroundStyle(Theme.faint)
                    }
                }
                if let w = s["with_rises"] as? JSON, let wf = w["found"] as? Int, let wr = w["rises"] as? Int, wf > found {
                    Text("With the \(wr) measured rises the tools list for you to look over, \(wf) of \(known) are in front of you.")
                        .font(.system(size: 12.5 * Theme.scale)).foregroundStyle(Theme.dim)
                }
                if let map = pictures["map"] as? String, let image = Images.load(root + "/" + map) {
                    VStack(alignment: .leading, spacing: 6) {
                        Image(nsImage: image).resizable().aspectRatio(contentMode: .fit).clipShape(RoundedRectangle(cornerRadius: 10))
                        HStack(spacing: 14) {
                            legend("circle", Theme.tan, "published, found")
                            legend("circle", Theme.amber, "published, missed")
                            legend("circle.fill", Theme.green, "the agent's finds")
                        }
                    }
                }
                if !missed.isEmpty {
                    section("Missed", missed.map { m in
                        let stage = (m["stage"] as? String).map { " Lost: \($0)." } ?? ""
                        let relief = (m["relief_m"] as? Double).map { " About \(String(format: "%.1f", $0)) m of relief." } ?? ""
                        return (m["feature"] as? String ?? "", "\(m["what"] as? String ?? ""), \(m["source"] as? String ?? "").\(stage)\(relief)")
                    }, close)
                }
                if !extra.isEmpty {
                    section("Not in the key", extra.map { ($0, names[$0] ?? "") }, close)
                }
                Text((s["note"] as? String ?? "") + " The key: " + (key["published"] as? String ?? ""))
                    .font(.system(size: 12 * Theme.scale)).foregroundStyle(Theme.faint).fixedSize(horizontal: false, vertical: true)
                HStack(spacing: 10) {
                    if let site = TestSites.all.first(where: { $0.id == key["id"] as? String }) {
                        Button { app.reportShown = nil; app.startTest(site) } label: { Label("Run it again", systemImage: "arrow.clockwise") }
                            .buttonStyle(SecondaryButton())
                    }
                    Button { app.reportShown = nil; app.startProject() } label: { Label("Try a new area", systemImage: "mappin.and.ellipse") }
                        .buttonStyle(SecondaryButton())
                }
            }
        }
    }

    private func tally(_ number: String, _ label: String, _ colour: Color) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(number).font(.system(size: 22 * Theme.scale, weight: .semibold)).foregroundStyle(colour)
            Text(label).font(.system(size: 11.5 * Theme.scale)).foregroundStyle(Theme.dim)
        }
        .padding(.horizontal, 12).padding(.vertical, 8)
        .background(RoundedRectangle(cornerRadius: 10).fill(Theme.ink.opacity(0.04)))
    }

    private func legend(_ symbol: String, _ colour: Color, _ label: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: symbol).font(.system(size: 9 * Theme.scale)).foregroundStyle(colour)
            Text(label).font(.system(size: 11.5 * Theme.scale)).foregroundStyle(Theme.dim)
        }
    }

    private func section(_ title: String, _ rows: [(String, String)], _ close: [String: String]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.system(size: 13.5 * Theme.scale, weight: .semibold))
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 10)], alignment: .leading, spacing: 10) {
                ForEach(rows, id: \.0) { id, words in
                    VStack(alignment: .leading, spacing: 4) {
                        if let path = close[id], let image = Images.load(root + "/" + path) {
                            Image(nsImage: image).resizable().aspectRatio(1, contentMode: .fit).clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                        Text(id).font(.system(size: 12 * Theme.scale, weight: .medium))
                        Text(words).font(.system(size: 11.5 * Theme.scale)).foregroundStyle(Theme.dim).lineLimit(3)
                    }
                }
            }
        }
    }
}



/// What a quick look found: the ground in two views, and one button to search the place properly.
struct QuickLookCard: View {
    let item: ChatItem
    let path: String
    @EnvironmentObject var app: AppState

    private var info: JSON {
        (item.result?.data(using: .utf8)).flatMap { (try? JSONSerialization.jsonObject(with: $0)) as? JSON } ?? [:]
    }

    var body: some View {
        let box = (info["box"] as? [Double]) ?? []
        let asked = item.details.first { $0.hasPrefix("place: ") }.map { String($0.dropFirst(7)) } ?? ""
        let name = asked.isEmpty ? String((info["place"] as? String ?? "Quick look").split(separator: ",").first ?? "Quick look") : asked
        VStack(alignment: .leading, spacing: 8) {
            if let image = Images.load(path) {
                Image(nsImage: image).resizable().aspectRatio(contentMode: .fit).frame(maxHeight: 280)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            }
            HStack(spacing: 10) {
                Text(caption).font(.system(size: 12 * Theme.scale)).foregroundStyle(Theme.faint).lineLimit(2)
                Spacer(minLength: 8)
                if box.count == 4 {
                    Button { app.searchHere(name: name, box: box) } label: { Label("Search this properly", glyph: "dig.trowel") }
                        .buttonStyle(SecondaryButton())
                        .help("Make a project here and run the whole search: every tile, the checks, what is published, and a report.")
                }
            }
        }
    }

    private var caption: String {
        let data = info["data"] as? JSON ?? [:]
        let source = data["source"] as? String ?? "open lidar"
        let count = info["on_record_count"] as? Int ?? 0
        return "\(source) · \(count == 0 ? "nothing on open record within 1 km" : "\(count) on open record within 1 km") · \(info["seconds"] as? Int ?? 0) s"
    }
}

extension AppState {
    /// What is this? A quick look at a place in a general chat, with the cheap model's plain description.
    func whatIs(_ place: String) {
        let name = place.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }
        if store.current != nil { store.close() }
        chat.draft = ""
        Task { @MainActor in
            await chat.open(project: nil)
            ask("What is this? Call quick_look with place \"\(name)\". Then, in a few short plain sentences: what the shapes in the two pictures probably are (built, natural or modern, and why), what is on open record nearby and from which sources, and what a full search could add. Never call anything new. Do not start a project.", title: "What is \(name)?")
        }
    }

    /// Search a quick look's square properly: a project there, and the whole search.
    func searchHere(name: String, box: [Double]) {
        guard let flow = ToolGuide.workflows.first(where: { $0.id == "full" }) else { return }
        Task { @MainActor in
            do {
                try await createProject(name: name, question: "What built features show in the ground at \(name), and which of them are already published?",
                                        box: box, fetch: false)
                try? await Task.sleep(for: .milliseconds(400))
                run(flow)
            } catch {
                placeProblem = error.localizedDescription
            }
        }
    }
}

import AppKit
import SwiftUI
import UserNotifications

// What a downloaded app needs on its first day (OPEN_LOOP O1 to O5): keeping the Mac awake while it works, saying when
// work is done, saying when a newer version is out, showing what it keeps on disk, and a way to report a problem.

/// Keeps the Mac from sleeping while a search, a timed session or second opinions run. The screen may still sleep.
@MainActor
enum Awake {
    private static var activity: NSObjectProtocol?

    static func set(_ working: Bool) {
        if working, activity == nil {
            activity = ProcessInfo.processInfo.beginActivity(options: [.userInitiated, .idleSystemSleepDisabled],
                                                             reason: "Dighouse is working")
            Notify.ask()
        } else if !working, let held = activity {
            ProcessInfo.processInfo.endActivity(held)
            activity = nil
        }
    }

    static var holding: Bool { activity != nil }
}

/// One notification when work a person waits for is done, and only when Dighouse is not in front.
@MainActor
enum Notify {
    /// Asked once, the first time Dighouse starts work, so the question comes with a reason.
    static func ask() {
        guard !UserDefaults.standard.bool(forKey: "notifyAsked") else { return }
        UserDefaults.standard.set(true, forKey: "notifyAsked")
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    static func say(_ title: String, _ body: String) {
        guard !NSApp.isActive else { return }
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        UNUserNotificationCenter.current().add(UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil))
    }
}

/// Whether a newer release is out, asked of GitHub at most once a day. Nothing is downloaded.
@MainActor @Observable
final class Updates {
    static let shared = Updates()
    static let repository = "chrissotraidis/dighouse"
    /// The newer version and its release page, when there is one.
    var newer: (version: String, page: URL)?

    static var current: String { Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0" }
    static var on: Bool { UserDefaults.standard.object(forKey: "checkUpdates") as? Bool ?? true }

    /// "v0.3.0" or "0.3" as numbers, so 0.10 comes after 0.9.
    nonisolated static func numbers(_ version: String) -> [Int] {
        version.trimmingCharacters(in: CharacterSet(charactersIn: "vV ")).split(separator: ".").map { Int($0.prefix { $0.isNumber }) ?? 0 }
    }

    nonisolated static func isNewer(_ latest: String, than current: String) -> Bool {
        let a = numbers(latest), b = numbers(current)
        for i in 0..<max(a.count, b.count) {
            let x = i < a.count ? a[i] : 0, y = i < b.count ? b[i] : 0
            if x != y { return x > y }
        }
        return false
    }

    func check() async {
        let defaults = UserDefaults.standard
        // -fakeLatest 9.9.9 shows the line without a release, for checking it.
        if let fake = defaults.string(forKey: "fakeLatest"), let page = URL(string: "https://github.com/\(Self.repository)/releases") {
            newer = Self.isNewer(fake, than: Self.current) ? (fake, page) : nil
            return
        }
        guard Self.on else { newer = nil; return }
        // A kept answer for a day: one request a day, from one address, is all GitHub sees.
        if let kept = defaults.string(forKey: "latestVersion"), let page = defaults.url(forKey: "latestPage"),
           Date().timeIntervalSince1970 - defaults.double(forKey: "latestChecked") < 86_400 {
            newer = Self.isNewer(kept, than: Self.current) ? (kept, page) : nil
            return
        }
        guard let url = URL(string: "https://api.github.com/repos/\(Self.repository)/releases/latest") else { return }
        var request = URLRequest(url: url, timeoutInterval: 10)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        // Offline, private or with no release yet: nothing is shown and nothing is kept, so it asks again next launch.
        guard let (data, reply) = try? await URLSession.shared.data(for: request), (reply as? HTTPURLResponse)?.statusCode == 200,
              let info = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any],
              let tag = info["tag_name"] as? String, let page = (info["html_url"] as? String).flatMap(URL.init(string:)) else { return }
        defaults.set(tag, forKey: "latestVersion")
        defaults.set(page, forKey: "latestPage")
        defaults.set(Date().timeIntervalSince1970, forKey: "latestChecked")
        newer = Self.isNewer(tag, than: Self.current) ? (tag, page) : nil
    }
}

/// The quiet line that says a newer version is out, on Home and in Settings.
struct UpdateLine: View {
    private var updates = Updates.shared

    var body: some View {
        if let newer = updates.newer {
            HStack(spacing: 8) {
                Image(systemName: "arrow.down.circle").foregroundStyle(Theme.tan)
                Text("Dighouse \(newer.version.trimmingCharacters(in: CharacterSet(charactersIn: "vV"))) is out. You have \(Updates.current).")
                    .foregroundStyle(Theme.dim)
                Button("What is new") { NSWorkspace.shared.open(newer.page) }
                    .buttonStyle(.plain).foregroundStyle(Theme.tan).fontWeight(.semibold)
            }
            .font(.system(size: 12.5 * Theme.scale))
        }
    }
}

/// What Dighouse keeps on disk: the projects' folders, and the cache of downloads. A file linked from both (a project's
/// points are a link to the cache's copy) counts once, in the project.
struct DiskUse: Sendable {
    var projects: Int64 = 0, cache: Int64 = 0
    /// Downloaded points in the cache that no project holds: fetched again if a search needs them.
    var loose: Int64 = 0, looseFiles: [String] = []

    nonisolated static var cacheFolder: String {
        ProcessInfo.processInfo.environment["DIGHOUSE_CACHE"] ?? Paths.home + "/.cache/dighouse"
    }

    nonisolated static func measure(_ projects: [String]) -> DiskUse {
        var out = DiskUse(), seen = Set<String>()
        func walk(_ root: String, _ add: (Int64) -> Void) {
            guard let items = FileManager.default.enumerator(atPath: root) else { return }
            for case let item as String in items {
                var s = stat()
                guard lstat(root + "/" + item, &s) == 0, (s.st_mode & S_IFMT) == S_IFREG,
                      seen.insert("\(s.st_dev):\(s.st_ino)").inserted else { continue }
                add(Int64(s.st_blocks) * 512)
            }
        }
        for root in projects { walk(root) { out.projects += $0 } }
        walk(cacheFolder) { out.cache += $0 }
        let points = cacheFolder + "/points"
        for name in (try? FileManager.default.contentsOfDirectory(atPath: points)) ?? [] where name.hasSuffix(".npz") {
            var s = stat()
            guard stat(points + "/" + name, &s) == 0, s.st_nlink == 1 else { continue }
            out.loose += Int64(s.st_blocks) * 512
            out.looseFiles.append(points + "/" + name)
        }
        return out
    }

    /// Remove the cache's points no project holds, with the note each has beside it. Nothing a project holds is touched:
    /// a project's points are a second link to the same file, so their count of links is above one.
    nonisolated static func free(_ files: [String]) -> Int64 {
        var freed: Int64 = 0
        for file in files {
            var s = stat()
            guard stat(file, &s) == 0, s.st_nlink == 1, file.hasPrefix(cacheFolder + "/points/") else { continue }
            if (try? FileManager.default.removeItem(atPath: file)) != nil {
                freed += Int64(s.st_blocks) * 512
                try? FileManager.default.removeItem(atPath: String(file.dropLast(4)) + ".json")
            }
        }
        return freed
    }

    nonisolated static func words(_ bytes: Int64) -> String {
        ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
    }
}

/// Settings' line on disk use, with a way to free the downloads no project holds.
struct DiskUseRow: View {
    @EnvironmentObject var store: ProjectStore
    @State private var use: DiskUse?
    @State private var asking = false
    @State private var note = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            SettingRow(title: "Space on this Mac", note: summary) {
                if let use, use.loose > 0, !asking {
                    Button("Free \(DiskUse.words(use.loose))") { asking = true }.buttonStyle(SecondaryButton())
                }
            }
            if asking, let use {
                HStack(spacing: 8) {
                    Text("Remove \(use.looseFiles.count) download\(use.looseFiles.count == 1 ? "" : "s") no project holds? A search that needs \(use.looseFiles.count == 1 ? "it" : "one") fetches it again.")
                        .font(.system(size: 12.5 * Theme.scale)).foregroundStyle(Theme.dim).fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 8)
                    Button("Cancel") { asking = false }.buttonStyle(SecondaryButton())
                    Button("Remove") { remove(use.looseFiles) }.buttonStyle(PrimaryButton())
                }
                .padding(.horizontal, 14).padding(.bottom, 12)
            }
        }
        .task { await measure() }
    }

    private var summary: String {
        guard let use else { return "Measuring…" }
        var words = "Projects \(DiskUse.words(use.projects)), downloads kept for later \(DiskUse.words(use.cache))."
        if use.loose > 0 { words += " \(DiskUse.words(use.loose)) of those are held by no project." }
        return note.isEmpty ? words : note + " " + words
    }

    private func measure() async {
        let roots = store.projects.map(\.path)
        use = await Task.detached { DiskUse.measure(roots) }.value
    }

    private func remove(_ files: [String]) {
        asking = false
        Task {
            let freed = await Task.detached { DiskUse.free(files) }.value
            note = "Freed \(DiskUse.words(freed))."
            await measure()
        }
    }
}

/// A new GitHub issue, filled in with what helps and nothing private. The person reads it and sends it.
enum ProblemReport {
    /// Coordinates and the home folder are taken out of anything put in a report.
    nonisolated static func clean(_ text: String) -> String {
        text.replacingOccurrences(of: #"-?\d{1,3}\.\d{4,}"#, with: "[removed]", options: .regularExpression)
            .replacingOccurrences(of: Paths.home, with: "~")
    }

    @MainActor
    static func open(app: AppState) {
        let os = ProcessInfo.processInfo.operatingSystemVersion
        var details = [
            "Dighouse \(Updates.current) (\(Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "?"))",
            "macOS \(os.majorVersion).\(os.minorVersion).\(os.patchVersion)",
            "Engine: Codex \(app.setup.codexVersion.isEmpty ? "not found" : app.setup.codexVersion)",
            "Search model: \(app.modelName)",
            "Second opinions: \(app.secondOpinionModels.first ?? "none")",
        ]
        if let problem = app.engine.problem { details.append("The engine says: \(problem)") }
        // The last stalls, when the app was started with -measure YES.
        if let log = try? String(contentsOf: Perf.file, encoding: .utf8) {
            details.append("Last lines of perf.log:\n" + log.split(separator: "\n").suffix(12).joined(separator: "\n"))
        }
        let body = "**What happened**\n\nSay what you did, what you expected, and what you saw.\n\n**Details** (written by Dighouse, with locations taken out)\n\n"
            + "~~~\n" + clean(details.joined(separator: "\n")) + "\n~~~\n"
        var parts = URLComponents(string: "https://github.com/\(Updates.repository)/issues/new")
        parts?.queryItems = [URLQueryItem(name: "title", value: ""), URLQueryItem(name: "body", value: body)]
        if let url = parts?.url { NSWorkspace.shared.open(url) }
    }
}

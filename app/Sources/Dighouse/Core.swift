import AppKit
import SwiftUI
import UniformTypeIdentifiers

typealias JSON = [String: Any]

/// A colour scheme for the whole app.
struct Palette {
    let bg, side, raised, pop, ink, text, dim, faint, accent, accentDeep, tan, green, amber, primary: Color

    private static func rgb(_ hex: UInt32) -> Color {
        Color(red: Double((hex >> 16) & 0xFF) / 255, green: Double((hex >> 8) & 0xFF) / 255, blue: Double(hex & 0xFF) / 255)
    }

    /// The colours of the app icon: dark soil, the tan ground line, the green canopy.
    static let earth = Palette(
        bg: rgb(0x261E17), side: rgb(0x1A1410), raised: rgb(0x362B21), pop: rgb(0x382D23), ink: rgb(0xFFE6C4),
        text: rgb(0xF3EBDF), dim: rgb(0xC4B4A0), faint: rgb(0x92826F), accent: rgb(0x7DD666), accentDeep: rgb(0x3F8433),
        tan: rgb(0xE2B170), green: rgb(0x7DD666), amber: rgb(0xF2A640), primary: rgb(0xF4E6CF))
    static let canopy = Palette(
        bg: rgb(0x141B15), side: rgb(0x0D130E), raised: rgb(0x202B22), pop: rgb(0x232E25), ink: rgb(0xE0FFE0),
        text: rgb(0xEAF2E8), dim: rgb(0xAEBFAD), faint: rgb(0x7B8C7A), accent: rgb(0xE2B170), accentDeep: rgb(0x8A6235),
        tan: rgb(0xE2B170), green: rgb(0x7DD666), amber: rgb(0xF2A640), primary: rgb(0xE9F3E4))
    static let graphite = Palette(
        // Its own colour for menus. It used to borrow the theme's, which the theme was still working out when the app
        // started in this look, so the app stopped before its window opened.
        bg: Color(white: 0.129), side: Color(white: 0.09), raised: Color(white: 0.185), pop: Color(white: 0.2), ink: .white,
        text: Color(white: 0.925), dim: Color(white: 0.7), faint: Color(white: 0.52), accent: rgb(0x5CA6FF), accentDeep: rgb(0x2B6EDB),
        tan: rgb(0xDBB075), green: rgb(0x5CC76B), amber: rgb(0xF5AD42), primary: .white)
}

/// The looks a person can pick in Settings.
enum Look: String, CaseIterable {
    case earth = "Earth", canopy = "Canopy", graphite = "Graphite"

    var palette: Palette {
        switch self {
        case .earth: return .earth
        case .canopy: return .canopy
        case .graphite: return .graphite
        }
    }

    var note: String {
        switch self {
        case .earth: return "Soil brown"
        case .canopy: return "Forest green"
        case .graphite: return "Neutral grey"
        }
    }
}

/// The text sizes, smallest first. ⌘+ and ⌘− step through them, and Settings › Personalize lists them.
enum TextSize {
    static let all: [(id: String, name: String, scale: CGFloat)] = [
        ("small", "Small", 0.92), ("standard", "Standard", 1), ("large", "Large", 1.1), ("larger", "Larger", 1.2), ("largest", "Largest", 1.3),
    ]

    static func scale(_ id: String) -> CGFloat { all.first { $0.id == id }?.scale ?? 1 }
}

/// Movement is short and quiet, and there is none when the Mac is set to reduce motion.
enum Motion {
    static var reduce: Bool { NSWorkspace.shared.accessibilityDisplayShouldReduceMotion }

    static func ease(_ seconds: Double = 0.2) -> Animation? { reduce ? nil : .easeOut(duration: seconds) }

    /// A small overshoot, for a tick that lands or a number that changes.
    static var settle: Animation? { reduce ? nil : .spring(response: 0.35, dampingFraction: 0.62) }
}

enum Theme {
    /// How large text is drawn, from ⌘+ and ⌘− or Settings › Personalize. Every font size is multiplied by it.
    static var scale: CGFloat { TextSize.scale(UserDefaults.standard.string(forKey: "textSize") ?? "standard") }

    static var palette = (Look(rawValue: UserDefaults.standard.string(forKey: "look") ?? "") ?? .earth).palette

    static var bg: Color { palette.bg }
    static var side: Color { palette.side }
    static var raised: Color { palette.raised }
    /// The surface of menus that float over a page.
    static var pop: Color { palette.pop }
    /// The light colour that is laid over the background, faintly, for fills and outlines.
    static var ink: Color { palette.ink }
    static var hover: Color { palette.ink.opacity(0.07) }
    static var line: Color { palette.ink.opacity(0.1) }
    static var text: Color { palette.text }
    static var dim: Color { palette.dim }
    static var faint: Color { palette.faint }
    static var accent: Color { palette.accent }
    static var accentDeep: Color { palette.accentDeep }
    static var tan: Color { palette.tan }
    static var green: Color { palette.green }
    static var amber: Color { palette.amber }
    /// The fill of the one main button on a screen.
    static var primary: Color { palette.primary }
}

enum Shell {
    /// Run a program and collect what it prints.
    static func run(_ exe: String, _ args: [String], env: [String: String]? = nil, in folder: String? = nil) async -> (code: Int32, out: String) {
        await withCheckedContinuation { done in
            DispatchQueue.global().async {
                let p = Process()
                p.executableURL = URL(fileURLWithPath: exe)
                p.arguments = args
                if let env { p.environment = env }
                if let folder { p.currentDirectoryURL = URL(fileURLWithPath: folder) }
                let pipe = Pipe()
                p.standardOutput = pipe
                p.standardError = pipe
                do { try p.run() } catch {
                    done.resume(returning: (-1, error.localizedDescription))
                    return
                }
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                p.waitUntilExit()
                done.resume(returning: (p.terminationStatus, String(decoding: data, as: UTF8.self)))
            }
        }
    }
}

/// Free keys and tokens that some open data services ask for. They sit in one file only this person can read, where
/// the tools look for them (src/dighouse/national.py, access_key).
enum Keys {
    static var file: URL { Paths.support.appendingPathComponent("keys.json") }

    static func read(_ name: String) -> String {
        guard let data = try? Data(contentsOf: file), let all = try? JSONSerialization.jsonObject(with: data) as? [String: String] else { return "" }
        return all[name] ?? ""
    }

    static func write(_ name: String, _ value: String) {
        var all = ((try? Data(contentsOf: file)).flatMap { try? JSONSerialization.jsonObject(with: $0) as? [String: String] }) ?? [:]
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        all[name] = trimmed.isEmpty ? nil : trimmed
        guard let data = try? JSONSerialization.data(withJSONObject: all, options: [.prettyPrinted, .sortedKeys]) else { return }
        FileManager.default.createFile(atPath: file.path, contents: data, attributes: [.posixPermissions: 0o600])
        try? FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: file.path)
    }
}

enum Paths {
    static var support: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let dir = base.appendingPathComponent("Dighouse")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    /// Where chats that belong to no project run.
    static var general: URL {
        let dir = support.appendingPathComponent("General")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    /// Folders that macOS keeps in iCloud when Desktop and Documents sync is on. Files there go offline, and every read
    /// of one waits for a download, so Dighouse offers to move projects out of them.
    static var cloudFolders: [String] {
        let home = NSHomeDirectory()
        var out: [String] = []
        if FileManager.default.fileExists(atPath: home + "/Library/Mobile Documents/com~apple~CloudDocs/Documents") {
            out += [home + "/Documents", home + "/Desktop", home + "/Library/Mobile Documents"]
        }
        if let test = UserDefaults.standard.string(forKey: "cloudFolderForTest") { out.append(test) }
        return out
    }

    static func inCloud(_ path: String) -> Bool { cloudFolders.contains { path == $0 || path.hasPrefix($0 + "/") } }

    /// Where projects go when they leave iCloud: the chosen projects folder if it is on this Mac, else ~/Dighouse.
    static var localProjectsHome: URL {
        let chosen = UserDefaults.standard.string(forKey: "projectsHome")
        if let chosen, !inCloud(chosen) { return URL(fileURLWithPath: chosen) }
        return FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Dighouse")
    }

    /// Where new projects go: ~/Dighouse, or the folder the person chose in Settings if it is not kept in iCloud.
    /// Projects made earlier stay where they are; Home offers to move any that sit in iCloud.
    static var projectsHome: URL {
        if let custom = UserDefaults.standard.string(forKey: "projectsHome"), !inCloud(custom) { return URL(fileURLWithPath: custom) }
        return FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Dighouse")
    }
}

// MARK: - What the app shows

struct ModelInfo: Identifiable, Hashable {
    let id: String
    let name: String
    let readsImages: Bool
    let hearsAudio: Bool
    let isDefault: Bool
    let efforts: [String]
    let defaultEffort: String?
    /// What the model list says each thinking step is for, by step.
    var effortNotes: [String: String] = [:]
}

struct ProjectRef: Identifiable, Codable, Hashable {
    var path: String
    var name: String
    var id: String { path }
}

struct Terrain: Identifiable {
    let id: String
    let dataset: String
    let areaKm2: Double
    let groundPerM2: Double
    var res = 0.5
    /// The corner and far corner of the terrain in its own metres, and the coordinate system they are in.
    var box: [Double] = []
    var epsg = 0
    var source = ""
    var collected = ""
    var file = ""
    var points: String?

    /// The survey's name, without the "usgs:" or "own:" in front.
    var name: String { dataset.split(separator: ":", maxSplits: 1).last.map(String.init) ?? dataset }
    var isOwn: Bool { dataset.hasPrefix("own:") }
}

struct Tile: Identifiable {
    let id: String
    let terrain: String
    let row: Int, col: Int, rows: Int, cols: Int
    let status: String
    let verdict: String?
    let note: String?
    let model: String?

    var short: String { id.split(separator: "-").last.map(String.init) ?? id }
}

struct Source: Identifiable {
    let id = UUID()
    let title: String, status: String, finding: String
    var link = ""

    /// "could_not_open" reads "Could not open".
    var statusLabel: String {
        let words = status.replacingOccurrences(of: "_", with: " ")
        return words.prefix(1).uppercased() + words.dropFirst()
    }
}

struct Candidate: Identifiable {
    let id: String
    let name: String
    let status: String
    let flagged: String
    let flaggedBy: String
    let tile: String
    let evidence: [String]
    let checks: JSON
    let sources: [Source]
    let decisions: [String]
    let folder: String
    /// The agent's suggested decision and its reason, if it left one.
    var suggestion: (status: String, reason: String, by: String)?
    var x = 0.5, y = 0.5

    var relief: String { "\(folder)/img/\(id)-relief.png" }
    var section: String { "\(folder)/img/\(id)-section.png" }
    var file: String { "\(folder)/\(id).md" }

    static let labels: [String: String] = [
        "flagged": "Not yet checked",
        "ground_confirmed": "In the ground",
        "modern": "Modern feature",
        "natural": "Natural feature",
        "already_published": "Already published",
        "no_match_in_sources_read": "No match in the sources read",
        "reported": "Reported to the heritage authority",
    ]
    /// A flag with its section and its modern-features check on record is waiting for the person, not for more checks.
    var statusLabel: String {
        if status == "flagged", checks["section"] != nil, checks["modern"] != nil { return "Needs your decision" }
        return Self.labels[status] ?? status
    }

    var statusColor: Color {
        switch status {
        case "flagged": return Theme.amber
        case "ground_confirmed", "no_match_in_sources_read", "reported": return Theme.accent
        case "already_published": return Theme.tan
        default: return Theme.faint
        }
    }

    var flaggedOn: String {
        let parse = DateFormatter()
        parse.dateFormat = "yyyy-MM-dd"
        guard let date = parse.date(from: flagged) else { return flagged }
        return date.formatted(date: .abbreviated, time: .omitted)
    }
}

struct RunStatus {
    var tiles = 0, unscreened = 0, screened = 0, unreadable = 0
    var candidates = 0
    var controls = 0, controlsFound = 0
    var needsPerson: [String] = []

    var readable: Int { tiles - unreadable }
    var progress: Double { readable > 0 ? Double(screened) / Double(readable) : 0 }
}

struct PlanStep: Hashable {
    let text: String
    let status: String
}

struct ChatItem: Identifiable {
    enum Kind { case user, agent, step, plan, note }
    enum State { case running, done, failed }
    let id: String
    var kind: Kind
    var text: String
    var icon = "circle"
    var state = State.done
    var tool: String?
    var details: [String] = []
    var result: String?
    var images: [String] = []
    var showsImage = false
    var plan: [PlanStep] = []
    var projectPath: String?
    var files: [String] = []
    /// The engine's turn this belongs to, so a chat can be copied up to here.
    var turn: String?
}

/// Something attached to a message: an image, a sound, a video, or any other file.
struct Attachment: Identifiable, Hashable {
    enum Kind { case image, audio, video, file }
    let path: String
    var id: String { path }
    var name: String { URL(fileURLWithPath: path).lastPathComponent }

    var kind: Kind {
        guard let type = UTType(filenameExtension: URL(fileURLWithPath: path).pathExtension) else { return .file }
        if type.conforms(to: .image) { return .image }
        if type.conforms(to: .movie) || type.conforms(to: .video) { return .video }
        if type.conforms(to: .audio) { return .audio }
        return .file
    }

    var icon: String {
        switch kind {
        case .image: return "photo"
        case .audio: return "waveform"
        case .video: return "film"
        case .file: return "doc"
        }
    }
}

/// An open lidar survey from a public catalog.
struct Survey: Identifiable, Hashable {
    let id: String
    let title: String
    let collected: String
    let why: String
    let url: String
    let box: [Double]
    /// A small area inside the survey that is known to hold ground data.
    let start: [Double]
}

/// A tool server the person added to Dighouse.
struct ToolServer: Identifiable, Codable, Hashable {
    var name: String
    var command: String
    var id: String { name }
    var key: String { name.lowercased().map { $0.isLetter || $0.isNumber ? String($0) : "_" }.joined() }
}

/// A place to begin: a known site to learn on, or an area where searching is still useful.
struct StartingPoint: Identifiable, Hashable {
    enum Kind { case learn, search, own, chat }
    let id: String
    let kind: Kind
    let title: String
    let place: String
    let about: String
    let source: String
    let name: String
    let question: String
    let box: [String]
    var dataset: String? = nil
    /// A place name to look up when the New project page opens, for a project started from typed text.
    var search: String? = nil
    /// The general chat this project is made from. It moves into the project once the project exists.
    var chat: String? = nil
    /// Why this area, as the chat settled it.
    var whyHere: String? = nil

    var centre: (lat: Double, lon: Double)? {
        let n = box.compactMap(Double.init)
        return n.count == 4 ? ((n[1] + n[3]) / 2, (n[0] + n[2]) / 2) : nil
    }
}

/// A project the agent offered from a general chat (suggest_project): what the New project page is filled in with.
struct ProjectOffer {
    var name: String
    var question: String
    var whyHere = ""
    var place = ""
    var box: [Double]? = nil

    init(name: String, question: String) {
        self.name = name
        self.question = question
    }

    /// From the tool's reply.
    init?(reply: String?) {
        guard let data = reply?.data(using: .utf8), let info = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any],
              info["offered"] as? Bool == true, let name = info["name"] as? String, let question = info["question"] as? String else { return nil }
        self.name = name
        self.question = question
        whyHere = info["why_here"] as? String ?? ""
        place = info["place"] as? String ?? ""
        box = (info["box"] as? [Any])?.compactMap { ($0 as? NSNumber)?.doubleValue }
        if box?.count != 4 { box = nil }
    }
}

enum Images {
    private static let cache = NSCache<NSString, NSImage>()

    static func load(_ path: String) -> NSImage? {
        let stamp = FileInfo.modified(path)?.timeIntervalSince1970 ?? 0
        let key = "\(path)#\(stamp)" as NSString
        if let hit = cache.object(forKey: key) { return hit }
        guard stamp > 0, let img = NSImage(contentsOfFile: path) else { return nil }
        cache.setObject(img, forKey: key)
        return img
    }
}

extension String {
    /// Inline Markdown (bold, code, links) rendered as text; falls back to the plain string.
    var inlineMarkdown: AttributedString {
        (try? AttributedString(markdown: self, options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)))
            ?? AttributedString(self)
    }
}


extension String {
    /// A path with the home folder shortened to ~, for showing to a person.
    var tildePath: String { (self as NSString).abbreviatingWithTildeInPath }
}


/// A file's modification date and size from stat(2). FileManager.attributesOfItem also reads extended attributes,
/// which can hang for a long time on a folder kept in iCloud; stat does not.
enum FileInfo {
    static func modified(_ path: String) -> Date? {
        var s = stat()
        guard stat(path, &s) == 0 else { return nil }
        return Date(timeIntervalSince1970: TimeInterval(s.st_mtimespec.tv_sec) + TimeInterval(s.st_mtimespec.tv_nsec) / 1e9)
    }

    static func size(_ path: String) -> Int? {
        var s = stat()
        return stat(path, &s) == 0 ? Int(s.st_size) : nil
    }
}

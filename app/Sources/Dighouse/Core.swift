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
        bg: Color(white: 0.129), side: Color(white: 0.09), raised: Color(white: 0.185), pop: Theme.pop, ink: .white,
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
        case .earth: return "Soil brown with the green and tan of the Dighouse icon."
        case .canopy: return "Forest green, with the same accents."
        case .graphite: return "Neutral grey and blue, like the Codex app."
        }
    }
}

enum Theme {
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
    static func run(_ exe: String, _ args: [String], env: [String: String]? = nil) async -> (code: Int32, out: String) {
        await withCheckedContinuation { done in
            DispatchQueue.global().async {
                let p = Process()
                p.executableURL = URL(fileURLWithPath: exe)
                p.arguments = args
                if let env { p.environment = env }
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

    static var projectsHome: URL {
        if let custom = UserDefaults.standard.string(forKey: "projectsHome") { return URL(fileURLWithPath: custom) }
        return FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent("Dighouse")
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
    var x = 0.5, y = 0.5

    var relief: String { "\(folder)/img/\(id)-relief.png" }
    var section: String { "\(folder)/img/\(id)-section.png" }
    var file: String { "\(folder)/\(id).md" }

    static let labels: [String: String] = [
        "flagged": "Not yet checked",
        "ground_confirmed": "Ground feature confirmed",
        "modern": "Modern feature",
        "natural": "Natural feature",
        "already_published": "Already published",
        "no_match_in_sources_read": "No match in the sources read",
        "reported": "Reported to the heritage authority",
    ]
    var statusLabel: String { Self.labels[status] ?? status }

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
    enum Kind { case user, agent, step, plan }
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
    enum Kind { case learn, search, own }
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

    var centre: (lat: Double, lon: Double)? {
        let n = box.compactMap(Double.init)
        return n.count == 4 ? ((n[1] + n[3]) / 2, (n[0] + n[2]) / 2) : nil
    }
}

enum Images {
    private static let cache = NSCache<NSString, NSImage>()

    static func load(_ path: String) -> NSImage? {
        let stamp = (try? FileManager.default.attributesOfItem(atPath: path)[.modificationDate] as? Date)?.timeIntervalSince1970 ?? 0
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

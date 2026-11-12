import AppKit
import Foundation

/// The toolkit in plain words. One source for the Toolbox page, the workflow menu, the welcome guide and the chat's step lines.
enum ToolGuide {
    struct Tool: Identifiable {
        let name: String, title: String, does: String
        var id: String { name }
    }

    /// One stage of a search: what happens, why it matters, and the tools that do it.
    struct Pack: Identifiable {
        let title: String, icon: String, summary: String, why: String
        /// A picture from the tour folder, or "reveal" for the forest and bare-ground pair.
        let image: String?
        /// The workflow that runs this stage.
        let flow: String
        let tools: [Tool]
        var id: String { title }
    }

    struct Handoff: Hashable {
        let who: String, does: String
    }

    struct Workflow: Identifiable {
        enum Scope { case general, project }
        let id: String, title: String, icon: String, summary: String, prompt: String
        let scope: Scope
        let steps: [Handoff]
    }

    struct DataSource: Identifiable {
        let name: String, what: String, gives: String, usedFor: String, url: String, probe: String
        var id: String { name }
    }

    /// A tool the person's Codex setup already has, in plain words.
    struct Addon {
        let title: String, icon: String, use: String
    }

    static var toolCount: Int { packs.map(\.tools.count).reduce(0, +) }

    static let packs: [Pack] = [
        Pack(title: "Choose where to look", icon: "binoculars",
             summary: "Before anything is downloaded, the agent works out where a search is worth doing: which places have open lidar, and what is already recorded there.",
             why: "A search adds most where the lidar is open and few sites are on record.",
             image: nil, flow: "choose",
             tools: [Tool(name: "find_place", title: "Find a place", does: "Turns a place name into an area on the map."),
                     Tool(name: "open_surveys", title: "List open surveys", does: "Lists open lidar surveys flown with archaeology in mind."),
                     Tool(name: "survey_area", title: "Size up an area", does: "Shows which open lidar covers an area and which sites are already recorded there."),
                     Tool(name: "find_data", title: "Find lidar for an area", does: "Lists every open lidar dataset that overlaps a search area.")]),
        Pack(title: "Strip the forest away", icon: "mountain.2",
             summary: "The agent downloads the raw laser points for the area and keeps only the ones that reached the ground. What is left is the bare ground, as if the trees were gone.",
             why: "Low walls, mounds and platforms are hidden in a photograph and plain in the bare ground.",
             image: "reveal", flow: "terrain",
             tools: [Tool(name: "fetch_terrain", title: "Fetch terrain", does: "Downloads the points for an area, builds the ground model, and reports how dense the ground returns are."),
                     Tool(name: "view_terrain", title: "View the terrain", does: "Shows the whole terrain at reduced size."),
                     Tool(name: "make_tiles", title: "Cut into tiles", does: "Cuts the terrain into overlapping tiles for screening.")]),
        Pack(title: "Look at every tile", icon: "square.grid.3x3",
             summary: "The terrain is cut into tiles about 250 m across. The agent looks at each one in more than one rendering and writes down what it sees: nothing, natural, modern, possible, or built.",
             why: "Nothing is skipped, and a tile the laser never reached is marked unreadable, never empty.",
             image: "tile", flow: "screen",
             tools: [Tool(name: "next_tiles", title: "Pick tiles", does: "Picks the tiles nobody has looked at yet."),
                     Tool(name: "view_tile", title: "Look at a tile", does: "Shows one tile as shaded relief, slope, or local relief."),
                     Tool(name: "record_verdict", title: "Record a verdict", does: "Records what a tile shows: nothing, natural, modern, possible or built."),
                     Tool(name: "flag_candidate", title: "Flag a candidate", does: "Opens a record for something that looks built.")]),
        Pack(title: "Check every flag", icon: "checkmark.seal",
             summary: "Each flag gets three tests. A slice through the raw points shows whether the shape is in the ground or in the trees. A second, different model looks at the same tile without seeing the first opinion. Open maps are checked for roads, buildings and sites already mapped.",
             why: "This is where false finds are caught, and it is the step a lone chatbot skips.",
             image: "section", flow: "check",
             tools: [Tool(name: "cut_section", title: "Cut a section", does: "Cuts a vertical slice through the raw points and measures the feature."),
                     Tool(name: "second_look", title: "Second look", does: "Records the opinion of a second, different model."),
                     Tool(name: "check_modern", title: "Check for modern features", does: "Checks open maps for roads, buildings and sites already mapped nearby."),
                     Tool(name: "add_control", title: "Add a known site", does: "Registers a published site the run should find again, as a test of the run itself.")]),
        Pack(title: "Search what is published", icon: "book",
             summary: "The agent searches an open index of scholarly work, opens what it finds, and logs each source as read, could not open, or not relevant.",
             why: "Most of what a search turns up is already known. The record says exactly what was read, so a short search is never mistaken for a discovery.",
             image: nil, flow: "prior",
             tools: [Tool(name: "search_literature", title: "Search the literature", does: "Searches an open index of scholarly works and returns abstracts."),
                     Tool(name: "read_source", title: "Open a source", does: "Opens a web page or a PDF and returns its text."),
                     Tool(name: "log_source", title: "Log a source", does: "Logs a source as read, could not open, or not relevant, with what it shows.")]),
        Pack(title: "Keep the record, and you decide", icon: "doc.text",
             summary: "Every candidate is a page with its pictures, measurements, checks and sources. The tools refuse a status the evidence does not support, and the last call is yours.",
             why: "A project is a plain folder of Markdown, so it can be shared, reviewed, or handed to an archaeologist.",
             image: "record-relief", flow: "decide",
             tools: [Tool(name: "init_project", title: "Create a project", does: "Creates a project folder."),
                     Tool(name: "add_evidence", title: "Add evidence", does: "Adds a line of evidence to a record."),
                     Tool(name: "set_status", title: "Set a status", does: "Moves a candidate to a status, if its checks support it."),
                     Tool(name: "list_candidates", title: "List candidates", does: "Lists candidates and what each still lacks."),
                     Tool(name: "run_status", title: "Report the run", does: "Reports coverage, candidates, controls, and what is waiting for you.")]),
    ]

    static let addons: [String: Addon] = [
        "notion": Addon(title: "Notion", icon: "note.text", use: "Keep a project notebook, or copy records into a shared workspace."),
        "github": Addon(title: "GitHub", icon: "arrow.triangle.branch", use: "Keep a project folder under version control and share it."),
        "gmail": Addon(title: "Gmail", icon: "envelope", use: "Draft a message to a heritage authority for you to review and send."),
        "google-calendar": Addon(title: "Google Calendar", icon: "calendar", use: "Schedule follow-ups."),
        "pdf": Addon(title: "PDF", icon: "doc.richtext", use: "Read and make PDFs, such as papers and reports."),
        "documents": Addon(title: "Documents", icon: "doc.text", use: "Write a report as a Word document."),
        "spreadsheets": Addon(title: "Spreadsheets", icon: "tablecells", use: "Export candidates and measurements as a table."),
        "presentations": Addon(title: "Presentations", icon: "rectangle.on.rectangle", use: "Turn a project into slides."),
        "browser": Addon(title: "Browser", icon: "globe", use: "Open web pages that need a real browser."),
        "hugging-face": Addon(title: "Hugging Face", icon: "cube", use: "Look up open models and datasets."),
        "visualize": Addon(title: "Visualize", icon: "chart.xyaxis.line", use: "Draw charts and diagrams from a project's numbers."),
    ]

    static let workflows: [Workflow] = [
        Workflow(id: "choose", title: "Help me choose a place", icon: "binoculars",
                 summary: "The agent asks what interests you, then suggests areas with open lidar and says what is already known at each.",
                 prompt: "Help me choose a place to search. Ask me what region, period or kind of site I care about, then suggest two or three areas that have open lidar, and say what is already recorded at each. When I pick one, create the project.",
                 scope: .general,
                 steps: [Handoff(who: "You", does: "Say what interests you"), Handoff(who: "Agent", does: "Compares open surveys and recorded sites"),
                         Handoff(who: "You", does: "Pick an area"), Handoff(who: "Agent", does: "Creates the project")]),
        Workflow(id: "surveys", title: "Show open surveys", icon: "list.bullet.rectangle",
                 summary: "Lists the open lidar surveys flown with archaeology in mind.",
                 prompt: "List the open lidar surveys flown with archaeology in mind. For each, say where it is, whether it can be fetched without an account, and what a search there could add.",
                 scope: .general, steps: [Handoff(who: "Agent", does: "Reads the open catalog")]),
        Workflow(id: "place", title: "Size up a place", icon: "mappin.and.ellipse",
                 summary: "Tell the agent a place name and it reports the open lidar and the recorded sites there.",
                 prompt: "I have a place in mind. Ask me its name, then tell me which open lidar covers it and which sites are already recorded there.",
                 scope: .general, steps: [Handoff(who: "You", does: "Name the place"), Handoff(who: "Agent", does: "Checks lidar coverage and recorded sites")]),
        Workflow(id: "full", title: "Run the whole search", icon: "play.circle",
                 summary: "Everything from fetching the terrain to the literature search, stopping for you at the second look and at each decision.",
                 prompt: "Run the whole search for this project. Fetch the terrain if it is missing and cut it into tiles. Screen every tile in two styles, handing batches to sub-agents when more than 12 are left. Flag what looks built, then cut a section and check for modern features for each flag, and search and log the literature. Keep a plan as you go. Stop for me at the second look and at any decision.",
                 scope: .project,
                 steps: [Handoff(who: "Agent", does: "Fetches lidar, builds the bare ground"), Handoff(who: "Agent and helpers", does: "Screen every tile"),
                         Handoff(who: "Agent", does: "Sections and modern-feature checks"), Handoff(who: "Second model", does: "Independent second look"),
                         Handoff(who: "Agent", does: "Literature search, every source logged"), Handoff(who: "You", does: "Decide each candidate")]),
        Workflow(id: "terrain", title: "Get the terrain", icon: "mountain.2",
                 summary: "Finds open lidar for the project's area, builds the bare ground and cuts it into tiles.",
                 prompt: "Find open lidar for this project's area, fetch it, and cut it into tiles. Tell me how good the ground data is.",
                 scope: .project, steps: [Handoff(who: "Agent", does: "Finds, fetches and tiles the terrain")]),
        Workflow(id: "screen", title: "Screen the tiles", icon: "square.grid.3x3",
                 summary: "Looks at every tile nobody has screened and flags what looks built.",
                 prompt: "Screen the tiles nobody has looked at yet, each in two styles. Hand batches to sub-agents when more than 12 are left. Flag what looks built.",
                 scope: .project, steps: [Handoff(who: "Agent and helpers", does: "View each tile, record a verdict"), Handoff(who: "Agent", does: "Opens a record for each flag")]),
        Workflow(id: "check", title: "Check the flags", icon: "checkmark.seal",
                 summary: "Cuts a section through each unchecked candidate and looks for modern features nearby.",
                 prompt: "For every candidate that still lacks them, cut a section through it, starting and ending on the surrounding ground, and check for modern features nearby.",
                 scope: .project, steps: [Handoff(who: "Agent", does: "Section and modern-feature check per candidate")]),
        Workflow(id: "second", title: "Second look", icon: "person.2",
                 summary: "Hands each unchecked candidate to your second-look model, which sees the tile but not the first opinion.",
                 prompt: "", scope: .project,
                 steps: [Handoff(who: "Dighouse", does: "Sends the tile to the second model"), Handoff(who: "Second model", does: "Agrees or disagrees, with a reason")]),
        Workflow(id: "prior", title: "Prior-art sweep", icon: "book",
                 summary: "Searches the literature for each open candidate and logs every source as read or not opened.",
                 prompt: "Search the literature for each candidate that has no sources yet, starting with studies of this dataset. Open what you find with read_source, and log each source on its record as soon as you have read it or failed to open it.",
                 scope: .project, steps: [Handoff(who: "Agent", does: "Searches, reads and logs sources")]),
        Workflow(id: "decide", title: "What needs my decision?", icon: "person.crop.circle.badge.questionmark",
                 summary: "A summary of each candidate, what is still missing, and what is ready for you.",
                 prompt: "Tell me what is waiting for my decision, and what is still missing on each candidate.",
                 scope: .project, steps: [Handoff(who: "Agent", does: "Summarizes the records"), Handoff(who: "You", does: "Decide")]),
        Workflow(id: "report", title: "Draft a report", icon: "envelope",
                 summary: "Drafts a report for the heritage authority for candidates you marked as having no match. You send it.",
                 prompt: "For each candidate I marked as having no match in the sources read, draft a short report for the relevant heritage authority in reports/, with the evidence, the checks and the sources searched. Leave the location out of the draft and tell me where the private annex should go. Do not send anything.",
                 scope: .project, steps: [Handoff(who: "Agent", does: "Drafts the report"), Handoff(who: "You", does: "Review and send")]),
    ]

    static let sources: [DataSource] = [
        DataSource(name: "OpenTopography",
                   what: "A US research archive of lidar surveys, including ones flown for archaeologists.",
                   gives: "The list of surveys and their raw laser points, from the files it publishes without an account.",
                   usedFor: "Choosing a place · Bare ground",
                   url: "https://opentopography.org", probe: "https://portal.opentopography.org/API/otCatalog?productFormat=PointCloud&minx=-90.1&miny=38.6&maxx=-90&maxy=38.7&detail=false&outputFormat=json&include_federated=false"),
        DataSource(name: "USGS 3DEP",
                   what: "The US Geological Survey's lidar of most of the United States, in the public domain.",
                   gives: "Raw laser points for any area it covers.",
                   usedFor: "Bare ground · Sections",
                   url: "https://www.usgs.gov/3d-elevation-program", probe: "https://s3-us-west-2.amazonaws.com/usgs-lidar-public/IL_10CoNRCS_3_D23/ept.json"),
        DataSource(name: "Wikidata",
                   what: "The open database behind Wikipedia.",
                   gives: "Archaeological sites that are already on record near an area. It is far from complete.",
                   usedFor: "Choosing a place",
                   url: "https://www.wikidata.org", probe: "https://www.wikidata.org/w/api.php?action=query&meta=siteinfo&format=json"),
        DataSource(name: "OpenStreetMap",
                   what: "The open map of the world.",
                   gives: "Place names, and the roads, buildings and mapped historic sites near a find.",
                   usedFor: "Choosing a place · Checks",
                   url: "https://www.openstreetmap.org", probe: "https://nominatim.openstreetmap.org/status?format=json"),
        DataSource(name: "OpenAlex",
                   what: "An open index of scholarly books and papers.",
                   gives: "Titles, abstracts and links to open copies for the literature search.",
                   usedFor: "Prior art",
                   url: "https://openalex.org", probe: "https://api.openalex.org/works?per-page=1"),
    ]

    static let rules = [
        "Nothing is ever called new. A record says how many sources were read and that none matched.",
        "Locations stay on this Mac. Records and notes carry no coordinates.",
        "A tile with too little ground data is unreadable and cannot be given a verdict.",
        "The second look must come from a different model than the one that flagged.",
        "You decide before a candidate is marked as having no match, and you send any report.",
    ]

    /// A step line for the chat: an icon and a sentence for one tool call.
    static func describe(_ tool: String, _ a: JSON) -> (String, String) {
        func s(_ key: String) -> String { a[key] as? String ?? "" }
        let tile = s("tile").split(separator: "-").last.map(String.init) ?? ""
        let style = s("style").isEmpty ? "" : ", " + s("style").replacingOccurrences(of: "_", with: " ")
        switch tool {
        case "find_place": return ("mappin.and.ellipse", "Looked up \(s("query"))")
        case "open_surveys": return ("list.bullet.rectangle", "Read the open survey catalog")
        case "survey_area": return ("binoculars", "Sized up an area: lidar coverage and recorded sites")
        case "init_project": return ("folder.badge.plus", "Created the project \(s("name"))")
        case "find_data": return ("magnifyingglass", "Looked for open lidar over the area")
        case "fetch_terrain": return ("arrow.down.circle", "Fetched terrain from \(s("dataset").split(separator: ":").last.map(String.init) ?? "")")
        case "view_terrain": return ("mountain.2", "Looked at the whole terrain")
        case "make_tiles": return ("square.grid.3x3", "Cut the terrain into tiles")
        case "next_tiles": return ("square.grid.3x3", "Picked the next tiles")
        case "view_tile": return ("eye", "Looked at tile \(tile)\(style)")
        case "record_verdict": return ("checkmark", "Tile \(tile): \(s("verdict"))")
        case "flag_candidate": return ("flag", "Flagged: \(s("name"))")
        case "cut_section": return ("waveform.path.ecg", "Cut a section" + (s("candidate").isEmpty ? " on tile \(tile)" : " through \(s("candidate"))"))
        case "second_look": return ("person.2", "Second look at \(s("candidate")) by \(s("model"))")
        case "check_modern": return ("building.2", "Checked for modern features near \(s("candidate"))")
        case "search_literature": return ("book", "Searched the literature: \(s("query"))")
        case "read_source": return ("doc.text.magnifyingglass", "Opened a source: \(URL(string: s("url"))?.host ?? s("url"))")
        case "log_source": return ("text.book.closed", "Logged a source (\(s("status").replacingOccurrences(of: "_", with: " "))): \(s("title"))")
        case "add_evidence": return ("plus", "Added evidence to \(s("candidate"))")
        case "set_status": return ("checkmark.seal", "Marked \(s("candidate")) as \(Candidate.labels[s("status")]?.lowercased() ?? s("status"))")
        case "list_candidates": return ("list.bullet", "Reviewed the candidates")
        case "add_control": return ("scope", "Registered a control: \(s("name"))")
        case "run_status": return ("gauge", "Checked the run status")
        default: return ("wrench", tool)
        }
    }
}

import Foundation

/// The tools in plain words: used by the welcome guide, the Tools tab, the composer's menu and the chat's step lines.
enum ToolGuide {
    struct Tool: Identifiable {
        let name: String, does: String
        var id: String { name }
    }

    struct Stage: Identifiable {
        let title: String, icon: String, summary: String, prompt: String, tools: [Tool]
        var id: String { title }
    }

    static let stages: [Stage] = [
        Stage(title: "Find data", icon: "magnifyingglass",
              summary: "The agent looks up which open lidar surveys cover your area, and how their publishers ask to be cited.",
              prompt: "Find open lidar for this project's area and tell me what is available before fetching anything.",
              tools: [Tool(name: "find_data", does: "Lists open lidar datasets that overlap the search area.")]),
        Stage(title: "Bare ground", icon: "mountain.2",
              summary: "It downloads the laser returns, keeps the ones that reached the ground, and builds the terrain with the forest removed.",
              prompt: "Fetch the terrain for this project's area and cut it into tiles.",
              tools: [Tool(name: "fetch_terrain", does: "Downloads the points for a box and builds the ground model. Reports how dense the ground returns are."),
                      Tool(name: "view_terrain", does: "Shows the whole terrain at reduced size.")]),
        Stage(title: "Screen", icon: "square.grid.3x3",
              summary: "The terrain is cut into tiles and the agent looks at every one. Tiles where the laser never reached the ground are marked unreadable, never empty.",
              prompt: "Continue screening the tiles nobody has looked at yet.",
              tools: [Tool(name: "make_tiles", does: "Cuts a terrain into overlapping tiles."),
                      Tool(name: "next_tiles", does: "Picks the tiles nobody has looked at yet."),
                      Tool(name: "view_tile", does: "Shows one tile in a chosen rendering."),
                      Tool(name: "record_verdict", does: "Records what a tile shows: nothing, natural, modern, possible or built.")]),
        Stage(title: "Check", icon: "checkmark.seal",
              summary: "Anything that looks built becomes a candidate and gets three checks: a slice through the raw points, a second opinion from a different model, and a look for modern features.",
              prompt: "For every candidate that is not yet checked, cut a section through it and check for modern features nearby. Leave the second look to me.",
              tools: [Tool(name: "flag_candidate", does: "Opens a record for something that looks built."),
                      Tool(name: "cut_section", does: "Cuts a vertical slice through the points, to see whether the feature is in the ground or in the trees."),
                      Tool(name: "second_look", does: "Records the opinion of a second, different model."),
                      Tool(name: "check_modern", does: "Checks open maps for roads, buildings and sites already mapped nearby.")]),
        Stage(title: "Prior art", icon: "book",
              summary: "The agent searches the published literature, starting with studies of the same data, and logs every source it read or could not open.",
              prompt: "Search the literature for each open candidate, starting with studies of this dataset. Read what you find and log every source.",
              tools: [Tool(name: "search_literature", does: "Searches an open index of scholarly works."),
                      Tool(name: "log_source", does: "Logs a source as read, could not open, or not relevant, with what it shows.")]),
        Stage(title: "Record", icon: "doc.text",
              summary: "Each candidate is a Markdown file with its evidence and checks. You decide its final status, and a person sends any report.",
              prompt: "Tell me what is waiting for my decision, and what is still missing on each candidate.",
              tools: [Tool(name: "add_evidence", does: "Adds a line of evidence to a record."),
                      Tool(name: "set_status", does: "Moves a candidate to a status, if its checks support it."),
                      Tool(name: "add_control", does: "Registers a published site as a control the run should find again."),
                      Tool(name: "run_status", does: "Reports coverage, candidates, controls, and what is waiting for you.")]),
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
        case "init_project": return ("folder", "Set up the project")
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

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
        let title: String, short: String, icon: String, summary: String, why: String
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
        let name: String, what: String
        /// Where its data reaches, in a few words.
        let reach: String
        let gives: String, usedFor: String, url: String, probe: String
        /// A picture made from this source, what it shows, and a question that puts the source to work.
        var image = "", caption = "", ask = ""
        /// A second part of the service that some tools need, and what stops working when only that part is down.
        /// The part counts as up when any of its addresses answers.
        var alsoProbe: [String] = [], alsoNote = ""
        var id: String { name }
    }

    /// A tool the person's Codex setup already has, in plain words.
    struct Addon {
        let title: String, icon: String, use: String
        /// One request a person could make with it, in their own words.
        let tryIt: String
    }

    static var toolCount: Int { packs.map(\.tools.count).reduce(0, +) }

    static let packs: [Pack] = [
        Pack(title: "Choose where to look", short: "Choose", icon: "binoculars",
             summary: "The agent weighs where lidar is open against what is already on record, so a search goes where it can add something.",
             why: "A search adds most where the lidar is open and few sites are on record.",
             image: nil, flow: "choose",
             tools: [Tool(name: "find_place", title: "Find a place", does: "Turns a place name into an area on the map."),
                     Tool(name: "open_surveys", title: "List open surveys", does: "Lists open lidar surveys flown with archaeology in mind."),
                     Tool(name: "survey_area", title: "Size up an area", does: "Shows which open lidar covers an area and which sites are already recorded there."),
                     Tool(name: "find_data", title: "Find lidar for an area", does: "Lists every open lidar dataset that overlaps a search area."),
                     Tool(name: "find_gaps", title: "Find the gaps", does: "Ranks the parts of a region by open lidar and by how few sites are on open record."),
                     Tool(name: "open_resources", title: "List open archives", does: "Says which open archives exist, how big they are, and which of them these tools read.")]),
        Pack(title: "Take the trees away", short: "Bare ground", icon: "dig.mound",
             summary: "The agent downloads the raw laser points and keeps only those that reached the ground.",
             why: "Low walls, mounds and platforms are hidden in a photograph and plain in the bare ground.",
             image: "reveal", flow: "terrain",
             tools: [Tool(name: "fetch_terrain", title: "Fetch the ground", does: "Downloads the points for an area and builds the ground model, or takes a national ground model ready-made, and reports how good the ground data is."),
                     Tool(name: "import_terrain", title: "Use your own data", does: "Reads a ground model (GeoTIFF) or point cloud (LAS, LAZ) from this Mac into the project."),
                     Tool(name: "view_terrain", title: "View the ground", does: "Shows all of the ground at reduced size."),
                     Tool(name: "render_tiles", title: "Render the tiles", does: "Draws every tile in one view (sky view, hillshade, local relief) so the map can show them that way."),
                     Tool(name: "make_tiles", title: "Cut into tiles", does: "Cuts the ground into overlapping tiles to look at.")]),
        Pack(title: "Look at every tile", short: "Look", icon: "dig.grid",
             summary: "The ground is cut into squares called tiles. A low-cost model looks at every one in bulk, and the agent looks closely at the ones worth it.",
             why: "Nothing is skipped, and a tile the laser never reached is marked unreadable, never empty.",
             image: "tile", flow: "screen",
             tools: [Tool(name: "look_at_tiles", title: "Look at every tile in bulk", does: "Puts every tile to a low-cost vision model, a few at a time, records each verdict, opens a find for each shape it points at, and returns the tiles worth a closer look."),
                     Tool(name: "sweep", title: "Sweep several areas at once", does: "Fetches up to four areas of a ready-made ground model side by side, looks at every tile in bulk, and returns one shortlist across them for the close look."),
                     Tool(name: "next_tiles", title: "Pick tiles", does: "Picks the tiles nobody has looked at yet."),
                     Tool(name: "view_tile", title: "Look at a tile", does: "Shows one tile as shaded relief, slope, local relief, or sky view, which darkens ditches and brightens banks whatever their direction."),
                     Tool(name: "find_mounds", title: "Measure small mounds", does: "Measures round rises in a tile that a picture can hide, and rings each for the agent and you to look at."),
                     Tool(name: "add_measured_rises", title: "Add measured rises", does: "Opens finds for the best measured rises on the tiles looked at, so small mounds a picture hides are looked at."),
                     Tool(name: "check_old_maps", title: "Check old maps", does: "Shows old maps at a find: USGS sheets and mine records in the United States, the État-major map and 1950s photographs in France"),
                     Tool(name: "record_old_maps", title: "File what old maps show", does: "Files what old maps and mine records show at a find, and whether they explain it."),
                     Tool(name: "shape_check", title: "Check a mound's shape", does: "Measures a find's rise, any pit beside it, its width two ways and the ground around it, to rank finds for review."),
                     Tool(name: "record_verdict", title: "Record a verdict", does: "Records what a tile shows: nothing, natural, modern, possible or built."),
                     Tool(name: "flag_candidate", title: "Mark a find", does: "Opens a record for something that looks built.")]),
        Pack(title: "Check every find", short: "Check", icon: "dig.layers",
             summary: "Each find gets three tests: a slice through the laser points, a second model's opinion, and open maps.",
             why: "This is where false finds are caught, and it is the step a lone chatbot skips.",
             image: "section", flow: "check",
             tools: [Tool(name: "cut_section", title: "Cut a slice", does: "Cuts a vertical slice through the raw points and measures the feature."),
                     Tool(name: "second_look", title: "Second opinion", does: "Records the opinion of a second, different model."),
                     Tool(name: "ask_second_opinions", title: "Ask for second opinions", does: "Asks a different model about each open find, a few at a time, and writes each answer on its record."),
                     Tool(name: "opinion_pictures", title: "Draw the second opinion's pictures", does: "Draws a find's tile in two views with the find ringed, for a second model asked through the chat. Only the app calls it."),
                     Tool(name: "second_look_failed", title: "Note a missing opinion", does: "Notes that a second model was asked and could not answer, and why. It does not count as an opinion."),
                     Tool(name: "find_views", title: "Draw close views", does: "Draws a find 60 m across, ringed, in six styles, for the person deciding it."),
                     Tool(name: "check_modern", title: "Check open maps", does: "Looks on open maps for roads, buildings and sites already mapped nearby."),
                     Tool(name: "check_finds", title: "Check all the finds", does: "Slices every open find, measures its shape and checks open maps, in one go."),
                     Tool(name: "add_control", title: "Add a known site", does: "Registers a published site the run should find again, as a test of the run itself."),
                     Tool(name: "feature_guide", title: "Read the feature guide", does: "What mounds, banks, terraces and hollow ways look like, and the look-alikes to rule out."),
                     Tool(name: "quick_look", title: "What is this?", does: "A quick look at one place without a project: the ground in two views, and what open records hold within 1 km."),
                     Tool(name: "calibration_site", title: "Pick a calibration site", does: "Names the known site, with lidar from the same source, to test the method on before searching a new area."),
                     Tool(name: "start_calibration", title: "Start the calibration", does: "Starts the blind test on that site for a search, without telling the agent which site it is."),
                     Tool(name: "record_calibration", title: "Record the calibration", does: "Copies a calibration test's score into the search. Too low, and the search stops."),
                     Tool(name: "list_tests", title: "List test sites", does: "Lists the known sites a blind test can run on, and what each answer key counts."),
                     Tool(name: "start_test", title: "Start a blind test", does: "Makes a project on a known site whose name says nothing about the place, and keeps the literature closed until scoring."),
                     Tool(name: "score_test", title: "Score a blind test", does: "Compares the finds with the published answer key: found, missed and extra. Then opens the literature.")]),
        Pack(title: "Search what is published", short: "Read", icon: "dig.sieve",
             summary: "The agent searches books and papers, opens what it can, and logs every source.",
             why: "Most of what a search turns up is already known. The record says exactly what was read, so a short search is never mistaken for a discovery.",
             image: nil, flow: "prior",
             tools: [Tool(name: "search_literature", title: "Search the literature", does: "Searches an open index of scholarly works and returns abstracts."),
                     Tool(name: "search_records", title: "Search published records", does: "Searches Open Context for published excavation and survey records."),
                     Tool(name: "view_source_page", title: "Inspect a PDF figure", does: "Opens an original PDF page so the agent can inspect its maps, legend and scale."),
                     Tool(name: "read_source", title: "Open a source", does: "Opens a web page or a PDF and returns its text."),
                     Tool(name: "log_source", title: "Log a source", does: "Logs a source as read, could not open, or not relevant, with what it shows.")]),
        Pack(title: "Keep the record, and you decide", short: "Record", icon: "dig.brush",
             summary: "Every find gets a page with its pictures, checks and sources. The agent suggests what it is; you confirm or change it.",
             why: "A project is a plain folder of Markdown, so it can be shared, reviewed, or handed to an archaeologist.",
             image: "record-relief", flow: "decide",
             tools: [Tool(name: "init_project", title: "Create a project", does: "Creates a project folder."),
                     Tool(name: "name_project", title: "Name the project", does: "Names a project after its region, with its question and the region's box."),
                     Tool(name: "start_from_chat", title: "Start from a chat", does: "Writes what a chat settled into the project made from it."),
                     Tool(name: "decide_many", title: "Decide many at once", does: "Records a person's decisions on many finds at once. Only the app calls it."),
                     Tool(name: "undo_decision", title: "Undo a decision", does: "Takes back a person's last decision on a find. Only the app calls it."),
                     Tool(name: "raise_rise", title: "Raise a measured rise", does: "Puts a measured rise kept on the map to the person. Only the app calls it."),
                     Tool(name: "who_to_tell", title: "Who to tell", does: "Names the body that keeps the official record of sites where the project is, whether that record is open, and what to do before sending anything."),
                     Tool(name: "check_before_publishing", title: "Check before publishing", does: "Checks that no location or download would leave the Mac before the person publishes the project."),
                     Tool(name: "suggest_project", title: "Offer a project", does: "Offers to turn a chat into a project. Nothing is made until you press Make this a project."),
                     Tool(name: "add_evidence", title: "Add evidence", does: "Adds a line of evidence to a record."),
                     Tool(name: "suggest_decision", title: "Suggest a decision", does: "Writes the decision the evidence points to, and why, so your review starts prepared."),
                     Tool(name: "set_status", title: "Set a status", does: "Moves a find to a status, if its checks support it."),
                     Tool(name: "list_candidates", title: "List finds", does: "Lists finds and what each still lacks."),
                     Tool(name: "run_status", title: "Report the run", does: "Reports coverage, finds, controls, and what is waiting for you."),
                     Tool(name: "write_summary", title: "Write the run summary", does: "Writes what a run did and what is left as a note in the project."),
                     Tool(name: "write_report", title: "Write the search report", does: "Writes the two-minute report a search ends with, from the project's records: what was looked at, marked, read and ruled out, and what needs you."),
                     Tool(name: "document_project", title: "Update the research record", does: "Rebuilds RESEARCH.md: everything looked at, read and decided, and what is left, so anyone can carry the project on."),
                     Tool(name: "export_finds", title: "Export for mapping software", does: "Saves the finds as a GeoJSON file for QGIS, ArcGIS or Google Earth, kept with the other locations under private.")]),
    ]

    static let addons: [String: Addon] = [
        "notion": Addon(title: "Notion", icon: "note.text", use: "Keep a project notebook, or copy records into a shared workspace.", tryIt: "Copy these records into Notion."),
        "github": Addon(title: "GitHub", icon: "arrow.triangle.branch", use: "Keep a project folder under version control and share it.", tryIt: "Put this project on GitHub, private."),
        "gmail": Addon(title: "Gmail", icon: "envelope", use: "Draft a message to a heritage authority for you to review and send.", tryIt: "Draft a message to the heritage office."),
        "google-calendar": Addon(title: "Google Calendar", icon: "calendar", use: "Schedule follow-ups.", tryIt: "Remind me to recheck this site in spring."),
        "pdf": Addon(title: "PDF", icon: "doc.richtext", use: "Read and make PDFs, such as papers and reports.", tryIt: "Read this paper and log it as a source."),
        "documents": Addon(title: "Documents", icon: "doc.text", use: "Write a report as a Word document.", tryIt: "Write the report as a Word file."),
        "spreadsheets": Addon(title: "Spreadsheets", icon: "tablecells", use: "Export finds and measurements as a table.", tryIt: "Export the finds as a table."),
        "presentations": Addon(title: "Presentations", icon: "rectangle.on.rectangle", use: "Turn a project into slides.", tryIt: "Make slides from this project."),
        "browser": Addon(title: "Browser", icon: "globe", use: "Open web pages that need a real browser.", tryIt: "Open this page in a real browser."),
        "hugging-face": Addon(title: "Hugging Face", icon: "cube", use: "Look up open models and datasets.", tryIt: "Find open models that read lidar."),
        "visualize": Addon(title: "Visualize", icon: "chart.xyaxis.line", use: "Draw charts and diagrams from a project's numbers.", tryIt: "Chart the height of each find."),
    ]

    /// The workflow a message was sent by, so the chat can show its name rather than its full instructions.
    static func workflow(sentAs text: String) -> Workflow? {
        // A whole search, as it is asked for now and as it was asked for before it ended with a report.
        if text.hasPrefix("Run the whole search for this project") { return workflows.first { $0.id == "full" } }
        // "What should I research?", as it is asked for now and as it was asked for before it ended with an offer.
        if text.hasPrefix("I want to contribute but do not know what to research") { return workflows.first { $0.id == "research" } }
        return (workflows + [carryOn]).filter { !$0.prompt.isEmpty && text.hasPrefix($0.prompt) }.max { $0.prompt.count < $1.prompt.count }
    }

    /// The six stages of a whole search, by the tools that belong to each, so a run can say which stage it is on.
    static let stages: [(title: String, icon: String, tools: Set<String>)] = [
        ("Getting the bare ground", "dig.mound", ["find_data", "fetch_terrain", "import_terrain", "view_terrain", "make_tiles"]),
        ("Looking at the tiles", "dig.grid", ["next_tiles", "view_tile", "render_tiles", "record_verdict", "flag_candidate"]),
        ("Checking the finds", "dig.layers", ["cut_section", "check_finds", "check_modern", "add_evidence", "second_look"]),
        ("Searching what is published", "dig.sieve", ["search_literature", "search_records", "read_source", "log_source"]),
        ("Suggesting decisions", "dig.brush", ["suggest_decision", "list_candidates"]),
        ("Writing the report", "doc.richtext", ["write_summary", "write_report", "document_project"]),
    ]

    /// What the agent is asked when a shared project is picked up: say what was done, then do what needs no download.
    /// It is offered on the overview of such a project only, so it is not in the list of workflows.
    static let carryOn = Workflow(
        id: "carry", title: "Carry on", icon: "arrow.right.circle",
        summary: "The agent reads the research record, says what was done, and does what is left that needs no download.",
        prompt: "This project was shared with me. Read RESEARCH.md and the finds' records, then tell me in a few lines what was already done here and what is left. Then do what is left that needs no download and no location: try the sources listed as could not be opened and log each one, and call suggest_decision for any find that has no suggestion. Do not fetch the ground or look at tiles again: the ground listed in the record was already looked at. End with write_summary.",
        scope: .project, steps: [])

    /// Asked when a finished search is widened, from the overview and from the Data tab.
    static let widen = "Widen this project's search by about 250 m on every side. Fetch the ground for the strips around what is already here with the same survey, in boxes under 6 square km, then cut it into tiles. Tell me how many tiles were added. The map shows them beside the old ones."

    static let workflows: [Workflow] = [
        Workflow(id: "research", title: "What should I research?", icon: "sparkle.magnifyingglass",
                 summary: "The agent reads the open archives and proposes three searches worth doing.",
                 prompt: "I want to contribute but do not know what to research. Work it out for me. Use open_resources to see which archives there are, open_surveys for lidar flown for archaeology, and find_gaps on one or two regions that look promising, together with what you know about archaeology. Then propose three concrete searches I could run with these tools, using only lidar known to build: a survey with a checked_start, or USGS 3DEP in the United States. Leave out any survey with a known_problem. Classify each proposal as an open research question, benchmark or defer. Cite the closest published study and state which plausible result would change an archaeological interpretation. Assess data feasibility separately. A benchmark can win for method testing. Sparse public records alone cannot establish a research gap; a quick_look on a place shows its ground in a minute. For each of the three, give the place, the lidar that covers it, what is already on open record and from which sources, what kind of feature to expect, what a search could add, and the known site that will calibrate it (calibration_site, or the calibration find_gaps gives). State when a suitable calibration is unavailable. Otherwise run the reference blind and describe which features it tests. Say plainly what the open record cannot show. Ask me at most one question first. When I pick one, offer it as a project with suggest_project, with the sources you read and the other two places as ruled out, each with why, so I can make it with one press.",
                 scope: .general,
                 steps: [Handoff(who: "Agent", does: "Reads the archives and the survey catalog"), Handoff(who: "Agent", does: "Ranks regions by lidar and recorded sites"),
                         Handoff(who: "You", does: "Pick one"), Handoff(who: "Agent", does: "Creates the project")]),
        Workflow(id: "timed-research", title: "Find something", icon: "clock",
                 summary: "Compare research questions and test the strongest leads until a deadline you choose.",
                 prompt: "Run a timed research session that searches new ground, inside this session's project. First choose one region with open lidar where earthworks survive and little is on record (find_gaps). Prefer a region where survey_area says a search can find and check, because a site register there is open, so each find can be checked against the record: Norway (Kartverket's 1 m ground model) needs no account and Denmark needs a free token; Navarre's and England's registers list protected sites and scheduled monuments only, so a find there is checked against part of the record. find_gaps leaves out ground models that need a token, so Denmark's cells show no lidar until its token is set in Settings. Say which kind of region it is. Name the project after it with name_project, giving a research question and the region's box. Then search areas inside the region, adding each to this project with fetch_terrain and a short area name (such as Perry A1); do not create other search projects, and do not go back over earlier projects unless I ask. Before choosing between regions, look at survey_area's calibration_lately: a lidar whose recent calibrations fell below the pass mark would stop the search, so prefer a region whose lidar passes, and say why. Calibrate once per lidar source: start the blind test with start_calibration and hand it to one helper agent whose only job it is, telling it to run the whole search on that folder as Find and report back does a blind test (look_at_tiles, a close look at every shortlisted tile in two views marking every feature as a find, add_measured_rises, check_finds, then score_test) and to report the score. While it works, choose the areas and search what is published for the region. When it reports, call record_calibration, before the first sweep, and reuse that score for the rest of the session. If the calibration fails, the search on that lidar stops: say so, then choose another region whose lidar passes (survey_area, calibration_lately), calibrate there and search it, rather than spending the session on reading. Where a ready-made ground model covers the region (a national one, or us:3dep-dem-1m in the United States), search three adjacent areas of about 6 square km at a time with one call to sweep, each named (such as Elverum B1): it fetches their ground side by side and looks at every tile in bulk, and returns one shortlist across them, best first (run_status keeps it, under close_look_next). Then look closely at no more than the first 24 tiles of that shortlist, handing them to three helper agents at once in batches of 8 (they record verdicts; you mark every feature you see, which takes over the bulk finds); the rest keep the bulk look's verdict and its finds, and the summary says how many shortlisted tiles were not looked at closely. Then add_measured_rises and check_finds, once each. Only where no ready-made model covers the region, use raw points area by area, 1 to 2 square km each: fetch_terrain, make_tiles, look_at_tiles, the same close look, add_measured_rises, check_finds. Then check_old_maps on hollows and straight-edged finds in the United States and France, search what is published for the region once, at the start, and again only for a find that needs it, and suggest a decision on each find run_status lists under to_suggest. Start another sweep whenever 20 minutes or more are left, and keep each suggestion to a sentence or two, so the time goes on new ground. Spend at most ten minutes on any one check: write down what is open and move on, and never stop the session over one check. Write the summary and report once per sweep (or per area on raw points), when it is done. Keep a running tally (areas, square km, finds, matches, leads). Cite prior work, call nothing new, and save a final assessment before the deadline. Dighouse asks a second model for opinions on the finds once you write each summary.",
                 scope: .general, steps: []),
        Workflow(id: "choose", title: "Pick a place on the map", icon: "map",
                 summary: "The map shows where open lidar reaches. Click a spot and start a project there.",
                 prompt: "Help me choose a place to search. Ask me what region, period or kind of site I care about, then suggest two or three areas that have open lidar, and say what is already recorded at each. When I pick one, create the project.",
                 scope: .general,
                 steps: [Handoff(who: "You", does: "Click where you want to look"), Handoff(who: "Dighouse", does: "Shows the open data there"),
                         Handoff(who: "You", does: "Create the project"), Handoff(who: "Agent", does: "Gets the ground")]),
        Workflow(id: "surveys", title: "Show open surveys", icon: "dig.grid",
                 summary: "Lists the open lidar surveys flown with archaeology in mind.",
                 prompt: "List the open lidar surveys flown with archaeology in mind. For each, say where it is, whether it can be fetched without an account, and what a search there could add.",
                 scope: .general, steps: [Handoff(who: "Agent", does: "Reads the open catalog")]),
        Workflow(id: "place", title: "Size up a place", icon: "mappin.and.ellipse",
                 summary: "Name a place. The agent says which lidar covers it and what is on record.",
                 prompt: "I have a place in mind. Ask me its name, then tell me which open lidar covers it and which sites are already recorded there.",
                 scope: .general, steps: [Handoff(who: "You", does: "Name the place"), Handoff(who: "Agent", does: "Checks lidar coverage and recorded sites")]),
        Workflow(id: "full", title: "Find and report back", icon: "dig.trowel",
                 summary: "The agent does every step, then comes back with a report and the decisions that are yours.",
                 prompt: "Run the whole search for this project from start to finish without stopping to ask me anything, then report back. Skip whatever the project already has. First call run_status: if it shows blind_test, this is a blind test, so do not search the literature or records or try to name the place until you have marked and sliced every find and called score_test (the second opinion is not needed for the score); then search the literature for each find score_test lists as extra. Fetch the ground if it is missing (a fetch can take ten minutes; wait for it to return) and cut it into tiles. Call look_at_tiles once: it looks at every tile nobody has looked at in bulk, opens a find for each shape it sees and returns a shortlist. Look closely at every tile on the shortlist, best first, in two views, handing batches to helper agents when more than 12 are left, and mark every feature you see as a find, one per feature, as if the bulk look had marked nothing: a mark on a shape it opened takes that find over. If the model router is not running, look at every tile yourself. Once every tile has a verdict, call add_measured_rises once: it opens finds for the best measured rises on the tiles looked at. Then call check_finds once: it slices every find, measures its shape and checks open maps; cut another slice by hand only where a find needs another direction. In the United States and France, call check_old_maps on every hollow, cut or straight-edged find, look at the sheets, and file what they show with record_old_maps. If the map service does not answer, say so and carry on. Search the literature for the area as a whole with search_literature and search_records, open what you can with read_source, and log every source with log_source as soon as you know its outcome, on all or on the finds it bears on. Spend at most ten minutes on any one check, then note it as open and move on. Add what each slice measured as evidence. For each find run_status lists under to_suggest (finds kept on the map need none), call suggest_decision with the decision the evidence points to and the reason, naming where it is published if it is. Keep a plan as you go. Do not set statuses or record a second opinion: Dighouse asks a second model itself when you are done, and I make the decisions, so leave both out of your advice. End with write_summary and then write_report, passing as advice two plain sentences on what you would try next. Once write_report has answered, the goal is met: mark it complete and tell me in two lines what the report says. If something stops you early, still end with write_summary and write_report.",
                 scope: .project,
                 steps: [Handoff(who: "Agent", does: "Fetches lidar, builds the bare ground"), Handoff(who: "Low-cost model", does: "Looks at every tile in bulk"), Handoff(who: "Agent and helpers", does: "Look closely at the shortlist"),
                         Handoff(who: "Agent", does: "A slice and a map check for each find"), Handoff(who: "Agent", does: "Literature search, every source logged"),
                         Handoff(who: "Second model", does: "Independent second opinion"), Handoff(who: "Dighouse", does: "The search report"),
                         Handoff(who: "You", does: "Decide each find")]),
        Workflow(id: "terrain", title: "Get the ground", icon: "dig.mound",
                 summary: "Finds open lidar for the area, builds the bare ground and cuts it into tiles.",
                 prompt: "Find open lidar for this project's area, fetch it, and cut it into tiles. Tell me how good the ground data is.",
                 scope: .project, steps: [Handoff(who: "Agent", does: "Finds the lidar, builds the ground, cuts tiles")]),
        Workflow(id: "screen", title: "Look at the tiles", icon: "dig.grid",
                 summary: "Looks at every tile nobody has looked at in bulk, then closely at the ones worth it, and marks what looks built.",
                 prompt: "Look at the tiles nobody has looked at yet: call look_at_tiles once, then look closely at every tile on its shortlist, best first, each in two views, and mark every feature you see as a find (a mark on a shape it opened takes that find over). Hand batches to helper agents when more than 12 need a close look. If the model router is not running, look at every tile yourself.",
                 scope: .project, steps: [Handoff(who: "Low-cost model", does: "Looks at every tile in bulk, opens a find for each shape"), Handoff(who: "Agent and helpers", does: "Look closely at the shortlist, record verdicts"), Handoff(who: "Agent", does: "Opens a record for each find it adds")]),
        Workflow(id: "check", title: "Check the finds", icon: "dig.layers",
                 summary: "Cuts a slice through each find and looks on open maps for roads and buildings.",
                 prompt: "For every find that still lacks them, cut a slice through it, starting and ending on the ground around it, and check open maps for modern features nearby.",
                 scope: .project, steps: [Handoff(who: "Agent", does: "A slice and a map check for each find")]),
        Workflow(id: "second", title: "Get a second opinion", icon: "person.2",
                 summary: "A different model looks at each find. It sees the tile but not the first opinion.",
                 prompt: "", scope: .project,
                 steps: [Handoff(who: "Dighouse", does: "Sends the tile to the second model"), Handoff(who: "Second model", does: "Agrees or disagrees, with a reason")]),
        Workflow(id: "prior", title: "Search what is published", icon: "dig.sieve",
                 summary: "Searches books, papers and site records for each find, and logs every source.",
                 prompt: "Search the literature for each find that has no sources yet, starting with studies of this dataset. Open what you find with read_source, and log each source on its record as soon as you have read it or failed to open it.",
                 scope: .project, steps: [Handoff(who: "Agent", does: "Searches, reads and logs sources")]),
        Workflow(id: "decide", title: "Suggest decisions", icon: "dig.brush",
                 summary: "The agent suggests what each find is, and why. You decide.",
                 prompt: "Suggest a decision for each find run_status lists under to_suggest; finds kept on the map need none. For each, read its record and sources and call suggest_decision with the decision the evidence points to and a reason I can check in one read: for already published, say where (author, year, title or record); for modern or natural, what shows it. If a find has no read source that names it, search the literature for it first. Then tell me in a few lines what is waiting for me and what is still missing.",
                 scope: .project, steps: [Handoff(who: "Agent", does: "Summarizes the records"), Handoff(who: "You", does: "Decide")]),
        Workflow(id: "report", title: "Draft a report", icon: "envelope",
                 summary: "Drafts a report to the heritage authority for finds with no match. You send it.",
                 prompt: "Call who_to_tell for this project. For each find I marked as having no match in the sources read, draft a short report for the body it names in reports/, with the evidence, the checks, the registers and lists it was checked against, and the sources searched. Leave the location out of the draft and tell me where the private annex should go. Do not send anything.",
                 scope: .project, steps: [Handoff(who: "Agent", does: "Drafts the report"), Handoff(who: "You", does: "Review and send")]),
        Workflow(id: "records", title: "Ask the records office", icon: "questionmark.folder",
                 summary: "Where the official site record is not open, drafts a short letter asking whether your strongest finds are already recorded. You send it.",
                 prompt: "Call who_to_tell for this project. If it says the official record is open, tell me that each find was already checked against it and stop. Otherwise, for each find I marked worth reporting or as having no match in the sources read, draft one short, polite letter to the office it names asking whether a site is already recorded there, with what the find is, its size and what was checked. The letter needs the locations, so write it under private/requests/, never in reports/ or anywhere else, and say so. Do not send anything.",
                 scope: .project, steps: [Handoff(who: "Agent", does: "Drafts the letter, with locations, under private/"), Handoff(who: "You", does: "Review and send")]),
    ]

    static var allSources: [DataSource] { sources + moreSources }

    static let sources: [DataSource] = [
        DataSource(name: "OpenTopography",
                   what: "A research archive of lidar surveys, some flown for archaeologists.", reach: "Worldwide, in patches",
                   gives: "The list of surveys and their raw laser points, from the files it publishes without an account.",
                   usedFor: "Choosing a place · Bare ground",
                   url: "https://opentopography.org", probe: "https://portal.opentopography.org/API/otCatalog?productFormat=PointCloud&minx=-90.1&miny=38.6&maxx=-90&maxy=38.7&detail=false&outputFormat=json&include_federated=false",
                   image: "start:yucatan", caption: "Bare ground under Yucatán forest, from a NASA survey OpenTopography hosts.",
                   ask: "List the open lidar surveys on OpenTopography that were flown with archaeology in mind, and say which can be fetched without an account."),
        DataSource(name: "USGS 3DEP",
                   what: "Public-domain lidar of most of the United States.", reach: "United States",
                   gives: "Raw laser points for any area it covers.",
                   usedFor: "Bare ground · Slices",
                   url: "https://www.usgs.gov/3d-elevation-program", probe: "https://s3-us-west-2.amazonaws.com/usgs-lidar-public/IL_10CoNRCS_3_D23/ept.json",
                   image: "start:newark", caption: "The Newark Great Circle in Ohio, built from USGS points.",
                   ask: "Is there open USGS lidar over Poverty Point in Louisiana? Say which dataset and when it was flown."),
        DataSource(name: "Wikidata",
                   what: "The open database behind Wikipedia.", reach: "Worldwide",
                   gives: "Archaeological sites that are already on record near an area. It is far from complete.",
                   usedFor: "Choosing a place",
                   url: "https://www.wikidata.org", probe: "https://www.wikidata.org/w/api.php?action=query&meta=siteinfo&format=json",
                   image: "data-wikidata", caption: "Sites on record within about 24 km of Cahokia. Each dot is one Wikidata entry.",
                   ask: "Which archaeological sites are already on record around Moundville, Alabama, and how far is each from it?"),
        DataSource(name: "OpenStreetMap",
                   what: "The open map of the world.", reach: "Worldwide",
                   gives: "Place names, and the roads, buildings and mapped historic sites near a find.",
                   usedFor: "Choosing a place · Checks",
                   url: "https://www.openstreetmap.org", probe: "https://nominatim.openstreetmap.org/status?format=json",
                   image: "data-osm", caption: "What OpenStreetMap has around Monks Mound: roads, buildings, and the mounds already mapped.",
                   ask: "Find Serpent Mound in Ohio and tell me which open lidar covers it.",
                   // The same servers, in the same order, that the modern-features check asks.
                   alsoProbe: ["https://overpass-api.de/api/interpreter?data=%5Bout%3Ajson%5D%3Bnode%281%29%3Bout%3B",
                               "https://overpass.private.coffee/api/interpreter?data=%5Bout%3Ajson%5D%3Bnode%281%29%3Bout%3B"],
                   alsoNote: "Place search answers. OpenStreetMap's Overpass servers do not, so the check for modern features uses OpenStreetMap's own map service, which is a little slower."),
        DataSource(name: "OpenAlex",
                   what: "An open index of scholarly books and papers.", reach: "Worldwide",
                   gives: "Titles, abstracts and links to open copies. Without a key it allows about 100 searches a day; past that, Crossref is asked.",
                   usedFor: "What is published",
                   url: "https://openalex.org", probe: "https://api.openalex.org/works?per-page=1",
                   image: "papers", caption: "What a search for Monks Mound returns. Two of them are free to read, and the agent reads those.",
                   ask: "What has been published about lidar and Maya settlement in the Usumacinta region? Give titles, years, and which have open copies."),
    ]

    static let moreSources: [DataSource] = [
        DataSource(name: "Open Context",
                   what: "An open archive of published excavation and survey records.", reach: "Worldwide",
                   gives: "Records that match a search, each with its project, place and dates.",
                   usedFor: "Choosing a place · What is published",
                   url: "https://opencontext.org", probe: "https://opencontext.org/query/.json?rows=1",
                   image: "records", caption: "Site-file entries Open Context returns around Cahokia. It holds 2,083 there, against 9 named sites on the other open lists.",
                   ask: "Search the published records for mounds in Madison County, Illinois, and tell me which projects they come from."),
        DataSource(name: "National Register of Historic Places",
                   what: "The US National Park Service's list of historic places.", reach: "United States",
                   gives: "Listed sites near an area. Sites with restricted locations are left out on purpose.",
                   usedFor: "Choosing a place",
                   url: "https://www.nps.gov/subjects/nationalregister", probe: "https://mapservices.nps.gov/arcgis/rest/services/cultural_resources/nrhp_locations/MapServer?f=json",
                   image: "data-nrhp", caption: "Places the Register lists as sites within about 60 km of Natchez, Mississippi. Each dot is one listing.",
                   ask: "Which sites on the National Register are within 60 km of Natchez, Mississippi?"),
        DataSource(name: "Environment Agency lidar (England)",
                   what: "A 1 m bare-ground model of England.", reach: "England",
                   gives: "The ground model for any area of England, ready-made. The service is slow, so allow a few minutes per square km.",
                   usedFor: "Bare ground",
                   url: "https://environment.data.gov.uk/dataset/13787b9a-26a4-4775-8523-806d13af58fc",
                   probe: "https://environment.data.gov.uk/spatialdata/lidar-composite-digital-terrain-model-dtm-1m/wcs?service=WCS&request=GetCapabilities&version=2.0.1",
                   image: "data-ea", caption: "Danebury hillfort in Hampshire, in sky view: the ramparts and ditches ring the hilltop.",
                   ask: "Is there open lidar over Maiden Castle in Dorset? Fetch a small box and tell me what the ramparts look like."),
        DataSource(name: "AHN (Netherlands)",
                   what: "A 0.5 m bare-ground model of the Netherlands.", reach: "The Netherlands",
                   gives: "The ground model for any area of the Netherlands, ready-made.",
                   usedFor: "Bare ground",
                   url: "https://www.ahn.nl", probe: "https://service.pdok.nl/rws/ahn/wcs/v1_0?service=WCS&request=GetCapabilities&version=2.0.1",
                   image: "data-ahn", caption: "Ginkelse Heide near Ede, in sky view: a banked enclosure and faint lines of banks, on a heath known for prehistoric fields.",
                   ask: "Fetch the AHN ground model for a small box on the Ginkelse Heide near Ede and look for the banks of prehistoric fields."),
        DataSource(name: "IGN LiDAR HD (France)",
                   what: "A 0.5 m bare-ground model of France, where it is published.", reach: "France",
                   gives: "The ground model for areas of France that have been published.",
                   usedFor: "Bare ground",
                   url: "https://geoservices.ign.fr/lidarhd", probe: "https://data.geopf.fr/wms-r/wms?SERVICE=WMS&VERSION=1.3.0&REQUEST=GetCapabilities",
                   image: "data-ign", caption: "The slopes below the Gergovie plateau in Auvergne, in sky view: field terraces either side of a wooded ravine.",
                   ask: "Fetch the French LiDAR HD ground model for a small box at the Gergovie plateau and describe what is built into the slopes."),
        DataSource(name: "DHM Vlaanderen (Flanders)",
                   what: "A 1 m bare-ground model of Flanders, in Belgium.", reach: "Flanders",
                   gives: "The ground model for any area of Flanders, ready-made.",
                   usedFor: "Bare ground",
                   url: "https://www.vlaanderen.be/digitaal-vlaanderen/onze-oplossingen/earth-observation-data-science-eodas/het-digitaal-hoogtemodel/digitaal-hoogtemodel-vlaanderen-ii",
                   probe: "https://geo.api.vlaanderen.be/DHMV/wcs?service=WCS&request=GetCapabilities&version=2.0.1",
                   image: "data-be", caption: "Hill 60 near Ypres, in sky view: the pocked ground of the First World War and a mine crater, beside a railway cutting.",
                   ask: "Fetch the Flemish ground model for a small box at Hill 60 near Ypres and describe what the war left in the ground."),
        DataSource(name: "Høydedata (Norway)",
                   what: "A 1 m bare-ground model of Norway.", reach: "Norway",
                   gives: "The ground model for areas of Norway that have been flown, ready-made. Allow a minute per square km.",
                   usedFor: "Bare ground",
                   url: "https://hoydedata.no", probe: "https://wcs.geonorge.no/skwms1/wcs.hoyde-dtm-nhm-25833?service=WCS&request=GetCapabilities&version=1.0.0",
                   image: "data-no", caption: "The burial mounds at Borre in Vestfold, in sky view. Several show the trench of an old dig.",
                   ask: "Fetch the Norwegian ground model for a small box at the Borre mounds in Vestfold and count the mounds you can see."),
        DataSource(name: "Maa-amet DTM (Estonia)",
                   what: "A 1 m bare-ground model of Estonia.", reach: "Estonia",
                   gives: "The ground model for any area of Estonia, ready-made. The service is slow, so allow a minute per square km.",
                   usedFor: "Bare ground",
                   url: "https://geoportaal.maaamet.ee/eng/Spatial-Data/Elevation-data-p308.html", probe: "https://teenus.maaamet.ee/ows/wcs-dtm?service=WCS&request=GetCapabilities&version=2.0.1",
                   image: "data-ee", caption: "Varbola stronghold in Rapla County, in sky view: the ring wall of one of Estonia's largest forts.",
                   ask: "Fetch the Estonian ground model for a small box at Varbola stronghold and describe its wall and gates."),
        DataSource(name: "swissALTI3D (Switzerland)",
                   what: "A 0.5 m bare-ground model of Switzerland.", reach: "Switzerland",
                   gives: "The ground model for any area of Switzerland, read from the file of each square km.",
                   usedFor: "Bare ground",
                   url: "https://www.swisstopo.admin.ch/en/height-model-swissalti3d", probe: "https://data.geo.admin.ch/api/stac/v0.9/collections/ch.swisstopo.swissalti3d",
                   image: "data-ch", caption: "The Roman amphitheatre of Vindonissa at Windisch, in sky view, among the houses of the town.",
                   ask: "Fetch the Swiss ground model for a small box at the Vindonissa amphitheatre in Windisch and say how large it is."),
        DataSource(name: "IDENA (Navarre, Spain)",
                   what: "A 2 m bare-ground model of Navarre, from the regional government's lidar.", reach: "Navarre, Spain",
                   gives: "The ground model for any area of Navarre, ready-made. Spain's national services cannot be used yet, so the rest of Spain is not covered.",
                   usedFor: "Bare ground",
                   url: "https://idena.navarra.es", probe: "https://idena.navarra.es/ogc/wcs?service=WCS&request=GetCapabilities&version=2.0.1",
                   image: "data-es", caption: "Irulegi hill in Aranguren, in sky view: the castle on the summit and the terraces of the Iron Age settlement below it.",
                   ask: "Fetch the Navarre ground model for a small box at Irulegi hill in Aranguren and describe the castle and the terraces around it."),
        DataSource(name: "geoEuskadi (Basque Country, Spain)",
                   what: "A 1 m bare-ground model of the Basque Country, from the Basque Government's latest lidar.", reach: "Basque Country, Spain",
                   gives: "The ground model for any area of the Basque Country, ready-made.",
                   usedFor: "Bare ground",
                   url: "https://www.geo.euskadi.eus", probe: "https://www.geo.euskadi.eus/WCS_KARTOGRAFIA?SERVICE=WCS&REQUEST=GetCapabilities&VERSION=2.0.1",
                   image: "data-es-pv", caption: "The Iron Age hillfort of Arrola on Marueleza hill in Bizkaia, in sky view: its banks and ditches across the ridge.",
                   ask: "Fetch the Basque ground model for a small box at the Arrola hillfort above Arratzu and count its banks."),
        DataSource(name: "DGM1 (Bavaria, Germany)",
                   what: "A 1 m bare-ground model of Bavaria.", reach: "Bavaria",
                   gives: "The ground model for any area of Bavaria, read from the file of each square km.",
                   usedFor: "Bare ground",
                   url: "https://geodaten.bayern.de/opengeodata/OpenDataDetail.html?pn=dgm1", probe: "https://geodaten.bayern.de/odd/a/dgm/dgm1/meta/metalink/09162.meta4",
                   image: "data-de-by", caption: "A Late Iron Age square enclosure in the Laufzorner Holz south of Munich, in sky view, among old ridge and furrow.",
                   ask: "Fetch the Bavarian ground model for a small box at the square enclosure in the Laufzorner Holz near Oberhaching and measure its sides."),
        DataSource(name: "DGM1 (Saxony, Germany)",
                   what: "A 1 m bare-ground model of Saxony.", reach: "Saxony",
                   gives: "The ground model for any area of Saxony, downloaded once for each 2 km square and kept on this Mac.",
                   usedFor: "Bare ground",
                   url: "https://www.geodaten.sachsen.de/downloadbereich-digitale-hoehenmodelle-4851.html", probe: "https://www.geodaten.sachsen.de/batch-download-4719.html",
                   image: "data-de-sn", caption: "The ring fort at Ostro in Upper Lusatia, in sky view: an oval rampart inside the bend of a stream.",
                   ask: "Fetch the Saxon ground model for a small box at the Ostro ring fort near Kamenz and describe its rampart."),
        DataSource(name: "DGM1 (North Rhine-Westphalia, Germany)",
                   what: "A 1 m bare-ground model of North Rhine-Westphalia, from Geobasis NRW.", reach: "North Rhine-Westphalia",
                   gives: "The ground model for any area of the state, handed over for the area asked.",
                   usedFor: "Bare ground",
                   url: "https://www.bezreg-koeln.nrw.de/geobasis-nrw", probe: "https://www.wcs.nrw.de/geobasis/wcs_nw_dgm?SERVICE=WCS&REQUEST=GetCapabilities&VERSION=2.0.1",
                   image: "data-de-nw", caption: "The Hünenburg above Bielefeld in sky view: the hilltop with its earthworks, crossed by later paths.",
                   ask: "Fetch the North Rhine-Westphalia ground model for a small box at the Hünenburg near Bielefeld and describe the earthworks."),
        DataSource(name: "Scottish Public Sector LiDAR",
                   what: "Scotland's open lidar: the National LiDAR Programme at 0.5 m, and the earlier phases at 0.5 to 1 m.", reach: "Scotland, where flown",
                   gives: "The ground model for the parts of Scotland flown so far, newest survey first, read from the file of each map sheet.",
                   usedFor: "Bare ground",
                   url: "https://remotesensingdata.gov.scot", probe: "https://srsp-open-data.s3.eu-west-2.amazonaws.com/?list-type=2&max-keys=1",
                   image: "data-uk-sc", caption: "Traprain Law in East Lothian in sky view: the hill's ramparts, and the quarry that cut into its east end.",
                   ask: "Fetch the Scottish ground model for a small box at Traprain Law and describe the ramparts."),
        DataSource(name: "Wales lidar composite",
                   what: "A 1 m bare-ground model of Wales, from the Welsh Government.", reach: "Wales",
                   gives: "The ground model for any area of Wales, read from one large file, only the part that is needed.",
                   usedFor: "Bare ground",
                   url: "https://datamap.gov.wales/maps/lidar-viewer/", probe: "https://dmwproductionblob.blob.core.windows.net/cogs/lidar/wales_dtm_32bit_cog.tif",
                   image: "data-uk-wa", caption: "Pen Dinas above Aberystwyth in sky view: the hillfort's ramparts along the ridge.",
                   ask: "Fetch the Welsh ground model for a small box at Pen Dinas, Aberystwyth, and describe the hillfort."),
        DataSource(name: "ARSO lidar (Slovenia)",
                   what: "A 1 m bare-ground model of Slovenia, from the Slovenian Environment Agency.", reach: "Slovenia",
                   gives: "The ground model for any area of Slovenia, read as text for each square km and kept on this Mac. A first fetch is slower.",
                   usedFor: "Bare ground",
                   url: "https://gis.arso.gov.si/evode/profile.aspx?id=atlas_voda_Lidar@Arso", probe: "https://gis.arso.gov.si/lidar/dmr1/b_35/D96TM/TM1_462_101.asc",
                   image: "data-si", caption: "The hillfort on Magdalenska gora in sky view: terraced ramparts round the church, and burial mounds on the slope.",
                   ask: "Fetch the Slovenian ground model for a small box at Magdalenska gora and describe the ramparts and the mounds."),
        DataSource(name: "LINZ elevation (New Zealand)",
                   what: "A 1 m bare-ground model of New Zealand, from Toitū Te Whenua Land Information New Zealand.", reach: "New Zealand",
                   gives: "The ground model for the areas of New Zealand flown so far, read from the file of each map sheet.",
                   usedFor: "Bare ground",
                   url: "https://registry.opendata.aws/nz-elevation/", probe: "https://nz-elevation.s3.ap-southeast-2.amazonaws.com/catalog.json",
                   image: "data-nz", caption: "Maungawhau in Auckland, in sky view: the terraces and pits of the pā that ring the volcano's crater.",
                   ask: "Fetch the New Zealand ground model for a small box at Maungawhau in Auckland and describe the terraces around the crater."),
        DataSource(name: "ČÚZK DMR 5G (Czechia)",
                   what: "A 2 m bare-ground model of Czechia, from the national lidar flown 2009 to 2013.", reach: "Czechia",
                   gives: "The ground model for any area of Czechia, read from ČÚZK's open image service.",
                   usedFor: "Bare ground",
                   url: "https://geoportal.cuzk.cz", probe: "https://ags.cuzk.cz/arcgis2/rest/services/dmr5g/ImageServer?f=json",
                   image: "data-cz", caption: "Závist above the Vltava, south of Prague, in sky view: the bank round the hilltop of an Iron Age oppidum.",
                   ask: "Fetch the Czech ground model for a small box at Závist, south of Prague, and describe the banks round the hilltop."),
        DataSource(name: "HRDEM (Canada)",
                   what: "A 1 m bare-ground model of Canada, mostly from lidar, where it has been flown.", reach: "Canada, mostly the south",
                   gives: "The ground model for any area it covers, read from Natural Resources Canada's open map service.",
                   usedFor: "Bare ground",
                   url: "https://open.canada.ca/data/en/dataset/0fe65119-e96e-4a57-8bfe-9d9245fba06b",
                   probe: "https://datacube.services.geo.ca/wrapper/ogc/elevation-hrdem-mosaic?service=WCS&version=1.1.1&request=GetCapabilities",
                   image: "data-ca", caption: "The Fortress of Louisbourg in Nova Scotia, in sky view: the bastioned walls and the grid of the town's streets.",
                   ask: "Fetch the Canadian ground model for a small box at the Fortress of Louisbourg and describe its walls."),
        DataSource(name: "VIRTUAL SHIZUOKA (Japan)",
                   what: "A 0.5 m bare-ground model of Shizuoka Prefecture, from lidar flown 2019 to 2025.", reach: "Shizuoka, Japan",
                   gives: "The ground model for any area flown, one small map sheet at a time, from the prefecture's open files.",
                   usedFor: "Bare ground",
                   url: "https://github.com/aigidjp/opendata_virtualshizuoka", probe: "https://virtual-shizuoka.s3.ap-northeast-1.amazonaws.com/?max-keys=1",
                   image: "data-jp", caption: "Yamanaka Castle above Mishima, in sky view: the terraced enclosures and moats of a sixteenth-century hill castle.",
                   ask: "Fetch the Shizuoka ground model for a small box at Yamanaka Castle near Mishima and describe its enclosures and moats."),
        DataSource(name: "INFOMAR (Irish waters)",
                   what: "Sonar surveys of the seabed around Ireland, as a depth model of about 4 m.", reach: "Irish waters",
                   gives: "The seafloor for any box it covers. Large wrecks show; small ones may not.",
                   usedFor: "Bare ground (seafloor)",
                   url: "https://www.infomar.ie", probe: "https://infomar.marine.ie/arcgis/rest/services/INFOMAR/AllBathymetry/ImageServer?f=json",
                   image: "data-ie", caption: "The seabed off the Old Head of Kinsale at about 90 m. The long shape at the centre is where the Lusitania lies.",
                   ask: "Fetch the INFOMAR seafloor for a small box off the Old Head of Kinsale where the Lusitania lies, and describe the wreck."),
        DataSource(name: "Danmarks Højdemodel (Denmark)",
                   what: "A 0.4 m bare-ground model of Denmark.", reach: "Denmark",
                   gives: "The ground model for any area of Denmark, once you paste a free Dataforsyningen token in Settings, Data and privacy.",
                   usedFor: "Bare ground",
                   url: "https://dataforsyningen.dk/data/930", probe: "https://api.dataforsyningen.dk/dhm_wcs_DAF?service=WCS&request=GetCapabilities",
                   ask: "Is Denmark's ground model ready to use on this Mac? If it needs a token, say where to get one."),
        DataSource(name: "Fund og Fortidsminder (Denmark)",
                   what: "Denmark's national register of ancient monuments and finds.", reach: "Denmark",
                   gives: "Every recorded site near an area, protected or not, so a find in Denmark is checked against the national register.",
                   usedFor: "Checking a find",
                   url: "https://www.kulturarv.dk/fundogfortidsminder/", probe: "https://www.kulturarv.dk/ffgeoserver/public/wfs?service=WFS&request=GetCapabilities",
                   ask: "Which monuments does Denmark's register list within 1 km of Trelleborg on Zealand, and which are protected?"),
        DataSource(name: "Norway's heritage register (Askeladden)",
                   what: "Riksantikvaren's register of cultural heritage, published openly through Geonorge.", reach: "Norway",
                   gives: "Every recorded locality and single monument near an area, except records kept back as sensitive, so a find in Norway is checked against the national register.",
                   usedFor: "Checking a find, and answer keys",
                   url: "https://kulturminnesok.no", probe: "https://api.ra.no/kulturminner/collections?f=json",
                   ask: "Which monuments does Norway's register list around the Borre mounds in Horten, and of what kind?"),
        DataSource(name: "National Heritage List for England",
                   what: "Historic England's list of designated places, here its scheduled monuments.", reach: "England",
                   gives: "Scheduled monuments near an area, as mapped areas. It holds designated monuments only; most known sites are in county records that are not open.",
                   usedFor: "Checking a find, and answer keys",
                   url: "https://historicengland.org.uk/listing/the-list/", probe: "https://services-eu1.arcgis.com/ZOdPfBS3aqqDYPUQ/ArcGIS/rest/services/National_Heritage_List_for_England_NHLE_v02_VIEW/FeatureServer/6?f=json",
                   ask: "Which scheduled monuments lie on Normanton Down near Stonehenge?"),
        DataSource(name: "Navarre's heritage register (Spain)",
                   what: "Navarre's register of protected archaeological sites.", reach: "Navarre, Spain",
                   gives: "The dolmens, burial mounds, stone circles and archaeological zones the register protects near an area.",
                   usedFor: "Checking a find",
                   url: "https://idena.navarra.es", probe: "https://idena.navarra.es/ogc/wfs?service=WFS&request=GetCapabilities",
                   ask: "Which protected megaliths does Navarre's register list on the Sierra de Urbasa?"),
        DataSource(name: "Pleiades",
                   what: "A gazetteer of about 35,000 ancient places.", reach: "Mediterranean and Near East",
                   gives: "Ancient places already on record near an area, in the Mediterranean, Europe and the Near East.",
                   usedFor: "Choosing a place",
                   url: "https://pleiades.stoa.org", probe: "https://pleiades.stoa.org/places/423025/json",
                   image: "data-pleiades", caption: "Ancient places Pleiades lists within about 9 km of Nîmes, the Roman Nemausus: its gates, quarries and a milestone. Each dot is one place.",
                   ask: "Which ancient places does Pleiades list within 10 km of Nîmes, and from which periods?"),
    ]

    /// Open data the tools do not read yet, and what stands in the way. Kept in step with what was tried.
    static let notYet: [(String, String)] = [
        ("State and national site files", "The full official lists of known sites. Access is restricted, to protect the sites."),
        ("Finland and Sweden", "Their national lidar is open, but each asks for an account or a key."),
        ("Spain", "The open service gives a 5 m ground model, too coarse for most earthworks."),
        ("Poland and Luxembourg", "Poland's service did not answer from here. Luxembourg's listed no ground model. Both are worth another try."),
        ("Satellite and aerial photographs", "Useful for cropmarks. The open archives need an account."),
    ]

    static let rules = [
        "Nothing is ever called new. A record says how many sources were read and that none matched.",
        "Locations stay on this Mac. Records and notes carry no coordinates.",
        "A tile with too little ground data is unreadable and cannot be given a verdict.",
        "The second opinion must come from a different model than the one that marked the find.",
        "You decide before a find is marked as having no match, and you send any report.",
    ]

    /// A step line for the chat: an icon and a sentence for one tool call.
    static func describe(_ tool: String, _ a: JSON) -> (String, String) {
        func s(_ key: String) -> String { a[key] as? String ?? "" }
        let tile = s("tile").split(separator: "-").last.map(String.init) ?? ""
        let style = s("style").isEmpty ? "" : ", " + s("style").replacingOccurrences(of: "_", with: " ")
        switch tool {
        case "find_place": return ("mappin.and.ellipse", "Looked up \(s("query"))")
        case "open_surveys": return ("dig.grid", "Read the open survey catalog")
        case "find_gaps": return ("square.grid.3x3.topleft.filled", "Ranked a region by open lidar and recorded sites")
        case "open_resources": return ("building.columns", "Listed the open archives")
        case "search_records": return ("dig.sieve", "Searched published records: \(s("query"))")
        case "survey_area": return ("binoculars", "Sized up an area: lidar coverage and recorded sites")
        case "init_project": return ("folder.badge.plus", "Created the project \(s("name"))")
        case "suggest_project": return ("folder.badge.plus", "Offered a project: \(s("name"))")
        case "find_data": return ("magnifyingglass", "Looked for open lidar over the area")
        case "import_terrain": return ("tray.and.arrow.down", "Added your own file")
        case "suggest_decision": return ("dig.brush", "Suggested a decision for \(s("candidate"))")
        case "fetch_terrain": return ("arrow.down.circle", "Fetched the ground from \(s("dataset").split(separator: ":").last.map(String.init) ?? "")")
        case "view_terrain": return ("dig.mound", "Looked at all of the ground")
        case "make_tiles": return ("dig.grid", "Cut the ground into tiles")
        case "next_tiles": return ("dig.grid", "Picked the next tiles")
        case "view_tile": return ("eye", "Looked at tile \(tile)\(style)")
        case "record_verdict": return ("checkmark", "Tile \(tile): \(s("verdict"))")
        case "flag_candidate": return ("flag", "Marked a find: \(s("name"))")
        case "cut_section": return ("dig.layers", "Cut a slice" + (s("candidate").isEmpty ? " on tile \(tile)" : " through \(s("candidate"))"))
        case "second_look": return ("person.2", "Second opinion on \(s("candidate")) by \(s("model"))")
        case "check_modern": return ("building.2", "Checked open maps near \(s("candidate"))")
        case "check_finds": return ("dig.layers", "Checked " + (s("candidates").isEmpty || s("candidates") == "all" ? "every open find" : s("candidates")) + ": slices, shapes, open maps")
        case "search_literature": return ("dig.sieve", "Searched the literature: \(s("query"))")
        case "read_source": return ("doc.text.magnifyingglass", "Opened a source: \(URL(string: s("url"))?.host ?? s("url"))")
        case "log_source": return ("text.book.closed", "Logged a source (\(s("status").replacingOccurrences(of: "_", with: " "))): \(s("title"))")
        case "add_evidence": return ("plus", "Added evidence to \(s("candidate"))")
        case "set_status": return ("checkmark.seal", "Marked \(s("candidate")) as \(Candidate.labels[s("status")]?.lowercased() ?? s("status"))")
        case "list_candidates": return ("list.bullet", "Reviewed the finds")
        case "add_control": return ("scope", "Registered a control: \(s("name"))")
        case "write_summary": return ("doc.richtext", "Wrote the run summary")
        case "write_report": return ("doc.richtext", "Wrote the search report")
        case "document_project": return ("book.closed", "Updated the research record")
        case "list_tests": return ("checklist", "Listed the test sites")
        case "feature_guide": return ("book", "Read the feature guide")
        case "find_mounds": return ("smallcircle.filled.circle", "Measured small mounds")
        case "add_measured_rises": return ("smallcircle.filled.circle", "Added measured rises as finds")
        case "check_old_maps": return ("map", "Checked old maps near \(s("candidate"))")
        case "record_old_maps": return ("map", "Filed the old maps for \(s("candidate"))")
        case "shape_check": return ("smallcircle.filled.circle", "Measured the shape of \(s("candidate"))")
        case "view_source_page": return ("doc.text.magnifyingglass", "Looked at a page of a source")
        case "render_tiles": return ("dig.grid", "Drew the tiles")
        case "export_finds": return ("square.and.arrow.up", "Exported the finds")
        case "second_look_failed": return ("person.2", "No second opinion on \(s("candidate"))")
        case "start_from_chat": return ("folder.badge.plus", "Wrote the chat into the project")
        case "check_before_publishing": return ("checkmark.shield", "Checked the project before publishing")
        case "calibration_site": return ("scope", "Picked a calibration site")
        case "record_calibration": return ("checkmark.seal", "Recorded the calibration")
        case "start_calibration": return ("eye.slash", "Started the calibration test")
        case "quick_look": return ("eye", s("place").isEmpty ? "Took a quick look" : "Took a quick look at \(s("place"))")
        case "start_test": return ("eye.slash", "Started a blind test")
        case "score_test": return ("target", "Scored the blind test")
        case "run_status": return ("gauge", "Checked the run status")
        default: return ("dig.trowel", tool)
        }
    }
}

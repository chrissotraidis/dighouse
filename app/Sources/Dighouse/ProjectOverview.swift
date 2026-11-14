import SwiftUI

/// What a project shows before a chat is opened: its question, how far the search has got, what the last run
/// found, and the next step explained for someone new to archaeology.
struct ProjectOverview: View {
    @EnvironmentObject var app: AppState
    @EnvironmentObject var store: ProjectStore

    private struct Stage: Identifiable {
        let id: String, icon: String, title: String, plain: String
        let done: Bool, detail: String
    }

    private var question: String {
        guard let root = store.current?.path, let text = try? String(contentsOfFile: root + "/PROJECT.md", encoding: .utf8),
              let range = text.range(of: "## Question") else { return "" }
        // The first line under the heading, unless the section is empty and the next heading comes first.
        let line = text[range.upperBound...].split(separator: "\n").first { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
            .map { String($0).trimmingCharacters(in: .whitespaces) } ?? ""
        return line.hasPrefix("#") ? "" : line
    }

    /// The newest run summary's first paragraph under "What was done", or its first lines.
    private var lastRun: (date: String, text: String)? {
        guard let root = store.current?.path,
              let files = try? FileManager.default.contentsOfDirectory(atPath: root + "/notes") else { return nil }
        guard let newest = files.filter({ $0.contains("-run-") && $0.hasSuffix(".md") }).sorted().last,
              let text = try? String(contentsOfFile: root + "/notes/" + newest, encoding: .utf8) else { return nil }
        let lines = text.split(separator: "\n").map(String.init).filter { !$0.hasPrefix("#") && !$0.trimmingCharacters(in: .whitespaces).isEmpty }
        // A short excerpt, so Markdown marks are taken out rather than drawn: bold, code and list bullets.
        let body = lines.prefix(4).map { $0.hasPrefix("- ") ? String($0.dropFirst(2)) : $0 }.joined(separator: " ")
            .replacingOccurrences(of: "**", with: "").replacingOccurrences(of: "\u{60}", with: "")
        // "2026-11-13-run-1430.md" reads "2026-11-13 at 14:30".
        let parts = newest.replacingOccurrences(of: ".md", with: "").components(separatedBy: "-run-")
        let time = parts.count > 1 && parts[1].count == 4 ? String(parts[1].prefix(2)) + ":" + String(parts[1].suffix(2)) : (parts.count > 1 ? parts[1] : "")
        let date = parts[0] + (time.isEmpty ? "" : " at " + time)
        return (date, String(body.prefix(520)) + (body.count > 520 ? "…" : ""))
    }

    private var stages: [Stage] {
        let s = store.status, all = store.candidates
        let decided = all.filter { !["flagged", "ground_confirmed"].contains($0.status) }.count
        let checked = all.filter { $0.checks["section"] != nil && $0.checks["modern"] != nil }.count
        let second = all.filter { $0.checks["second_look"] != nil }.count
        let sourced = all.filter { !$0.sources.isEmpty }.count
        // A shared project: its ground was fetched and looked at on the Mac it came from.
        let before = store.terrains.isEmpty ? store.screenedBefore : nil
        let finds = "\(all.count) find\(all.count == 1 ? "" : "s")"
        let none = "No finds yet"
        return [
            Stage(id: "terrain", icon: "dig.mound", title: "Bare ground", plain: "The laser scans, with the trees taken away.",
                  done: !store.terrains.isEmpty || before != nil,
                  detail: before != nil ? "Done on the other Mac" : store.terrains.isEmpty ? "Not yet" : "\(s.tiles) tile\(s.tiles == 1 ? "" : "s")"),
            Stage(id: "screen", icon: "dig.grid", title: "A first look", plain: "The agent looks at every tile for shapes people built.",
                  done: (s.tiles > 0 && s.unscreened == 0) || before != nil,
                  detail: before.map { "\($0) tile\($0 == 1 ? "" : "s") on the other Mac, \(finds)" }
                    ?? (s.tiles == 0 ? "Waiting for the ground" : "\(s.screened) of \(s.readable) tiles, \(finds)")),
            Stage(id: "check", icon: "dig.layers", title: "Checks", plain: "Is each find in the ground, and is it a road or a building?",
                  done: !all.isEmpty && checked == all.count, detail: all.isEmpty ? none : "\(checked) of \(all.count) checked"),
            Stage(id: "second", icon: "person.2", title: "Second opinion", plain: "A different AI model looks at each find on its own.",
                  done: !all.isEmpty && second == all.count, detail: all.isEmpty ? none : "\(second) of \(all.count)"),
            Stage(id: "prior", icon: "dig.sieve", title: "What is published", plain: "Books, papers and site records searched for each find.",
                  done: !all.isEmpty && sourced == all.count, detail: all.isEmpty ? none : "\(sourced) of \(all.count) searched"),
            Stage(id: "decide", icon: "dig.brush", title: "Your decisions", plain: "You decide what each find is.",
                  done: !all.isEmpty && decided == all.count, detail: all.isEmpty ? none : "\(decided) of \(all.count) decided"),
        ]
    }

    /// The card at the top of a project: what happens next, what comes after it, and the button that does it.
    private struct Next {
        let title: String, what: String, after: String, icon: String
        let label: String
        let action: () -> Void
        /// A smaller choice beside the main button, such as doing one step alone.
        var other: (label: String, help: String, action: () -> Void)? = nil
        var coach: Tutorial.Target? = nil
    }

    /// What one step of a search does, in words a newcomer has, and what is left after it.
    static func step(_ id: String, tiles: Int, finds: Int) -> (title: String, what: String, after: String) {
        let f = "\(finds) find\(finds == 1 ? "" : "s")"
        switch id {
        case "terrain":
            return ("get the ground", "The agent downloads the open laser scans for this area and takes the trees away, leaving the bare ground.",
                    "After that it looks at the ground, checks what it marks and reports back. About 5 to 15 minutes in all.")
        case "screen":
            return ("look at \(tiles) tile\(tiles == 1 ? "" : "s")", "The ground is cut into squares called tiles. The agent looks at each one and marks any shape that looks built.",
                    "After that it checks each find and reports back. About 5 to 15 minutes in all.")
        case "check":
            return ("check \(f)", "The agent cuts a slice, straight down through the laser points, to see if each find is in the ground or only in the treetops. It also looks on open maps for roads and buildings.",
                    "After that: a second opinion, what is published, and a report. About 5 minutes in all.")
        case "second":
            return ("get a second opinion", "A different AI model looks at each find without seeing the first opinion. Two that agree are harder to fool.",
                    "After that: what is published, and a report. A few minutes.")
        case "prior":
            return ("see what is published", "The agent searches books, papers and site records for each find. Most turn out to be known already, and that is a result too.",
                    "After that: a report, and the decisions are yours. A few minutes.")
        default:
            return ("get the agent's suggestions", "The agent reads each find's record and suggests what it is, with a reason you can check.",
                    "After that the decisions are yours. A minute or two.")
        }
    }

    private var next: Next? {
        let all = store.candidates
        let open = all.filter { $0.status == "flagged" || $0.status == "ground_confirmed" }
        let finds = "\(open.count) find\(open.count == 1 ? "" : "s")"
        let whole = ToolGuide.workflows.first { $0.id == "full" }
        // A project someone shared: the ground was looked at on their Mac, and what is left needs no download.
        if store.terrains.isEmpty, let before = store.screenedBefore {
            return Next(title: "Pick up where it was left",
                        what: "This project was shared with you. The agent reads its research record, tells you what was done, and does what is left.",
                        after: "\(before) tile\(before == 1 ? " was" : "s were") looked at on the other Mac. Nothing needs downloading.",
                        icon: "dig.layers", label: "Carry on") { app.ask(ToolGuide.carryOn.prompt, title: ToolGuide.carryOn.title) }
        }
        let suggested = !open.isEmpty && open.allSatisfy { $0.suggestion != nil || Review_hasSuggestion($0) }
        let decide = Next(title: "Your turn\(app.firstName.isEmpty ? "" : ", " + app.firstName): decide \(finds)",
                          what: suggested ? "The agent checked \(open.count == 1 ? "the find" : "each find") and suggests what it is, with its reason. Look at the pictures, then agree or change it."
                                          : "Look at each find and decide what it is.",
                          after: "About a minute each. Nothing is final until you decide.",
                          icon: "dig.brush", label: "Decide \(finds)") { app.reviewing = true }
        if let flow = app.nextStep {
            let unchecked = open.filter { $0.checks["section"] == nil || $0.checks["modern"] == nil }.count
            let words = Self.step(flow.id, tiles: store.status.unscreened, finds: unchecked)
            if flow.id == "second" {
                // The second opinion is asked by Dighouse itself, of another model, so the whole search is not the way to get it.
                return Next(title: "Next: \(words.title)", what: words.what,
                            after: suggested ? "After that the decisions are yours. About a minute a find." : words.after,
                            icon: flow.icon, label: flow.title, action: { app.run(flow) },
                            other: suggested ? (decide.label, "Go to the review without a second opinion.", decide.action) : nil)
            }
            if flow.id == "decide" {
                // Only the suggestions are left, so the step itself is the main button, and going straight to the review is the other.
                return Next(title: "Next: \(words.title)", what: words.what, after: words.after, icon: flow.icon, label: flow.title,
                            action: { app.run(flow) }, other: (decide.label, "Go to the review without the agent's suggestions.", decide.action))
            }
            // In the tutorial the steps are taken one at a time. Otherwise the agent carries the search to its end,
            // and doing one step alone is the smaller choice.
            if app.tutorialStep == nil, let whole, app.state(of: whole).ready {
                let first = store.terrains.isEmpty
                return Next(title: first ? "Start the search" : "Next: \(words.title)",
                            what: first ? "The agent downloads the open laser scans for this area, takes the trees away, and looks over the bare ground for shapes people built." : words.what,
                            after: first ? "You get a short report and the finds to decide. About 5 to 15 minutes for a small area." : words.after,
                            icon: first ? whole.icon : flow.icon, label: whole.title, action: { app.run(whole) },
                            other: ("Only \(words.title)", "Do this one step and stop.", { app.run(flow) }))
            }
            return Next(title: "Next: \(words.title)", what: words.what, after: "", icon: flow.icon, label: flow.title, action: { app.run(flow) },
                        coach: flow.id == "terrain" && app.layout != .workspace ? .getTerrain : nil)
        }
        if !open.isEmpty { return decide }
        guard store.status.tiles > 0, app.chat.running == false else { return nil }
        let widen: (label: String, help: String, action: () -> Void) =
            ("Widen the search", "Fetch the ground around this area and look at it too.", { app.ask(ToolGuide.widen, title: "Widen the search") })
        if all.isEmpty {
            return Next(title: "Nothing here looked built", what: "The agent looked at every tile and marked nothing. That is a result too: it saves the next person the same search.",
                        after: "", icon: "dig.grid", label: widen.label, action: widen.action)
        }
        return Next(title: "This search is finished", what: "Every find is decided. The report says what was found, and the research record keeps the detail.",
                    after: "", icon: "dig.trowel", label: app.latestReport == nil ? "Research record" : "Read the report",
                    action: { if let report = app.latestReport { app.reportShown = report } else { app.showNotes("record") } }, other: widen)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(store.current?.name ?? "").font(.system(size: 26 * Theme.scale, weight: .bold))
                    if !question.isEmpty {
                        Text(question).font(.system(size: 15 * Theme.scale)).foregroundStyle(Theme.text.opacity(0.8)).fixedSize(horizontal: false, vertical: true)
                    }
                }
                .arrives()
                if let next {
                    let words = HStack(alignment: .top, spacing: 14) {
                        IconTile(name: next.icon, size: 38)
                        VStack(alignment: .leading, spacing: 5) {
                            Text(next.title).font(.system(size: 16 * Theme.scale, weight: .semibold))
                            Text(next.what).font(.system(size: 13.5 * Theme.scale)).foregroundStyle(Theme.text.opacity(0.86)).lineSpacing(2)
                                .fixedSize(horizontal: false, vertical: true)
                            if !next.after.isEmpty {
                                Text(next.after).font(.system(size: 12.5 * Theme.scale)).foregroundStyle(Theme.faint).fixedSize(horizontal: false, vertical: true)
                            }
                        }
                    }
                    VStack(alignment: .leading, spacing: 14) {
                        words
                        HStack(spacing: 8) {
                            Button(next.label, action: next.action).buttonStyle(PrimaryButton()).coach(next.coach)
                            if let other = next.other {
                                Button(other.label, action: other.action).buttonStyle(SecondaryButton()).help(other.help)
                            }
                        }
                        .padding(.leading, 52)
                    }
                    .padding(16).frame(maxWidth: .infinity, alignment: .leading)
                    .background(RoundedRectangle(cornerRadius: 14).fill(Theme.tan.opacity(0.08)))
                    .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(Theme.tan.opacity(0.3)))
                    .arrives(1)
                }
                VStack(alignment: .leading, spacing: 8) {
                    Text("The search so far").font(.system(size: 14 * Theme.scale, weight: .semibold))
                    VStack(spacing: 0) {
                        ForEach(Array(stages.enumerated()), id: \.element.id) { i, stage in
                            if i > 0 { Hairline() }
                            HStack(spacing: 12) {
                                // Each stage has its own drawing; a finished one is in colour with a tick at the end of its row.
                                Glyph(name: stage.icon, size: 15 * Theme.scale).foregroundStyle(stage.done ? Theme.tan : Theme.faint)
                                    .frame(width: 30, height: 30)
                                    .background(RoundedRectangle(cornerRadius: 8).fill(Theme.ink.opacity(stage.done ? 0.07 : 0.03)))
                                VStack(alignment: .leading, spacing: 1) {
                                    Text(stage.title).font(.system(size: 13.5 * Theme.scale, weight: .medium))
                                    Text(stage.plain).font(.system(size: 12 * Theme.scale)).foregroundStyle(Theme.faint)
                                }
                                Spacer(minLength: 8)
                                // A count rolls to its new value, and the tick lands, when a run moves a stage on.
                                Text(stage.detail).font(.system(size: 12.5 * Theme.scale)).foregroundStyle(Theme.dim)
                                    .contentTransition(.numericText()).animation(Motion.ease(0.25), value: stage.detail)
                                Image(systemName: "checkmark").font(.system(size: 11 * Theme.scale, weight: .bold)).foregroundStyle(Theme.green)
                                    .opacity(stage.done ? 1 : 0).scaleEffect(stage.done ? 1 : 0.3).animation(Motion.settle, value: stage.done)
                                    .accessibilityLabel(stage.done ? "Done" : "Not done yet")
                            }
                            .padding(.horizontal, 14).padding(.vertical, 9)
                        }
                    }
                    .panel()
                    HStack(alignment: .center, spacing: 12) {
                        if let report = app.latestReport {
                            Button { app.reportShown = report } label: { Label("Search report", glyph: "dig.trowel") }
                                .buttonStyle(SecondaryButton()).help("The short report of what the last whole search found.")
                        }
                        Button { app.showNotes("record") } label: { Label("Research record", systemImage: "book.closed") }
                            .buttonStyle(SecondaryButton()).help("Everything looked at, read and decided in this project.")
                        Spacer(minLength: 0)
                    }
                    .padding(.top, 4)
                }
                if let lastRun {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("The last run, \(lastRun.date)").font(.system(size: 14 * Theme.scale, weight: .semibold))
                        Text(lastRun.text).font(.system(size: 13 * Theme.scale)).foregroundStyle(Theme.dim).lineSpacing(2).fixedSize(horizontal: false, vertical: true)
                        Button("Read the run summaries") { app.showNotes("runs") }.buttonStyle(SecondaryButton())
                    }
                }
                Text("Or ask the agent anything about this project, below. Type / for commands.")
                    .font(.system(size: 12.5 * Theme.scale)).foregroundStyle(Theme.faint)
            }
            .padding(24).frame(maxWidth: 640, alignment: .leading).frame(maxWidth: .infinity)
        }
    }
}

/// A suggestion the review can make from the record itself, when the agent left none.
func Review_hasSuggestion(_ c: Candidate) -> Bool { ReviewSheet.suggestion(for: c) != nil }


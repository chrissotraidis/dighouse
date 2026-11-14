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
        // A shared project: its ground was fetched and screened on the Mac it came from.
        let before = store.terrains.isEmpty ? store.screenedBefore : nil
        return [
            Stage(id: "terrain", icon: "dig.mound", title: "Bare ground", plain: "Download the laser scans and strip the trees away.",
                  done: !store.terrains.isEmpty || before != nil,
                  detail: before != nil ? "Done on the other Mac" : store.terrains.isEmpty ? "Not yet" : "\(store.terrains.count) terrain, \(s.tiles) tiles"),
            Stage(id: "screen", icon: "dig.grid", title: "Screening", plain: "Look at every tile for shapes people built.",
                  done: (s.tiles > 0 && s.unscreened == 0) || before != nil,
                  detail: before.map { "\($0) tile\($0 == 1 ? "" : "s") before the handover, \(all.count) flagged" }
                    ?? (s.tiles == 0 ? "Waiting for terrain" : "\(s.screened) of \(s.readable) tiles, \(s.candidates) flagged")),
            Stage(id: "check", icon: "dig.layers", title: "Checks", plain: "Slice through each flag, and look for roads and buildings.",
                  done: !all.isEmpty && checked == all.count, detail: all.isEmpty ? "Waiting for flags" : "\(checked) of \(all.count) checked"),
            Stage(id: "second", icon: "person.2", title: "Second opinion", plain: "A different AI model looks at each flag on its own.",
                  done: !all.isEmpty && second == all.count, detail: all.isEmpty ? "Waiting for flags" : "\(second) of \(all.count)"),
            Stage(id: "prior", icon: "dig.sieve", title: "What is published", plain: "Search the literature to see if each find is already known.",
                  done: !all.isEmpty && sourced == all.count, detail: all.isEmpty ? "Waiting for flags" : "\(sourced) of \(all.count) searched"),
            Stage(id: "decide", icon: "dig.brush", title: "Your decisions", plain: "You decide what each one is.",
                  done: !all.isEmpty && decided == all.count, detail: all.isEmpty ? "Waiting for flags" : "\(decided) of \(all.count) decided"),
        ]
    }

    /// The next thing to do, in plain words, with the button that does it.
    private var next: (title: String, why: String, action: () -> Void, label: String, icon: String)? {
        let open = store.candidates.filter { $0.status == "flagged" || $0.status == "ground_confirmed" }
        // A project someone shared: the ground was looked at on their Mac, and what is left needs no download.
        if store.terrains.isEmpty, let before = store.screenedBefore {
            return ("Pick up where it was left",
                    "This project was shared with you. Its downloads and locations stayed on the other Mac, but the research record says what was done: \(before) tile\(before == 1 ? "" : "s") screened and \(store.candidates.count) find\(store.candidates.count == 1 ? "" : "s"). The agent reads it and tells you what is left.",
                    { app.ask(ToolGuide.carryOn.prompt, title: ToolGuide.carryOn.title) }, "Carry on", "dig.layers")
        }
        // In the tutorial the steps are taken one at a time, so the card offers the step the tutorial is on.
        let stepwise = app.tutorialStep != nil
        if store.terrains.isEmpty, !stepwise, let flow = ToolGuide.workflows.first(where: { $0.id == "full" }) {
            return ("Run the search", "The agent fetches the open lidar for this area, looks at every tile, checks what it flags and searches what is published. It stops for you at the decisions. It takes about 10 to 20 minutes.", { app.run(flow) }, "Run the whole search", flow.icon)
        }
        if !open.isEmpty, open.allSatisfy({ $0.suggestion != nil || Review_hasSuggestion($0) }) {
            return ("Decide what the finds are", "The agent has looked at \(open.count) find\(open.count == 1 ? "" : "s") and suggests what each one is, with its reason. Look at the pictures and agree or change each suggestion.", { app.reviewing = true }, "Review \(open.count)", "dig.brush")
        }
        if let flow = app.nextStep {
            let why: [String: String] = [
                "terrain": "The project has no bare ground yet. The agent downloads the laser scans for the area and strips the trees away.",
                "screen": "Some tiles have not been looked at. The agent looks at each and flags shapes that look built.",
                "check": "Some flags have no section yet. A slice through the laser points shows whether a shape is in the ground or in the trees.",
                "second": "A second AI model, from a different maker, looks at each flag without seeing the first opinion.",
                "prior": "Before anything counts as new, the agent searches what is published about each find.",
                "decide": "The agent reads each record and suggests what each find is, so your review starts prepared.",
            ]
            return (flow.title, why[flow.id] ?? flow.summary, { app.run(flow) }, flow.title, flow.icon)
        }
        if !open.isEmpty { return ("Decide what the finds are", "Look at each find and decide what it is.", { app.reviewing = true }, "Review \(open.count)", "dig.brush") }
        return nil
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
                if let next {
                    let words = HStack(alignment: .top, spacing: 14) {
                        IconTile(name: next.icon, size: 38)
                        VStack(alignment: .leading, spacing: 3) {
                            Text("Next: \(next.title)").font(.system(size: 15 * Theme.scale, weight: .semibold))
                            Text(next.why).font(.system(size: 13 * Theme.scale)).foregroundStyle(Theme.dim).fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    let button = Button(next.label, action: next.action).buttonStyle(PrimaryButton())
                        .coach(next.label == "Get the terrain" && app.layout != .workspace ? .getTerrain : nil)
                    // In a narrow chat the button goes under the words, so they are never squeezed into a thin column.
                    ViewThatFits(in: .horizontal) {
                        HStack(alignment: .center, spacing: 14) {
                            words.frame(minWidth: 280, alignment: .leading)
                            Spacer(minLength: 0)
                            button
                        }
                        VStack(alignment: .leading, spacing: 12) {
                            words
                            button.padding(.leading, 52)
                        }
                    }
                    .padding(16).frame(maxWidth: .infinity, alignment: .leading)
                    .background(RoundedRectangle(cornerRadius: 14).fill(Theme.tan.opacity(0.08)))
                    .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(Theme.tan.opacity(0.3)))
                }
                VStack(alignment: .leading, spacing: 8) {
                    Text("How far the search has got").font(.system(size: 14 * Theme.scale, weight: .semibold))
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
                                Text(stage.detail).font(.system(size: 12.5 * Theme.scale)).foregroundStyle(Theme.dim)
                                Image(systemName: "checkmark").font(.system(size: 11 * Theme.scale, weight: .bold)).foregroundStyle(Theme.green)
                                    .opacity(stage.done ? 1 : 0).accessibilityLabel(stage.done ? "Done" : "Not done yet")
                            }
                            .padding(.horizontal, 14).padding(.vertical, 9)
                        }
                    }
                    .panel()
                    HStack(alignment: .center, spacing: 12) {
                        Text("Everything looked at, read and decided here is kept in the research record, so you or anyone you share the project with can pick it up without starting again.")
                            .font(.system(size: 12.5 * Theme.scale)).foregroundStyle(Theme.faint).fixedSize(horizontal: false, vertical: true)
                        Spacer(minLength: 8)
                        Button { app.showNotes("record") } label: { Label("Research record", systemImage: "book.closed") }
                            .buttonStyle(SecondaryButton())
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
                Text("Or type below to ask the agent anything about this project. Type / for commands.")
                    .font(.system(size: 12.5 * Theme.scale)).foregroundStyle(Theme.faint)
            }
            .padding(24).frame(maxWidth: 640, alignment: .leading).frame(maxWidth: .infinity)
        }
    }
}

/// A suggestion the review can make from the record itself, when the agent left none.
func Review_hasSuggestion(_ c: Candidate) -> Bool { ReviewSheet.suggestion(for: c) != nil }


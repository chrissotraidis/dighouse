import SwiftUI

/// What a project shows before a chat is opened: its question, how far the search has got, what the last run
/// found, and the next step explained for someone new to archaeology.
struct ProjectOverview: View {
    @EnvironmentObject var app: AppState
    @EnvironmentObject var store: ProjectStore

    private struct Stage: Identifiable {
        let id: String, title: String, plain: String
        let done: Bool, detail: String
    }

    private var question: String {
        guard let root = store.current?.path, let text = try? String(contentsOfFile: root + "/PROJECT.md", encoding: .utf8),
              let range = text.range(of: "## Question") else { return "" }
        return text[range.upperBound...].split(separator: "\n").first { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
            .map { String($0).trimmingCharacters(in: .whitespaces) } ?? ""
    }

    /// The newest run summary's first paragraph under "What was done", or its first lines.
    private var lastRun: (date: String, text: String)? {
        guard let root = store.current?.path,
              let files = try? FileManager.default.contentsOfDirectory(atPath: root + "/notes") else { return nil }
        guard let newest = files.filter({ $0.contains("-run-") && $0.hasSuffix(".md") }).sorted().last,
              let text = try? String(contentsOfFile: root + "/notes/" + newest, encoding: .utf8) else { return nil }
        let lines = text.split(separator: "\n").map(String.init).filter { !$0.hasPrefix("#") && !$0.trimmingCharacters(in: .whitespaces).isEmpty }
        let body = lines.prefix(4).map { $0.hasPrefix("- ") ? String($0.dropFirst(2)) : $0 }.joined(separator: " ")
        let date = newest.replacingOccurrences(of: ".md", with: "").replacingOccurrences(of: "-run-", with: " at ")
        return (date, String(body.prefix(520)) + (body.count > 520 ? "…" : ""))
    }

    private var stages: [Stage] {
        let s = store.status, all = store.candidates
        let decided = all.filter { !["flagged", "ground_confirmed"].contains($0.status) }.count
        let checked = all.filter { $0.checks["section"] != nil && $0.checks["modern"] != nil }.count
        let second = all.filter { $0.checks["second_look"] != nil }.count
        let sourced = all.filter { !$0.sources.isEmpty }.count
        return [
            Stage(id: "terrain", title: "Bare ground", plain: "Download the laser scans and strip the trees away.",
                  done: !store.terrains.isEmpty, detail: store.terrains.isEmpty ? "Not yet" : "\(store.terrains.count) terrain, \(s.tiles) tiles"),
            Stage(id: "screen", title: "Screening", plain: "Look at every tile for shapes people built.",
                  done: s.tiles > 0 && s.unscreened == 0, detail: s.tiles == 0 ? "Waiting for terrain" : "\(s.screened) of \(s.readable) tiles, \(s.candidates) flagged"),
            Stage(id: "check", title: "Checks", plain: "Slice through each flag, and look for roads and buildings.",
                  done: !all.isEmpty && checked == all.count, detail: all.isEmpty ? "Waiting for flags" : "\(checked) of \(all.count) checked"),
            Stage(id: "second", title: "Second opinion", plain: "A different AI model looks at each flag on its own.",
                  done: !all.isEmpty && second == all.count, detail: all.isEmpty ? "Waiting for flags" : "\(second) of \(all.count)"),
            Stage(id: "prior", title: "What is published", plain: "Search the literature to see if each find is already known.",
                  done: !all.isEmpty && sourced == all.count, detail: all.isEmpty ? "Waiting for flags" : "\(sourced) of \(all.count) searched"),
            Stage(id: "decide", title: "Your decisions", plain: "You decide what each one is.",
                  done: !all.isEmpty && decided == all.count, detail: all.isEmpty ? "Waiting for flags" : "\(decided) of \(all.count) decided"),
        ]
    }

    /// The next thing to do, in plain words, with the button that does it.
    private var next: (title: String, why: String, action: () -> Void, label: String)? {
        let open = store.candidates.filter { $0.status == "flagged" || $0.status == "ground_confirmed" }
        if store.terrains.isEmpty, let flow = ToolGuide.workflows.first(where: { $0.id == "full" }) {
            return ("Run the search", "The agent fetches the open lidar for this area, looks at every tile, checks what it flags and searches what is published. It stops for you at the decisions. It takes about 10 to 20 minutes.", { app.run(flow) }, "Run the whole search")
        }
        if !open.isEmpty, open.allSatisfy({ $0.suggestion != nil || Review_hasSuggestion($0) }) {
            return ("Decide what the finds are", "The agent has looked at \(open.count) find\(open.count == 1 ? "" : "s") and suggests what each one is, with its reason. Look at the pictures and agree or change each suggestion.", { app.reviewing = true }, "Review \(open.count)")
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
            return (flow.title, why[flow.id] ?? flow.summary, { app.run(flow) }, flow.title)
        }
        if !open.isEmpty { return ("Decide what the finds are", "Look at each find and decide what it is.", { app.reviewing = true }, "Review \(open.count)") }
        return nil
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(store.current?.name ?? "").font(.system(size: 26, weight: .bold))
                    if !question.isEmpty {
                        Text(question).font(.system(size: 15)).foregroundStyle(Theme.text.opacity(0.8)).fixedSize(horizontal: false, vertical: true)
                    }
                }
                if let next {
                    HStack(alignment: .center, spacing: 14) {
                        IconTile(name: "arrow.right.circle", size: 38)
                        VStack(alignment: .leading, spacing: 3) {
                            Text("Next: \(next.title)").font(.system(size: 15, weight: .semibold))
                            Text(next.why).font(.system(size: 13)).foregroundStyle(Theme.dim).fixedSize(horizontal: false, vertical: true)
                        }
                        Spacer(minLength: 12)
                        Button(next.label, action: next.action).buttonStyle(PrimaryButton())
                    }
                    .padding(16).frame(maxWidth: .infinity, alignment: .leading)
                    .background(RoundedRectangle(cornerRadius: 14).fill(Theme.tan.opacity(0.08)))
                    .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(Theme.tan.opacity(0.3)))
                }
                VStack(alignment: .leading, spacing: 8) {
                    Text("How far the search has got").font(.system(size: 14, weight: .semibold))
                    VStack(spacing: 0) {
                        ForEach(Array(stages.enumerated()), id: \.element.id) { i, stage in
                            if i > 0 { Hairline() }
                            HStack(spacing: 12) {
                                Image(systemName: stage.done ? "checkmark.circle.fill" : "circle")
                                    .font(.system(size: 15)).foregroundStyle(stage.done ? Theme.green : Theme.faint)
                                VStack(alignment: .leading, spacing: 1) {
                                    Text(stage.title).font(.system(size: 13.5, weight: .medium))
                                    Text(stage.plain).font(.system(size: 12)).foregroundStyle(Theme.faint)
                                }
                                Spacer(minLength: 8)
                                Text(stage.detail).font(.system(size: 12.5)).foregroundStyle(Theme.dim)
                            }
                            .padding(.horizontal, 14).padding(.vertical, 9)
                        }
                    }
                    .panel()
                }
                if let lastRun {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("The last run, \(lastRun.date)").font(.system(size: 14, weight: .semibold))
                        Text(lastRun.text).font(.system(size: 13)).foregroundStyle(Theme.dim).lineSpacing(2).fixedSize(horizontal: false, vertical: true)
                        Button("Read the notes") { app.tab = .notes; if app.layout == .chat { app.layout = .split } }.buttonStyle(SecondaryButton())
                    }
                }
                Text("Or type below to ask the agent anything about this project. Type / for commands.")
                    .font(.system(size: 12.5)).foregroundStyle(Theme.faint)
            }
            .padding(24).frame(maxWidth: 640, alignment: .leading).frame(maxWidth: .infinity)
        }
    }
}

/// A suggestion the review can make from the record itself, when the agent left none.
func Review_hasSuggestion(_ c: Candidate) -> Bool { ReviewSheet.suggestion(for: c) != nil }


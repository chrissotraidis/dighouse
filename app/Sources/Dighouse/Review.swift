import SwiftUI

/// Deciding, one candidate at a time: the pictures, the checks and the sources side by side, with the decisions on keys.
struct ReviewSheet: View {
    @EnvironmentObject var app: AppState
    @EnvironmentObject var store: ProjectStore
    @Environment(\.dismiss) private var dismiss
    /// The candidates to go through, fixed when the review opens so a decision does not reorder them.
    @State private var queue: [String] = []
    @State private var index = 0
    @State private var choice: String?
    @State private var reason = ""
    @State private var busy = false
    @State private var problem: String?
    @State private var decided = 0
    @FocusState private var typing: Bool

    static let decisions: [(key: String, status: String, title: String, prompt: String)] = [
        ("1", "already_published", "Already published", "Where is it published?"),
        ("2", "natural", "Natural feature", "What makes it natural?"),
        ("3", "modern", "Modern feature", "What modern feature is it?"),
        ("4", "no_match_in_sources_read", "No match in sources read", "Your reason"),
    ]

    /// What to suggest for a candidate: the agent's own suggestion, or else a read source whose finding names it.
    static func suggestion(for c: Candidate) -> (status: String, reason: String, by: String)? {
        if let s = c.suggestion { return s }
        if let named = c.sources.first(where: { $0.status == "read" && $0.finding.contains(c.id) }) {
            return ("already_published", named.title, "the sources on its record")
        }
        if (c.checks["modern"] as? JSON)?["likely_modern"] as? Bool == true, c.sources.allSatisfy({ $0.status != "read" }),
           let summary = (c.checks["modern"] as? JSON)?["summary"] as? String {
            return ("modern", summary, "the map check")
        }
        return nil
    }

    private var current: Candidate? {
        guard queue.indices.contains(index) else { return nil }
        return store.candidates.first { $0.id == queue[index] }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Hairline()
            if let c = current {
                ScrollView { content(c).padding(22) }
                Hairline()
                footer(c).padding(.horizontal, 22).padding(.vertical, 14)
            } else {
                VStack(spacing: 10) {
                    EmptyDrawing(name: "dig.brush", size: 76)
                    Text(decided > 0 ? "Reviewed. \(decided) decision\(decided == 1 ? "" : "s") written into the records." : "Nothing left to review.")
                        .font(.system(size: 16 * Theme.scale, weight: .semibold))
                    Button("Close") { dismiss() }.buttonStyle(PrimaryButton()).keyboardShortcut(.defaultAction)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .frame(width: min(900, app.windowSize.width - 40), height: min(720, app.windowSize.height - 40))
        .background(Theme.bg).foregroundStyle(Theme.text)
        .onAppear {
            let open = store.candidates.filter { $0.status == "flagged" || $0.status == "ground_confirmed" }
            queue = (open.isEmpty ? store.candidates : open).map(\.id)
            if let picked = store.selectedCandidate, let i = queue.firstIndex(of: picked) { index = i }
            prefill()
        }
        .onChange(of: index) { _, _ in prefill() }
    }

    private var header: some View {
        HStack(spacing: 12) {
            Text("Review").font(.system(size: 17 * Theme.scale, weight: .semibold))
            if !queue.isEmpty, current != nil {
                Text("\(index + 1) of \(queue.count)").font(.system(size: 13 * Theme.scale)).foregroundStyle(Theme.dim)
            }
            Spacer()
            if store.candidates.contains(where: { $0.suggestion == nil && ($0.status == "flagged" || $0.status == "ground_confirmed") }),
               let flow = ToolGuide.workflows.first(where: { $0.id == "decide" }) {
                Button { dismiss(); app.run(flow) } label: { Label("Prepare", glyph: "dig.brush") }
                    .buttonStyle(SecondaryButton())
                    .help("Starts a chat in which the agent reads each record and suggests a decision and its reason. Uses your model.")
            }
            if let flow = ToolGuide.workflows.first(where: { $0.id == "second" }) {
                let state = app.state(of: flow)
                Button { app.run(flow) } label: {
                    Label(app.secondLookBusy != nil ? "Asking…" : "Second looks", systemImage: "person.2")
                }
                .buttonStyle(SecondaryButton()).disabled(!state.ready || app.secondLookBusy != nil)
                .help(state.ready ? "Ask your second-look model about every candidate that has no second look yet (\(state.note)). It sees the tile but not the first opinion."
                                  : state.note)
            }
            Button("Done") { dismiss() }.buttonStyle(SecondaryButton()).keyboardShortcut(choice == nil ? .cancelAction : nil)
        }
        .padding(.horizontal, 22).padding(.vertical, 14)
    }

    @ViewBuilder private func content(_ c: Candidate) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            if let step = app.tutorialStep, step.target == .record {
                // The tutorial's last step happens in here, so its sentence comes along.
                HStack(spacing: 10) {
                    Glyph(name: "dig.trowel", size: 14 * Theme.scale).foregroundStyle(Theme.tan)
                    Text("First project · Step \(step.number) of \(Tutorial.count). ").fontWeight(.semibold).foregroundColor(Theme.tan)
                        + Text(choice == nil ? "Look at the pictures and the checks, then pick what you think the find is. Serpent Mound is in every textbook, so Already published fits."
                               : step.words + " Press Record.")
                }
                .font(.system(size: 13 * Theme.scale)).fixedSize(horizontal: false, vertical: true)
                .padding(12).frame(maxWidth: .infinity, alignment: .leading)
                .background(RoundedRectangle(cornerRadius: 10).fill(Theme.tan.opacity(0.1)))
            }
            HStack(spacing: 10) {
                Text("\(c.id) \(c.name)").font(.system(size: 22 * Theme.scale, weight: .bold)).lineLimit(2)
                Badge(text: c.statusLabel, color: c.statusColor)
            }
            if let sug = Self.suggestion(for: c), let d = Self.decisions.first(where: { $0.status == sug.status }) {
                HStack(alignment: .top, spacing: 10) {
                    Glyph(name: "dig.brush", size: 14 * Theme.scale).foregroundStyle(Theme.tan).padding(.top, 1)
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Suggested: \(d.title.lowercased())").font(.system(size: 13.5 * Theme.scale, weight: .semibold))
                        Text(sug.reason).font(.system(size: 13 * Theme.scale)).foregroundStyle(Theme.dim).fixedSize(horizontal: false, vertical: true)
                        Text("From \(sug.by). Check it against the pictures and sources; the decision is yours.")
                            .font(.system(size: 11.5 * Theme.scale)).foregroundStyle(Theme.faint)
                    }
                }
                .padding(12).frame(maxWidth: .infinity, alignment: .leading)
                .background(RoundedRectangle(cornerRadius: 10).fill(Theme.tan.opacity(0.08)))
                .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(Theme.tan.opacity(0.25)))
            }
            HStack(alignment: .top, spacing: 14) {
                picture(c.relief, "Bare-ground relief")
                picture(c.section, "Section through the feature")
            }
            let stacked = app.windowSize.width < 860
            (stacked ? AnyLayout(VStackLayout(alignment: .leading, spacing: 18)) : AnyLayout(HStackLayout(alignment: .top, spacing: 18))) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Checks").font(.system(size: 13.5 * Theme.scale, weight: .semibold))
                    checks(c)
                }
                .frame(width: stacked ? nil : 330, alignment: .leading)
                VStack(alignment: .leading, spacing: 8) {
                    Text("What the agent saw").font(.system(size: 13.5 * Theme.scale, weight: .semibold))
                    ForEach(c.evidence.prefix(3), id: \.self) { line in
                        Text(line).font(.system(size: 12.5 * Theme.scale)).foregroundStyle(Theme.dim).fixedSize(horizontal: false, vertical: true)
                    }
                    let read = c.sources.filter { $0.status == "read" }
                    Text("Sources: \(read.count) read, \(c.sources.filter { $0.status == "could_not_open" }.count) could not be opened")
                        .font(.system(size: 13.5 * Theme.scale, weight: .semibold)).padding(.top, 4)
                    ForEach(read.prefix(3)) { s in
                        VStack(alignment: .leading, spacing: 2) {
                            Text(s.title).font(.system(size: 12.5 * Theme.scale, weight: .medium)).lineLimit(2)
                            Text(s.finding).font(.system(size: 12 * Theme.scale)).foregroundStyle(Theme.dim).lineLimit(4)
                        }
                    }
                }
            }
            if !c.decisions.isEmpty {
                Text("Decided before: " + c.decisions.joined(separator: "; ")).font(.system(size: 12 * Theme.scale)).foregroundStyle(Theme.faint)
            }
        }
        .textSelection(.enabled)
    }

    private func checks(_ c: Candidate) -> some View {
        let cut = c.checks["section"] as? JSON, look = c.checks["second_look"] as? JSON, modern = c.checks["modern"] as? JSON
        let read = c.sources.filter { $0.status == "read" }.count
        let rows: [(Bool?, String)] = [
            (cut?["in_ground"] as? Bool, cut.map { "In the ground: \($0["feature_height_m"] ?? "?") m high" } ?? "No section yet"),
            (look?["agrees"] as? Bool, look.map { ($0["agrees"] as? Bool == true ? "A second model agrees" : "A second model disagrees") + " (\($0["model"] as? String ?? ""))" } ?? "No second look yet"),
            (modern.map { $0["likely_modern"] as? Bool != true }, modern == nil ? "Modern features not checked" : (modern?["likely_modern"] as? Bool == true ? "Modern features mapped close by" : "No modern feature on it")),
            (c.sources.isEmpty ? nil : read > 0, c.sources.isEmpty ? "Literature not searched" : "\(read) source\(read == 1 ? "" : "s") read"),
        ]
        return VStack(alignment: .leading, spacing: 6) {
            ForEach(rows.indices, id: \.self) { i in
                HStack(spacing: 8) {
                    let done = rows[i].0
                    Image(systemName: done == true ? "checkmark.circle.fill" : done == false ? "exclamationmark.circle.fill" : "circle")
                        .foregroundStyle(done == true ? Theme.green : done == false ? Theme.amber : Theme.faint)
                    Text(rows[i].1).font(.system(size: 12.5 * Theme.scale)).foregroundStyle(Theme.dim).lineLimit(2)
                }
            }
        }
    }

    @ViewBuilder private func picture(_ path: String, _ caption: String) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            if let image = Images.load(path) {
                // A wide picture sits on its caption, not in the middle of the space the taller one needs.
                Image(nsImage: image).resizable().aspectRatio(contentMode: .fit).frame(maxHeight: 250, alignment: .bottomLeading)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            } else {
                RoundedRectangle(cornerRadius: 8).fill(Theme.side).frame(height: 160)
                    .overlay(Text("None yet").font(.system(size: 12 * Theme.scale)).foregroundStyle(Theme.faint))
            }
            Text(caption).font(.system(size: 11.5 * Theme.scale)).foregroundStyle(Theme.faint)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder private func footer(_ c: Candidate) -> some View {
        if let choice, let d = Self.decisions.first(where: { $0.status == choice }) {
            VStack(alignment: .leading, spacing: 8) {
                Text(Self.suggestion(for: c)?.status == d.status && reason == Self.suggestion(for: c)?.reason
                     ? "\(d.title), as suggested. Edit the reason if you need to." : "\(d.title): \(d.prompt)")
                    .font(.system(size: 13 * Theme.scale, weight: .medium))
                HStack(spacing: 8) {
                    TextField(d.prompt, text: $reason).field().focused($typing).onSubmit { record(c) }
                    Button("Other decision") { self.choice = nil; reason = "" }.buttonStyle(SecondaryButton())
                    Button("Record") { record(c) }.buttonStyle(PrimaryButton())
                        .disabled(busy || reason.trimmingCharacters(in: .whitespaces).isEmpty)
                        .coach(.record)
                }
                Text("Recorded as decided by \(app.userName). Return records it and moves to the next; Escape picks another decision.")
                    .font(.system(size: 11.5 * Theme.scale)).foregroundStyle(Theme.faint)
                if let problem { Text(problem).font(.system(size: 12.5 * Theme.scale)).foregroundStyle(Theme.amber) }
            }
            .onAppear { typing = true }
            .background(Button("") { self.choice = nil; reason = "" }.keyboardShortcut(.cancelAction).hidden())
        } else {
            HStack(spacing: 8) {
                ForEach(Self.decisions, id: \.status) { d in
                    Button {
                        choice = d.status
                    } label: {
                        HStack(spacing: 6) {
                            Text(d.key).font(.system(size: 11 * Theme.scale, weight: .bold, design: .monospaced)).foregroundStyle(Theme.faint)
                                .frame(width: 18, height: 18).background(RoundedRectangle(cornerRadius: 4).strokeBorder(Theme.line))
                            Text(d.title)
                        }
                    }
                    .buttonStyle(SecondaryButton())
                    .keyboardShortcut(KeyEquivalent(Character(d.key)), modifiers: [])
                    .coach(d.status == "already_published" ? .record : nil)
                }
                Spacer()
                Button("Previous") { move(-1) }.buttonStyle(SecondaryButton()).disabled(index == 0)
                    .keyboardShortcut(.leftArrow, modifiers: [])
                Button("Skip") { move(1) }.buttonStyle(SecondaryButton())
                    .keyboardShortcut(.rightArrow, modifiers: [])
            }
        }
    }

    private func move(_ step: Int) {
        index = min(max(index + step, 0), queue.count)
        choice = nil
        reason = ""
        problem = nil
        prefill()
    }

    /// Start from the suggestion, so a right one needs only Return.
    private func prefill() {
        guard let c = current, let sug = Self.suggestion(for: c) else { return }
        choice = sug.status
        reason = sug.reason
    }

    private func record(_ c: Candidate) {
        guard let choice, !reason.trimmingCharacters(in: .whitespaces).isEmpty, !busy else { return }
        busy = true
        Task { @MainActor in
            defer { busy = false }
            do {
                try await app.decide(c, status: choice, reason: reason.trimmingCharacters(in: .whitespaces))
                decided += 1
                move(1)
            } catch {
                problem = error.localizedDescription
            }
        }
    }
}


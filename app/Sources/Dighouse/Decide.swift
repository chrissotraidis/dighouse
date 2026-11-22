import SwiftUI

/// Deciding what the finds are, in one place: the ones that need a person, one at a time; the routine ones, agreed with
/// together from their pictures; and what was decided, with Undo. Every decision carries the person's name and a reason.
struct DecideView: View {
    @EnvironmentObject var app: AppState
    @EnvironmentObject var store: ProjectStore
    @Environment(\.dismiss) private var dismiss

    enum Step: Int, CaseIterable { case needs, bulk, done }

    /// One decision made here, so it can be shown under Done and taken back.
    struct Made: Identifiable {
        let id: String
        let name: String
        let status: String
        var undone = false
    }

    static let choices: [(key: Character, status: String, title: String, prompt: String)] = [
        ("n", "natural", "Natural", "What makes it natural?"),
        ("m", "modern", "Modern", "What modern feature is it?"),
        ("p", "already_published", "Published", "Where is it published?"),
        ("r", "no_match_in_sources_read", "Worth reporting", "Why is it worth reporting?"),
    ]

    @State private var step = Step.needs
    /// Fixed when Decide opens, so a decision does not reorder what is left.
    @State private var needs: [String] = []
    @State private var bulk: [String] = []
    @State private var index = 0
    @State private var unticked = Set<String>()
    @State private var made: [Made] = []
    /// A decision other than the suggestion, waiting for its reason.
    @State private var changing: String?
    @State private var reason = ""
    @State private var busy = false
    @State private var progress = ""
    @State private var problem: String?
    @FocusState private var typing: Bool

    private func find(_ id: String) -> Candidate? { store.candidates.first { $0.id == id } }
    private var current: Candidate? { needs.indices.contains(index) ? find(needs[index]) : nil }
    private var needsLeft: Int { needs.compactMap(find).filter(\.waiting).count }
    private var bulkLeft: [Candidate] { bulk.compactMap(find).filter(\.waiting) }
    private var chosen: [Candidate] { bulkLeft.filter { !unticked.contains($0.id) } }

    var body: some View {
        VStack(spacing: 0) {
            header
            Hairline()
            Group {
                if store.isBlindTest {
                    message("A blind test is scored against the published features, so none of its finds needs a decision.")
                } else {
                    switch step {
                    case .needs: needsStep
                    case .bulk: bulkStep
                    case .done: doneStep
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(width: max(640, app.windowSize.width - 40), height: max(520, app.windowSize.height - 40))
        .background(Theme.bg).foregroundStyle(Theme.text)
        .onAppear(perform: start)
        // While a reason is being typed, Escape takes back the choice; it does not close Decide.
        .interactiveDismissDisabled(changing != nil)
    }

    // MARK: - Opening

    private func start() {
        let order: (Candidate, Candidate) -> Bool = { ($0.group.rawValue, $0.id) < ($1.group.rawValue, $1.id) }
        let waiting = store.candidates.filter { $0.waiting && $0.group != .layer }.sorted(by: order)
        // The first project's tutorial decides its find on its own page, as the tutorial's words say.
        let tutorial = app.tutorialOn && app.tutorialProject == store.current?.path
        needs = waiting.filter { tutorial || !$0.group.confirmable }.map(\.id)
        bulk = tutorial ? [] : waiting.filter { $0.group.confirmable }.map(\.id)
        if let focus = app.decideFocus {
            needs.removeAll { $0 == focus }
            bulk.removeAll { $0 == focus }
            needs.insert(focus, at: 0)
            app.decideFocus = nil
        }
        index = 0
        step = !needs.isEmpty ? .needs : !bulk.isEmpty ? .bulk : .done
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 14) {
            Text("Decide").font(.system(size: 17 * Theme.scale, weight: .semibold))
            if !store.isBlindTest {
                HStack(spacing: 4) {
                    stepButton(.needs, "Needs you", needsLeft)
                    stepButton(.bulk, "Agree in bulk", bulkLeft.count)
                    stepButton(.done, "Done", made.filter { !$0.undone }.count)
                }
            }
            Spacer()
            if let flow = ToolGuide.workflows.first(where: { $0.id == "second" }) {
                let state = app.state(of: flow)
                Button { app.run(flow) } label: {
                    Label(app.secondLookBusy != nil ? "Asking…" : "Second opinions", systemImage: "person.2")
                }
                .buttonStyle(SecondaryButton()).disabled(!state.ready || app.secondLookBusy != nil)
                .help(state.ready ? "A different model looks at every find that has no second opinion yet (\(state.note))."
                                  : (state.note.isEmpty ? "Every find has a second opinion." : state.note))
            }
            Button("Close") { dismiss() }.buttonStyle(SecondaryButton())
                .keyboardShortcut(changing == nil ? .cancelAction : nil)
        }
        .padding(.horizontal, 22).padding(.vertical, 12)
    }

    private func stepButton(_ s: Step, _ title: String, _ count: Int) -> some View {
        Button { step = s; changing = nil } label: {
            Text("\(title) · \(count)").font(.system(size: 13 * Theme.scale, weight: step == s ? .semibold : .regular))
                .padding(.horizontal, 10).padding(.vertical, 5)
                .background(Capsule().fill(step == s ? Theme.ink.opacity(0.12) : .clear))
                .foregroundStyle(step == s ? Theme.text : Theme.dim)
        }
        .buttonStyle(.plain)
        .help(s == .needs ? "Leads, finds where the agent and the second model disagree, and finds with no suggestion"
              : s == .bulk ? "Finds the agent calls modern, natural or already published, to agree with from their pictures"
              : "What you decided here, with Undo")
    }

    private func message(_ text: String, button: (String, () -> Void)? = nil) -> some View {
        VStack(spacing: 12) {
            EmptyDrawing(name: "dig.brush", size: 76)
            Text(text).font(.system(size: 15 * Theme.scale, weight: .semibold)).multilineTextAlignment(.center)
                .frame(maxWidth: 460)
            if let button { Button(button.0, action: button.1).buttonStyle(PrimaryButton()).keyboardShortcut(.defaultAction) }
        }
    }

    // MARK: - Needs you

    @ViewBuilder private var needsStep: some View {
        if let c = current {
            VStack(spacing: 0) {
                ScrollView { FindCard(candidate: c, position: "\(index + 1) of \(needs.count)").padding(22).arrives() }.id(c.id)
                Hairline()
                decisionBar(c).padding(.horizontal, 22).padding(.vertical, 12)
            }
            // Draw the next find's views while this one is looked at.
            .task(id: c.id) {
                if let next = needs.dropFirst(index + 1).compactMap(find).first(where: \.waiting) { await app.ensureViews(next) }
            }
        } else {
            VStack(spacing: 16) {
                if !bulkLeft.isEmpty {
                    message("Nothing more needs you one at a time. \(bulkLeft.count) routine find\(bulkLeft.count == 1 ? "" : "s") to agree with.",
                            button: ("Agree in bulk", { step = .bulk }))
                } else {
                    message(made.isEmpty ? "Nothing waits for a decision." : "Every find here is decided.", button: ("Close", { dismiss() }))
                }
                layerOffer
            }
        }
    }

    /// Measured rises kept on the map that the second model calls built, one press away.
    @ViewBuilder private var layerOffer: some View {
        let built = store.candidates.filter { $0.group == .layer && $0.secondSaysBuilt == true && !needs.contains($0.id) }
        let kept = store.candidates.filter { $0.group == .layer }.count
        if kept > 0 {
            VStack(spacing: 8) {
                Text("\(kept) measured rise\(kept == 1 ? " is" : "s are") kept on the map: the second model did not call \(kept == 1 ? "it" : "them") built, or the shape ranks in the lower half here.")
                    .font(.system(size: 12.5 * Theme.scale)).foregroundStyle(Theme.dim).multilineTextAlignment(.center).frame(maxWidth: 460)
                if !built.isEmpty {
                    Button("Look at the \(built.count) the second model calls built") {
                        needs.append(contentsOf: built.map(\.id))
                        index = needs.firstIndex(of: built[0].id) ?? index
                        step = .needs
                    }
                    .buttonStyle(SecondaryButton())
                }
            }
        }
    }

    @ViewBuilder private func decisionBar(_ c: Candidate) -> some View {
        let suggestion = c.likely
        if let changing, let d = Self.choices.first(where: { $0.status == changing }) {
            VStack(alignment: .leading, spacing: 8) {
                Text("\(d.title): \(d.prompt)").font(.system(size: 13 * Theme.scale, weight: .medium))
                HStack(spacing: 8) {
                    TextField(d.prompt, text: $reason).field().focused($typing).onSubmit { record(c, d.status, reason) }
                        .onExitCommand { self.changing = nil; reason = "" }
                    Button("Cancel") { self.changing = nil; reason = "" }.buttonStyle(SecondaryButton()).keyboardShortcut(.cancelAction)
                    Button("Record") { record(c, d.status, reason) }.buttonStyle(PrimaryButton())
                        .disabled(busy || reason.trimmingCharacters(in: .whitespaces).isEmpty).coach(.record)
                }
                if let open = openItems(c, d.status) {
                    Text(open).font(.system(size: 11.5 * Theme.scale)).foregroundStyle(Theme.amber).fixedSize(horizontal: false, vertical: true)
                }
                footnote
            }
            // Focus once the field is on screen; set straight away it is lost in a sheet.
            .onAppear { DispatchQueue.main.async { typing = true } }
        } else {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    if let s = suggestion, let d = Self.choices.first(where: { $0.status == s.status }) {
                        Button { record(c, s.status, s.reason) } label: {
                            Label("Agree: \(d.title.lowercased())", systemImage: "return")
                        }
                        .buttonStyle(PrimaryButton()).keyboardShortcut(.defaultAction).disabled(busy)
                        .help(openItems(c, s.status) ?? "Records the suggestion and its reason, with your name. Return.")
                        .coach(.record)
                    }
                    ForEach(Self.choices.filter { $0.status != suggestion?.status }, id: \.status) { d in
                        Button { reason = ""; changing = d.status } label: {
                            HStack(spacing: 6) { keyCap(String(d.key).uppercased()); Text(d.title) }
                        }
                        .buttonStyle(SecondaryButton())
                        .keyboardShortcut(KeyEquivalent(d.key), modifiers: [])
                        .disabled(busy)
                        .help(openItems(c, d.status) ?? (d.status == "no_match_in_sources_read"
                              ? "Marks it as having no match in the sources read, ready for a report you send."
                              : "Pick this, then give your reason."))
                    }
                    Spacer()
                    Button { move(-1) } label: { Image(systemName: "chevron.left") }.buttonStyle(SecondaryButton())
                        .keyboardShortcut(.leftArrow, modifiers: []).disabled(index == 0).help("The previous find")
                    Button { move(1) } label: { HStack(spacing: 6) { keyCap("S"); Text("Skip") } }.buttonStyle(SecondaryButton())
                        .keyboardShortcut("s", modifiers: []).help("Leave it for later")
                    if made.contains(where: { !$0.undone }) {
                        Button("Undo") { undoLast() }.buttonStyle(SecondaryButton())
                            .keyboardShortcut("z", modifiers: .command).disabled(busy).help("Take back your last decision. ⌘Z")
                    }
                }
                if let s = suggestion, let open = openItems(c, s.status) {
                    Text(open).font(.system(size: 11.5 * Theme.scale)).foregroundStyle(Theme.amber).fixedSize(horizontal: false, vertical: true)
                }
                footnote
            }
        }
    }

    private var footnote: some View {
        Group {
            if let problem {
                Text(problem).foregroundStyle(Theme.amber)
            } else {
                Text(busy ? "Recording…" : "Recorded as decided by \(app.userName), with the reason. The agent only suggests.")
                    .foregroundStyle(Theme.faint)
            }
        }
        .font(.system(size: 11.5 * Theme.scale)).lineLimit(2)
    }

    private func keyCap(_ key: String) -> some View {
        Text(key).font(.system(size: 11 * Theme.scale, weight: .bold, design: .monospaced)).foregroundStyle(Theme.faint)
            .frame(width: 18, height: 18).background(RoundedRectangle(cornerRadius: 4).strokeBorder(Theme.line))
    }

    /// What is still open on the record for this decision (ledger.blockers). A person may decide anyway; the tools
    /// write these beside the decision.
    private func openItems(_ c: Candidate, _ status: String) -> String? {
        guard status == "no_match_in_sources_read" else { return nil }
        let open = c.reportBlockers
        return open.isEmpty ? nil : "Still open, and written beside your decision: " + open.joined(separator: " ")
    }

    private func move(_ by: Int) {
        index = min(max(index + by, 0), needs.count)
        changing = nil
        reason = ""
        problem = nil
    }

    private func record(_ c: Candidate, _ status: String, _ why: String) {
        let why = why.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !why.isEmpty, !busy else { return }
        busy = true
        problem = nil
        Task { @MainActor in
            defer { busy = false }
            do {
                try await app.decide(c, status: status, reason: why)
                made.append(Made(id: c.id, name: c.name, status: status))
                move(1)
                if index >= needs.count, !bulkLeft.isEmpty { step = .bulk }
            } catch {
                problem = error.localizedDescription
            }
        }
    }

    private func undoLast() {
        guard let i = made.lastIndex(where: { !$0.undone }) else { return }
        undo(i)
    }

    private func undo(_ i: Int) {
        let m = made[i]
        busy = true
        Task { @MainActor in
            defer { busy = false }
            do {
                try await app.undoDecision(m.id)
                made[i].undone = true
                // It goes back where a person decides it alone, at the front if it was decided there.
                bulk.removeAll { $0 == m.id }
                if let at = needs.firstIndex(of: m.id) { index = at } else { needs.insert(m.id, at: min(index, needs.count)) }
                changing = nil
            } catch {
                problem = error.localizedDescription
            }
        }
    }

    // MARK: - Agree in bulk

    @ViewBuilder private var bulkStep: some View {
        if bulkLeft.isEmpty {
            message(needsLeft > 0 ? "Nothing routine left. \(needsLeft) find\(needsLeft == 1 ? "" : "s") need\(needsLeft == 1 ? "s" : "") you one at a time."
                                  : "Nothing routine left to agree with.",
                    button: needsLeft > 0 ? ("Needs you", { step = .needs; index = needs.firstIndex { find($0)?.waiting == true } ?? 0 })
                                          : ("Close", { dismiss() }))
        } else {
            VStack(spacing: 0) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        Text("Each picture is \(Int(ProjectStore.closeMetres)) m across, with the find ringed. Untick any that look wrong; they move to Needs you. The rest are recorded as suggested, each with its own reason.")
                            .font(.system(size: 13 * Theme.scale)).foregroundStyle(Theme.dim).fixedSize(horizontal: false, vertical: true)
                        ForEach(["already_published", "modern", "natural"], id: \.self) { status in
                            let items = bulkLeft.filter { $0.likely?.status == status }
                            if !items.isEmpty {
                                VStack(alignment: .leading, spacing: 10) {
                                    Text("\(Candidate.labels[status] ?? status) · \(items.count)")
                                        .font(.system(size: 13.5 * Theme.scale, weight: .semibold))
                                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 168, maximum: 240), spacing: 12)], alignment: .leading, spacing: 12) {
                                        ForEach(items) { c in tile(c) }
                                    }
                                }
                            }
                        }
                    }
                    .padding(22)
                }
                Hairline()
                HStack(spacing: 10) {
                    Button(unticked.isEmpty ? "Untick all" : "Tick all") {
                        unticked = unticked.isEmpty ? Set(bulkLeft.map(\.id)) : []
                    }
                    .buttonStyle(SecondaryButton()).disabled(busy)
                    Text(busy ? progress : problem ?? "Recorded as decided by \(app.userName). \(unticked.count) unticked will move to Needs you.")
                        .font(.system(size: 11.5 * Theme.scale)).foregroundStyle(problem == nil ? Theme.faint : Theme.amber).lineLimit(2)
                    Spacer()
                    Button(chosen.isEmpty ? "Move \(unticked.count) to Needs you" : "Agree with \(chosen.count)") { agreeInBulk() }
                        .buttonStyle(PrimaryButton()).keyboardShortcut(.defaultAction).disabled(busy || bulkLeft.isEmpty)
                }
                .padding(.horizontal, 22).padding(.vertical, 12)
            }
        }
    }

    private func tile(_ c: Candidate) -> some View {
        let on = !unticked.contains(c.id)
        return Button { if on { unticked.insert(c.id) } else { unticked.remove(c.id) } } label: {
            VStack(alignment: .leading, spacing: 6) {
                ZStack(alignment: .topLeading) {
                    Group {
                        if let image = Images.crop(c.relief, x: c.x, y: c.y, side: store.closeSide(c)) {
                            Image(nsImage: image).resizable().aspectRatio(contentMode: .fill)
                        } else {
                            Theme.side.overlay(Text("No picture").font(.system(size: 11 * Theme.scale)).foregroundStyle(Theme.faint))
                        }
                    }
                    .frame(height: 128).frame(maxWidth: .infinity).clipped()
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    Image(systemName: on ? "checkmark.square.fill" : "square")
                        .font(.system(size: 16 * Theme.scale)).foregroundStyle(on ? Theme.accent : Theme.faint)
                        .padding(5).background(Circle().fill(Theme.bg.opacity(0.7))).padding(5)
                }
                Text("\(c.id) \(c.name)").font(.system(size: 12 * Theme.scale, weight: .medium)).lineLimit(1)
                Text(c.likely?.reason ?? "").font(.system(size: 11.5 * Theme.scale)).foregroundStyle(Theme.dim).lineLimit(2)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(8)
            .background(RoundedRectangle(cornerRadius: 10).fill(Theme.raised))
            .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(on ? Theme.line : Theme.amber.opacity(0.6)))
            .opacity(on ? 1 : 0.55)
        }
        .buttonStyle(.plain)
        .help(on ? "Ticked: agree that it is \((Candidate.labels[c.likely?.status ?? ""] ?? "").lowercased()). Press to untick."
                 : "Unticked: it will move to Needs you.")
        .contextMenu {
            Button("Look at it closer") { moveToNeeds([c.id]); step = .needs; index = needs.firstIndex(of: c.id) ?? 0 }
        }
        .accessibilityLabel("\(c.id) \(c.name), suggested \((Candidate.labels[c.likely?.status ?? ""] ?? "").lowercased()), \(on ? "ticked" : "unticked")")
    }

    private func moveToNeeds(_ ids: [String]) {
        bulk.removeAll { ids.contains($0) }
        needs.append(contentsOf: ids.filter { !needs.contains($0) })
        unticked.subtract(ids)
    }

    private func agreeInBulk() {
        let agree = chosen
        let away = bulkLeft.filter { unticked.contains($0.id) }.map(\.id)
        guard !agree.isEmpty else { moveToNeeds(away); step = .needs; return }
        busy = true
        problem = nil
        progress = "Recording \(agree.count) decisions…"
        Task { @MainActor in
            defer { busy = false }
            do {
                try await app.decideMany(agree.compactMap { c in
                    c.likely.map { (c, $0.status, $0.reason + " (Agreed with the suggestion from \($0.by).)") }
                })
                made.append(contentsOf: agree.map { Made(id: $0.id, name: $0.name, status: $0.likely?.status ?? "") })
                moveToNeeds(away)
                step = needsLeft > 0 ? .needs : .done
                index = needs.firstIndex { find($0)?.waiting == true } ?? needs.count
            } catch {
                problem = error.localizedDescription
            }
        }
    }

    // MARK: - Done

    @ViewBuilder private var doneStep: some View {
        if made.isEmpty {
            message("Nothing decided yet.", button: needsLeft > 0 ? ("Needs you", { step = .needs }) : bulkLeft.isEmpty ? nil : ("Agree in bulk", { step = .bulk }))
        } else {
            VStack(spacing: 0) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        let kept = made.filter { !$0.undone }.count
                        Text("\(kept) decided here\(needsLeft + bulkLeft.count > 0 ? ", \(needsLeft + bulkLeft.count) still waiting" : "").")
                            .font(.system(size: 15 * Theme.scale, weight: .semibold)).padding(.bottom, 10)
                        ForEach(Array(made.enumerated()).reversed(), id: \.element.id) { i, m in
                            HStack(spacing: 10) {
                                Text("\(m.id) \(m.name)").font(.system(size: 13 * Theme.scale)).lineLimit(1)
                                Spacer()
                                Text(m.undone ? "Undone" : (Candidate.labels[m.status] ?? m.status))
                                    .font(.system(size: 12.5 * Theme.scale)).foregroundStyle(m.undone ? Theme.faint : Theme.dim)
                                if !m.undone {
                                    Button("Undo") { undo(i) }.buttonStyle(SecondaryButton()).disabled(busy)
                                }
                            }
                            .padding(.vertical, 6)
                            Hairline()
                        }
                    }
                    .padding(22).frame(maxWidth: 720, alignment: .leading).frame(maxWidth: .infinity)
                }
                layerOffer.padding(.bottom, 16)
                if let problem { Text(problem).font(.system(size: 12 * Theme.scale)).foregroundStyle(Theme.amber).padding(8) }
            }
        }
    }
}

/// One find, laid out to be read at a glance: what the agent and the second model say, the pictures, and the checks.
struct FindCard: View {
    @EnvironmentObject var app: AppState
    @EnvironmentObject var store: ProjectStore
    let candidate: Candidate
    var position = ""
    /// The view last chosen, kept from find to find and between launches.
    @AppStorage("decideView") private var view = "composite"
    @State private var drawn = 0

    static let views: [(style: String, title: String)] = [
        ("composite", "Composite"), ("relief_small", "Local relief"), ("sky_view", "Sky view"),
        ("hillshade", "Hillshade"), ("positive_openness", "Openness up"), ("negative_openness", "Openness down"),
    ]

    static func viewPath(_ c: Candidate, _ style: String) -> String {
        (c.folder as NSString).deletingLastPathComponent + "/data/views/\(c.id)-\(style).png"
    }

    var body: some View {
        let c = candidate
        VStack(alignment: .leading, spacing: 14) {
            if let step = app.tutorialStep, step.target == .record {
                Text("First project · Step \(step.number) of \(Tutorial.count). ").fontWeight(.semibold).foregroundColor(Theme.tan)
                    + Text("Look at the pictures and the checks, then agree or pick what you think the find is. Serpent Mound is in every textbook, so Published fits.")
            }
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text("\(c.id) \(c.name)").font(.system(size: 21 * Theme.scale, weight: .bold)).lineLimit(2)
                if c.waiting { Badge(text: c.group.title, color: c.group == .closer ? Theme.accent : Theme.amber) }
                else { Badge(text: Candidate.labels[c.status] ?? c.status, color: c.statusColor) }
                Spacer()
                if !position.isEmpty { Text(position).font(.system(size: 12.5 * Theme.scale)).foregroundStyle(Theme.faint) }
            }
            verdict(c)
            if let s = c.likely {
                (Text(s.reason).font(.system(size: 13 * Theme.scale)).foregroundColor(Theme.dim)
                    + Text("  From \(s.by).").font(.system(size: 11.5 * Theme.scale)).foregroundColor(Theme.faint))
                    .fixedSize(horizontal: false, vertical: true)
            }
            HStack(alignment: .bottom, spacing: 14) {
                VStack(alignment: .leading, spacing: 6) {
                    viewPicker
                    let title = Self.views.first { $0.style == view }?.title ?? "Composite"
                    picture(Images.load(Self.viewPath(c, view)) ?? Images.crop(c.relief, x: c.x, y: c.y, side: store.closeSide(c)),
                            "\(title), \(Int(ProjectStore.closeMetres)) m across, find ringed")
                        .id(drawn)
                }
                .frame(maxWidth: 320)
                picture(Images.load(c.relief), "The whole tile, \(Int(store.tileMetres(c))) m").frame(maxWidth: 300)
                picture(Images.load(c.section), "Slice straight down through the laser points")
            }
            Flow(spacing: 6) { ForEach(chips(c), id: \.self) { chip($0) } }
            details(c)
        }
        .textSelection(.enabled)
        .task(id: c.id) {
            await app.ensureViews(c)
            drawn += 1
        }
    }

    /// The six ways of drawing the close view, on the keys 1 to 6.
    private var viewPicker: some View {
        HStack(spacing: 2) {
            ForEach(Array(Self.views.enumerated()), id: \.element.style) { i, v in
                Button { view = v.style } label: {
                    Text("\(i + 1)").font(.system(size: 11 * Theme.scale, weight: view == v.style ? .bold : .regular, design: .monospaced))
                        .frame(width: 22, height: 20)
                        .background(RoundedRectangle(cornerRadius: 5).fill(view == v.style ? Theme.ink.opacity(0.14) : .clear))
                        .foregroundStyle(view == v.style ? Theme.text : Theme.dim)
                }
                .buttonStyle(.plain)
                .keyboardShortcut(KeyEquivalent(Character("\(i + 1)")), modifiers: [])
                .help("\(v.title) (\(i + 1))")
                .accessibilityLabel(v.title)
            }
        }
    }

    /// "Agent: natural · Second model: built · they disagree", in words, with no tick that could read as agreement.
    private func verdict(_ c: Candidate) -> some View {
        let agent = c.likely?.status
        let agentWord = agent.map { ["natural": "natural", "modern": "modern", "already_published": "already published",
                                     "no_match_in_sources_read": "worth reporting"][$0] ?? $0 } ?? "no suggestion yet"
        let tried = c.checks["second_look_tried"] as? JSON
        let second = c.secondSaysBuilt
        let secondWord = second == true ? "built" : second == false ? "not built" : tried != nil ? "could not answer" : "not asked yet"
        let together: (String, Color)? = {
            guard let agent, let second else { return nil }
            // Modern and "not built" differ, but both rule it out as something old that people built.
            if agent == "modern", !second { return ("both rule it out", Theme.dim) }
            let agentBuilt = agent != "natural"
            return agentBuilt == second ? ("they agree", Theme.dim) : ("they disagree", Theme.amber)
        }()
        return HStack(spacing: 6) {
            Text("Agent: ").foregroundColor(Theme.faint) + Text(agentWord).fontWeight(.semibold)
            Text("·").foregroundStyle(Theme.faint)
            Text("Second model: ").foregroundColor(Theme.faint) + Text(secondWord).fontWeight(.semibold)
            if let together {
                Text("·").foregroundStyle(Theme.faint)
                Text(together.0).fontWeight(.semibold).foregroundStyle(together.1)
            }
            if c.flaggedBy.hasPrefix("measured") {
                Text("·").foregroundStyle(Theme.faint)
                Text("measured, not seen by a model").foregroundStyle(Theme.faint)
            }
        }
        .font(.system(size: 13.5 * Theme.scale))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("The agent says \(agentWord). The second model says \(secondWord)."
                            + (together.map { " \($0.0.capitalizedFirst)." } ?? "")
                            + (c.flaggedBy.hasPrefix("measured") ? " Measured, not seen by a model." : ""))
    }

    private func chips(_ c: Candidate) -> [String] {
        var out: [String] = []
        if let cut = c.checks["section"] as? JSON {
            let h = "\(cut["feature_height_m"] ?? "?") m high"
            out.append(cut["in_ground"] as? Bool == true ? (cut["from_ground_model_only"] as? Bool == true ? "\(h), ground model only" : "\(h), in the ground")
                       : "\(h), not clear in the slice")
        } else { out.append("No slice yet") }
        if let shape = c.checks["shape"] as? JSON, shape["rise_m"] != nil {
            out.append("\(shape["width_ew_m"] ?? "?") × \(shape["width_ns_m"] ?? "?") m" + (((shape["hints"] as? [String]) ?? []).first.map { ", \($0)" } ?? ""))
        }
        if let modern = c.checks["modern"] as? JSON {
            let near = (modern["near"] as? [String]) ?? []
            out.append(modern["likely_modern"] as? Bool == true ? (near.isEmpty ? "Modern features close by" : ListFormatter.localizedString(byJoining: near).capitalizedFirst + " close by")
                       : "Nothing modern mapped on it")
        }
        if let old = c.checks["old_maps"] as? JSON { out.append(old["explains"] as? Bool == true ? "Old maps explain it" : "Old maps: nothing") }
        let read = c.sources.filter { $0.status == "read" }.count, unread = c.sources.filter { $0.status == "could_not_open" }.count
        out.append(c.sources.isEmpty ? "Nothing published read" : "\(read) read" + (unread > 0 ? ", \(unread) would not open" : ""))
        return out
    }

    private func chip(_ text: String) -> some View {
        Text(text).font(.system(size: 12 * Theme.scale)).foregroundStyle(Theme.dim)
            .padding(.horizontal, 9).padding(.vertical, 4)
            .background(Capsule().fill(Theme.ink.opacity(0.07)))
    }

    @ViewBuilder private func details(_ c: Candidate) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            if let look = c.checks["second_look"] as? JSON, let note = look["note"] as? String, !note.isEmpty {
                DisclosureGroup("What the second model said") {
                    Text("\(look["model"] as? String ?? ""): \(note) " + RecordsView.secondMeaning(look["agrees"] as? Bool == true))
                        .font(.system(size: 12.5 * Theme.scale)).foregroundStyle(Theme.dim).fixedSize(horizontal: false, vertical: true).padding(.top, 4)
                }
            }
            if !c.sources.isEmpty {
                DisclosureGroup("Sources (\(c.sources.count))") {
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(c.sources) { s in
                            Text(s.title).font(.system(size: 12.5 * Theme.scale, weight: .medium))
                                + Text(" · \(s.statusLabel) · \(s.finding)").font(.system(size: 12 * Theme.scale)).foregroundColor(Theme.dim)
                        }
                    }
                    .padding(.top, 4)
                }
            }
            if !c.evidence.isEmpty {
                DisclosureGroup("What the agent saw") {
                    Text(c.evidence.joined(separator: "\n\n")).font(.system(size: 12.5 * Theme.scale)).foregroundStyle(Theme.dim)
                        .fixedSize(horizontal: false, vertical: true).padding(.top, 4)
                }
            }
            if !c.decisions.isEmpty {
                Text("Decided before: " + c.decisions.joined(separator: "; ")).font(.system(size: 12 * Theme.scale)).foregroundStyle(Theme.faint)
            }
        }
        .font(.system(size: 12.5 * Theme.scale)).foregroundStyle(Theme.faint)
    }

    @ViewBuilder private func picture(_ image: NSImage?, _ caption: String) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            if let image {
                Image(nsImage: image).resizable().aspectRatio(contentMode: .fit).frame(maxHeight: 280, alignment: .bottomLeading)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            } else {
                RoundedRectangle(cornerRadius: 8).fill(Theme.side).frame(height: 160)
                    .overlay(Text("None yet").font(.system(size: 12 * Theme.scale)).foregroundStyle(Theme.faint))
            }
            Text(caption).font(.system(size: 11.5 * Theme.scale)).foregroundStyle(Theme.faint)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

extension Candidate {
    /// What still stands between this find and "no match in the sources read", in a person's words (ledger.blockers).
    var reportBlockers: [String] {
        var items: [String] = []
        if (checks["section"] as? JSON)?["in_ground"] as? Bool != true { items.append("No slice shows it in the ground.") }
        if (checks["second_look"] as? JSON)?["agrees"] as? Bool != true { items.append("No second model has called it built.") }
        if checks["modern"] == nil { items.append("Open maps have not been checked.") }
        if !sources.contains(where: { $0.status == "read" }) { items.append("No source has been read.") }
        let unread = sources.filter { $0.status == "could_not_open" }.count
        if unread > 0 { items.append("\(unread) source\(unread == 1 ? "" : "s") would not open; open \(unread == 1 ? "it" : "them") in Sources.") }
        return items
    }
}

extension String {
    var capitalizedFirst: String { prefix(1).uppercased() + dropFirst() }
}


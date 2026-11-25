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
        // Within each group, the finds most checks agree on come first (rank A, then B, then C).
        let order: (Candidate, Candidate) -> Bool = { ($0.group.rawValue, -$0.agreement, $0.id) < ($1.group.rawValue, -$1.agreement, $1.id) }
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

    /// Finds kept on the map that the second model calls built, one press away.
    @ViewBuilder private var layerOffer: some View {
        let built = store.candidates.filter { $0.group == .layer && $0.secondSaysBuilt == true && !needs.contains($0.id) }
        let kept = store.candidates.filter { $0.group == .layer }.count
        if kept > 0 {
            VStack(spacing: 8) {
                Text("\(kept) find\(kept == 1 ? " is" : "s are") kept on the map: measured rises and shapes the bulk look pointed at that the second model did not call built, and rises whose shape ranks in the lower half here.")
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
    /// The slice last chosen: west to east, or north to south.
    @AppStorage("sliceNorthSouth") private var northSouth = false
    @State private var drawn = 0
    @State private var comparing = false
    @State private var cuttingMaps = false
    @State private var showing3D = false
    @State private var flightsOpen = true
    @State private var mapsOpen = true

    /// Each view with one line saying what it shows. The last three are from the Relief Visualization Toolbox.
    static let views: [(style: String, title: String, shows: String)] = [
        ("composite", "Composite", "Shading and local relief together"),
        ("relief_small", "Local relief", "Rises and dips 5 to 15 m across"),
        ("sky_view", "Sky view", "Dark where little sky is seen: ditches and hollows"),
        ("hillshade", "Hillshade", "Lit from four directions"),
        ("positive_openness", "Openness up", "Bright on rises and edges"),
        ("negative_openness", "Openness down", "Bright in hollows and ditches"),
        ("vat", "VAT", "Four views blended; reads in most ground"),
        ("msrm", "Multi-scale relief", "Rises 2 to 20 m across, every size between"),
        ("local_dominance", "Local dominance", "Bright where ground stands over its surroundings: low mounds"),
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
                    .fixedSize(horizontal: false, vertical: true).layoutPriority(1)
                if c.waiting {
                    Badge(text: c.group.title, color: c.group == .closer ? Theme.accent : Theme.amber).fixedSize()
                    Text("Rank \(c.rank)").font(.system(size: 12 * Theme.scale, weight: .semibold)).foregroundStyle(Theme.dim).fixedSize()
                        .help("\(c.agreement) of 3 checks point to something built: the shape, a model's eye, the second model")
                        .accessibilityLabel("Rank \(c.rank): \(c.agreement) of 3 checks point to something built")
                }
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
                    let shown = Self.views.first { $0.style == view } ?? Self.views[0]
                    picture(Images.load(Self.viewPath(c, view)) ?? Images.crop(c.relief, x: c.x, y: c.y, side: store.closeSide(c)),
                            "\(shown.shows). \(Int(ProjectStore.closeMetres)) m across, find ringed")
                        .id(drawn)
                }
                .frame(maxWidth: 320)
                picture(Images.load(c.relief), "The whole tile, \(Int(store.tileMetres(c))) m").frame(maxWidth: 300)
                VStack(alignment: .leading, spacing: 6) {
                    sliceSwitch(c)
                    let ns = northSouth && FileManager.default.fileExists(atPath: c.sectionNS)
                    picture(Images.load(ns ? c.sectionNS : c.section),
                            "Slice \(ns ? "north to south" : "west to east"), straight down, a person 1.70 m for scale")
                }
            }
            Text(numbers(c).joined(separator: "  ·  ")).font(.system(size: 13 * Theme.scale)).foregroundStyle(Theme.dim)
            theCase(c)
            details(c)
        }
        .textSelection(.enabled)
        .task(id: c.id) {
            await app.ensureViews(c)
            drawn += 1
            // The old maps and the two flights come by themselves for a find that waits for a person, after a moment on
            // its card, so going through cards quickly does not queue them (EASE_LOOP E8).
            try? await Task.sleep(for: .seconds(1.2))
            guard !Task.isCancelled, c.waiting, !c.inLayer, app.engine.ready else { return }
            let root = (c.folder as NSString).deletingLastPathComponent
            let datasets = store.terrains.map(\.dataset)
            if c.checks["flights"] == nil, datasets.contains(where: { $0.hasPrefix("usgs:") || $0.hasPrefix("us:") }), !comparing {
                comparing = true
                await app.compareFlights(c)
                comparing = false
                store.reloadIfChanged()
            }
            guard !Task.isCancelled else { return }
            if !FileManager.default.fileExists(atPath: root + "/data/views/\(c.id)-oldmaps.json"),
               datasets.contains(where: { ["us:", "usgs:", "fr:"].contains(where: $0.hasPrefix) }), !cuttingMaps {
                cuttingMaps = true
                await app.oldMapViews(c)
                cuttingMaps = false
                drawn += 1
            }
        }
    }

    /// The nine ways of drawing the close view, on the keys 1 to 9, with the chosen one named.
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
                .help("\(v.title): \(v.shows) (\(i + 1))")
                .accessibilityLabel(v.title)
                .accessibilityHint(v.shows)
            }
            Text(Self.views.first { $0.style == view }?.title ?? "").font(.system(size: 11.5 * Theme.scale)).foregroundStyle(Theme.faint)
                .lineLimit(1).padding(.leading, 6)
        }
    }

    /// West to east or north to south, on the key D; north to south only where check_finds cut it.
    private func sliceSwitch(_ c: Candidate) -> some View {
        let both = FileManager.default.fileExists(atPath: c.sectionNS)
        return HStack(spacing: 2) {
            ForEach([false, true], id: \.self) { ns in
                Button { northSouth = ns } label: {
                    Text(ns ? "N–S" : "W–E").font(.system(size: 11 * Theme.scale, weight: northSouth == ns ? .bold : .regular))
                        .frame(width: 38, height: 20)
                        .background(RoundedRectangle(cornerRadius: 5).fill(northSouth == ns ? Theme.ink.opacity(0.14) : .clear))
                        .foregroundStyle(northSouth == ns ? Theme.text : Theme.dim)
                }
                .buttonStyle(.plain).disabled(ns && !both)
                .accessibilityLabel(ns ? "Slice north to south" : "Slice west to east")
            }
            Button("") { if both { northSouth.toggle() } }.keyboardShortcut("d", modifiers: []).opacity(0).frame(width: 0)
                .accessibilityHidden(true)
        }
        .help(both ? "Which way the slice runs (D)" : "Only the west-to-east slice was cut for this find")
    }

    /// What marked the find, and the four numbers: its height, its size, the ground under it, and the finds near it.
    private func numbers(_ c: Candidate) -> [String] {
        var out = [c.flaggedBy.hasPrefix("measured") ? "Measured rise" : c.flaggedBy.contains("bulk") ? "Seen in the bulk look"
                   : c.flaggedBy.hasPrefix("a person") ? "Marked by hand" : "Marked by the agent"]
        out.append(Candidate.heightWords(c.checks).capitalizedFirst)
        if let shape = c.checks["shape"] as? JSON, let ew = shape["width_ew_m"], let ns = shape["width_ns_m"] { out.append("\(ew) × \(ns) m") }
        let context = c.checks["context"] as? JSON ?? [:]
        if let density = (context["ground_points_per_m2"] as? Double) ?? (context["ground_points_per_m2"] as? Int).map(Double.init) {
            out.append("\(density.formatted(.number.precision(.fractionLength(0...1)))) ground points per m²")
        } else if (c.checks["section"] as? JSON)?["from_ground_model_only"] as? Bool == true {
            out.append("Ground model, no raw points")
        }
        if let near = context["finds_within_200m"] as? Int { out.append(near == 1 ? "1 other find within 200 m" : "\(near) other finds within 200 m") }
        return out
    }

    /// The checks on the record, sorted into reasons for an old, built feature and reasons against. Counted, never weighed.
    private func reasons(_ c: Candidate) -> (for: [String], against: [String]) {
        var yes: [String] = [], no: [String] = []
        let cut = c.checks["section"] as? JSON
        if cut?["in_ground"] as? Bool == true { yes.append("In the ground") }
        if cut?["in_ground"] as? Bool == false { no.append("Not clear in the slice") }
        if c.secondSaysBuilt == true { yes.append("Second model: built") }
        if c.secondSaysBuilt == false { no.append("Second model: not built") }
        if let modern = c.checks["modern"] as? JSON {
            let near = (modern["near"] as? [String]) ?? []
            if modern["likely_modern"] as? Bool == true {
                no.append(near.isEmpty ? "Modern features close by" : ListFormatter.localizedString(byJoining: near).capitalizedFirst + " close by")
            } else { yes.append("Nothing modern mapped") }
        }
        if let old = c.checks["old_maps"] as? JSON { if old["explains"] as? Bool == true { no.append("Old maps explain it") } else { yes.append("Not on old maps") } }
        if let answer = (c.checks["flights"] as? JSON)?["answer"] as? String {
            if answer.hasPrefix("present in both") { yes.append("In both flights") }
            else if answer.contains("possibly modern") { no.append("Absent in the older flight") }
        }
        if let s = c.likely?.status, s == "natural" || s == "modern" { no.append("Agent: \(s)") }
        return (yes, no)
    }

    /// For and against as two rows with a count each, then what was read and what is on record.
    private func theCase(_ c: Candidate) -> some View {
        let r = reasons(c)
        var other: [String] = []
        if let rec = c.checks["records"] as? JSON {
            let near = (rec["near"] as? [JSON]) ?? []
            let registers = ((rec["registers"] as? [JSON]) ?? []).compactMap { $0["register"] as? String }
            other.append(!near.isEmpty ? "On record: \(near[0]["name"] as? String ?? "a site")"
                         : registers.isEmpty ? "Not on the open lists; records here not open" : "Not in \(registers[0])")
        }
        let read = c.sources.filter { $0.status == "read" }.count, unread = c.sources.filter { $0.status == "could_not_open" }.count
        other.append(c.sources.isEmpty ? "Nothing published read" : "\(read) read" + (unread > 0 ? ", \(unread) would not open" : ""))
        return VStack(alignment: .leading, spacing: 6) {
            reasonRow("For", r.for, Theme.accent)
            reasonRow("Against", r.against, Theme.amber)
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text("Records").font(.system(size: 12 * Theme.scale, weight: .semibold)).foregroundStyle(Theme.dim)
                    .frame(width: 120, alignment: .leading)
                Flow(spacing: 6) { ForEach(other, id: \.self) { chip($0) } }
                Spacer(minLength: 0)
                Text("A count of reasons, not a probability").font(.system(size: 11 * Theme.scale)).foregroundStyle(Theme.faint)
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("\(r.for.count) reasons for, \(r.against.count) against. A count of reasons, not a probability.")
    }

    private func reasonRow(_ title: String, _ items: [String], _ color: Color) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            HStack(spacing: 3) {
                Text("\(title) \(items.count)").font(.system(size: 12 * Theme.scale, weight: .semibold)).foregroundStyle(color)
                    .frame(width: 74, alignment: .leading)
                ForEach(0..<max(items.count, 0), id: \.self) { _ in RoundedRectangle(cornerRadius: 2).fill(color.opacity(0.8)).frame(width: 7, height: 10) }
            }
            .frame(width: 120, alignment: .leading)
            if items.isEmpty { Text("none on the record").font(.system(size: 12 * Theme.scale)).foregroundStyle(Theme.faint) }
            else { Flow(spacing: 6) { ForEach(items, id: \.self) { chip($0) } } }
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

    private func chip(_ text: String) -> some View {
        Text(text).font(.system(size: 12 * Theme.scale)).foregroundStyle(Theme.dim)
            .padding(.horizontal, 9).padding(.vertical, 4)
            .background(Capsule().fill(Theme.ink.opacity(0.07)))
    }

    /// When did it appear: the oldest and newest dated flights over the find, once compared; before that, a button.
    @ViewBuilder private func flights(_ c: Candidate) -> some View {
        if let f = c.checks["flights"] as? JSON, let answer = f["answer"] as? String {
            DisclosureGroup(isExpanded: $flightsOpen) {
                VStack(alignment: .leading, spacing: 6) {
                    if let path = f["image"] as? String, let image = Images.load((c.folder as NSString).deletingLastPathComponent + "/" + path) {
                        FlightCompare(image: image, years: (f["years"] as? [Int]) ?? [])
                    }
                    if let rise = f["rise_m"] as? [Double], let noise = f["noise_m"] as? Double, rise.count == 2 {
                        Text("Rises \(rise[0].formatted()) m, then \(rise[1].formatted()) m above the ground around it. The ground away from it differs by up to \(noise.formatted()) m between flights, so less than that is noise. Blue where ground went, red where it came.")
                            .font(.system(size: 12 * Theme.scale)).foregroundStyle(Theme.dim).fixedSize(horizontal: false, vertical: true)
                    }
                }
                .padding(.top, 4).frame(maxWidth: .infinity, alignment: .leading)
            } label: { Text("Two flights: " + answer) }
        } else if store.terrains.contains(where: { $0.dataset.hasPrefix("usgs:") || $0.dataset.hasPrefix("us:") }) {
            HStack(spacing: 8) {
                Button(comparing ? "Comparing flights…" : "Compare two flights") {
                    comparing = true
                    Task { await app.compareFlights(c); comparing = false }
                }
                .buttonStyle(SecondaryButton()).disabled(comparing || !app.engine.ready)
                .help("Where two dated flights cover this find: was it there in both, or did it appear or go between them? About ten seconds.")
                if comparing { DigIndicator(size: 12) }
            }
        }
    }

    /// Old maps beside the ground (old_map_views), in the United States and France; before they are cut, a button.
    @ViewBuilder private func oldMaps(_ c: Candidate) -> some View {
        let root = (c.folder as NSString).deletingLastPathComponent
        let file = root + "/data/views/\(c.id)-oldmaps.json"
        if FileManager.default.fileExists(atPath: file) {
            DisclosureGroup(isExpanded: $mapsOpen) {
                OldMapCompare(root: root, file: file).padding(.top, 4).frame(maxWidth: .infinity, alignment: .leading)
            } label: { Text("Old maps beside the ground") }
        } else if store.terrains.contains(where: { ["us:", "usgs:", "fr:"].contains(where: $0.dataset.hasPrefix) }) {
            HStack(spacing: 8) {
                Button(cuttingMaps ? "Cutting the old maps…" : "Old maps beside the ground") {
                    cuttingMaps = true
                    Task { await app.oldMapViews(c); cuttingMaps = false; drawn += 1 }
                }
                .buttonStyle(SecondaryButton()).disabled(cuttingMaps || !app.engine.ready)
                .help("The oldest USGS sheets here (in France, the État-major map and the 1950s photographs), cut to the same 240 m as the ground, with a divider to slide between them.")
                if cuttingMaps { DigIndicator(size: 12) }
            }
        }
    }

    @ViewBuilder private func details(_ c: Candidate) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            flights(c)
            oldMaps(c)
            let surface = (c.folder as NSString).deletingLastPathComponent + "/data/views/\(c.id)-surface.json"
            if FileManager.default.fileExists(atPath: surface) {
                Button("See it in 3D") { showing3D = true }.buttonStyle(SecondaryButton())
                    .help("The ground 120 m around the find in 3D, with a person 1.70 m tall for scale")
                    .sheet(isPresented: $showing3D) { Relief3D(title: "\(c.id) in 3D", path: surface) }
            }
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

/// The two flights over a find, one over the other with a divider to slide between them, and the change map beside
/// them. compare_flights draws the three side by side in one picture (300 px each, 8 px apart); this cuts it up.
private struct FlightCompare: View {
    let image: NSImage
    let years: [Int]
    @State private var split = 0.5

    private func panel(_ i: Int) -> NSImage? {
        guard let cg = image.cgImage(forProposedRect: nil, context: nil, hints: nil), cg.height > 26 else { return nil }
        let side = cg.height - 26
        guard cg.width >= 3 * side + 16, let part = cg.cropping(to: CGRect(x: i * (side + 8), y: 0, width: side, height: side)) else { return nil }
        return NSImage(cgImage: part, size: NSSize(width: side, height: side))
    }

    var body: some View {
        let side: CGFloat = 230
        let first = years.first.map(String.init) ?? "Older", last = years.last.map(String.init) ?? "Newer"
        if let old = panel(0), let new = panel(1), let change = panel(2) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    ZStack(alignment: .leading) {
                        Image(nsImage: new).resizable().frame(width: side, height: side)
                        Image(nsImage: old).resizable().frame(width: side, height: side)
                            .mask(alignment: .leading) { Rectangle().frame(width: side * split) }
                        Rectangle().fill(.white).frame(width: 2, height: side).offset(x: side * split - 1)
                    }
                    .frame(width: side, height: side).clipShape(RoundedRectangle(cornerRadius: 8))
                    .contentShape(Rectangle())
                    .gesture(DragGesture(minimumDistance: 0).onChanged { split = min(max($0.location.x / side, 0), 1) })
                    .accessibilityElement().accessibilityLabel("The ground in \(first) on the left of the line, in \(last) on the right")
                    Slider(value: $split, in: 0...1).frame(width: side).accessibilityLabel("Divider between the two flights")
                    Text("\(first) left of the line, \(last) right").font(.system(size: 12 * Theme.scale)).foregroundStyle(Theme.dim)
                }
                VStack(alignment: .leading, spacing: 6) {
                    Image(nsImage: change).resizable().frame(width: side, height: side).clipShape(RoundedRectangle(cornerRadius: 8))
                        .accessibilityLabel("The change between the flights")
                    Text("Change").font(.system(size: 12 * Theme.scale)).foregroundStyle(Theme.dim)
                }
            }
        } else {
            Image(nsImage: image).resizable().aspectRatio(contentMode: .fit).frame(maxWidth: 640, maxHeight: 230, alignment: .leading)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .accessibilityLabel("The ground in both flights, and the change between them")
        }
    }
}

/// The bare ground with an old map laid over it, the same 240 m square of each. Drag across it, or use the slider,
/// to move the divider; the second slider fades the map so the ground shows through it; the sheet buttons choose which.
private struct OldMapCompare: View {
    let root: String
    let file: String
    @State private var split = 0.5
    @State private var strength = 1.0
    @State private var sheet = 0

    private var info: (ground: String, maps: [(title: String, image: String)]) {
        guard let data = FileManager.default.contents(atPath: file),
              let json = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] else { return ("", []) }
        let maps = ((json["maps"] as? [[String: Any]]) ?? []).compactMap { m -> (String, String)? in
            guard let t = m["title"] as? String, let i = m["image"] as? String else { return nil }
            return (t, i)
        }
        return (json["ground"] as? String ?? "", maps)
    }

    var body: some View {
        let info = info
        let side: CGFloat = 340
        VStack(alignment: .leading, spacing: 8) {
            if info.maps.isEmpty {
                Text("No old map covers this place.").font(.system(size: 12 * Theme.scale)).foregroundStyle(Theme.faint)
            } else {
                let pick = min(sheet, info.maps.count - 1)
                ZStack(alignment: .leading) {
                    if let ground = Images.load(root + "/" + info.ground) { Image(nsImage: ground).resizable().frame(width: side, height: side) }
                    if let map = Images.load(root + "/" + info.maps[pick].image) {
                        Image(nsImage: map).resizable().frame(width: side, height: side)
                            .opacity(strength)
                            .mask(alignment: .leading) { Rectangle().frame(width: side * split) }
                    }
                    Rectangle().fill(.white).frame(width: 2, height: side).offset(x: side * split - 1)
                }
                .frame(width: side, height: side).clipShape(RoundedRectangle(cornerRadius: 8))
                .contentShape(Rectangle())
                .gesture(DragGesture(minimumDistance: 0).onChanged { split = min(max($0.location.x / side, 0), 1) })
                .accessibilityElement().accessibilityLabel("\(info.maps[pick].title) on the left, the bare ground on the right")
                sliderRow("Line", value: $split, side: side).accessibilityLabel("Divider between the old map and the ground")
                sliderRow("Map", value: $strength, side: side).accessibilityLabel("How strongly the old map shows over the ground")
                HStack(spacing: 6) {
                    ForEach(Array(info.maps.enumerated()), id: \.offset) { i, m in
                        Button(m.title.replacingOccurrences(of: "USGS ", with: "")) { sheet = i }
                            .buttonStyle(SecondaryButton()).opacity(i == pick ? 1 : 0.6)
                    }
                }
                Text("Old map on the left of the line, the bare ground on the right; both 240 m across, the find in the middle. Fade the map to see the ground through it.")
                    .font(.system(size: 12 * Theme.scale)).foregroundStyle(Theme.dim)
            }
        }
    }

    private func sliderRow(_ name: String, value: Binding<Double>, side: CGFloat) -> some View {
        HStack(spacing: 8) {
            Text(name).font(.system(size: 12 * Theme.scale)).foregroundStyle(Theme.dim).frame(width: 34, alignment: .leading)
            Slider(value: value, in: 0...1)
        }
        .frame(width: side)
    }
}


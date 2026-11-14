import SwiftUI
import UniformTypeIdentifiers

/// A conversation with the agent: what it said and did, and the message box.
struct ChatView: View {
    @EnvironmentObject var chat: ChatModel

    var body: some View {
        VStack(spacing: 0) {
            if chat.loading {
                HStack(spacing: 8) {
                    ProgressView().controlSize(.small)
                    Text("Opening the chat").font(.system(size: 13 * Theme.scale)).foregroundStyle(Theme.faint)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if chat.items.isEmpty { EmptyChat() } else { Messages() }
            RecoveryBar()
            if let approval = chat.approval {
                VStack(alignment: .leading, spacing: 10) {
                    Text(approval.message).font(.system(size: 13 * Theme.scale))
                    HStack(spacing: 8) {
                        Button("Allow") { chat.answer(true) }.buttonStyle(PrimaryButton())
                        Button("Decline") { chat.answer(false) }.buttonStyle(SecondaryButton())
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading).panel(padding: 14)
                .frame(maxWidth: 760).padding(.horizontal, 16).padding(.bottom, 8)
            }
            Composer().frame(maxWidth: 760).padding(.horizontal, 16).padding(.top, 4).padding(.bottom, 4)
            StatusLine().frame(maxWidth: 760).padding(.horizontal, 28).padding(.bottom, 8)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.bg)
    }
}

/// When the engine has stopped, or the chat ended on a failure, say in plain words what happened and offer the next step.
private struct RecoveryBar: View {
    @EnvironmentObject var app: AppState
    @EnvironmentObject var chat: ChatModel

    var body: some View {
        // When the engine stops, the whole page says so and offers a restart, so this bar only covers failures in the chat.
        if let failed = chat.lastProblem {
            let (title, advice) = Self.explain(failed.text)
            bar(title, advice) {
                if chat.items.contains(where: { $0.kind == .user }) {
                    Button { Task { @MainActor in await chat.retry() } } label: { Label("Try again", systemImage: "arrow.clockwise") }
                        .buttonStyle(PrimaryButton())
                }
                Button { app.pickerRequest = .model } label: { Label("Choose another model", systemImage: "cpu") }
                    .buttonStyle(SecondaryButton())
            }
        }
    }

    private func bar(_ title: String, _ advice: String, @ViewBuilder buttons: () -> some View) -> some View {
        HStack(alignment: .center, spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill").font(.system(size: 15 * Theme.scale)).foregroundStyle(Theme.amber)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.system(size: 13.5 * Theme.scale, weight: .semibold))
                Text(advice).font(.system(size: 12.5 * Theme.scale)).foregroundStyle(Theme.dim).fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 8)
            buttons()
        }
        .panel(padding: 12)
        .frame(maxWidth: 760).padding(.horizontal, 16).padding(.bottom, 6)
    }

    /// A heading and the advice for an error message from the engine or the model's provider.
    static func explain(_ raw: String) -> (String, String) {
        let text = raw.lowercased()
        func has(_ words: String...) -> Bool { words.contains { text.contains($0) } }
        if has("rate limit", "usage limit", "quota", "429", "too many requests") {
            return ("The usage limit was reached", "Wait until it resets (/status says when), or choose a model that runs through another provider.")
        }
        if has("model") && has("not found", "not supported", "does not exist", "unsupported", "unknown model", "no access", "not available") {
            return ("This model could not run the request", "Choose another model. Models that read images are needed for screening.")
        }
        if has("network", "connection", "timed out", "timeout", "offline", "disconnected", "unreachable", "dns") {
            return ("The connection dropped", "Check that this Mac is online, then try again.")
        }
        if has("context", "too long", "maximum length", "token limit") {
            return ("The chat is too long for this model", "Type /compact to shorten it, start a new chat, or choose a model with more room.")
        }
        if has("unauthorized", "401", "403", "api key", "sign in", "login") {
            return ("The provider refused the request", "Check the model's account or key, or choose another model.")
        }
        return ("That did not work", "The message above says what went wrong. Try again, or choose another model.")
    }
}

/// A quiet line under the message box: how full this chat is and how much of the account's usage is left.
private struct StatusLine: View {
    @EnvironmentObject var chat: ChatModel

    var body: some View {
        HStack(spacing: 10) {
            if let id = chat.active, let use = chat.usage[id], let window = use.window, window > 0 {
                let share = Double(use.used) / Double(window)
                Text("Chat \(Int((share * 100).rounded()))% full")
                    .foregroundStyle(share > 0.8 ? Theme.amber : Theme.faint)
                    .help("How much of the model's memory this chat uses. Near full, /compact shortens it.")
            }
            Spacer()
            if let left = chat.usageLeft {
                Text("\(left)% of usage left").foregroundStyle(left < 15 ? Theme.amber : Theme.faint)
                    .help("From your account's limits, as the engine reports them. /status gives the details.")
            }
        }
        .font(.system(size: 11.5 * Theme.scale))
    }
}

// MARK: - Messages

/// One row of the conversation: a single item, or a run of steps folded into one line.
private enum Block: Identifiable {
    case item(ChatItem)
    case steps(String, [ChatItem])

    var id: String {
        switch self {
        case .item(let item): return item.id
        case .steps(let first, _): return "run-" + first
        }
    }

    /// Fold long runs of steps. While the agent is working, its three latest steps stay visible.
    static func group(_ items: [ChatItem], live: Bool) -> [Block] {
        var out: [Block] = []
        var run: [ChatItem] = []
        func flush(tail: Bool) {
            let keep = tail && live ? 3 : 0
            if run.count > keep + 3 {
                out.append(.steps(run[0].id, Array(run.dropLast(keep))))
                out += run.suffix(keep).map(Block.item)
            } else {
                out += run.map(Block.item)
            }
            run = []
        }
        for item in items {
            if item.kind == .step, item.projectPath == nil, item.state != .failed, !item.showsImage {
                run.append(item)
            } else {
                flush(tail: false)
                out.append(.item(item))
            }
        }
        flush(tail: true)
        return out
    }
}

private struct Messages: View {
    @EnvironmentObject var chat: ChatModel

    /// What the agent is on now: the step running, or else the step its plan marks in progress.
    private var working: String {
        if let step = chat.items.last(where: { $0.kind == .step && $0.state == .running }) { return step.text }
        guard let plan = chat.items.last(where: { $0.kind == .plan })?.plan,
              let i = plan.firstIndex(where: { $0.status.lowercased().contains("progress") }) else { return "Working" }
        return "Step \(i + 1) of \(plan.count): \(plan[i].text)"
    }

    var body: some View {
        ScrollViewReader { scroll in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 12) {
                    ForEach(Block.group(chat.items, live: chat.running)) { block in
                        switch block {
                        case .item(let item): ChatRow(item: item)
                        case .steps(_, let steps): StepGroup(steps: steps)
                        }
                    }
                    if chat.running {
                        HStack(spacing: 8) {
                            ProgressView().controlSize(.small)
                            Text(working).font(.system(size: 13 * Theme.scale)).foregroundStyle(Theme.faint).lineLimit(1)
                        }
                        .padding(.top, 2)
                    }
                    Color.clear.frame(height: 10).id("end")
                }
                .frame(maxWidth: 760, alignment: .leading)
                .padding(.horizontal, 20).padding(.top, 18)
                .frame(maxWidth: .infinity)
            }
            .defaultScrollAnchor(.bottom)
            .onChange(of: chat.items.count) { scroll.scrollTo("end", anchor: .bottom) }
            .onChange(of: chat.items.last?.text) { scroll.scrollTo("end", anchor: .bottom) }
            .onAppear { scroll.scrollTo("end", anchor: .bottom) }
        }
    }
}

private struct ChatRow: View {
    let item: ChatItem
    @EnvironmentObject var chat: ChatModel
    @State private var showInstructions = false
    @State private var hovering = false

    /// The last message the person sent, which can be edited and sent again.
    private var isLastUser: Bool { chat.items.last { $0.kind == .user }?.id == item.id }
    /// The last answer of a turn, where Retry and "Copy chat from here" make sense. Answers read back from the engine
    /// carry their turn; one that does not is treated as ending its turn when no answer follows it before the next message.
    private var endsTurn: Bool {
        guard let i = chat.items.firstIndex(where: { $0.id == item.id }) else { return false }
        for next in chat.items[(i + 1)...] {
            if next.kind == .user { return true }
            if next.kind == .agent { return item.turn != nil && next.turn != item.turn }
        }
        return true
    }

    var body: some View {
        switch item.kind {
        case .user:
            VStack(alignment: .trailing, spacing: 6) {
                if !item.images.isEmpty {
                    HStack(spacing: 6) {
                        ForEach(item.images.prefix(6), id: \.self) { path in
                            if let image = Images.load(path) {
                                Image(nsImage: image).resizable().aspectRatio(contentMode: .fill)
                                    .frame(width: 88, height: 88).clipShape(RoundedRectangle(cornerRadius: 10))
                            }
                        }
                    }
                }
                if !item.files.isEmpty {
                    HStack(spacing: 6) {
                        ForEach(item.files, id: \.self) { name in
                            Label(name, systemImage: Attachment(path: name).icon).font(.system(size: 12 * Theme.scale)).lineLimit(1)
                                .padding(.horizontal, 10).frame(height: 28)
                                .background(Capsule().fill(Theme.ink.opacity(0.06)))
                        }
                    }
                }
                if !item.text.isEmpty {
                    Text(item.text).font(.system(size: 14 * Theme.scale)).lineSpacing(3).textSelection(.enabled)
                        .padding(.horizontal, 14).padding(.vertical, 9)
                        .background(RoundedRectangle(cornerRadius: 18).fill(Theme.raised))
                        .frame(maxWidth: 520, alignment: .trailing)
                }
                if let instructions = item.result {
                    // A workflow: its name above, and the instructions it sent folded away.
                    Button(showInstructions ? "Hide the instructions" : "Show the instructions") { showInstructions.toggle() }
                        .buttonStyle(.plain).font(.system(size: 12 * Theme.scale)).foregroundStyle(Theme.faint)
                    if showInstructions {
                        Text(instructions).font(.system(size: 12.5 * Theme.scale)).foregroundStyle(Theme.dim).lineSpacing(2).textSelection(.enabled)
                            .padding(12).frame(maxWidth: 520, alignment: .leading)
                            .background(RoundedRectangle(cornerRadius: 12).strokeBorder(Theme.line))
                    }
                }
                actions(user: true)
            }
            .frame(maxWidth: .infinity, alignment: .trailing)
            .padding(.vertical, 4)
            .onHover { hovering = $0 }
        case .agent:
            VStack(alignment: .leading, spacing: 4) {
                MarkdownText(text: item.text).frame(maxWidth: .infinity, alignment: .leading).padding(.vertical, 2)
                if endsTurn { actions(user: false) }
            }
            .contentShape(Rectangle())
            .onHover { hovering = $0 }
        case .plan:
            PlanCard(item: item)
        case .note:
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "info.circle").font(.system(size: 13 * Theme.scale)).foregroundStyle(Theme.tan).padding(.top, 2)
                MarkdownText(text: item.text).frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(12).frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 12).fill(Theme.ink.opacity(0.05)))
            .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Theme.line))
        case .step:
            if let path = item.projectPath {
                StepRow(item: item)
                ProjectCard(path: path)
            } else {
                StepRow(item: item)
            }
        }
    }

    /// Copy, edit, retry and copying the chat. Always shown under an answer, as in Codex; under the person's own message,
    /// shown for the last one and while the pointer is over the others.
    private func actions(user: Bool) -> some View {
        let canChange = !chat.running
        return HStack(spacing: 2) {
            action("doc.on.doc", "Copy") {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(item.result ?? item.text, forType: .string)
            }
            if user, isLastUser, canChange, item.result == nil {
                action("pencil", "Edit and send again") {
                    Task { @MainActor in
                        if let text = await chat.undo() { chat.draft = text }
                    }
                }
            }
            if !user, canChange, let last = chat.items.last(where: { $0.kind == .agent }), last.id == item.id,
               let question = chat.items.last(where: { $0.kind == .user }) {
                action("arrow.clockwise", "Ask again") {
                    Task { @MainActor in await chat.resend(question.result ?? question.text) }
                }
            }
            if !user, canChange, let turn = item.turn {
                action("arrow.triangle.branch", "Copy the chat up to here, to try something else") {
                    Task { @MainActor in await chat.fork(through: turn) }
                }
            }
        }
        .opacity(!user || hovering || isLastUser ? 1 : 0)
        .animation(.easeOut(duration: 0.12), value: hovering)
    }

    private func action(_ icon: String, _ help: String, _ run: @escaping () -> Void) -> some View {
        Button(action: run) {
            Image(systemName: icon).font(.system(size: 11.5 * Theme.scale)).foregroundStyle(Theme.faint)
                .frame(width: 26, height: 22).contentShape(Rectangle())
        }
        .buttonStyle(.plain).help(help).accessibilityLabel(help)
    }
}

/// The agent's plan for a run, ticked off as it goes.
private struct PlanCard: View {
    let item: ChatItem

    private var done: Int { item.plan.filter { $0.status == "completed" }.count }

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack {
                Label("Plan", systemImage: "list.bullet.clipboard").font(.system(size: 12.5 * Theme.scale, weight: .semibold))
                Spacer()
                Text("\(done) of \(item.plan.count) done").font(.system(size: 12 * Theme.scale)).foregroundStyle(Theme.faint)
            }
            ForEach(Array(item.plan.enumerated()), id: \.offset) { _, step in
                HStack(alignment: .firstTextBaseline, spacing: 9) {
                    Image(systemName: step.status == "completed" ? "checkmark.circle.fill"
                          : step.status.lowercased().contains("progress") ? "circle.dotted.circle" : "circle")
                        .font(.system(size: 13 * Theme.scale))
                        .foregroundStyle(step.status == "completed" ? Theme.green
                                         : step.status.lowercased().contains("progress") ? Theme.accent : Theme.faint)
                        .frame(width: 16)
                    Text(step.text).font(.system(size: 13 * Theme.scale))
                        .foregroundStyle(step.status == "completed" ? Theme.dim : Theme.text)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .panel(padding: 14, radius: 12)
    }
}

/// Shown when the agent creates a project in a general chat.
private struct ProjectCard: View {
    let path: String
    @EnvironmentObject var app: AppState
    @EnvironmentObject var store: ProjectStore

    var body: some View {
        let project = store.projects.first { $0.path == path }
        HStack(spacing: 12) {
            IconTile(name: "folder")
            VStack(alignment: .leading, spacing: 2) {
                Text(project?.name ?? URL(fileURLWithPath: path).lastPathComponent).font(.system(size: 13.5 * Theme.scale, weight: .semibold))
                Text("Project created. Open it to work with its map and records beside the chat.")
                    .font(.system(size: 12.5 * Theme.scale)).foregroundStyle(Theme.dim).fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 8)
            Button("Open project") {
                store.register(path: path)
                if let project = store.projects.first(where: { $0.path == path }) { app.open(project) }
            }
            .buttonStyle(PrimaryButton())
        }
        .panel(padding: 12, radius: 12)
    }
}

/// A finished run of steps, folded into one line.
private struct StepGroup: View {
    let steps: [ChatItem]
    @State private var open = false
    @State private var hover = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Button { open.toggle() } label: {
                HStack(spacing: 8) {
                    Image(systemName: "square.stack.3d.up").frame(width: 18)
                    Text("\(steps.count) steps")
                    if !open, let last = steps.last {
                        Text("· " + last.text).foregroundStyle(Theme.faint).lineLimit(1)
                    }
                    Image(systemName: "chevron.right").font(.system(size: 8.5 * Theme.scale, weight: .bold)).foregroundStyle(Theme.faint)
                        .rotationEffect(.degrees(open ? 90 : 0))
                    Spacer(minLength: 0)
                }
                .font(.system(size: 13 * Theme.scale)).foregroundStyle(hover ? Theme.text : Theme.dim)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .onHover { hover = $0 }
            .help("Show every step of this run")

            if open {
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(steps) { StepRow(item: $0) }
                }
                .padding(.leading, 12)
                .overlay(alignment: .leading) { Rectangle().fill(Theme.line).frame(width: 1) }
            }
        }
    }
}

/// One thing the agent did. Click it to see the tool, what it was given and what came back.
private struct StepRow: View {
    let item: ChatItem
    @State private var open = false
    @State private var hover = false

    private var expandable: Bool { !item.details.isEmpty || !(item.result ?? "").isEmpty || !item.images.isEmpty }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button { if expandable { open.toggle() } } label: {
                HStack(spacing: 8) {
                    Group {
                        if item.state == .running { ProgressView().controlSize(.mini) } else { Image(systemName: item.icon) }
                    }
                    .frame(width: 18)
                    Text(item.text).lineLimit(open ? 3 : 1).multilineTextAlignment(.leading)
                    if expandable {
                        Image(systemName: "chevron.right").font(.system(size: 8.5 * Theme.scale, weight: .bold)).foregroundStyle(Theme.faint)
                            .rotationEffect(.degrees(open ? 90 : 0))
                    }
                    Spacer(minLength: 0)
                }
                .font(.system(size: 13 * Theme.scale))
                .foregroundStyle(item.state == .failed ? Theme.amber : hover ? Theme.text : Theme.dim)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .onHover { hover = $0 }

            if open {
                VStack(alignment: .leading, spacing: 8) {
                    if let tool = item.tool {
                        Text(tool).font(.system(size: 12 * Theme.scale, weight: .medium, design: .monospaced)).foregroundStyle(Theme.green)
                    }
                    if !item.details.isEmpty {
                        Text(item.details.joined(separator: "\n")).foregroundStyle(Theme.dim).lineLimit(14)
                    }
                    if let result = item.result, !result.isEmpty {
                        Hairline()
                        Text(String(result.prefix(1400))).foregroundStyle(Theme.dim).lineLimit(18)
                    }
                    ForEach(item.images, id: \.self) { path in picture(path, height: 280) }
                }
                .font(.system(size: 11.5 * Theme.scale, design: .monospaced)).textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
                .panel(padding: 12, radius: 10)
                .padding(.leading, 26)
            } else if item.showsImage, let path = item.images.first {
                picture(path, height: 150).padding(.leading, 26)
            }
        }
    }

    @ViewBuilder private func picture(_ path: String, height: CGFloat) -> some View {
        if let image = Images.load(path) {
            Image(nsImage: image).resizable().aspectRatio(contentMode: .fit)
                .frame(maxHeight: height).clipShape(RoundedRectangle(cornerRadius: 8))
        }
    }
}

// MARK: - Empty chat

/// A workflow as something to click: what it is, what it does, and where it stands.
struct WorkflowRow: View {
    let flow: ToolGuide.Workflow
    var outlined = true
    let action: () -> Void
    @EnvironmentObject var app: AppState

    var body: some View {
        let state = app.state(of: flow)
        let done = state.note == "Done"
        Button(action: action) {
            HStack(spacing: 12) {
                if done {
                    Image(systemName: "checkmark.circle.fill").font(.system(size: 17 * Theme.scale)).foregroundStyle(Theme.green).frame(width: 30, height: 30)
                } else {
                    IconTile(name: flow.icon, size: 30).opacity(state.ready ? 1 : 0.5)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(flow.title).font(.system(size: 13.5 * Theme.scale, weight: .medium)).foregroundStyle(state.ready || done ? Theme.text : Theme.dim)
                    // A workflow that cannot run says why, in place of what it does.
                    Text(state.ready || done ? flow.summary : state.note + ".").font(.system(size: 12.5 * Theme.scale))
                        .foregroundStyle(state.ready ? Theme.dim : Theme.faint)
                        .lineLimit(outlined ? 2 : 1).multilineTextAlignment(.leading)
                }
                Spacer(minLength: 8)
                if done {
                    Text("Done").font(.system(size: 12 * Theme.scale, weight: .medium)).foregroundStyle(Theme.green)
                } else if state.ready, !state.note.isEmpty {
                    Text(state.note).font(.system(size: 12 * Theme.scale, weight: .medium)).foregroundStyle(Theme.tan).lineLimit(1).fixedSize()
                }
            }
            .padding(.vertical, 6)
        }
        .buttonStyle(RowButton())
        .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(outlined ? Theme.line : .clear))
        .disabled(!state.ready)
    }
}

/// What a new chat shows: the workflows that make sense right now, and a few questions to try.
private struct EmptyChat: View {
    @EnvironmentObject var app: AppState
    @EnvironmentObject var store: ProjectStore

    private var flows: [ToolGuide.Workflow] {
        let all = ToolGuide.workflows
        guard store.current != nil else { return all.filter { $0.scope == .general && $0.id != "research" } }
        let ready = all.filter { $0.scope == .project && app.state(of: $0).ready }
        if store.status.tiles == 0 { return ready.filter { ["full", "terrain"].contains($0.id) } }
        return Array(ready.filter { !["full", "terrain"].contains($0.id) }.prefix(4))
    }

    private var heading: (String, String) {
        if store.current == nil {
            return ("What are you looking for?", "Every chat has the archaeology tools, so the agent can look things up in the open data as it answers.")
        }
        if store.status.tiles == 0, !store.terrains.isEmpty {
            return ("Where should we start?", "The bare ground is built but not cut into tiles yet. Cut it from the map, or run the whole search.")
        }
        if store.status.tiles == 0 {
            return ("Where should we start?", "This project has no terrain yet. The agent can find open lidar for its area and build the bare ground.")
        }
        return ("What next?", "Tell the agent what to do, or run the next part of the search.")
    }

    /// Questions that show what the tools can answer before there is a project.
    private let questions: [(String, String)] = [
        ("map", "Is there open lidar over the Newark Earthworks in Ohio?"),
        ("airplane", "Which open surveys cover the Maya lowlands, and what is recorded near each?"),
        ("building.columns", "Which open archives do archaeologists use, and how big are they?"),
        ("book", "What has been published about Angel Mounds in Indiana?"),
    ]

    var body: some View {
        if store.current != nil { ProjectOverview() } else { generalStart }
    }

    private var generalStart: some View {
        GeometryReader { geo in
            ScrollView {
                VStack(spacing: 22) {
                    VStack(spacing: 8) {
                        if store.current == nil { MoundMark(lively: true).frame(width: 64, height: 28).padding(.bottom, 4) }
                        Text(heading.0).font(.system(size: 26 * Theme.scale, weight: .semibold))
                        Text(heading.1).font(.system(size: 14 * Theme.scale)).foregroundStyle(Theme.dim).multilineTextAlignment(.center).lineSpacing(2)
                            .fixedSize(horizontal: false, vertical: true).frame(maxWidth: 520)
                    }
                    if store.current == nil { general }
                }
                .padding(.horizontal, 24).padding(.vertical, 24)
                .frame(maxWidth: .infinity, minHeight: geo.size.height)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var general: some View {
        VStack(alignment: .leading, spacing: 18) {
            if let research = ToolGuide.workflows.first(where: { $0.id == "research" }) {
                StartTile(icon: research.icon, title: research.title, text: research.summary, strong: true) { app.run(research) }
            }
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 190), spacing: 10, alignment: .top)], spacing: 10) {
                ForEach(flows) { flow in
                    StartTile(icon: flow.icon, title: flow.title, text: flow.summary) { app.run(flow) }
                }
            }
            VStack(alignment: .leading, spacing: 4) {
                Text("Or ask a question").font(.system(size: 12 * Theme.scale, weight: .semibold)).foregroundStyle(Theme.faint).padding(.leading, 10)
                VStack(spacing: 0) {
                    ForEach(Array(questions.enumerated()), id: \.offset) { index, question in
                        if index > 0 { Hairline().padding(.leading, 40) }
                        Button { app.ask(question.1) } label: {
                            HStack(spacing: 12) {
                                Image(systemName: question.0).font(.system(size: 12 * Theme.scale)).foregroundStyle(Theme.tan).frame(width: 18)
                                Text(question.1).font(.system(size: 13.5 * Theme.scale)).multilineTextAlignment(.leading)
                                Spacer(minLength: 8)
                                Image(systemName: "arrow.up").font(.system(size: 10 * Theme.scale, weight: .bold)).foregroundStyle(Theme.faint)
                            }
                            .padding(.vertical, 5)
                        }
                        .buttonStyle(RowButton())
                    }
                }
                .padding(4).panel(radius: 12)
            }
        }
        .frame(maxWidth: 640)
    }
}

/// A card that starts something: an icon, a title, and one or two lines on what happens.
struct StartTile: View {
    let icon: String, title: String, text: String
    var strong = false
    let action: () -> Void
    @State private var hover = false

    var body: some View {
        Button(action: action) {
            Group {
                if strong {
                    HStack(alignment: .center, spacing: 14) {
                        IconTile(name: icon, size: 42)
                        words
                        Spacer(minLength: 8)
                        Image(systemName: "arrow.right").font(.system(size: 13 * Theme.scale, weight: .semibold)).foregroundStyle(Theme.tan)
                    }
                } else {
                    VStack(alignment: .leading, spacing: 10) {
                        IconTile(name: icon, size: 30)
                        words
                    }
                }
            }
            .padding(14).frame(maxWidth: .infinity, minHeight: strong ? 0 : 128, alignment: .topLeading)
            .background(RoundedRectangle(cornerRadius: 14).fill(Theme.ink.opacity(hover ? 0.08 : strong ? 0.055 : 0.035)))
            .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(strong ? Theme.tan.opacity(hover ? 0.9 : 0.5) : hover ? Theme.ink.opacity(0.22) : Theme.line))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hover = $0 }
        .animation(.easeOut(duration: 0.12), value: hover)
    }

    private var words: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title).font(.system(size: strong ? 15.5 : 13.5, weight: .semibold))
            Text(text).font(.system(size: 12.5 * Theme.scale)).foregroundStyle(Theme.dim).lineSpacing(2)
                .multilineTextAlignment(.leading).fixedSize(horizontal: false, vertical: true)
        }
    }
}

// MARK: - Message box

enum Effort {
    static func label(_ id: String) -> String {
        id == "xhigh" ? "Extra high" : id.prefix(1).uppercased() + id.dropFirst()
    }

    static func short(_ id: String) -> String {
        id == "xhigh" ? "X-high" : id == "medium" ? "Med" : label(id)
    }

    static func note(_ id: String) -> String {
        switch id {
        case "low", "minimal": return "Quick answers. Good for lookups and questions."
        case "medium": return "A balance of speed and care. Good for most runs."
        case "high": return "More careful. Good for screening and checks."
        default: return "Slowest and most thorough. For hard judgement calls."
        }
    }
}

/// Whether the chosen step was tested with this model, so a step on the list is not taken as working.
private struct EffortTestLine: View {
    @EnvironmentObject var app: AppState
    let model: ModelInfo, effort: String

    var body: some View {
        if let check = app.modelChecks[model.id], check.effort == effort {
            Text(check.ok ? "Tested at this step: it answered." : "Failed its test at this step. See Settings.")
                .font(.system(size: 11.5 * Theme.scale)).foregroundStyle(check.ok ? Theme.faint : Theme.amber)
        } else {
            Text("Not tested at this step. Settings can test it.").font(.system(size: 11.5 * Theme.scale)).foregroundStyle(Theme.faint)
        }
    }
}

/// One pill for the model and how hard it thinks. It opens a slider for effort, with the model list behind the name.
struct ModelControl: View {
    @EnvironmentObject var app: AppState
    @EnvironmentObject var engine: Engine
    @State private var open = false
    @State private var listing = false

    var body: some View {
        Button {
            listing = app.activeEffort == nil
            open = true
        } label: {
            HStack(spacing: 6) {
                Text(app.modelName).foregroundStyle(Theme.text).lineLimit(1)
                if let effort = app.activeEffort { Text(Effort.label(effort)).foregroundStyle(Theme.faint).lineLimit(1) }
                Image(systemName: "chevron.down").font(.system(size: 8.5 * Theme.scale, weight: .bold)).foregroundStyle(Theme.dim)
            }
            .font(.system(size: 12.5 * Theme.scale))
            .padding(.horizontal, 12).frame(height: 30)
            .background(Capsule().fill(Theme.ink.opacity(open ? 0.12 : 0.06)))
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .help("Choose the model and how hard it thinks")
        .onChange(of: app.pickerRequest) { _, request in
            guard let request else { return }
            listing = request == .model || app.activeEffort == nil
            open = true
            app.pickerRequest = nil
        }
        .popover(isPresented: $open, arrowEdge: .top) {
            Group {
                if listing {
                    ModelList(models: engine.models, current: app.model?.id, checks: app.modelChecks) { model in
                        app.modelID = model.id
                        if model.efforts.isEmpty { open = false } else { listing = false }
                    }
                } else if let model = app.model, let effort = app.activeEffort {
                    VStack(spacing: 16) {
                        VStack(spacing: 5) {
                            Text(Effort.label(effort)).font(.system(size: 22 * Theme.scale, weight: .semibold)).foregroundStyle(Theme.accent)
                            Button { listing = true } label: {
                                HStack(spacing: 5) {
                                    Text(model.name)
                                    Image(systemName: "chevron.right").font(.system(size: 10 * Theme.scale, weight: .semibold))
                                }
                                .font(.system(size: 14.5 * Theme.scale)).foregroundStyle(Theme.dim).contentShape(Rectangle())
                            }
                            .buttonStyle(.plain).help("Choose another model")
                        }
                        StepSlider(steps: model.efforts, value: Binding(get: { effort }, set: { app.effort = $0 }), showLabels: true)
                        Text(Effort.note(effort)).font(.system(size: 12 * Theme.scale)).foregroundStyle(Theme.faint)
                        EffortTestLine(model: model, effort: effort)
                        Text("The steps are the ones your model list gives for this model.").font(.system(size: 11 * Theme.scale)).foregroundStyle(Theme.faint.opacity(0.8))
                    }
                    .padding(.horizontal, 20).padding(.vertical, 18).frame(width: 340)
                }
            }
            .foregroundStyle(Theme.text)
            .popoverSurface()
        }
    }
}

struct Composer: View {
    @EnvironmentObject var app: AppState
    @EnvironmentObject var chat: ChatModel
    @EnvironmentObject var store: ProjectStore
    @State private var showFlows = false
    @State private var dropping = false
    /// The highlighted row in the command list, and the draft at which Escape closed it.
    @State private var selected = 0
    @State private var dismissed: String?
    @State private var keys: Any?
    /// What "@" can point at in the open project, read when the list opens, and the mentions picked so far.
    @State private var pool: [Mention] = []
    @State private var picked: [Mention] = []
    @FocusState private var focused: Bool

    private var commands: [SlashCommand] { dismissed == chat.draft ? [] : SlashCommands.matches(chat.draft) }
    private var mentions: [Mention] {
        guard dismissed != chat.draft, let q = Mentions.query(chat.draft) else { return [] }
        return Mentions.matches(q, in: pool)
    }
    /// How many rows the open list has, commands or mentions.
    private var listCount: Int { commands.isEmpty ? mentions.count : commands.count }
    /// The mentions picked that are still in the draft, shown as chips.
    private var shownMentions: [Mention] { picked.filter { chat.draft.contains("@" + $0.label) } }
    /// Text typed on Home that reads like a place name: short, no question, not a command.
    private var typedPlace: String? {
        guard app.route == .home else { return nil }
        let text = chat.draft.trimmingCharacters(in: .whitespacesAndNewlines)
        let words = text.split(separator: " ")
        guard (1...5).contains(words.count), text.count >= 3, !text.contains("?"), !text.hasPrefix("/"), !text.hasPrefix("@") else { return nil }
        let asks = ["what", "how", "why", "which", "where", "who", "can", "should", "show", "find", "tell", "help", "is", "are", "do", "list"]
        return asks.contains(words[0].lowercased()) ? nil : text
    }

    private var canSend: Bool {
        !chat.draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || !chat.attachments.isEmpty
    }

    private var placeholder: String {
        if chat.running { return "Steer the run" }
        return store.current == nil ? "Ask about a place, a survey, or what to search" : "Ask the agent to search, check or explain"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if !commands.isEmpty { commandList }
            else if !mentions.isEmpty { mentionList }
            else if let place = typedPlace {
                // On Home, short text that looks like a place can start a project there.
                Button { chat.draft = ""; app.startProject(at: place) } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "mappin.and.ellipse").font(.system(size: 12 * Theme.scale)).foregroundStyle(Theme.tan)
                        Text("Start a project at \(place)").font(.system(size: 13 * Theme.scale, weight: .medium))
                        Spacer()
                        Text("or press Return to ask the agent").font(.system(size: 12 * Theme.scale)).foregroundStyle(Theme.faint)
                    }
                    .padding(.horizontal, 10).frame(height: 30)
                    .background(RoundedRectangle(cornerRadius: 8).fill(Theme.ink.opacity(0.06)))
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            if !chat.attachments.isEmpty || !shownMentions.isEmpty { chips }
            TextField(placeholder, text: $chat.draft, axis: .vertical)
                .textFieldStyle(.plain).lineLimit(1...8).font(.system(size: 14 * Theme.scale))
                .focused($focused).onSubmit { listCount == 0 ? send() : runSelected() }
                .padding(.horizontal, 4)
            ViewThatFits(in: .horizontal) {
                controls(wide: true)
                controls(wide: false)
            }
        }
        .padding(.horizontal, 12).padding(.top, 13).padding(.bottom, 9)
        .background(RoundedRectangle(cornerRadius: 24).fill(Theme.raised))
        .overlay(RoundedRectangle(cornerRadius: 24).strokeBorder(dropping ? Theme.accent : Theme.line, lineWidth: dropping ? 1.5 : 1))
        .onDrop(of: [.fileURL], isTargeted: $dropping) { providers in
            for provider in providers {
                _ = provider.loadObject(ofClass: URL.self) { url, _ in
                    guard let url else { return }
                    Task { @MainActor in chat.attach(url.path) }
                }
            }
            return true
        }
        .onAppear { focused = true }
        .onChange(of: chat.draft) { _, draft in
            if Mentions.query(draft) != nil, pool.isEmpty { pool = Mentions.pool(store: store) }
            if Mentions.query(draft) == nil, commands.isEmpty { pool = [] }
            selected = commands.isEmpty ? 0 : commands.firstIndex { app.unavailable($0) == nil } ?? 0
            if dismissed != draft { dismissed = nil }
            if draft.isEmpty { picked = [] }
        }
        .onChange(of: listCount == 0) { _, empty in empty ? stopKeys() : startKeys() }
        .onDisappear { stopKeys() }
    }

    // MARK: @ mentions

    private var mentionList: some View {
        let list = mentions
        return ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 1) {
                    ForEach(Array(list.enumerated()), id: \.element.id) { index, m in
                        Button { selected = index; runSelected() } label: {
                            HStack(spacing: 10) {
                                Image(systemName: m.icon).font(.system(size: 12 * Theme.scale)).foregroundStyle(Theme.tan).frame(width: 16)
                                Text(m.label).font(.system(size: 13 * Theme.scale, weight: .medium)).foregroundStyle(Theme.text).lineLimit(1)
                                Text(m.detail).font(.system(size: 12.5 * Theme.scale)).foregroundStyle(Theme.dim).lineLimit(1)
                                Spacer(minLength: 8)
                                Text(m.kind.rawValue).font(.system(size: 12 * Theme.scale)).foregroundStyle(Theme.faint)
                            }
                            .padding(.horizontal, 10).frame(height: 30)
                            .background(RoundedRectangle(cornerRadius: 8).fill(index == selected ? Theme.ink.opacity(0.09) : .clear))
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain).id(m.id)
                    }
                }
            }
            .frame(maxHeight: min(CGFloat(list.count) * 31, 280))
            .onChange(of: selected) { _, i in if list.indices.contains(i) { proxy.scrollTo(list[i].id) } }
        }
        .padding(.bottom, 2)
    }

    // MARK: slash commands

    private var commandList: some View {
        let list = commands
        return ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 1) {
                    ForEach(Array(list.enumerated()), id: \.element.id) { index, c in
                        let reason = app.unavailable(c)
                        Button { selected = index; runSelected() } label: {
                            HStack(alignment: .firstTextBaseline, spacing: 10) {
                                Text(c.name).font(.system(size: 13 * Theme.scale, weight: .medium, design: .monospaced))
                                    .foregroundStyle(reason == nil ? Theme.text : Theme.faint)
                                if let arg = c.argument {
                                    Text(arg).font(.system(size: 12.5 * Theme.scale)).foregroundStyle(Theme.faint)
                                }
                                Text(c.summary).font(.system(size: 12.5 * Theme.scale)).foregroundStyle(reason == nil ? Theme.dim : Theme.faint).lineLimit(1)
                                Spacer(minLength: 8)
                                if let reason { Text(reason).font(.system(size: 12 * Theme.scale)).foregroundStyle(Theme.faint).lineLimit(1) }
                            }
                            .padding(.horizontal, 10).frame(height: 30)
                            .background(RoundedRectangle(cornerRadius: 8).fill(index == selected ? Theme.ink.opacity(0.09) : .clear))
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain).id(c.id)
                    }
                }
            }
            .frame(maxHeight: min(CGFloat(list.count) * 31, 280))
            .onChange(of: selected) { _, i in if list.indices.contains(i) { proxy.scrollTo(list[i].id) } }
        }
        .padding(.bottom, 2)
    }

    private func runSelected() {
        if commands.isEmpty {
            let list = mentions
            guard list.indices.contains(selected) else { return }
            let m = list[selected]
            chat.draft = Mentions.insert(m, into: chat.draft)
            if !picked.contains(m) { picked.append(m) }
            return
        }
        let list = commands
        guard list.indices.contains(selected), let (_, argument) = SlashCommands.parse(chat.draft) else { return }
        let c = list[selected]
        guard app.unavailable(c) == nil else { return }
        if c.needsArgument && argument.isEmpty {
            chat.draft = c.name + " "
            dismissed = chat.draft
            return
        }
        chat.draft = ""
        app.perform(c, argument: argument)
    }

    /// While the command list is open, the arrow keys move through it, Tab fills in the name and Escape closes it.
    private func startKeys() {
        guard keys == nil else { return }
        keys = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            guard focused, listCount > 0 else { return event }
            switch event.keyCode {
            case 126: selected = max(0, selected - 1); return nil
            case 125: selected = min(listCount - 1, selected + 1); return nil
            case 53: dismissed = chat.draft; return nil
            case 48:
                if commands.indices.contains(selected) { chat.draft = commands[selected].name + " " } else { runSelected() }
                return nil
            case 36, 76: runSelected(); return nil
            default: return event
            }
        }
    }

    private func stopKeys() {
        if let keys { NSEvent.removeMonitor(keys) }
        keys = nil
    }

    private var chips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(shownMentions) { m in
                    HStack(spacing: 6) {
                        Image(systemName: m.icon).font(.system(size: 11 * Theme.scale)).foregroundStyle(Theme.tan)
                        Text("@" + m.label).font(.system(size: 12 * Theme.scale)).lineLimit(1).frame(maxWidth: 180, alignment: .leading)
                        Button {
                            chat.draft = chat.draft.replacingOccurrences(of: "@" + m.label, with: m.label)
                            picked.removeAll { $0 == m }
                        } label: {
                            Image(systemName: "xmark").font(.system(size: 9 * Theme.scale, weight: .bold)).foregroundStyle(Theme.dim)
                                .frame(width: 16, height: 16).contentShape(Rectangle())
                        }
                        .buttonStyle(.plain).help("Keep the words, drop the link")
                    }
                    .padding(.horizontal, 9).frame(height: 30)
                    .background(Capsule().fill(Theme.tan.opacity(0.12)))
                    .overlay(Capsule().strokeBorder(Theme.tan.opacity(0.3)))
                    .help(m.reference)
                }
                ForEach(chat.attachments) { file in
                    HStack(spacing: 7) {
                        if file.kind == .image, let image = Images.load(file.path) {
                            Image(nsImage: image).resizable().aspectRatio(contentMode: .fill)
                                .frame(width: 30, height: 30).clipShape(RoundedRectangle(cornerRadius: 6))
                        } else {
                            Image(systemName: file.icon).font(.system(size: 13 * Theme.scale)).foregroundStyle(Theme.tan).frame(width: 30, height: 30)
                                .background(RoundedRectangle(cornerRadius: 6).fill(Theme.ink.opacity(0.07)))
                        }
                        Text(file.name).font(.system(size: 12 * Theme.scale)).lineLimit(1).frame(maxWidth: 150, alignment: .leading)
                        Button { chat.attachments.removeAll { $0 == file } } label: {
                            Image(systemName: "xmark").font(.system(size: 9 * Theme.scale, weight: .bold)).foregroundStyle(Theme.dim)
                                .frame(width: 18, height: 18).contentShape(Rectangle())
                        }
                        .buttonStyle(.plain).help("Remove")
                    }
                    .padding(.leading, 5).padding(.trailing, 6).frame(height: 40)
                    .background(RoundedRectangle(cornerRadius: 10).fill(Theme.ink.opacity(0.05)))
                    .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(Theme.line))
                }
            }
        }
    }

    private func controls(wide: Bool) -> some View {
        HStack(spacing: 2) {
            Menu {
                Button("Attach files…", action: attachFiles)
                if let tile = store.selectedTile, let root = store.current?.path {
                    Button("Attach the selected tile") { chat.attach("\(root)/data/tiles/\(tile)-composite.png") }
                }
                if let c = store.candidates.first(where: { $0.id == store.selectedCandidate }) {
                    Button("Attach the section through \(c.id)") { chat.attach(c.section) }
                }
            } label: {
                Image(systemName: "plus").font(.system(size: 15 * Theme.scale, weight: .medium)).foregroundStyle(Theme.dim)
                    .frame(width: 30, height: 30).contentShape(Rectangle())
            }
            .menuStyle(.button).buttonStyle(.plain).menuIndicator(.hidden).fixedSize()
            .help("Attach images, video, audio or any file. You can also drop files here.")

            Button { showFlows.toggle() } label: {
                HStack(spacing: 5) {
                    Image(systemName: "point.3.connected.trianglepath.dotted").font(.system(size: 12 * Theme.scale))
                    if wide { Text("Workflows").font(.system(size: 12.5 * Theme.scale)) }
                }
                .foregroundStyle(Theme.dim).padding(.horizontal, 8).frame(height: 30).contentShape(Rectangle())
            }
            .buttonStyle(.plain).help("Run a workflow")
            .popover(isPresented: $showFlows, arrowEdge: .top) {
                WorkflowMenu { showFlows = false }.withApp(app).popoverSurface()
            }

            Spacer(minLength: 4)

            if chat.preparing {
                ProgressView().controlSize(.small).padding(.trailing, 4).help("Reading the attachments")
            }
            ModelControl()
            if chat.running && !canSend {
                Button { Task { await chat.stop() } } label: {
                    Image(systemName: "stop.fill").font(.system(size: 11 * Theme.scale)).foregroundStyle(.black)
                        .frame(width: 30, height: 30).background(Circle().fill(Theme.primary))
                }
                .buttonStyle(.plain).help("Stop the run").padding(.leading, 6)
            } else {
                Button(action: send) {
                    Image(systemName: "arrow.up").font(.system(size: 13 * Theme.scale, weight: .bold)).foregroundStyle(.black)
                        .frame(width: 30, height: 30).background(Circle().fill(canSend ? Color.white : Theme.ink.opacity(0.25)))
                }
                .buttonStyle(.plain).disabled(!canSend).padding(.leading, 6)
                .help(chat.running ? "Send this to the running agent" : "Send")
            }
        }
    }

    private func send() {
        guard canSend else { return }
        let text = Mentions.expand(chat.draft, with: picked)
        chat.draft = ""
        picked = []
        app.ask(text)
    }

    private func attachFiles() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        panel.message = "Images, video, audio, or any file the agent should read."
        if panel.runModal() == .OK { panel.urls.forEach { chat.attach($0.path) } }
    }
}

/// The workflows that fit the open chat. Picking one starts it.
private struct WorkflowMenu: View {
    @EnvironmentObject var app: AppState
    @EnvironmentObject var store: ProjectStore
    let close: () -> Void

    private var flows: [ToolGuide.Workflow] {
        ToolGuide.workflows.filter { $0.scope == (store.current == nil ? .general : .project) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(store.current == nil ? "Workflows" : "Workflows for this project")
                .font(.system(size: 13 * Theme.scale)).foregroundStyle(Theme.faint).padding(.horizontal, 10).padding(.vertical, 4)
            ScrollView {
                VStack(spacing: 1) {
                    ForEach(flows) { flow in
                        WorkflowRow(flow: flow, outlined: false) {
                            close()
                            app.run(flow)
                        }
                    }
                }
            }
            .frame(maxHeight: 400)
            Hairline().padding(.vertical, 4)
            Button {
                close()
                app.show(.toolbox)
            } label: {
                Label("Open the Toolbox", systemImage: "wrench.and.screwdriver").font(.system(size: 13 * Theme.scale))
            }
            .buttonStyle(RowButton())
        }
        .padding(8).frame(width: 440)
        .foregroundStyle(Theme.text)
    }
}


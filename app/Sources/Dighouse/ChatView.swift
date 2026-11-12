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
                    Text("Opening the chat").font(.system(size: 13)).foregroundStyle(Theme.faint)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if chat.items.isEmpty { EmptyChat() } else { Messages() }
            if let approval = chat.approval {
                VStack(alignment: .leading, spacing: 10) {
                    Text(approval.message).font(.system(size: 13))
                    HStack(spacing: 8) {
                        Button("Allow") { chat.answer(true) }.buttonStyle(PrimaryButton())
                        Button("Decline") { chat.answer(false) }.buttonStyle(SecondaryButton())
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading).panel(padding: 14)
                .frame(maxWidth: 760).padding(.horizontal, 16).padding(.bottom, 8)
            }
            Composer().frame(maxWidth: 760).padding(.horizontal, 16).padding(.top, 4).padding(.bottom, 14)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.bg)
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

    /// What the agent is on now, taken from its plan when it keeps one.
    private var working: String {
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
                            Text(working).font(.system(size: 13)).foregroundStyle(Theme.faint).lineLimit(1)
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
                            Label(name, systemImage: Attachment(path: name).icon).font(.system(size: 12)).lineLimit(1)
                                .padding(.horizontal, 10).frame(height: 28)
                                .background(Capsule().fill(Color.white.opacity(0.06)))
                        }
                    }
                }
                if !item.text.isEmpty {
                    Text(item.text).font(.system(size: 14)).lineSpacing(3).textSelection(.enabled)
                        .padding(.horizontal, 14).padding(.vertical, 9)
                        .background(RoundedRectangle(cornerRadius: 18).fill(Theme.raised))
                        .frame(maxWidth: 520, alignment: .trailing)
                }
            }
            .frame(maxWidth: .infinity, alignment: .trailing)
            .padding(.vertical, 4)
        case .agent:
            MarkdownText(text: item.text).frame(maxWidth: .infinity, alignment: .leading).padding(.vertical, 2)
        case .plan:
            PlanCard(item: item)
        case .step:
            if let path = item.projectPath {
                StepRow(item: item)
                ProjectCard(path: path)
            } else {
                StepRow(item: item)
            }
        }
    }
}

/// The agent's plan for a run, ticked off as it goes.
private struct PlanCard: View {
    let item: ChatItem

    private var done: Int { item.plan.filter { $0.status == "completed" }.count }

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack {
                Label("Plan", systemImage: "list.bullet.clipboard").font(.system(size: 12.5, weight: .semibold))
                Spacer()
                Text("\(done) of \(item.plan.count) done").font(.system(size: 12)).foregroundStyle(Theme.faint)
            }
            ForEach(Array(item.plan.enumerated()), id: \.offset) { _, step in
                HStack(alignment: .firstTextBaseline, spacing: 9) {
                    Image(systemName: step.status == "completed" ? "checkmark.circle.fill"
                          : step.status.lowercased().contains("progress") ? "circle.dotted.circle" : "circle")
                        .font(.system(size: 13))
                        .foregroundStyle(step.status == "completed" ? Theme.green
                                         : step.status.lowercased().contains("progress") ? Theme.accent : Theme.faint)
                        .frame(width: 16)
                    Text(step.text).font(.system(size: 13))
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
                Text(project?.name ?? URL(fileURLWithPath: path).lastPathComponent).font(.system(size: 13.5, weight: .semibold))
                Text("Project created. Open it to work with its map and records beside the chat.")
                    .font(.system(size: 12.5)).foregroundStyle(Theme.dim).fixedSize(horizontal: false, vertical: true)
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
                    Image(systemName: "chevron.right").font(.system(size: 8.5, weight: .bold)).foregroundStyle(Theme.faint)
                        .rotationEffect(.degrees(open ? 90 : 0))
                    Spacer(minLength: 0)
                }
                .font(.system(size: 13)).foregroundStyle(hover ? Theme.text : Theme.dim)
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
                        Image(systemName: "chevron.right").font(.system(size: 8.5, weight: .bold)).foregroundStyle(Theme.faint)
                            .rotationEffect(.degrees(open ? 90 : 0))
                    }
                    Spacer(minLength: 0)
                }
                .font(.system(size: 13))
                .foregroundStyle(item.state == .failed ? Theme.amber : hover ? Theme.text : Theme.dim)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .onHover { hover = $0 }

            if open {
                VStack(alignment: .leading, spacing: 8) {
                    if let tool = item.tool {
                        Text(tool).font(.system(size: 12, weight: .medium, design: .monospaced)).foregroundStyle(Theme.green)
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
                .font(.system(size: 11.5, design: .monospaced)).textSelection(.enabled)
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
        Button(action: action) {
            HStack(spacing: 12) {
                IconTile(name: flow.icon, size: 30)
                VStack(alignment: .leading, spacing: 2) {
                    Text(flow.title).font(.system(size: 13.5, weight: .medium))
                    Text(flow.summary).font(.system(size: 12.5)).foregroundStyle(Theme.dim)
                        .lineLimit(2).multilineTextAlignment(.leading)
                }
                Spacer(minLength: 4)
                if !state.note.isEmpty { Badge(text: state.note, color: state.note == "Done" ? Theme.green : Theme.dim) }
            }
            .padding(.vertical, 6)
            .opacity(state.ready ? 1 : 0.5)
        }
        .buttonStyle(RowButton())
        .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(outlined ? Theme.line : .clear))
        .disabled(!state.ready)
    }
}

/// What a new chat shows: the workflows that make sense right now.
private struct EmptyChat: View {
    @EnvironmentObject var app: AppState
    @EnvironmentObject var store: ProjectStore

    private var flows: [ToolGuide.Workflow] {
        let all = ToolGuide.workflows
        guard store.current != nil else { return all.filter { $0.scope == .general } }
        let ready = all.filter { $0.scope == .project && app.state(of: $0).ready }
        if store.status.tiles == 0 { return ready.filter { ["full", "terrain"].contains($0.id) } }
        return Array(ready.filter { !["full", "terrain"].contains($0.id) }.prefix(4))
    }

    private var heading: (String, String) {
        if store.current == nil {
            return ("What are you looking for?", "Ask anything, or begin with one of these. The archaeology tools work in every chat.")
        }
        if store.status.tiles == 0 {
            return ("Where should we start?", "This project has no terrain yet. The agent can find open lidar for its area and build the bare ground.")
        }
        return ("What next?", "Tell the agent what to do, or run the next part of the search.")
    }

    var body: some View {
        GeometryReader { geo in
            ScrollView {
                VStack(spacing: 22) {
                    VStack(spacing: 8) {
                        Text(heading.0).font(.system(size: 26, weight: .semibold))
                        Text(heading.1).font(.system(size: 14)).foregroundStyle(Theme.dim).multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    VStack(spacing: 8) {
                        ForEach(flows) { flow in WorkflowRow(flow: flow) { app.run(flow) } }
                    }
                    .frame(maxWidth: 540)
                }
                .padding(.horizontal, 24).padding(.vertical, 24)
                .frame(maxWidth: .infinity, minHeight: geo.size.height)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Message box

enum Effort {
    static func label(_ id: String) -> String {
        id == "xhigh" ? "Extra high" : id.prefix(1).uppercased() + id.dropFirst()
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
                Image(systemName: "chevron.down").font(.system(size: 8.5, weight: .bold)).foregroundStyle(Theme.dim)
            }
            .font(.system(size: 12.5))
            .padding(.horizontal, 12).frame(height: 30)
            .background(Capsule().fill(Color.white.opacity(open ? 0.12 : 0.06)))
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .help("Choose the model and how hard it thinks")
        .popover(isPresented: $open, arrowEdge: .top) {
            Group {
                if listing {
                    ModelList(models: engine.models, current: app.model?.id) { model in
                        app.modelID = model.id
                        if model.efforts.isEmpty { open = false } else { listing = false }
                    }
                } else if let model = app.model, let effort = app.activeEffort {
                    VStack(spacing: 16) {
                        VStack(spacing: 5) {
                            Text(Effort.label(effort)).font(.system(size: 22, weight: .semibold)).foregroundStyle(Theme.accent)
                            Button { listing = true } label: {
                                HStack(spacing: 5) {
                                    Text(model.name)
                                    Image(systemName: "chevron.right").font(.system(size: 10, weight: .semibold))
                                }
                                .font(.system(size: 14.5)).foregroundStyle(Theme.dim).contentShape(Rectangle())
                            }
                            .buttonStyle(.plain).help("Choose another model")
                        }
                        StepSlider(steps: model.efforts, value: Binding(get: { effort }, set: { app.effort = $0 }))
                        Text(Effort.note(effort)).font(.system(size: 12)).foregroundStyle(Theme.faint)
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
    @FocusState private var focused: Bool

    private var canSend: Bool {
        !chat.draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || !chat.attachments.isEmpty
    }

    private var placeholder: String {
        if chat.running { return "Steer the run" }
        return store.current == nil ? "Ask about a place, a survey, or what to search" : "Ask the agent to search, check or explain"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if !chat.attachments.isEmpty { chips }
            TextField(placeholder, text: $chat.draft, axis: .vertical)
                .textFieldStyle(.plain).lineLimit(1...8).font(.system(size: 14))
                .focused($focused).onSubmit(send)
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
    }

    private var chips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(chat.attachments) { file in
                    HStack(spacing: 7) {
                        if file.kind == .image, let image = Images.load(file.path) {
                            Image(nsImage: image).resizable().aspectRatio(contentMode: .fill)
                                .frame(width: 30, height: 30).clipShape(RoundedRectangle(cornerRadius: 6))
                        } else {
                            Image(systemName: file.icon).font(.system(size: 13)).foregroundStyle(Theme.tan).frame(width: 30, height: 30)
                                .background(RoundedRectangle(cornerRadius: 6).fill(Color.white.opacity(0.07)))
                        }
                        Text(file.name).font(.system(size: 12)).lineLimit(1).frame(maxWidth: 150, alignment: .leading)
                        Button { chat.attachments.removeAll { $0 == file } } label: {
                            Image(systemName: "xmark").font(.system(size: 9, weight: .bold)).foregroundStyle(Theme.dim)
                                .frame(width: 18, height: 18).contentShape(Rectangle())
                        }
                        .buttonStyle(.plain).help("Remove")
                    }
                    .padding(.leading, 5).padding(.trailing, 6).frame(height: 40)
                    .background(RoundedRectangle(cornerRadius: 10).fill(Color.white.opacity(0.05)))
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
                Image(systemName: "plus").font(.system(size: 15, weight: .medium)).foregroundStyle(Theme.dim)
                    .frame(width: 30, height: 30).contentShape(Rectangle())
            }
            .menuStyle(.button).buttonStyle(.plain).menuIndicator(.hidden).fixedSize()
            .help("Attach images, video, audio or any file. You can also drop files here.")

            Button { showFlows.toggle() } label: {
                HStack(spacing: 5) {
                    Image(systemName: "point.3.connected.trianglepath.dotted").font(.system(size: 12))
                    if wide { Text("Workflows").font(.system(size: 12.5)) }
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
                    Image(systemName: "stop.fill").font(.system(size: 11)).foregroundStyle(.black)
                        .frame(width: 30, height: 30).background(Circle().fill(.white))
                }
                .buttonStyle(.plain).help("Stop the run").padding(.leading, 6)
            } else {
                Button(action: send) {
                    Image(systemName: "arrow.up").font(.system(size: 13, weight: .bold)).foregroundStyle(.black)
                        .frame(width: 30, height: 30).background(Circle().fill(canSend ? Color.white : Color.white.opacity(0.25)))
                }
                .buttonStyle(.plain).disabled(!canSend).padding(.leading, 6)
                .help(chat.running ? "Send this to the running agent" : "Send")
            }
        }
    }

    private func send() {
        guard canSend else { return }
        let text = chat.draft
        chat.draft = ""
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
                .font(.system(size: 13)).foregroundStyle(Theme.faint).padding(.horizontal, 10).padding(.vertical, 4)
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
                Label("Open the Toolbox", systemImage: "wrench.and.screwdriver").font(.system(size: 13))
            }
            .buttonStyle(RowButton())
        }
        .padding(8).frame(width: 400)
        .foregroundStyle(Theme.text)
    }
}


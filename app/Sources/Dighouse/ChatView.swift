import SwiftUI
import UniformTypeIdentifiers

struct ChatView: View {
    @EnvironmentObject var chat: ChatModel

    var body: some View {
        VStack(spacing: 0) {
            if chat.items.isEmpty { EmptyChat() } else { Messages() }
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

private struct Messages: View {
    @EnvironmentObject var chat: ChatModel

    var body: some View {
        ScrollViewReader { scroll in
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(chat.items) { item in ChatRow(item: item).id(item.id) }
                    if chat.running {
                        HStack(spacing: 8) {
                            ProgressView().controlSize(.small)
                            Text("Working").font(.system(size: 13)).foregroundStyle(Theme.faint)
                        }
                        .padding(.top, 2)
                    }
                    Color.clear.frame(height: 10).id("end")
                }
                .frame(maxWidth: 760, alignment: .leading)
                .padding(.horizontal, 20).padding(.top, 18)
                .frame(maxWidth: .infinity)
            }
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
                        ForEach(Array(item.images.enumerated()), id: \.offset) { _, image in
                            Image(nsImage: image).resizable().aspectRatio(contentMode: .fill)
                                .frame(width: 96, height: 96).clipShape(RoundedRectangle(cornerRadius: 10))
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
        case .step:
            StepRow(item: item)
        }
    }
}

/// One thing the agent did. Click it to see the tool, what it was given and what came back.
private struct StepRow: View {
    let item: ChatItem
    @State private var open = false
    @State private var hover = false

    private var expandable: Bool { !item.details.isEmpty || !(item.result ?? "").isEmpty || !item.images.isEmpty }
    private var showsImage: Bool { ["cut_section", "flag_candidate"].contains(item.tool ?? "") && !item.images.isEmpty }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button { if expandable { open.toggle() } } label: {
                HStack(spacing: 8) {
                    Group {
                        if item.state == .running { ProgressView().controlSize(.mini) } else { Image(systemName: item.icon) }
                    }
                    .frame(width: 18)
                    Text(item.text).lineLimit(1)
                    if let tool = item.tool, hover || open {
                        Text(tool).font(.system(size: 11, design: .monospaced)).foregroundStyle(Theme.faint)
                    }
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
                        Text(item.details.joined(separator: "\n")).foregroundStyle(Theme.dim)
                    }
                    if let result = item.result, !result.isEmpty {
                        Hairline()
                        Text(String(result.prefix(1400))).foregroundStyle(Theme.dim).lineLimit(18)
                    }
                    ForEach(Array(item.images.enumerated()), id: \.offset) { _, image in
                        Image(nsImage: image).resizable().aspectRatio(contentMode: .fit)
                            .frame(maxHeight: 260).clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                }
                .font(.system(size: 11.5, design: .monospaced)).textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
                .panel(padding: 12, radius: 10)
                .padding(.leading, 26)
            } else if showsImage, let image = item.images.first {
                Image(nsImage: image).resizable().aspectRatio(contentMode: .fit)
                    .frame(maxHeight: 150).clipShape(RoundedRectangle(cornerRadius: 8))
                    .padding(.leading, 26)
            }
        }
    }
}

/// What a new chat shows: what the project needs next, as things you can click.
private struct EmptyChat: View {
    @EnvironmentObject var app: AppState
    @EnvironmentObject var store: ProjectStore

    private var ideas: [ToolGuide.Stage] {
        let s = store.status, stages = ToolGuide.stages
        if s.tiles == 0 { return [stages[1], stages[0]] }
        var out: [ToolGuide.Stage] = []
        if s.unscreened > 0 { out.append(stages[2]) }
        if store.candidates.contains(where: { $0.status == "flagged" }) { out += [stages[3], stages[4]] }
        return out + [stages[5]]
    }

    var body: some View {
        VStack(spacing: 22) {
            Spacer(minLength: 0)
            VStack(spacing: 8) {
                Text(store.status.tiles == 0 ? "Where should we start?" : "What next?")
                    .font(.system(size: 26, weight: .semibold))
                Text(store.status.tiles == 0
                     ? "This project has no terrain yet. The agent can find open lidar for its area and build the bare ground."
                     : "Tell the agent what to do, or pick the next stage of the search.")
                    .font(.system(size: 14)).foregroundStyle(Theme.dim).multilineTextAlignment(.center)
            }
            VStack(spacing: 8) {
                ForEach(ideas) { stage in
                    Button { app.ask(stage.prompt) } label: {
                        HStack(spacing: 12) {
                            IconTile(name: stage.icon, size: 30)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(stage.title).font(.system(size: 13.5, weight: .medium))
                                Text(stage.prompt).font(.system(size: 12.5)).foregroundStyle(Theme.dim)
                                    .lineLimit(2).multilineTextAlignment(.leading)
                            }
                            Spacer(minLength: 0)
                            Image(systemName: "arrow.up.right").font(.system(size: 11, weight: .semibold)).foregroundStyle(Theme.faint)
                        }
                        .padding(.vertical, 6)
                    }
                    .buttonStyle(RowButton())
                    .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(Theme.line))
                }
            }
            .frame(maxWidth: 520)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

/// The models, grouped by where they come from when the list is long.
struct ModelMenuItems: View {
    let models: [ModelInfo]
    let pick: (ModelInfo) -> Void

    private func source(_ name: String) -> String {
        for separator in [" · ", " / "] {
            if let cut = name.range(of: separator) { return String(name[..<cut.lowerBound]) }
        }
        return ""
    }

    private var groups: [(String, [ModelInfo])] {
        var order: [String] = []
        var bySource: [String: [ModelInfo]] = [:]
        for model in models {
            let key = source(model.name)
            if bySource[key] == nil { order.append(key) }
            bySource[key, default: []].append(model)
        }
        return order.map { ($0, bySource[$0] ?? []) }
    }

    private func label(_ model: ModelInfo) -> String { model.name + (model.readsImages ? "" : "  (text only)") }

    var body: some View {
        if models.count < 14 {
            ForEach(models) { model in Button(label(model)) { pick(model) } }
        } else {
            ForEach(groups, id: \.0) { group in
                if group.0.isEmpty || group.1.count == 1 {
                    ForEach(group.1) { model in Button(label(model)) { pick(model) } }
                } else {
                    Menu(group.0) {
                        ForEach(group.1) { model in Button(label(model)) { pick(model) } }
                    }
                }
            }
        }
    }
}

struct Composer: View {
    @EnvironmentObject var app: AppState
    @EnvironmentObject var chat: ChatModel
    @EnvironmentObject var store: ProjectStore
    @EnvironmentObject var engine: Engine
    @State private var showTools = false
    @FocusState private var focused: Bool

    private var canSend: Bool {
        store.current != nil && (!chat.draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || !chat.attachments.isEmpty)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if !chat.attachments.isEmpty {
                HStack(spacing: 8) {
                    ForEach(chat.attachments, id: \.self) { path in
                        ZStack(alignment: .topTrailing) {
                            if let image = Images.load(path) {
                                Image(nsImage: image).resizable().aspectRatio(contentMode: .fill)
                                    .frame(width: 56, height: 56).clipShape(RoundedRectangle(cornerRadius: 9))
                            }
                            Button { chat.attachments.removeAll { $0 == path } } label: {
                                Image(systemName: "xmark").font(.system(size: 8, weight: .bold)).foregroundStyle(.black)
                                    .frame(width: 16, height: 16).background(Circle().fill(.white))
                            }
                            .buttonStyle(.plain).offset(x: 5, y: -5)
                        }
                    }
                }
            }
            TextField(chat.running ? "Steer the run" : "Ask the agent to search, check or explain", text: $chat.draft, axis: .vertical)
                .textFieldStyle(.plain).lineLimit(1...8).font(.system(size: 14))
                .focused($focused).onSubmit(send)
                .padding(.horizontal, 4)
            HStack(spacing: 2) {
                Menu {
                    Button("Attach an image…", action: attachFile)
                    if let tile = store.selectedTile {
                        Button("Attach the selected tile") { attach("\(store.current?.path ?? "")/data/tiles/\(tile)-composite.png") }
                    }
                    if let c = store.candidates.first(where: { $0.id == store.selectedCandidate }) {
                        Button("Attach the section through \(c.id)") { attach(c.section) }
                    }
                } label: {
                    Image(systemName: "plus").font(.system(size: 15, weight: .medium)).foregroundStyle(Theme.dim)
                        .frame(width: 30, height: 30).contentShape(Rectangle())
                }
                .menuStyle(.button).buttonStyle(.plain).menuIndicator(.hidden).fixedSize()
                .help("Attach an image")

                Button { showTools.toggle() } label: {
                    HStack(spacing: 5) {
                        Image(systemName: "wrench.and.screwdriver").font(.system(size: 12))
                        Text("Tools").font(.system(size: 12.5))
                    }
                    .foregroundStyle(Theme.dim).padding(.horizontal, 8).frame(height: 30).contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .popover(isPresented: $showTools, arrowEdge: .top) {
                    ToolsPopover { showTools = false }.withApp(app)
                }

                Spacer(minLength: 4)

                PillMenu(title: app.modelName, quiet: true) {
                    ModelMenuItems(models: engine.models) { app.modelID = $0.id }
                }
                if let model = app.model, !model.efforts.isEmpty {
                    PillMenu(title: (app.activeEffort ?? "").capitalized, quiet: true) {
                        ForEach(model.efforts, id: \.self) { effort in
                            Button(effort.capitalized) { app.effort = effort }
                        }
                    }
                    .help("How hard the model thinks")
                }
                if chat.running && !canSend {
                    Button { Task { await chat.stop() } } label: {
                        Image(systemName: "stop.fill").font(.system(size: 11)).foregroundStyle(.black)
                            .frame(width: 30, height: 30).background(Circle().fill(.white))
                    }
                    .buttonStyle(.plain).help("Stop the run").padding(.leading, 4)
                } else {
                    Button(action: send) {
                        Image(systemName: "arrow.up").font(.system(size: 13, weight: .bold)).foregroundStyle(.black)
                            .frame(width: 30, height: 30).background(Circle().fill(canSend ? Color.white : Color.white.opacity(0.25)))
                    }
                    .buttonStyle(.plain).disabled(!canSend).padding(.leading, 4)
                }
            }
        }
        .padding(.horizontal, 12).padding(.top, 13).padding(.bottom, 9)
        .background(RoundedRectangle(cornerRadius: 24).fill(Theme.raised))
        .overlay(RoundedRectangle(cornerRadius: 24).strokeBorder(Theme.line))
        .onAppear { focused = true }
    }

    private func send() {
        guard canSend else { return }
        let text = chat.draft
        chat.draft = ""
        app.exploring = false
        Task { @MainActor in await chat.send(text) }
    }

    private func attach(_ path: String) {
        if FileManager.default.fileExists(atPath: path), !chat.attachments.contains(path) { chat.attachments.append(path) }
    }

    private func attachFile() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.image]
        panel.allowsMultipleSelection = true
        if panel.runModal() == .OK { panel.urls.forEach { attach($0.path) } }
    }
}

/// The stages of a search with the tools behind each. Picking one writes the request for you.
private struct ToolsPopover: View {
    @EnvironmentObject var app: AppState
    @EnvironmentObject var chat: ChatModel
    let close: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("What the agent can do").font(.system(size: 12, weight: .medium)).foregroundStyle(Theme.faint)
                .padding(.horizontal, 10).padding(.bottom, 4)
            ForEach(ToolGuide.stages) { stage in
                Button {
                    chat.draft = stage.prompt
                    close()
                } label: {
                    HStack(spacing: 10) {
                        IconTile(name: stage.icon, size: 28)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(stage.title).font(.system(size: 13, weight: .medium))
                            Text(stage.tools.map(\.name).joined(separator: "  "))
                                .font(.system(size: 10.5, design: .monospaced)).foregroundStyle(Theme.faint).lineLimit(1)
                        }
                    }
                    .padding(.vertical, 4)
                }
                .buttonStyle(RowButton())
            }
            Hairline().padding(.vertical, 4)
            Button {
                app.show(.tools)
                close()
            } label: {
                Label("See what each tool does", systemImage: "book").font(.system(size: 13))
            }
            .buttonStyle(RowButton())
        }
        .padding(8).frame(width: 360)
        .foregroundStyle(Theme.text)
    }
}

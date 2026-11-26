import AppKit
import SwiftUI
import UniformTypeIdentifiers

/// What the project holds, how to get more, the person's own files, and everything to take away, in one place.
struct DataView: View {
    @EnvironmentObject var app: AppState
    @EnvironmentObject var store: ProjectStore
    @EnvironmentObject var engine: Engine
    @State private var busy: String?
    @State private var message: String?
    @State private var dropping = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // In the order a search uses them: the ground it has, more of it, then what comes out at the end.
                section("The ground", summary) {
                    if store.terrains.isEmpty {
                        EmptyLine(icon: "dig.mound", text: store.screenedBefore != nil ? "The ground stayed on the Mac this project came from. Get it again, or add a file of your own below, only if you want to look at it yourself."
                                  : "None yet. Get the ground, or add a file of your own below.")
                    } else {
                        VStack(spacing: 0) {
                            let sorted = store.terrains.sorted { ($0.area ?? $0.id).localizedStandardCompare($1.area ?? $1.id) == .orderedAscending }
                            ForEach(Array(sorted.enumerated()), id: \.element.id) { index, t in
                                if index > 0 { Hairline() }
                                terrainRow(t)
                            }
                        }
                        .panel(radius: 12)
                    }
                }

                section("Get more ground", "Each of these asks the agent, in a chat in this project.") {
                    VStack(spacing: 0) {
                        if store.terrains.isEmpty {
                            row("Get the ground", "Fetches the open lidar for this project's area and takes the trees away.", "Get it") {
                                if let flow = ToolGuide.workflows.first(where: { $0.id == "terrain" }) { app.run(flow) }
                            }
                        } else {
                            row("Fill the gaps", "Fetches ground for any part of the area that has none yet, from the same survey where it can.", "Fetch") {
                                app.ask("Find open lidar for any part of this project's area that has no ground yet, fetch it with the same survey where possible, and cut it into tiles. If the whole area is covered, say so.")
                            }
                            Hairline()
                            row("Widen the area", "Adds the ground around what was already searched.", "Widen") {
                                app.ask(ToolGuide.widen, title: "Widen the search")
                            }
                            Hairline()
                            row("Use another survey", "Lists every open survey over this area, and asks which to fetch. Nothing is fetched yet.", "List them") {
                                app.ask("List every open lidar survey that covers this project's area with find_data: for each, who flew it, when, and how dense it is likely to be. Mark the one already fetched. Then ask me which to fetch; do not fetch anything yet.")
                            }
                        }
                        Hairline()
                        ownFile
                    }
                    .panel(radius: 12)
                    .disabled(busy != nil)
                }

                let report = ToolGuide.workflows.first { $0.id == "report" }
                let ready = report.map { app.state(of: $0) } ?? (ready: false, note: "")
                section("Report what you decided", ready.ready ? "Drafts only. You read each one and send it yourself."
                        : "These open once you have decided a find is worth reporting, in Decide.") {
                    VStack(spacing: 0) {
                        row("A report for the heritage authority", "A draft from the finds you decided are worth reporting.", "Draft a report",
                            id: "report", disabled: !ready.ready) { if let report { app.run(report) } }
                        Hairline()
                        // Where the official record is closed, the person asks the office that keeps it whether a find is known.
                        let records = ToolGuide.workflows.first { $0.id == "records" }
                        row("A question for the records office", "Where the official site record is not open: a short letter asking whether your strongest finds are already recorded.",
                            "Draft the letter", id: "records", keeps: true, disabled: !ready.ready) { if let records { app.run(records) } }
                    }
                    .panel(radius: 12)
                }

                section("Take it elsewhere", "") {
                    VStack(spacing: 0) {
                        row("The finds, for mapping software", "A GeoJSON file for QGIS, ArcGIS or Google Earth.", "Export finds", id: "finds", keeps: true, action: exportFinds)
                        Hairline()
                        row("The project, to share", "A zip of the records, notes, sources and reports, without the downloaded data.", "Export project…",
                            id: "zip", keeps: false, action: exportProject)
                    }
                    .panel(radius: 12)
                }

                if let message {
                    Text(message).font(.system(size: 12.5 * Theme.scale)).foregroundStyle(Theme.dim).textSelection(.enabled)
                        .padding(12).frame(maxWidth: .infinity, alignment: .leading)
                        .background(RoundedRectangle(cornerRadius: 10).fill(Theme.ink.opacity(0.05)))
                }
            }
            .padding(24).frame(maxWidth: 720, alignment: .leading).frame(maxWidth: .infinity)
        }
    }

    // MARK: pieces

    /// The whole of the ground in a few words: how many areas, how much of it, how many tiles.
    private var summary: String {
        guard !store.terrains.isEmpty else { return "" }
        let km2 = store.terrains.reduce(0) { $0 + $1.areaKm2 }
        return "\(store.terrains.count) area\(store.terrains.count == 1 ? "" : "s") · \(String(format: "%.1f", km2)) sq km · \(store.tiles.count) tiles"
    }

    private func section<Content: View>(_ title: String, _ about: String, @ViewBuilder _ content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text(title).font(.system(size: 15 * Theme.scale, weight: .semibold))
                if !about.isEmpty {
                    Text(about).font(.system(size: 12.5 * Theme.scale)).foregroundStyle(Theme.faint).fixedSize(horizontal: false, vertical: true)
                }
            }
            content()
        }
    }

    /// One thing to do, on one line: what it is, what it does, whether its file holds locations, and its button.
    private func row(_ title: String, _ text: String, _ button: String, id: String = "", keeps: Bool? = nil, disabled: Bool = false,
                     action: @escaping () -> Void) -> some View {
        let words = VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.system(size: 13.5 * Theme.scale, weight: .medium))
            Text(text).font(.system(size: 12.5 * Theme.scale)).foregroundStyle(Theme.dim).fixedSize(horizontal: false, vertical: true)
            if let keeps {
                Label(keeps ? "Holds locations, so it is saved under private/ and stays on this Mac" : "Holds no locations",
                      systemImage: keeps ? "lock.fill" : "checkmark.shield")
                    .font(.system(size: 11.5 * Theme.scale, weight: .medium)).foregroundStyle(keeps ? Theme.tan : Theme.green)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        let control = HStack(spacing: 8) {
            if !id.isEmpty, busy == id { DigIndicator() }
            Button(button, action: action).buttonStyle(SecondaryButton()).disabled(disabled || busy != nil)
        }
        // The words wrap, so the button always sits at the right, on every row alike.
        return HStack(alignment: .center, spacing: 12) {
            words.frame(maxWidth: .infinity, alignment: .leading)
            control.fixedSize()
        }
        .padding(.horizontal, 14).padding(.vertical, 10).frame(maxWidth: .infinity, alignment: .leading)
    }

    /// A ground model or a point cloud of the person's own, dropped on the row or chosen.
    private var ownFile: some View {
        let words = VStack(alignment: .leading, spacing: 4) {
            Text(busy == "import" ? "Reading the file…" : "Add a file of your own").font(.system(size: 13.5 * Theme.scale, weight: .medium))
            Text("Drop a ground model (GeoTIFF) or a point cloud (LAS or LAZ) here. It needs a coordinate system in metres, such as UTM. The file stays where it is.")
                .font(.system(size: 12.5 * Theme.scale)).foregroundStyle(Theme.dim).fixedSize(horizontal: false, vertical: true)
        }
        let pick = Button("Choose a file…", action: choose).buttonStyle(SecondaryButton()).disabled(busy != nil)
        return HStack(alignment: .center, spacing: 12) {
            words.frame(maxWidth: .infinity, alignment: .leading)
            pick.fixedSize()
        }
        .padding(.horizontal, 14).padding(.vertical, 10).frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 10).strokeBorder(Theme.accent, style: StrokeStyle(lineWidth: 1.5, dash: [5, 4])).opacity(dropping ? 1 : 0))
        .onDrop(of: [.fileURL], isTargeted: $dropping) { providers in
            _ = providers.first?.loadObject(ofClass: URL.self) { url, _ in
                if let url { Task { @MainActor in await importFile(url) } }
            }
            return true
        }
    }

    private func terrainRow(_ t: Terrain) -> some View {
        let tiles = store.tiles.filter { $0.terrain == t.id }
        var facts = ["\(String(format: "%.2f", t.areaKm2)) sq km", "\(t.res.formatted()) m cells"]
        if t.groundPerM2 > 0 { facts.append("\(String(format: "%.1f", t.groundPerM2)) ground returns per sq m") }
        if t.isOwn { facts.append("your own file") } else if !t.collected.isEmpty { facts.append("flown \(t.collected)") }
        facts.append(tiles.isEmpty ? "not cut into tiles" : "\(tiles.count) tiles")
        facts.append(size(of: t))
        return HStack(alignment: .top, spacing: 12) {
            Image(systemName: t.isOwn ? "doc" : t.points == nil ? "square.stack.3d.up" : "circle.grid.3x3")
                .font(.system(size: 14 * Theme.scale)).foregroundStyle(Theme.tan).frame(width: 20).padding(.top, 2)
            VStack(alignment: .leading, spacing: 4) {
                // The area's name first, as the map's area menu calls it, so several downloads of one survey read apart.
                if let area = t.area, !area.isEmpty {
                    (Text(area).fontWeight(.medium) + Text("  \(t.name)").foregroundColor(Theme.dim)).font(.system(size: 13.5 * Theme.scale))
                } else {
                    Text(t.name).font(.system(size: 13.5 * Theme.scale, weight: .medium))
                }
                Text(facts.joined(separator: " · ")).font(.system(size: 12.5 * Theme.scale)).foregroundStyle(Theme.dim)
                if !t.source.isEmpty { Text(t.source).font(.system(size: 12 * Theme.scale)).foregroundStyle(Theme.faint) }
            }
            Spacer()
            if tiles.isEmpty {
                Button("Cut into tiles") {
                    app.ask("Cut \(t.id) into tiles with make_tiles, then tell me how many tiles there are and how many have too little ground data to read.")
                }
                .buttonStyle(SecondaryButton())
            }
        }
        .padding(.horizontal, 14).padding(.vertical, 10)
    }

    /// Disk space the terrain's files take in the project.
    private func size(of t: Terrain) -> String {
        guard let root = store.current?.path else { return "" }
        let bytes = [t.file, t.points ?? ""].filter { !$0.isEmpty }.compactMap {
            FileInfo.size(root + "/" + $0)
        }.reduce(0, +)
        return ByteCountFormatter.string(fromByteCount: Int64(bytes), countStyle: .file) + " on disk"
    }

    // MARK: actions

    private func choose() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = ["tif", "tiff", "las", "laz"].compactMap { UTType(filenameExtension: $0) }
        panel.message = "A ground model (GeoTIFF) or a point cloud (LAS or LAZ)."
        if panel.runModal() == .OK, let url = panel.url { Task { await importFile(url) } }
    }

    private func importFile(_ url: URL) async {
        guard let root = store.current?.path else { return }
        busy = "import"
        message = nil
        defer { busy = nil }
        do {
            let reply = try await engine.callTool("import_terrain", ["project": root, "file": url.path])
            let info = (try? JSONSerialization.jsonObject(with: Data(reply.utf8))) as? JSON ?? [:]
            let id = info["terrain"] as? String ?? ""
            message = "Added \(url.lastPathComponent) as \(id). The agent is cutting it into tiles."
            store.reloadIfChanged()
            app.ask("I added my own file \(url.lastPathComponent) as \(id). Cut it into tiles with make_tiles, then tell me how many tiles there are and how many have too little ground data to read.")
        } catch {
            message = "Could not add \(url.lastPathComponent): \(error.localizedDescription)"
        }
    }

    private func exportFinds() {
        guard let root = store.current?.path else { return }
        busy = "finds"
        Task {
            defer { busy = nil }
            do {
                let reply = try await engine.callTool("export_finds", ["project": root])
                let info = (try? JSONSerialization.jsonObject(with: Data(reply.utf8))) as? JSON ?? [:]
                let file = info["file"] as? String ?? ""
                message = "Saved \(info["candidates"] as? Int ?? 0) finds to \(file). It holds their locations, so keep it on this Mac."
                if !file.isEmpty { NSWorkspace.shared.selectFile(file, inFileViewerRootedAtPath: "") }
            } catch {
                message = "Could not export the finds: \(error.localizedDescription)"
            }
        }
    }

    private func exportProject() {
        busy = "zip"
        Task {
            defer { busy = nil }
            if let said = await app.exportProject(quiet: true) { message = said }
        }
    }
}


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
            VStack(alignment: .leading, spacing: 22) {
                section("Ground in this project") {
                    if store.terrains.isEmpty {
                        EmptyLine(icon: "dig.mound", text: store.screenedBefore != nil ? "The ground stayed on the Mac this project came from. Get it again, or add a file of your own below, only if you want to look at it yourself."
                                  : "None yet. Get the ground, or add a file of your own below.")
                    }
                    ForEach(store.terrains) { t in terrainRow(t) }
                    HStack(spacing: 8) {
                        Button(store.terrains.isEmpty ? "Get the ground" : "Fetch more") {
                            if let flow = ToolGuide.workflows.first(where: { $0.id == "terrain" }), store.terrains.isEmpty { app.run(flow) }
                            else { app.ask("Find open lidar for any part of this project's area that has no ground yet, fetch it with the same survey where possible, and cut it into tiles. If the whole area is covered, say so.") }
                        }
                        .buttonStyle(SecondaryButton())
                        Button("Widen the area") {
                            app.ask(ToolGuide.widen, title: "Widen the search")
                        }
                        .buttonStyle(SecondaryButton()).disabled(store.terrains.isEmpty)
                        Button("Use another survey") {
                            app.ask("List every open lidar survey that covers this project's area with find_data: for each, who flew it, when, and how dense it is likely to be. Mark the one already fetched. Then ask me which to fetch; do not fetch anything yet.")
                        }
                        .buttonStyle(SecondaryButton())
                    }
                    .disabled(busy != nil)
                }

                section("Your own data") {
                    Text("Drop a ground model (GeoTIFF) or a point cloud (LAS or LAZ) here, or choose one. It needs a coordinate system in metres, such as UTM or a national grid. The file stays where it is; Dighouse reads it into the project.")
                        .font(.system(size: 13 * Theme.scale)).foregroundStyle(Theme.dim).fixedSize(horizontal: false, vertical: true)
                    HStack(spacing: 10) {
                        Image(systemName: "tray.and.arrow.down").font(.system(size: 18 * Theme.scale)).foregroundStyle(dropping ? Theme.accent : Theme.faint)
                        Text(busy == "import" ? "Reading the file…" : "Drop a file here").foregroundStyle(Theme.dim)
                        Spacer()
                        Button("Choose a file…", action: choose).buttonStyle(SecondaryButton()).disabled(busy != nil)
                    }
                    .padding(14)
                    .background(RoundedRectangle(cornerRadius: 12).strokeBorder(dropping ? Theme.accent : Theme.line, style: StrokeStyle(lineWidth: 1, dash: [5, 4])))
                    .onDrop(of: [.fileURL], isTargeted: $dropping) { providers in
                        _ = providers.first?.loadObject(ofClass: URL.self) { url, _ in
                            if let url { Task { @MainActor in await importFile(url) } }
                        }
                        return true
                    }
                }

                section("Take it with you") {
                    exportRow("Finds for mapping software", "A GeoJSON file of the finds for QGIS, ArcGIS or Google Earth. It holds their locations, so it is saved under private/ in the project.",
                              "Export finds", id: "finds", action: exportFinds)
                    exportRow("The project to share", "A zip of the records, notes, sources and reports, without the downloaded data or anything under private/, so it holds no locations.",
                              "Export project…", id: "zip", action: exportProject)
                    let report = ToolGuide.workflows.first { $0.id == "report" }
                    let ready = report.map { app.state(of: $0) } ?? (ready: false, note: "")
                    exportRow("A report for the heritage authority", ready.ready ? "A draft from the decided finds. You read it and send it yourself." : "Needs a find you have decided has no match in the sources read.",
                              "Draft a report", id: "report", disabled: !ready.ready) { if let report { app.run(report) } }
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

    private func section<Content: View>(_ title: String, @ViewBuilder _ content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title).font(.system(size: 15 * Theme.scale, weight: .semibold))
            content()
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
            VStack(alignment: .leading, spacing: 3) {
                Text(t.name).font(.system(size: 13.5 * Theme.scale, weight: .medium))
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
        .padding(12).background(RoundedRectangle(cornerRadius: 10).fill(Theme.ink.opacity(0.035)))
        .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(Theme.line))
    }

    private func exportRow(_ title: String, _ text: String, _ button: String, id: String, disabled: Bool = false, action: @escaping () -> Void) -> some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.system(size: 13.5 * Theme.scale, weight: .medium))
                Text(text).font(.system(size: 12.5 * Theme.scale)).foregroundStyle(Theme.dim).fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 12)
            if busy == id { DigIndicator() }
            Button(button, action: action).buttonStyle(SecondaryButton()).disabled(disabled || busy != nil)
        }
    }

    /// Disk space the terrain's files take in the project.
    private func size(of t: Terrain) -> String {
        guard let root = store.current?.path else { return "" }
        let bytes = [t.file, t.points ?? ""].filter { !$0.isEmpty }.compactMap {
            (try? FileManager.default.attributesOfItem(atPath: root + "/" + $0)[.size]) as? Int
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


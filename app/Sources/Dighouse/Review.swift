import SwiftUI

/// The search report a whole search ends with, and the way into Decide for what waits on a person.
struct ReportSheet: View {
    let file: String
    @EnvironmentObject var app: AppState
    @EnvironmentObject var store: ProjectStore

    var body: some View {
        // The file's first line is its title, which the header already shows.
        let text = ((try? String(contentsOfFile: file, encoding: .utf8)) ?? "").split(separator: "\n", omittingEmptySubsequences: false)
            .drop { $0.hasPrefix("# ") || $0.isEmpty }.joined(separator: "\n")
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 12) {
                Glyph(name: "dig.trowel", size: 16 * Theme.scale).foregroundStyle(Theme.tan)
                Text("Search report").font(.system(size: 17 * Theme.scale, weight: .semibold))
                Text(store.current?.name ?? "").font(.system(size: 13 * Theme.scale)).foregroundStyle(Theme.dim).lineLimit(1)
                Spacer()
                Button { NSWorkspace.shared.selectFile(file, inFileViewerRootedAtPath: "") } label: { Image(systemName: "folder") }
                    .buttonStyle(IconButton(size: 28)).help("Show the report's file in Finder")
                Button("Done") { app.reportShown = nil }.buttonStyle(SecondaryButton()).keyboardShortcut(.cancelAction)
            }
            .padding(.horizontal, 22).padding(.vertical, 14)
            Hairline()
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    // A blind test opens on its scorecard; the report follows.
                    if let root = store.current?.path, FileManager.default.fileExists(atPath: root + "/private/state/score.json") {
                        Scorecard(root: root)
                        Hairline()
                    }
                    MarkdownText(text: text)
                }
                .padding(22).frame(maxWidth: .infinity, alignment: .leading)
            }
            // A link to a find opens its record; the link to the research record opens it.
            .environment(\.openURL, OpenURLAction { url in
                guard url.scheme == nil || url.isFileURL else { return .systemAction }
                let name = URL(fileURLWithPath: url.relativePath).deletingPathExtension().lastPathComponent
                app.reportShown = nil
                if url.relativePath.contains("candidates/") { app.showRecords(name) } else { app.showNotes("record") }
                return .handled
            })
            Hairline()
            VStack(alignment: .leading, spacing: 8) {
                let needs = store.needsYou.count, agree = store.toAgree.count, kept = store.onMap
                if store.isBlindTest {
                    Text("A blind test: its finds are scored against the published key, so none waits for your decision.")
                        .font(.system(size: 13 * Theme.scale)).foregroundStyle(Theme.dim)
                } else {
                    // The same counts as Home and the project page: what needs a person, what to agree with, what stays on the map.
                    HStack(spacing: 12) {
                        Text(needs + agree == 0 ? "Nothing is waiting for your decision." + (kept > 0 ? " \(kept) find\(kept == 1 ? " stays" : "s stay") on the map." : "")
                             : [needs > 0 ? "\(needs) need\(needs == 1 ? "s" : "") you" : nil, agree > 0 ? "\(agree) to agree with" : nil].compactMap { $0 }.joined(separator: ", ")
                                + (kept > 0 ? ". \(kept) find\(kept == 1 ? " stays" : "s stay") on the map." : "."))
                            .font(.system(size: 13 * Theme.scale, weight: needs + agree > 0 ? .medium : .regular))
                            .foregroundStyle(needs + agree > 0 ? Theme.text : Theme.dim)
                        Spacer(minLength: 8)
                        if needs + agree > 0 {
                            Button("Decide") {
                                app.reportShown = nil
                                // One sheet has to close before the next can open.
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { app.openDecide() }
                            }
                            .buttonStyle(PrimaryButton()).keyboardShortcut(.defaultAction)
                        }
                    }
                }
            }
            .padding(.horizontal, 22).padding(.vertical, 14)
        }
        .frame(width: min(760, app.windowSize.width - 40), height: min(740, app.windowSize.height - 40))
        .background(Theme.bg).foregroundStyle(Theme.text)
        .closesOnOutsideClick { app.reportShown = nil }
    }
}

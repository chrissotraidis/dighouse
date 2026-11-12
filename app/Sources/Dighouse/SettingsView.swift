import SwiftUI

struct SettingsView: View {
    var body: some View {
        TabView {
            GeneralSettings().tabItem { Label("General", systemImage: "gearshape") }
            ModelSettings().tabItem { Label("Models", systemImage: "cpu") }
            EngineSettings().tabItem { Label("Engine", systemImage: "bolt") }
        }
        .frame(width: 600, height: 420)
        .foregroundStyle(Theme.text)
    }
}

private struct SettingRow<Content: View>: View {
    let title: String
    var note = ""
    @ViewBuilder let content: () -> Content

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.system(size: 13.5, weight: .medium))
                if !note.isEmpty {
                    Text(note).font(.system(size: 12)).foregroundStyle(Theme.dim).fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            content()
        }
        .padding(14)
    }
}

private struct GeneralSettings: View {
    @EnvironmentObject var app: AppState
    @AppStorage("projectsHome") private var projectsHome = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(spacing: 0) {
                SettingRow(title: "Your name", note: "Written into a record when you make a decision on a candidate.") {
                    TextField("Name", text: $app.userName).field().frame(width: 220)
                }
                Hairline()
                SettingRow(title: "Projects folder", note: projectsHome.isEmpty ? Paths.projectsHome.path : projectsHome) {
                    Button("Choose…") {
                        let panel = NSOpenPanel()
                        panel.canChooseDirectories = true
                        panel.canChooseFiles = false
                        panel.canCreateDirectories = true
                        if panel.runModal() == .OK, let url = panel.url { projectsHome = url.path }
                    }
                    .buttonStyle(SecondaryButton())
                }
                Hairline()
                SettingRow(title: "Welcome guide", note: "What Dighouse is, how a search works, and setting up.") {
                    Button("Open") { app.showWelcome = true }.buttonStyle(SecondaryButton())
                }
            }
            .panel()
            Spacer()
        }
        .padding(20)
    }
}

private struct ModelSettings: View {
    @EnvironmentObject var app: AppState
    @EnvironmentObject var engine: Engine
    @EnvironmentObject var setup: Setup

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(spacing: 0) {
                SettingRow(title: "Agent model", note: "Runs the search. Screening tiles needs a model that reads images.") {
                    PillMenu(title: app.modelName) {
                        ModelMenuItems(models: engine.models) { app.modelID = $0.id }
                    }
                }
                if let model = app.model, !model.efforts.isEmpty {
                    Hairline()
                    SettingRow(title: "Thinking", note: "More thinking is slower and more careful.") {
                        PillMenu(title: (app.activeEffort ?? "").capitalized) {
                            ForEach(model.efforts, id: \.self) { effort in Button(effort.capitalized) { app.effort = effort } }
                        }
                    }
                }
                Hairline()
                SettingRow(title: "Second-look model", note: "Gives the independent second opinion on a candidate. Choose a different model from the agent's.") {
                    PillMenu(title: app.secondModelName) {
                        ModelMenuItems(models: engine.models.filter { $0.readsImages }) { app.secondModelID = $0.id }
                    }
                }
            }
            .panel()
            Text(setup.ocxRunning
                 ? "The OpenCodex router is running, so every model in its roster is listed: \(engine.models.count) in total."
                 : "\(engine.models.count) models are available from your Codex sign-in. Start the OpenCodex router to add the models in its roster.")
                .font(.system(size: 12.5)).foregroundStyle(Theme.dim).fixedSize(horizontal: false, vertical: true)
            Spacer()
        }
        .padding(20)
    }
}

private struct EngineSettings: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            SetupChecklist()
            Spacer()
        }
        .padding(20)
    }
}

import Foundation

/// Finds what Dighouse needs on this Mac: the Codex engine, a model router, and the tools' runtime.
@MainActor
final class Setup: ObservableObject {
    @Published var checked = false
    @Published var path = ""
    @Published var codex: String?
    @Published var codexVersion = ""
    @Published var uv: String?
    @Published var ocxRunning = false
    @Published var toolsSource: String?
    @Published var toolsReady = false
    @Published var toolsBusy = false
    @Published var toolsProblem: String?

    private var venv: String { Paths.support.appendingPathComponent("tools-env").path }
    var toolsBinary: String { venv + "/bin/dighouse-tools" }
    private var marker: URL { Paths.support.appendingPathComponent("tools-source.txt") }

    var skill: String {
        guard let toolsSource else { return "" }
        for candidate in ["\(toolsSource)/SKILL.md", "\(toolsSource)/skills/dighouse/SKILL.md"] {
            if let text = try? String(contentsOfFile: candidate, encoding: .utf8) { return text }
        }
        return ""
    }

    func detect() async {
        // A login shell knows where the person's command-line tools live; an app started from Finder does not.
        let probe = await Shell.run("/bin/zsh", ["-lic", "echo DH_PATH=$PATH; echo DH_CODEX=$(command -v codex); echo DH_UV=$(command -v uv)"])
        func value(_ key: String) -> String? {
            probe.out.split(separator: "\n").last { $0.hasPrefix(key + "=") }.map { String($0.dropFirst(key.count + 1)) }
        }
        let home = NSHomeDirectory()
        path = value("DH_PATH") ?? "/usr/bin:/bin:/opt/homebrew/bin:/usr/local/bin:\(home)/.local/bin"
        codex = existing([value("DH_CODEX"), "\(home)/.local/bin/codex", "/opt/homebrew/bin/codex", "/usr/local/bin/codex"])
        uv = existing([value("DH_UV"), "\(home)/.local/bin/uv", "/opt/homebrew/bin/uv", "/usr/local/bin/uv", "\(home)/.cargo/bin/uv"])
        if let codex {
            codexVersion = await Shell.run(codex, ["--version"]).out.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        ocxRunning = await routerAnswers()
        toolsSource = existing([
            ProcessInfo.processInfo.environment["DIGHOUSE_TOOLS_DIR"],
            Bundle.main.resourceURL?.appendingPathComponent("tools").path,
        ].map { $0.map { $0 + "/pyproject.toml" } })?.replacingOccurrences(of: "/pyproject.toml", with: "")
        let prepared = (try? String(contentsOf: marker, encoding: .utf8)) == toolsSource
        toolsReady = prepared && FileManager.default.isExecutableFile(atPath: toolsBinary)
        checked = true
    }

    /// Build the tools' private Python environment. Needs uv; takes about a minute the first time.
    func prepareTools() async {
        guard let uv, let toolsSource else { return }
        toolsBusy = true
        toolsProblem = nil
        var env = ProcessInfo.processInfo.environment
        env["PATH"] = path
        env["UV_PROJECT_ENVIRONMENT"] = venv
        let run = await Shell.run(uv, ["sync", "--frozen", "--no-dev", "--directory", toolsSource], env: env)
        toolsBusy = false
        if run.code == 0, FileManager.default.isExecutableFile(atPath: toolsBinary) {
            try? toolsSource.write(to: marker, atomically: true, encoding: .utf8)
            toolsReady = true
        } else {
            toolsProblem = String(run.out.suffix(400))
        }
    }

    private func existing(_ candidates: [String?]) -> String? {
        candidates.compactMap { $0 }.first { !$0.isEmpty && FileManager.default.fileExists(atPath: $0) }
    }

    /// OpenCodex listens on a fixed local address. Any answer, even a refusal, means it is running.
    private func routerAnswers() async -> Bool {
        var request = URLRequest(url: URL(string: "http://127.0.0.1:10100/v1/models")!)
        request.timeoutInterval = 1.5
        return (try? await URLSession.shared.data(for: request)) != nil
    }
}

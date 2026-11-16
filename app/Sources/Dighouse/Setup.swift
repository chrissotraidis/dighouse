import CryptoKit
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

    /// What the prepared tools were built from: where they live and the exact list of parts they need.
    private var stamp: String? {
        guard let toolsSource else { return nil }
        let lock = FileManager.default.contents(atPath: toolsSource + "/uv.lock") ?? Data()
        return toolsSource + "\n" + SHA256.hash(data: lock).map { String(format: "%02x", $0) }.joined()
    }

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
        uv = existing([value("DH_UV"), "\(home)/.local/bin/uv", "/opt/homebrew/bin/uv", "/usr/local/bin/uv", "\(home)/.cargo/bin/uv"])
        // A Mac can hold several copies of the engine: one installed for the command line, one inside the Codex app.
        // The newest wins, because providers refuse their newer models to an older engine.
        let copies = [value("DH_CODEX"), "\(home)/.local/bin/codex", "/opt/homebrew/bin/codex", "/usr/local/bin/codex",
                      "/Applications/ChatGPT.app/Contents/Resources/codex-cli/CodexCLI.app/Contents/MacOS/codex",
                      "/Applications/Codex.app/Contents/Resources/codex"]
            .compactMap { $0 }.filter { !$0.isEmpty && FileManager.default.isExecutableFile(atPath: $0) }
        var best: (path: String, version: String)?
        for copy in copies where best?.path != copy {
            let version = await Shell.run(copy, ["--version"]).out.trimmingCharacters(in: .whitespacesAndNewlines)
            if best == nil || Self.newer(version, than: best?.version ?? "") { best = (copy, version) }
        }
        codex = best?.path
        codexVersion = best?.version ?? ""
        ocxRunning = await routerAnswers()
        findTools()
        UserDefaults.standard.set(["path": path, "codex": codex ?? "", "version": codexVersion, "uv": uv ?? ""], forKey: "setupFound")
    }

    /// What the last full check found, if the engine it found is still there. A full check starts a login shell to learn
    /// where the person's tools live, which takes seconds; with this, the engine starts at once and the check runs after.
    func restore() -> Bool {
        guard let found = UserDefaults.standard.dictionary(forKey: "setupFound") as? [String: String],
              let engine = found["codex"], FileManager.default.isExecutableFile(atPath: engine), let saved = found["path"] else { return false }
        path = saved
        codex = engine
        codexVersion = found["version"] ?? ""
        uv = found["uv"].flatMap { $0.isEmpty || !FileManager.default.fileExists(atPath: $0) ? nil : $0 }
        findTools()
        return toolsReady
    }

    private func findTools() {
        toolsSource = existing([
            ProcessInfo.processInfo.environment["DIGHOUSE_TOOLS_DIR"],
            Bundle.main.resourceURL?.appendingPathComponent("tools").path,
        ].map { $0.map { $0 + "/pyproject.toml" } })?.replacingOccurrences(of: "/pyproject.toml", with: "")
        let prepared = stamp != nil && (try? String(contentsOf: marker, encoding: .utf8)) == stamp
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
            try? stamp?.write(to: marker, atomically: true, encoding: .utf8)
            toolsReady = true
        } else {
            toolsProblem = String(run.out.suffix(400))
        }
    }

    private func existing(_ candidates: [String?]) -> String? {
        candidates.compactMap { $0 }.first { !$0.isEmpty && FileManager.default.fileExists(atPath: $0) }
    }

    /// Whether one "codex-cli 0.167.0-alpha.4" style version is later than another. With the same numbers, a finished
    /// release is later than its alpha.
    static func newer(_ a: String, than b: String) -> Bool {
        func parts(_ text: String) -> (numbers: [Int], finished: Bool) {
            let word = text.split(separator: " ").last.map(String.init) ?? ""
            let core = word.split(separator: "-", maxSplits: 1)
            return ((core.first ?? "").split(separator: ".").map { Int($0) ?? 0 }, core.count == 1)
        }
        let (x, y) = (parts(a), parts(b))
        for i in 0..<max(x.numbers.count, y.numbers.count) {
            let (m, n) = (i < x.numbers.count ? x.numbers[i] : 0, i < y.numbers.count ? y.numbers[i] : 0)
            if m != n { return m > n }
        }
        return x.finished && !y.finished
    }

    /// OpenCodex listens on a fixed local address. Any answer, even a refusal, means it is running.
    private func routerAnswers() async -> Bool {
        var request = URLRequest(url: URL(string: "http://127.0.0.1:10100/v1/models")!)
        request.timeoutInterval = 1.5
        return (try? await URLSession.shared.data(for: request)) != nil
    }
}

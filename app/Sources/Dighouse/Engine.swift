import AppKit
import Foundation

struct EngineError: LocalizedError {
    let message: String
    var errorDescription: String? { message }

    /// Providers often wrap their message in JSON; show the sentence inside.
    static func plain(_ raw: String) -> String {
        guard let data = raw.data(using: .utf8), let outer = try? JSONSerialization.jsonObject(with: data) as? JSON else { return raw }
        return (outer["error"] as? JSON)?["message"] as? String ?? outer["message"] as? String ?? raw
    }
}

/// Splits the engine's output into messages on a background queue, so a large reply never stalls the window.
private final class LineParser: @unchecked Sendable {
    private var buffer = Data()

    func feed(_ data: Data) -> [JSON] {
        var out: [JSON] = []
        var rest = data[...]
        // Only the new bytes are searched for a line end, so a reply of many megabytes is read once.
        while let newline = rest.firstIndex(of: 0x0A) {
            buffer.append(rest[..<newline])
            if let message = try? JSONSerialization.jsonObject(with: buffer) as? JSON, let light = Self.scrub(message) as? JSON {
                out.append(light)
            }
            buffer.removeAll(keepingCapacity: true)
            rest = rest[rest.index(after: newline)...]
        }
        buffer.append(rest)
        return out
    }

    /// Tool results carry images as long base64 strings. The app shows the files instead, so drop them here.
    private static func scrub(_ value: Any) -> Any {
        if let dict = value as? JSON {
            var out = JSON(minimumCapacity: dict.count)
            for (key, inner) in dict {
                if key == "data", let text = inner as? String, text.count > 4096 { out[key] = "" } else { out[key] = scrub(inner) }
            }
            return out
        }
        if let list = value as? [Any] { return list.map(scrub) }
        return value
    }
}

struct Connection: Identifiable {
    let name: String
    let tools: Int
    var id: String { name }
}

/// The Codex engine, run as a child process and spoken to in JSON lines.
@MainActor
final class Engine: ObservableObject {
    @Published var ready = false
    @Published var problem: String?
    @Published var account: String?
    @Published var plan: String?
    @Published var models: [ModelInfo] = []
    @Published var defaultModel: String?
    @Published var connections: [Connection] = []
    @Published var plugins: [String] = []
    @Published var toolCount = 0

    var onNotification: ((String, JSON) -> Void)?
    var onServerRequest: ((Any, String, JSON) -> Void)?

    private var process: Process?
    /// Whether the engine process is up, so it can be asked to sign in before its models are listed.
    var running: Bool { process?.isRunning == true }
    private var input: FileHandle?
    private var nextID = 0
    private var waiting: [Int: CheckedContinuation<JSON, Error>] = [:]
    private var serviceThread: String?
    private var connectionsLoaded = false
    /// True once the engine has said what else is connected, so a page can tell "none" from "not read yet".
    @Published private(set) var connectionsRead = false

    func start(codex: String, toolsBinary: String, path: String, extraServers: [ToolServer], claude: String? = nil) async {
        stop()
        problem = nil
        connectionsLoaded = false
        connectionsRead = false
        let p = Process()
        p.executableURL = URL(fileURLWithPath: codex)
        var arguments = [
            "app-server",
            // Codex's memories hold notes from the person's other chats. A search works from the project's own record,
            // and a blind test must not learn the site's name from a note, so Dighouse's engine runs without them.
            "-c", "features.memories=false",
            "-c", "mcp_servers.dighouse.command=\(toml(toolsBinary))",
            "-c", "mcp_servers.dighouse.args=[]",
            "-c", "mcp_servers.dighouse.startup_timeout_sec=60",
            // Downloading a survey's tiles for a few square km can take well over the default five minutes.
            "-c", "mcp_servers.dighouse.tool_timeout_sec=1200",
            // Newer engines ask before every tool call. Dighouse's own tools are part of the app, so they are approved here;
            // tools the person adds still ask.
            "-c", "mcp_servers.dighouse.default_tools_approval_mode=\"approve\"",
            // The engine starts tool servers with only a few of its own variables, so the folders go in the server's own
            // settings: where init_project puts a project named without a folder, and the GitHub folder, used only when
            // the person asks to work out of it.
            // Claude Code's place too, when there is one, so second opinions can be asked of Claude through it.
            "-c", "mcp_servers.dighouse.env={DIGHOUSE_PROJECTS_HOME=\(toml(Paths.projectsHome.path)),DIGHOUSE_GITHUB_HOME=\(toml(Paths.githubHome.path))"
                + (claude.map { ",DIGHOUSE_CLAUDE=\(toml($0))" } ?? "") + "}",
        ]
        for server in extraServers {
            let parts = Self.words(server.command)
            guard let command = parts.first, !server.key.isEmpty else { continue }
            arguments += ["-c", "mcp_servers.\(server.key).command=\(toml(command))",
                          "-c", "mcp_servers.\(server.key).args=[\(parts.dropFirst().map(toml).joined(separator: ","))]"]
        }
        p.arguments = arguments
        var env = ProcessInfo.processInfo.environment
        env["PATH"] = path
        // The engine keeps its chats in Dighouse's own folder, so they do not appear in the Codex app.
        Paths.prepareCodexHome()
        env["CODEX_HOME"] = Paths.codexHome.path
        p.environment = env
        let stdin = Pipe(), stdout = Pipe()
        p.standardInput = stdin
        p.standardOutput = stdout
        p.standardError = FileHandle.nullDevice
        let parser = LineParser()
        stdout.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            guard !data.isEmpty else { return }
            let messages = parser.feed(data)
            guard !messages.isEmpty else { return }
            DispatchQueue.main.async { MainActor.assumeIsolated { messages.forEach { self?.dispatch($0) } } }
        }
        p.terminationHandler = { [weak self] _ in
            DispatchQueue.main.async { MainActor.assumeIsolated { self?.ended() } }
        }
        do { try p.run() } catch {
            problem = "Could not start the Codex engine: \(error.localizedDescription)"
            return
        }
        process = p
        input = stdin.fileHandleForWriting
        do {
            // The experimental API is needed to read chats the engine stores page by page.
            _ = try await request("initialize", ["clientInfo": ["name": "dighouse", "title": "Dighouse", "version": Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.2.1"],
                                                 "capabilities": ["experimentalApi": true]])
            send(["method": "initialized"])
            let who = try await request("account/read")
            if let acct = who["account"] as? JSON {
                account = Self.who(acct)
                plan = acct["planType"] as? String
            }
            try await loadModels()
            let service = try await request("thread/start", ["cwd": Paths.support.path, "ephemeral": true, "approvalPolicy": "never"])
            serviceThread = (service["thread"] as? JSON)?["id"] as? String
            defaultModel = service["model"] as? String
            ready = true
        } catch {
            problem = "The Codex engine did not answer: \(error.localizedDescription)"
        }
    }

    func stop() {
        process?.terminationHandler = nil
        process?.terminate()
        process = nil
        input = nil
        ready = false
        serviceThread = nil
    }

    private func ended() {
        ready = false
        problem = "The Codex engine stopped."
        let all = waiting
        waiting = [:]
        all.values.forEach { $0.resume(throwing: EngineError(message: "The Codex engine stopped.")) }
    }

    private func loadModels() async throws {
        var found: [ModelInfo] = []
        var cursor: String?
        repeat {
            var params: JSON = ["limit": 100]
            if let cursor { params["cursor"] = cursor }
            let page = try await request("model/list", params)
            for m in page["data"] as? [JSON] ?? [] where (m["hidden"] as? Bool) != true && !ModelInfo.unsupported(m["id"] as? String ?? "") {
                let inputs = m["inputModalities"] as? [String] ?? []
                found.append(ModelInfo(
                    id: m["id"] as? String ?? "",
                    name: m["displayName"] as? String ?? (m["id"] as? String ?? ""),
                    readsImages: inputs.contains("image"), hearsAudio: inputs.contains("audio"),
                    isDefault: m["isDefault"] as? Bool ?? false,
                    efforts: (m["supportedReasoningEfforts"] as? [JSON] ?? []).compactMap { $0["reasoningEffort"] as? String },
                    defaultEffort: m["defaultReasoningEffort"] as? String,
                    effortNotes: Dictionary((m["supportedReasoningEfforts"] as? [JSON] ?? []).compactMap { step in
                        guard let id = step["reasoningEffort"] as? String, let note = step["description"] as? String else { return nil }
                        return (id, note)
                    }, uniquingKeysWith: { first, _ in first })))
            }
            cursor = page["nextCursor"] as? String
        } while cursor != nil
        models = found
    }

    /// What the person's Codex setup adds: other tool servers and enabled plugins.
    /// Asked once per engine start, since listing every server's tools takes the engine a few seconds.
    func loadConnections() async {
        guard ready, !connectionsLoaded else { return }
        connectionsLoaded = true
        if let listed = try? await request("mcpServerStatus/list") {
            let servers = listed["data"] as? [JSON] ?? []
            toolCount = (servers.first { $0["name"] as? String == "dighouse" }?["tools"] as? JSON)?.count ?? 0
            connections = servers.compactMap { server in
                guard let name = server["name"] as? String, name != "dighouse" else { return nil }
                return Connection(name: name, tools: (server["tools"] as? JSON)?.count ?? 0)
            }.sorted { $0.tools > $1.tools }
        }
        if let installed = try? await request("plugin/installed") {
            plugins = (installed["marketplaces"] as? [JSON] ?? []).flatMap { $0["plugins"] as? [JSON] ?? [] }
                .filter { $0["installed"] as? Bool == true && $0["enabled"] as? Bool == true }
                .compactMap { $0["name"] as? String }.sorted()
        }
        connectionsRead = true
    }

    // MARK: talking to the engine

    /// Sign the engine in with ChatGPT from the app: it hands out a sign-in page, the person signs in in their browser,
    /// and the account shows here once the engine has it. Dighouse never sees the password.
    func signIn() async throws {
        let reply = try await request("account/login/start", ["type": "chatgpt"])
        guard let link = reply["authUrl"] as? String, let url = URL(string: link) else { throw EngineError(message: "The engine gave no sign-in page.") }
        NSWorkspace.shared.open(url)
        for _ in 0..<300 {
            try await Task.sleep(for: .seconds(1))
            if let who = try? await request("account/read"), let acct = who["account"] as? JSON {
                account = Self.who(acct)
                return
            }
        }
        throw EngineError(message: "Sign-in did not finish within five minutes. Press Sign in to try again.")
    }

    /// Sign the engine in with an OpenAI API key, for a person without a ChatGPT plan. Each request is billed to the key.
    func signIn(apiKey: String) async throws {
        let key = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        // The engine takes any text as a key, so ask OpenAI first: a mistyped key should fail here, not at the first search.
        var check = URLRequest(url: URL(string: "https://api.openai.com/v1/models")!)
        check.setValue("Bearer " + key, forHTTPHeaderField: "Authorization")
        check.timeoutInterval = 15
        let status: Int
        do { status = ((try await URLSession.shared.data(for: check)).1 as? HTTPURLResponse)?.statusCode ?? 0 }
        catch { throw EngineError(message: "Could not reach OpenAI to check the key: \(error.localizedDescription)") }
        guard status == 200 else {
            throw EngineError(message: status == 401 ? "OpenAI did not accept the key. Check it and paste it again." : "OpenAI answered \(status) when the key was checked.")
        }
        _ = try await request("account/login/start", ["type": "apiKey", "apiKey": key])
        guard let acct = (try await request("account/read"))["account"] as? JSON else { throw EngineError(message: "The engine did not take the key.") }
        account = Self.who(acct)
        plan = nil
    }

    /// The account in words: an email for a ChatGPT sign-in, or what kind of key it is.
    static func who(_ acct: JSON) -> String {
        if let email = acct["email"] as? String, !email.isEmpty { return email }
        switch acct["type"] as? String {
        case "apiKey": return "an OpenAI API key"
        case "amazonBedrock": return "Amazon Bedrock"
        default: return acct["type"] as? String ?? "an account"
        }
    }

    func request(_ method: String, _ params: JSON = [:]) async throws -> JSON {
        guard input != nil else { throw EngineError(message: "The Codex engine is not running.") }
        nextID += 1
        let id = nextID
        return try await withCheckedThrowingContinuation { waiter in
            waiting[id] = waiter
            send(["id": id, "method": method, "params": params])
        }
    }

    func respond(to id: Any, result: JSON) { send(["id": id, "result": result]) }

    func refuse(_ id: Any, _ why: String) { send(["id": id, "error": ["code": -32601, "message": why]]) }

    /// Call one Dighouse tool directly, without an agent, and return its text.
    func callTool(_ tool: String, _ arguments: JSON) async throws -> String {
        let out = try await request("mcpServer/tool/call", [
            "threadId": serviceThread ?? "", "server": "dighouse", "tool": tool, "arguments": arguments,
        ])
        let texts = (out["content"] as? [JSON] ?? []).compactMap { $0["text"] as? String }
        if out["isError"] as? Bool == true { throw EngineError(message: texts.joined(separator: "\n")) }
        // A tool that returns a list sends one block per entry; put them back together as one JSON list.
        return texts.count > 1 ? "[" + texts.joined(separator: ",") + "]" : texts.first ?? ""
    }

    /// The entries of a tool reply that is a list, or a single entry.
    static func rows(_ text: String) -> [JSON] {
        let parsed = try? JSONSerialization.jsonObject(with: Data(text.utf8))
        if let list = parsed as? [JSON] { return list }
        if let one = parsed as? JSON { return [one] }
        return []
    }

    private func send(_ message: JSON) {
        guard let input, var data = try? JSONSerialization.data(withJSONObject: message) else { return }
        data.append(0x0A)
        try? input.write(contentsOf: data)
    }

    private func dispatch(_ message: JSON) {
        let method = message["method"] as? String
        if let method, let id = message["id"] {
            onServerRequest?(id, method, message["params"] as? JSON ?? [:])
        } else if let method {
            onNotification?(method, message["params"] as? JSON ?? [:])
        } else if let id = message["id"] as? Int, let waiter = waiting.removeValue(forKey: id) {
            if let error = message["error"] as? JSON {
                waiter.resume(throwing: EngineError(message: error["message"] as? String ?? "The engine reported an error."))
            } else {
                waiter.resume(returning: message["result"] as? JSON ?? [:])
            }
        }
    }

    private func toml(_ s: String) -> String {
        "\"" + s.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\"") + "\""
    }

    /// Split a command into words, keeping anything inside double quotes together so paths may hold spaces.
    static func words(_ command: String) -> [String] {
        var out: [String] = []
        var word = ""
        var quoted = false
        for c in command {
            if c == "\"" { quoted.toggle() } else if c == " ", !quoted {
                if !word.isEmpty { out.append(word); word = "" }
            } else { word.append(c) }
        }
        if !word.isEmpty { out.append(word) }
        return out
    }
}

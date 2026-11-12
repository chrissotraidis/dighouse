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

/// The Codex engine, run as a child process and spoken to in JSON lines.
@MainActor
final class Engine: ObservableObject {
    @Published var ready = false
    @Published var problem: String?
    @Published var account: String?
    @Published var models: [ModelInfo] = []
    @Published var defaultModel: String?

    var onNotification: ((String, JSON) -> Void)?
    var onServerRequest: ((Any, String, JSON) -> Void)?

    private var process: Process?
    private var input: FileHandle?
    private var nextID = 0
    private var waiting: [Int: CheckedContinuation<JSON, Error>] = [:]
    private var buffer = Data()
    private var serviceThread: String?

    func start(codex: String, toolsBinary: String, path: String) async {
        stop()
        problem = nil
        let p = Process()
        p.executableURL = URL(fileURLWithPath: codex)
        p.arguments = [
            "app-server",
            "-c", "mcp_servers.dighouse.command=\(toml(toolsBinary))",
            "-c", "mcp_servers.dighouse.args=[]",
            "-c", "mcp_servers.dighouse.startup_timeout_sec=60",
        ]
        var env = ProcessInfo.processInfo.environment
        env["PATH"] = path
        p.environment = env
        let stdin = Pipe(), stdout = Pipe()
        p.standardInput = stdin
        p.standardOutput = stdout
        p.standardError = FileHandle.nullDevice
        stdout.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            guard !data.isEmpty else { return }
            DispatchQueue.main.async { MainActor.assumeIsolated { self?.receive(data) } }
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
            _ = try await request("initialize", ["clientInfo": ["name": "dighouse", "title": "Dighouse", "version": "0.1.0"]])
            send(["method": "initialized"])
            let who = try await request("account/read")
            if let acct = who["account"] as? JSON {
                account = (acct["email"] as? String) ?? (acct["type"] as? String)
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
            for m in page["data"] as? [JSON] ?? [] where (m["hidden"] as? Bool) != true {
                found.append(ModelInfo(
                    id: m["id"] as? String ?? "",
                    name: m["displayName"] as? String ?? (m["id"] as? String ?? ""),
                    readsImages: (m["inputModalities"] as? [String] ?? []).contains("image"),
                    isDefault: m["isDefault"] as? Bool ?? false,
                    efforts: (m["supportedReasoningEfforts"] as? [JSON] ?? []).compactMap { $0["reasoningEffort"] as? String },
                    defaultEffort: m["defaultReasoningEffort"] as? String))
            }
            cursor = page["nextCursor"] as? String
        } while cursor != nil
        models = found
    }

    // MARK: talking to the engine

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
        if serviceThread == nil {
            let started = try await request("thread/start", ["cwd": Paths.support.path, "ephemeral": true, "approvalPolicy": "never"])
            serviceThread = (started["thread"] as? JSON)?["id"] as? String
        }
        let out = try await request("mcpServer/tool/call", [
            "threadId": serviceThread ?? "", "server": "dighouse", "tool": tool, "arguments": arguments,
        ])
        let text = (out["content"] as? [JSON] ?? []).compactMap { $0["text"] as? String }.joined(separator: "\n")
        if out["isError"] as? Bool == true { throw EngineError(message: text) }
        return text
    }

    private func send(_ message: JSON) {
        guard let input, var data = try? JSONSerialization.data(withJSONObject: message) else { return }
        data.append(0x0A)
        try? input.write(contentsOf: data)
    }

    private func receive(_ data: Data) {
        buffer.append(data)
        while let newline = buffer.firstIndex(of: 0x0A) {
            let line = buffer.subdata(in: buffer.startIndex..<newline)
            buffer.removeSubrange(buffer.startIndex...newline)
            guard let message = try? JSONSerialization.jsonObject(with: line) as? JSON else { continue }
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
    }

    private func toml(_ s: String) -> String {
        "\"" + s.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\"") + "\""
    }
}

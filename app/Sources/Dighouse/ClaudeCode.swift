import Foundation

/// Claude Code, used for second opinions on the person's own Claude plan (EASE_LOOP E5). It is run with no tools, no
/// tool servers, none of the person's settings, hooks or memory, and no saved session, so the model sees only what it is
/// sent. The tools ask it in the same way for a find (src/dighouse/review.py); this is the check in Settings.
enum ClaudeCode {
    /// The model's alias for Claude Code: "claude-code/claude-sonnet" is "sonnet".
    static func alias(_ id: String) -> String {
        String(id.dropFirst("claude-code/".count)).replacingOccurrences(of: "claude-", with: "")
    }

    /// Ask a Claude model through Claude Code what one lidar picture shows, to see that it answers and reads images.
    static func describe(_ claude: String, model: String, picture: String) async -> (ok: Bool, text: String) {
        guard let data = FileManager.default.contents(atPath: picture) else { return (false, "The test picture is missing.") }
        let message: [String: Any] = ["type": "user", "message": ["role": "user", "content": [
            ["type": "text", "text": "This is a lidar picture of bare ground. In one short sentence, what does it show?"],
            ["type": "image", "source": ["type": "base64", "media_type": "image/jpeg", "data": data.base64EncodedString()]],
        ]]]
        guard let line = try? JSONSerialization.data(withJSONObject: message) else { return (false, "Could not write the question.") }
        let run = await Shell.run(claude, ["-p", "--safe-mode", "--tools", "", "--strict-mcp-config", "--no-session-persistence",
                                           "--model", alias(model), "--input-format", "stream-json", "--output-format", "stream-json", "--verbose"],
                                  in: NSTemporaryDirectory(), input: String(decoding: line, as: UTF8.self) + "\n")
        let result = run.out.split(separator: "\n").reversed().lazy
            .compactMap { try? JSONSerialization.jsonObject(with: Data($0.utf8)) as? [String: Any] }
            .first { $0["type"] as? String == "result" }
        guard let result else { return (false, String(run.out.suffix(200)).trimmingCharacters(in: .whitespacesAndNewlines)) }
        let text = (result["result"] as? String ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let failed = result["is_error"] as? Bool == true || text.isEmpty
        if failed, text.lowercased().contains("authenticat") || text.contains("/login") {
            return (false, "Claude Code is not signed in. In Terminal, run claude and sign in with /login, then check again.")
        }
        return (!failed, text.isEmpty ? "No answer." : text)
    }

    /// Whether Claude Code has Dighouse's tool server.
    static func connected(_ claude: String) async -> Bool {
        await Shell.run(claude, ["mcp", "get", "dighouse"]).code == 0
    }

    private static var skillFile: URL { Paths.homeURL.appendingPathComponent(".claude/skills/dighouse/SKILL.md") }

    /// Give Claude Code, for this person, Dighouse's tool server and its search guide as a skill. Returns a problem in
    /// words, or nil. A guide already there is kept, unless it is Dighouse's own.
    static func connect(_ claude: String, tools: String, skill: String) async -> String? {
        let add = await Shell.run(claude, ["mcp", "add", "--scope", "user", "dighouse",
                                           "-e", "DIGHOUSE_PROJECTS_HOME=\(Paths.projectsHome.path)", "-e", "DIGHOUSE_CLAUDE=\(claude)", "--", tools])
        guard add.code == 0 else { return "Claude Code did not take the tools: " + add.out.trimmingCharacters(in: .whitespacesAndNewlines).prefix(200) }
        let existing = (try? String(contentsOf: skillFile, encoding: .utf8)) ?? ""
        if !skill.isEmpty, existing.isEmpty || existing.contains("name: dighouse") {
            try? FileManager.default.createDirectory(at: skillFile.deletingLastPathComponent(), withIntermediateDirectories: true)
            try? skill.write(to: skillFile, atomically: true, encoding: .utf8)
        }
        return nil
    }

    /// Take the tool server out of Claude Code, and move Dighouse's guide to the Trash.
    static func disconnect(_ claude: String) async -> String? {
        let remove = await Shell.run(claude, ["mcp", "remove", "--scope", "user", "dighouse"])
        if ((try? String(contentsOf: skillFile, encoding: .utf8)) ?? "").contains("name: dighouse") {
            try? FileManager.default.trashItem(at: skillFile.deletingLastPathComponent(), resultingItemURL: nil)
        }
        return remove.code == 0 ? nil : "Claude Code did not remove the tools: " + remove.out.trimmingCharacters(in: .whitespacesAndNewlines).prefix(200)
    }
}

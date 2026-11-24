import Foundation

/// The goal engine owns the research turns. This clock owns deadlines and recovery
/// from a provider throttle, including when another chat is visible.
@MainActor
final class TimedResearch {
    struct Session: Codable {
        let model: String
        let deadline: Date
        let closeAt: Date
        var closing = false
        var retries = 0
        var retryAt: Date?
        /// Whether an early close has already been turned back once.
        var reopened: Bool? = nil
    }

    typealias Request = (String, JSON) async throws -> JSON
    var request: Request?
    var turn: (String) -> String? = { _ in nil }
    var announce: (String, String) -> Void = { _, _ in }
    private let defaults: UserDefaults
    private let key = "timedResearchSessions"
    private var sessions: [String: Session] {
        didSet { defaults.set(try? JSONEncoder().encode(sessions), forKey: key) }
    }
    private var checkFailures: [String: Int] = [:]
    private var timers: [String: Task<Void, Never>] = [:]

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        sessions = defaults.data(forKey: key).flatMap { try? JSONDecoder().decode([String: Session].self, from: $0) } ?? [:]
    }

    var threadIDs: [String] { Array(sessions.keys) }

    func model(for id: String) -> String? { sessions[id]?.model }

    func status(for id: String) -> String? {
        guard let session = sessions[id] else { return nil }
        let end = session.deadline.formatted(date: .omitted, time: .shortened)
        if let retry = session.retryAt, retry < session.deadline {
            return "Retry at " + retry.formatted(date: .omitted, time: .standard) + " on " + session.model + ". Ends at " + end + "."
        }
        return (session.closing ? "Closing the session" : "Timed research on " + session.model) + " · Ends at " + end
    }

    func start(_ id: String, model: String, deadline: Date, now: Date = Date()) {
        let reserve = min(600, max(1, deadline.timeIntervalSince(now) / 5))
        sessions[id] = Session(model: model, deadline: deadline, closeAt: deadline.addingTimeInterval(-reserve))
        schedule(id)
    }

    func restore() {
        for id in sessions.keys {
            timers[id]?.cancel()
            timers[id] = Task { [weak self] in await self?.tick(id) }
        }
    }

    /// The longest goal objective the engine accepts. A longer one is refused, and the session never starts.
    static let objectiveLimit = 4000

    func remove(_ id: String) {
        checkFailures.removeValue(forKey: id)
        timers.removeValue(forKey: id)?.cancel()
        if sessions[id] != nil { sessions.removeValue(forKey: id) }
    }

    func goalChanged(_ id: String, status: String) {
        if status == "complete" || status == "blocked", reopenIfEarly(id) { return }
        if ["complete", "paused", "budgetLimited", "usageLimited", "usage_limited", "budget_limited"].contains(status) {
            remove(id)
        }
    }

    /// A session the agent closes, or calls blocked, long before its deadline is reopened once with the next thing to do:
    /// the person chose the time. An early "complete" left four hours unused in the first session, and a "blocked" on one
    /// unplaceable control left 40 minutes unused in the third. A block from a provider limit waits for its retry instead.
    @discardableResult
    private func reopenIfEarly(_ id: String) -> Bool {
        guard let s = sessions[id], !s.closing, s.reopened != true, s.retryAt == nil, s.closeAt.timeIntervalSinceNow > 10 * 60, let request else { return false }
        sessions[id]?.reopened = true
        let end = s.deadline.formatted(date: .omitted, time: .shortened)
        let prompt = "Dighouse's timer: the session runs until \(end). Keep the assessment you saved and leave aside what you cannot resolve, "
            + "then use the time on the next most useful pass: search a new area of open lidar where little is on record, or test a lead you listed. "
            + "Checkpoint as before. Dighouse will ask you to close shortly before the deadline."
        Task { _ = try? await request("thread/goal/set", ["threadId": id, "objective": prompt, "status": "active"]) }
        announce(id, "The agent stopped the session early; Dighouse asked it to keep going until \(end).")
        return true
    }

    func failed(_ id: String, error: JSON, now: Date = Date()) {
        guard var session = sessions[id], session.retryAt == nil else { return }
        let message = (error["message"] as? String ?? "").lowercased()
        let details = String(describing: error["codexErrorInfo"] ?? "").lowercased()
        guard !details.contains("usagelimitexceeded"), !message.contains("quota"),
              !message.contains("usage limit"),
              message.contains("429") || message.contains("too many requests") || message.contains("rate limit") else { return }
        guard session.retries < 3 else {
            announce(id, "The provider still limits requests after three retries. The session is blocked.")
            return
        }
        let delay = Self.retryDelay(error: error, attempt: session.retries, now: now)
        session.retryAt = now.addingTimeInterval(delay)
        session.retries += 1
        sessions[id] = session
        announce(id, "The provider limited this request. Retry scheduled on \(session.model) in \(Int(delay.rounded(.up))) seconds, within the session deadline.")
        schedule(id)
    }

    static func retryDelay(error: JSON, attempt: Int, now: Date) -> TimeInterval {
        let backoff = 15 * pow(2.0, Double(attempt))
        let value = error["retryAfterSeconds"] ?? error["retryAfter"] ?? (error["headers"] as? JSON)?.first { $0.key.lowercased() == "retry-after" }?.value
        let text = String(describing: value ?? "")
        if let seconds = Double(text), seconds.isFinite { return max(seconds, backoff) }
        let date = DateFormatter()
        date.locale = Locale(identifier: "en_US_POSIX")
        date.dateFormat = "EEE, dd MMM yyyy HH:mm:ss zzz"
        if let when = date.date(from: text) { return max(when.timeIntervalSince(now), backoff) }
        let message = (error["message"] as? String ?? "").lowercased()
        if let match = message.firstMatch(of: #/(?:retry.after|try again in|retry in)[: =]+([0-9]+(?:\.[0-9]+)?)\s*(?:seconds?|s\b)/#),
           let seconds = Double(match.1) { return max(seconds, backoff) }
        return backoff
    }

    private func schedule(_ id: String) {
        timers[id]?.cancel()
        guard let s = sessions[id] else { return }
        let next = min(s.deadline, s.retryAt ?? (s.closing ? s.deadline : s.closeAt))
        timers[id] = Task { [weak self] in
            try? await Task.sleep(for: .seconds(max(0, next.timeIntervalSinceNow)))
            guard !Task.isCancelled else { return }
            await self?.tick(id)
        }
    }

    func tick(_ id: String, now: Date = Date()) async {
        guard let s = sessions[id], let request else { return }
        do {
            let reply = try await request("thread/goal/get", ["threadId": id])
            guard sessions[id] != nil else { return }
            let status = (reply["goal"] as? JSON)?["status"] as? String
            guard status == "active" || status == "blocked" else { remove(id); return }
            // Blocked by the agent itself (found after a relaunch, or missed while the app was busy): turn it back once.
            if status == "blocked", turn(id) == nil, reopenIfEarly(id) { schedule(id); return }
            if now >= s.deadline {
                let currentTurn = turn(id)
                _ = try await request("thread/goal/set", ["threadId": id, "status": "paused"])
                if let turn = currentTurn, !turn.isEmpty {
                    _ = try? await request("turn/interrupt", ["threadId": id, "turnId": turn])
                }
                remove(id)
                announce(id, "The session reached its deadline and stopped.")
                return
            }
            var canClose = status == "active"
            if let retry = s.retryAt, now >= retry {
                if status == "blocked" && turn(id) == nil {
                    _ = try await request("thread/goal/set", ["threadId": id, "status": "active"])
                    canClose = true
                }
                sessions[id]?.retryAt = nil
            }
            if now >= s.closeAt, !s.closing, sessions[id]?.retryAt == nil {
                let prompt = "Dighouse's timer, not the person: the deadline is near, so close this timed research session now. Use the latest checkpoint. Save the ranked assessment, the decisive next test, benchmark and deferred work, interventions and human decisions. Mark the goal complete after saving. Do not start another acquisition."
                if let turn = turn(id), !turn.isEmpty {
                    _ = try await request("turn/steer", ["threadId": id, "expectedTurnId": turn, "input": [["type": "text", "text": prompt]]])
                } else if canClose {
                    // The engine takes an objective of at most 4,000 characters: past that, the close is sent on its own.
                    let joined = ((reply["goal"] as? JSON)?["objective"] as? String ?? "") + "\n\n" + prompt
                    _ = try await request("thread/goal/set", ["threadId": id, "objective": joined.count <= Self.objectiveLimit ? joined : prompt, "status": "active"])
                }
                sessions[id]?.closing = true
            }
        } catch {
            let attempts = checkFailures[id, default: 0] + 1
            checkFailures[id] = attempts
            if attempts == 1 { announce(id, "Timed session check failed: \(error.localizedDescription)") }
            // Allow a busy engine to finish its transition before trying again.
            guard sessions[id] != nil else { return }
            timers[id] = Task { [weak self] in
                let backoff = min(60, 5 * attempts)
                let delay = s.deadline > Date() ? min(Double(backoff), s.deadline.timeIntervalSinceNow) : Double(backoff)
                try? await Task.sleep(for: .seconds(max(0, delay)))
                if !Task.isCancelled { await self?.tick(id) }
            }
            return
        }
        checkFailures.removeValue(forKey: id)
        schedule(id)
    }
}

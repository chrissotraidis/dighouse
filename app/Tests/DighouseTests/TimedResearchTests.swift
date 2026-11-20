import XCTest
@testable import Dighouse

final class TimedResearchTests: XCTestCase {
    @MainActor
    func testProvider429ResumesCheckpointAndClosesAtOriginalDeadline() async throws {
        let domain = "Dighouse-Replay-" + UUID().uuidString
        let defaults = try XCTUnwrap(UserDefaults(suiteName: domain))
        defer { defaults.removePersistentDomain(forName: domain) }
        let chat = ChatModel()
        let clock = TimedResearch(defaults: defaults)
        chat.timed = clock
        let thread = "saved-research-chat"
        let account = "primary/gpt-6.2-sol"
        let deadline = Date().addingTimeInterval(23)
        var status = "blocked"
        var calls: [String] = []
        let finished = expectation(description: "deadline interrupts a still-running closeout")
        var retryTime: Date?
        clock.turn = { chat.live[$0] }
        clock.request = { method, params in
            XCTAssertEqual(params["threadId"] as? String, thread)
            XCTAssertEqual(clock.model(for: thread), account)
            XCTAssertNil(params["model"], "Resume the original thread's model")
            calls.append(method)
            switch method {
            case "thread/goal/get": return ["goal": ["status": status]]
            case "thread/goal/set":
                status = try XCTUnwrap(params["status"] as? String)
                if status == "active" {
                    retryTime = Date()
                    chat.handle("turn/started", ["threadId": thread, "turn": ["id": "continued"]])
                }
            case "turn/steer":
                XCTAssertEqual(params["expectedTurnId"] as? String, "continued")
                XCTAssertTrue(String(describing: params["input"]).contains("ranked assessment"))
            case "turn/interrupt":
                XCTAssertEqual(params["turnId"] as? String, "continued")
                finished.fulfill()
            default: XCTFail("Unexpected call: " + method)
            }
            return [:]
        }
        clock.start(thread, model: account, deadline: deadline)
        let failedAt = Date()
        chat.handle("turn/completed", ["threadId": thread, "turn": ["status": "failed",
            "error": ["message": "exceeded retry limit, last status: 429 Too Many Requests", "retryAfterSeconds": 16]]])
        chat.handle("thread/goal/updated", ["threadId": thread, "goal": ["status": "blocked"]])
        XCTAssertEqual(TimedResearch(defaults: defaults).model(for: thread), account)
        await fulfillment(of: [finished], timeout: 28)
        XCTAssertGreaterThanOrEqual(try XCTUnwrap(retryTime).timeIntervalSince(failedAt), 15.9)
        XCTAssertLessThan(abs(Date().timeIntervalSince(deadline)), 2)
        XCTAssertEqual(calls, ["thread/goal/get", "thread/goal/set", "thread/goal/get", "turn/steer",
                               "thread/goal/get", "thread/goal/set", "turn/interrupt"])
        XCTAssertNil(clock.model(for: thread))
    }

    @MainActor
    func testRestoredSessionHonorsQuotaAndCompletedGoal() async throws {
        let domain = "Dighouse-Replay-" + UUID().uuidString
        let defaults = try XCTUnwrap(UserDefaults(suiteName: domain))
        defer { defaults.removePersistentDomain(forName: domain) }
        let id = "restored"
        let owner = TimedResearch(defaults: defaults)
        owner.start(id, model: "original", deadline: Date().addingTimeInterval(300))
        let restored = TimedResearch(defaults: defaults)
        defer { owner.remove(id) }
        var notices: [String] = []
        restored.announce = { _, notice in notices.append(notice) }
        restored.failed(id, error: ["message": "429 quota exhausted", "codexErrorInfo": "usageLimitExceeded"])
        XCTAssertTrue(notices.isEmpty)
        let checked = expectation(description: "Check persisted goal on relaunch")
        restored.request = { method, _ in
            XCTAssertEqual(method, "thread/goal/get")
            checked.fulfill()
            return ["goal": ["status": "complete"]]
        }
        restored.restore()
        await fulfillment(of: [checked], timeout: 2)
        XCTAssertNil(restored.model(for: id))
    }

    @MainActor
    func testStoppedSessionCannotRetry() async throws {
        let domain = "Dighouse-Replay-" + UUID().uuidString
        let defaults = try XCTUnwrap(UserDefaults(suiteName: domain))
        defer { defaults.removePersistentDomain(forName: domain) }
        let clock = TimedResearch(defaults: defaults)
        clock.request = { _, _ in XCTFail("Resumed a stopped session"); return [:] }
        clock.start("stopped", model: "selected", deadline: Date().addingTimeInterval(600))
        clock.failed("stopped", error: ["message": "429"])
        clock.goalChanged("stopped", status: "paused")
        await clock.tick("stopped", now: Date().addingTimeInterval(30))
        XCTAssertNil(TimedResearch(defaults: defaults).model(for: "stopped"))
    }
}

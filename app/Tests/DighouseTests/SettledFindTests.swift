import XCTest
@testable import Dighouse

/// A find's group, likely status and strength are worked out once when a project is read (settle), since a large
/// project asks for them tens of thousands of times a redraw. The kept answers must be the ones worked out afresh, and
/// the strongest finds must still put those that wait for a person first.
@MainActor
final class SettledFindTests: XCTestCase {
    private func find(_ id: String, status: String = "flagged", suggestion: String? = nil, second: Bool? = nil,
                      hints: [String] = [], by: String = "GPT-6", sources: [Source] = []) -> Candidate {
        var checks: JSON = ["shape": ["hints": hints]]
        if let second { checks["second_look"] = ["agrees": second] }
        var c = Candidate(id: id, name: id, status: status, flagged: "2026-11-25", flaggedBy: by, tile: "t", evidence: [],
                          checks: checks, sources: sources, decisions: [], folder: "/tmp")
        if let suggestion { c.suggestion = (suggestion, "because", "the agent") }
        return c
    }

    func testSettledAnswersMatchFreshOnes() {
        let named = Source(title: "A survey", status: "read", finding: "C-004 is the mound on the survey", link: "")
        let all = [
            find("C-001"), find("C-002", suggestion: "natural", second: true), find("C-003", suggestion: "modern"),
            find("C-004", sources: [named]), find("C-005", status: "natural"),
            find("C-006", suggestion: "no_match_in_sources_read", second: true, hints: ["a coherent, round rise"]),
        ]
        for fresh in all {
            var kept = fresh
            kept.settle()
            XCTAssertEqual(kept.group, fresh.group, fresh.id)
            XCTAssertEqual(kept.likely?.status, fresh.likely?.status, fresh.id)
            XCTAssertEqual(kept.agreement, fresh.agreement, fresh.id)
        }
        XCTAssertEqual(all[3].likely?.status, "already_published")
        XCTAssertEqual(all[1].group, .lookAgain)
    }

    func testStrongestPutsWaitingFindsFirstThenTheStrongest() {
        let store = ProjectStore()
        let finds = [
            find("C-001"), find("C-002", second: true, hints: ["a coherent, round rise"]), find("C-003", second: true),
            find("C-004"),
        ].map { c -> Candidate in var c = c; c.settle(); return c }
        let picked = store.strongest(3, among: finds, first: ["C-004"]).map(\.id)
        XCTAssertEqual(picked, ["C-004", "C-002", "C-003"])
    }
}

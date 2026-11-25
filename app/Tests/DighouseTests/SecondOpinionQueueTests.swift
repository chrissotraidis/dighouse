import XCTest
@testable import Dighouse

/// Second opinions go only where they can change what reaches a person (EASE_LOOP E1). A measured rise reaches a person
/// only if the second model calls it built and its shape ranks in the project's top half, so a rise below the cut is
/// never asked; the agent's own finds come first, then the rest best first.
final class SecondOpinionQueueTests: XCTestCase {
    private func find(_ id: String, by: String, rank: Double, raised: Bool = false, asked: Bool = false, status: String = "flagged") -> Candidate {
        var checks: JSON = ["shape": ["rank": rank]]
        if asked { checks["second_look"] = ["agrees": true] }
        var c = Candidate(id: id, name: id, status: status, flagged: "2026-11-25", flaggedBy: by, tile: "t", evidence: [],
                          checks: checks, sources: [], decisions: [], folder: "/tmp")
        c.raised = raised
        return c
    }

    func testRisesBelowTheCutAreNotAskedAndTheAgentsFindsComeFirst() {
        let all = [
            find("R1", by: "measured (find_mounds)", rank: 1), find("R2", by: "measured (find_mounds)", rank: 2),
            find("R3", by: "measured (find_mounds)", rank: 3), find("R4", by: "measured (find_mounds)", rank: 4),
            find("R0", by: "measured (find_mounds)", rank: 0.5, raised: true),
            find("B1", by: "seen in bulk by a model", rank: 0.1),
            find("A1", by: "GPT-6", rank: 0),
            find("D1", by: "GPT-6", rank: 9, status: "natural"),
            find("S1", by: "GPT-6", rank: 9, asked: true),
        ]
        // Five rises: the cut is the middle rank (2), as in ledger.layer; R1 is below it, R0 is raised by a person.
        XCTAssertEqual(ProjectStore.worthAsking(all), ["A1", "R4", "R3", "R2", "R0", "B1"])
    }
}

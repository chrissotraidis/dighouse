import XCTest
@testable import Dighouse

/// The engine refuses a goal objective over 4,000 characters, and a refused goal is a session that never starts:
/// Find something went over once its instructions grew (2026-11-24). Each workflow is sent as an objective with the
/// deadline added, and a timed session's closing note can be added to it later.
final class WorkflowPromptTests: XCTestCase {
    func testEveryWorkflowFitsTheEnginesGoalWithRoomForTheDeadlineAndTheClose() {
        let roomForDeadlineAndClose = 600
        for flow in ToolGuide.workflows {
            XCTAssertLessThanOrEqual(flow.prompt.count + roomForDeadlineAndClose, TimedResearch.objectiveLimit,
                                     "\(flow.id) is \(flow.prompt.count) characters")
        }
    }
}

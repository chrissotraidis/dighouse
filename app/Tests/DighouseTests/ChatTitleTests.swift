import XCTest
@testable import Dighouse

/// A chat named from the start of its prompt can carry a place; the sidebar and the project page must not show it.
final class ChatTitleTests: XCTestCase {
    func testTitlesLoseBoxesAndCoordinates() {
        XCTAssertEqual(ChatThread.withoutPlaces("Use find_gaps on the Middle Usumacinta region (west -91.6, south 17.4, east -91."),
                       "Use find_gaps on the Middle Usumacinta region")
        XCTAssertEqual(ChatThread.withoutPlaces("Look at 39.87398, -82.31794 again"), "Look at again")
        XCTAssertEqual(ChatThread.withoutPlaces("Check C-008 near lat 38.6"), "Check C-008 near")
        XCTAssertEqual(ChatThread.withoutPlaces("Prior-art sweep"), "Prior-art sweep")
        XCTAssertEqual(ChatThread.withoutPlaces("Search on its own 2"), "Search on its own 2")
        XCTAssertEqual(ChatThread.withoutPlaces("Fetch 2.5 km² of OH_Statewide_Phase2_4_2020"), "Fetch 2.5 km² of OH_Statewide_Phase2_4_2020")
    }
}

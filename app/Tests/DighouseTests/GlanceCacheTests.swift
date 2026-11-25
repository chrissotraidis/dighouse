import XCTest
@testable import Dighouse

/// Home counts every project's finds from glances kept between launches. A kept count must be used only while the
/// project's files are unchanged: a decision written to a record has to show on Home.
final class GlanceCacheTests: XCTestCase {
    private func write(_ root: String, status: String, at date: Date) throws {
        let file = root + "/candidates/C-001.md"
        let text = "---\nid: \"C-001\"\nname: \"A rise\"\nstatus: \"\(status)\"\ntile: \"t\"\n---\n\nA rise.\n"
        try text.write(toFile: file, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.modificationDate: date], ofItemAtPath: file)
    }

    func testKeptCountsFollowChangedRecords() throws {
        let base = FileManager.default.temporaryDirectory.appendingPathComponent("glance-\(UUID().uuidString)")
        let root = base.appendingPathComponent("project").path
        try FileManager.default.createDirectory(atPath: root + "/candidates", withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: base) }
        let kept = base.appendingPathComponent("glances.json")

        try write(root, status: "flagged", at: Date(timeIntervalSince1970: 1_000_000))
        let first = ProjectStore.glances([root], keptIn: kept)[0]
        XCTAssertEqual(first.finds, 1)
        XCTAssertEqual(first.undecided, 1)
        XCTAssertTrue(FileManager.default.fileExists(atPath: kept.path))
        // Unchanged files: the kept counts, the same as reading afresh.
        let again = ProjectStore.glances([root], keptIn: kept)[0]
        XCTAssertEqual(again.finds, first.finds)
        XCTAssertEqual(again.undecided, first.undecided)
        XCTAssertEqual(again.needsYou, ProjectStore.glance(root).needsYou)

        // A person decides: the record changes, and the count follows.
        try write(root, status: "natural", at: Date(timeIntervalSince1970: 2_000_000))
        let after = ProjectStore.glances([root], keptIn: kept)[0]
        XCTAssertEqual(after.finds, 1)
        XCTAssertEqual(after.undecided, 0)
        XCTAssertEqual(after.needsYou, ProjectStore.glance(root).needsYou)
    }
}

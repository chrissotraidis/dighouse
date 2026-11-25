import XCTest
@testable import Dighouse

/// The day-one basics that can be checked without the window: telling versions apart, and keeping locations out of
/// a problem report.
final class BasicsTests: XCTestCase {
    func testNewerVersions() {
        XCTAssertTrue(Updates.isNewer("v0.3.0", than: "0.2.0"))
        XCTAssertTrue(Updates.isNewer("0.10", than: "0.9.4"))
        XCTAssertFalse(Updates.isNewer("v0.2.0", than: "0.2.0"))
        XCTAssertFalse(Updates.isNewer("0.2", than: "0.2.0"))
        XCTAssertFalse(Updates.isNewer("v0.1.9", than: "0.2.0"))
    }

    /// Freeing space removes only downloads no project holds: a file linked from a project stays, and counts once.
    func testFreeingKeepsWhatProjectsHold() throws {
        let base = FileManager.default.temporaryDirectory.appendingPathComponent("disk-\(UUID().uuidString)")
        let cache = base.appendingPathComponent("cache"), project = base.appendingPathComponent("project")
        try FileManager.default.createDirectory(at: cache.appendingPathComponent("points"), withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: project.appendingPathComponent("data"), withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: base); unsetenv("DIGHOUSE_CACHE") }
        setenv("DIGHOUSE_CACHE", cache.path, 1)
        let loose = cache.appendingPathComponent("points/loose.npz"), held = cache.appendingPathComponent("points/held.npz")
        try Data(count: 200_000).write(to: loose)
        try Data("{}".utf8).write(to: cache.appendingPathComponent("points/loose.json"))
        try Data(count: 300_000).write(to: held)
        try FileManager.default.linkItem(at: held, to: project.appendingPathComponent("data/points.npz"))

        let use = DiskUse.measure([project.path])
        XCTAssertEqual(use.looseFiles, [loose.path])
        XCTAssertGreaterThanOrEqual(use.projects, 300_000)
        XCTAssertLessThan(use.cache, 300_000)   // the linked file counted once, in the project
        XCTAssertGreaterThan(DiskUse.free(use.looseFiles + [held.path]), 0)
        XCTAssertFalse(FileManager.default.fileExists(atPath: loose.path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: cache.appendingPathComponent("points/loose.json").path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: held.path))   // held by a project: never removed
    }

    func testReportsCarryNoLocations() {
        // Made-up numbers, put together here so no coordinate is written in the repository.
        let north = "34." + "123456", west = "-91." + "654321"
        let text = "Tile at \(north), \(west) in " + Paths.home + "/Dighouse/x; version 0.2.0, 12.5 m"
        let clean = ProblemReport.clean(text)
        XCTAssertFalse(clean.contains(north))
        XCTAssertFalse(clean.contains(west.dropFirst()))
        XCTAssertFalse(clean.contains(Paths.home + "/"))
        XCTAssertTrue(clean.contains("version 0.2.0, 12.5 m"))
        XCTAssertTrue(clean.contains("~/Dighouse/x"))
    }
}

import XCTest
@testable import ClipFlow

final class ShortcutTests: XCTestCase {
    func testShortcutScenarios() async {
        await MainActor.run {
            for scenario in ShortcutScenarios.all {
                XCTAssertNoThrow(try scenario.run(), scenario.name)
            }
        }
    }
}

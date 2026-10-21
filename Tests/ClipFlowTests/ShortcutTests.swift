import XCTest
@testable import ClipFlow

final class ShortcutTests: XCTestCase {
    func testShortcutScenarios() async {
        await MainActor.run {
            for scenario in ShortcutScenarios.all + PanelSurfaceScenarios.all {
                XCTAssertNoThrow(try scenario.run(), scenario.name)
            }
        }
    }
}

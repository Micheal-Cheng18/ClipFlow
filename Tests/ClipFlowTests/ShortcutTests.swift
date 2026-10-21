import XCTest
@testable import ClipFlow

final class ShortcutTests: XCTestCase {
    func testShortcutScenarios() async {
        await MainActor.run {
            for scenario in ShortcutScenarios.all + PanelSurfaceScenarios.all {
                do { try scenario.run() }
                catch { XCTFail("\(scenario.name): \(error)") }
            }
        }
    }
}

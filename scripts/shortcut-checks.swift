// Runs the same scenarios as XCTest when only Command Line Tools are installed.
import Foundation

@main struct ShortcutChecks {
    @MainActor static func main() {
        var failures = 0
        let scenarios = ShortcutScenarios.all
        for scenario in scenarios {
            do { try scenario.run(); print("PASS \(scenario.name)") }
            catch { failures += 1; print("FAIL \(scenario.name): \(error)") }
        }
        print("\(scenarios.count - failures)/\(scenarios.count) shortcut checks passed")
        if failures > 0 { exit(1) }
    }
}

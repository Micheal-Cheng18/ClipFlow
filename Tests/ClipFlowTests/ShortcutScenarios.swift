import AppKit
import Carbon
import Foundation
#if canImport(ClipFlow)
@testable import ClipFlow
#endif

@MainActor
private final class MockHotKeyRegistrar: HotKeyRegistering {
    var nextStatus: OSStatus = noErr
    private(set) var activeShortcut: Shortcut?
    private(set) var registrationAttempts: [Shortcut] = []
    private(set) var unregisterCount = 0

    func register(_ shortcut: Shortcut) -> OSStatus {
        registrationAttempts.append(shortcut)
        guard nextStatus == noErr else { return nextStatus }
        activeShortcut = shortcut
        return noErr
    }

    func unregister() {
        unregisterCount += 1
        activeShortcut = nil
    }
}

private struct ExpectationFailure: Error, CustomStringConvertible {
    let description: String
}

private func expect(_ value: Bool, _ message: String = "Expected true", file: StaticString = #filePath, line: UInt = #line) throws {
    guard value else { throw ExpectationFailure(description: "\(file):\(line): \(message)") }
}

private func expectFalse(_ value: Bool, _ message: String = "Expected false", file: StaticString = #filePath, line: UInt = #line) throws {
    try expect(!value, message, file: file, line: line)
}

private func equal<T: Equatable>(_ actual: T, _ expected: T, _ message: String = "Values differ", file: StaticString = #filePath, line: UInt = #line) throws {
    try expect(actual == expected, "\(message): \(actual) != \(expected)", file: file, line: line)
}

private func expectNil<T>(_ value: T?, _ message: String = "Expected nil", file: StaticString = #filePath, line: UInt = #line) throws {
    try expect(value == nil, message, file: file, line: line)
}

private func expectNotNil<T>(_ value: T?, _ message: String = "Expected a value", file: StaticString = #filePath, line: UInt = #line) throws {
    try expect(value != nil, message, file: file, line: line)
}

@MainActor
struct ShortcutScenario {
    let name: String
    let run: () throws -> Void
}

@MainActor
private func withDefaults(_ body: (UserDefaults) throws -> Void) rethrows {
    let suiteName = "ClipFlow.ShortcutTests.\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suiteName)!
    defer { defaults.removePersistentDomain(forName: suiteName) }
    try body(defaults)
}

@MainActor
enum ShortcutScenarios {
    private static var customShortcut: Shortcut {
        Shortcut(keyCode: UInt32(kVK_ANSI_K), modifiers: UInt32(controlKey | optionKey), keyLabel: "K")
    }

    static var all: [ShortcutScenario] {
        [
            ShortcutScenario(name: "testDefaultShortcutIsValidAndRegistersOnLaunch", run: {
                try withDefaults { defaults in
                    let registrar = MockHotKeyRegistrar()
                    let manager = ShortcutManager(defaults: defaults, registrar: registrar)

                    try equal(manager.shortcut, .defaultShortcut)
                    try equal(manager.shortcut.keyCode, UInt32(kVK_ANSI_V))
                    try equal(manager.shortcut.modifiers, UInt32(cmdKey | shiftKey))
                    try expectNil(manager.shortcut.validationMessage)
                    try expect(manager.isAvailable)
                    try expectFalse(manager.isRecording)
                    try equal(registrar.activeShortcut, Shortcut.defaultShortcut)
                }
            }),
            ShortcutScenario(name: "testSuccessfulChangePersistsAndIsRestoredOnNextLaunch", run: {
                try withDefaults { defaults in
                    let registrar = MockHotKeyRegistrar()
                    let manager = ShortcutManager(defaults: defaults, registrar: registrar)
                    let candidate = customShortcut

                    try expect(manager.apply(candidate))
                    try equal(manager.shortcut, candidate)
                    try equal(registrar.activeShortcut, candidate)
                    try expectNotNil(defaults.object(forKey: ShortcutManager.preferenceKey))

                    let relaunchedRegistrar = MockHotKeyRegistrar()
                    let relaunched = ShortcutManager(defaults: defaults, registrar: relaunchedRegistrar)
                    try equal(relaunched.shortcut, candidate)
                    try equal(relaunchedRegistrar.activeShortcut, candidate)
                    try expect(relaunched.isAvailable)
                }
            }),
            ShortcutScenario(name: "testRegistrationConflictPreservesPreviousShortcutAndPreference", run: {
                try withDefaults { defaults in
                    let registrar = MockHotKeyRegistrar()
                    let manager = ShortcutManager(defaults: defaults, registrar: registrar)
                    try expect(manager.apply(customShortcut))
                    let previousData = defaults.data(forKey: ShortcutManager.preferenceKey)
                    let candidate = Shortcut(keyCode: UInt32(kVK_ANSI_J), modifiers: UInt32(cmdKey | optionKey), keyLabel: "J")
                    registrar.nextStatus = OSStatus(eventHotKeyExistsErr)

                    try expectFalse(manager.apply(candidate))
                    try equal(manager.shortcut, customShortcut)
                    try equal(registrar.activeShortcut, customShortcut)
                    try equal(defaults.data(forKey: ShortcutManager.preferenceKey), previousData)
                    try expect(manager.isAvailable)
                    try expectFalse(manager.message.isEmpty)
                }
            }),
            ShortcutScenario(name: "testRecordingTemporarilyUnregistersAndCancelRestoresShortcut", run: {
                try withDefaults { defaults in
                    let registrar = MockHotKeyRegistrar()
                    let manager = ShortcutManager(defaults: defaults, registrar: registrar)
                    try expect(manager.apply(customShortcut))
                    let previousData = defaults.data(forKey: ShortcutManager.preferenceKey)

                    manager.startRecording()
                    try expect(manager.isRecording)
                    try expectNil(registrar.activeShortcut)
                    try equal(registrar.unregisterCount, 1)

                    manager.cancelRecording()
                    try expectFalse(manager.isRecording)
                    try expect(manager.isAvailable)
                    try equal(manager.shortcut, customShortcut)
                    try equal(registrar.activeShortcut, customShortcut)
                    try equal(defaults.data(forKey: ShortcutManager.preferenceKey), previousData)
                }
            }),
            ShortcutScenario(name: "testConflictDuringRecordingKeepsRecordingAndDoesNotPersistCandidate", run: {
                try withDefaults { defaults in
                    let registrar = MockHotKeyRegistrar()
                    let manager = ShortcutManager(defaults: defaults, registrar: registrar)
                    try expect(manager.apply(customShortcut))
                    let previousData = defaults.data(forKey: ShortcutManager.preferenceKey)
                    manager.startRecording()
                    registrar.nextStatus = OSStatus(eventHotKeyExistsErr)

                    try expectFalse(manager.apply(.defaultShortcut))
                    try expect(manager.isRecording)
                    try equal(manager.shortcut, customShortcut)
                    try equal(defaults.data(forKey: ShortcutManager.preferenceKey), previousData)
                    try expectFalse(manager.message.isEmpty)

                    registrar.nextStatus = noErr
                    manager.cancelRecording()
                    try equal(registrar.activeShortcut, customShortcut)
                    try expect(manager.isAvailable)
                }
            }),
            ShortcutScenario(name: "testSuccessfulRecordingAppliesCandidateAndEndsRecording", run: {
                try withDefaults { defaults in
                    let registrar = MockHotKeyRegistrar()
                    let manager = ShortcutManager(defaults: defaults, registrar: registrar)
                    manager.startRecording()

                    try expect(manager.apply(customShortcut))
                    try expectFalse(manager.isRecording)
                    try expect(manager.isAvailable)
                    try equal(registrar.activeShortcut, customShortcut)
                    try equal(manager.shortcut, customShortcut)
                }
            }),
            ShortcutScenario(name: "testInvalidCombinationDoesNotReachRegistrarOrChangePreference", run: {
                try withDefaults { defaults in
                    let registrar = MockHotKeyRegistrar()
                    let manager = ShortcutManager(defaults: defaults, registrar: registrar)
                    let attemptsBefore = registrar.registrationAttempts.count
                    let candidate = Shortcut(keyCode: UInt32(kVK_ANSI_K), modifiers: UInt32(shiftKey), keyLabel: "K")

                    try expectFalse(manager.apply(candidate))
                    try equal(registrar.registrationAttempts.count, attemptsBefore)
                    try equal(manager.shortcut, .defaultShortcut)
                    try expectNil(defaults.object(forKey: ShortcutManager.preferenceKey))
                    try expectFalse(manager.message.isEmpty)
                }
            }),
            ShortcutScenario(name: "testPlainAndShiftOnlyKeysAreRejected", run: {
                for modifiers: UInt32 in [0, UInt32(shiftKey)] {
                    let candidate = Shortcut(keyCode: UInt32(kVK_ANSI_K), modifiers: modifiers, keyLabel: "K")
                    try expectNotNil(candidate.validationMessage)
                }
                for modifiers: UInt32 in [UInt32(cmdKey), UInt32(controlKey), UInt32(optionKey)] {
                    let candidate = Shortcut(keyCode: UInt32(kVK_ANSI_K), modifiers: modifiers, keyLabel: "K")
                    try expectNil(candidate.validationMessage)
                }

            }),
            ShortcutScenario(name: "testCommonBareCommandShortcutsAreProtectedByPhysicalKeyCode", run: {
                let protectedKeys = [kVK_ANSI_V, kVK_ANSI_C, kVK_ANSI_X, kVK_ANSI_Z, kVK_ANSI_A,
                                     kVK_ANSI_Q, kVK_ANSI_W, kVK_ANSI_H, kVK_ANSI_M, kVK_ANSI_S,
                                     kVK_ANSI_P, kVK_ANSI_F, kVK_ANSI_N, kVK_ANSI_O]
                for keyCode in protectedKeys {
                    let candidate = Shortcut(keyCode: UInt32(keyCode), modifiers: UInt32(cmdKey), keyLabel: "布局相关名称")
                    try expectNotNil(candidate.validationMessage, "Must protect key code \(keyCode)")
                }
                try expectNil(Shortcut.defaultShortcut.validationMessage)

            }),
            ShortcutScenario(name: "testDisplayIncludesChosenKeyAndModifierSymbols", run: {
                let candidate = customShortcut
                try expect(candidate.display.contains("K"))
                try expect(candidate.display.contains("⌃"))
                try expect(candidate.display.contains("⌥"))
                try expectFalse(candidate.display.contains("⌘"))

            }),
            ShortcutScenario(name: "testCorruptStoredPreferenceFallsBackToDefault", run: {
                try withDefaults { defaults in
                    defaults.set(Data("invalid shortcut".utf8), forKey: ShortcutManager.preferenceKey)
                    let registrar = MockHotKeyRegistrar()
                    let manager = ShortcutManager(defaults: defaults, registrar: registrar)
                    try equal(manager.shortcut, .defaultShortcut)
                    try equal(registrar.activeShortcut, Shortcut.defaultShortcut)
                    try expect(manager.isAvailable)
                }
            }),
            ShortcutScenario(name: "testRecorderConsumesAndSavesSyntheticKeyEquivalent", run: {
                try withDefaults { defaults in
                    let registrar = MockHotKeyRegistrar()
                    let manager = ShortcutManager(defaults: defaults, registrar: registrar)
                    let recorder = ShortcutRecorderView(manager: manager)
                    manager.startRecording()
                    let event = NSEvent.keyEvent(with: .keyDown, location: .zero,
                        modifierFlags: [.control, .option], timestamp: 0, windowNumber: 0,
                        context: nil, characters: "k", charactersIgnoringModifiers: "k",
                        isARepeat: false, keyCode: UInt16(kVK_ANSI_K))!

                    try expect(recorder.performKeyEquivalent(with: event))
                    try expectFalse(manager.isRecording)
                    try expect(manager.isAvailable)
                    try equal(manager.shortcut.keyCode, customShortcut.keyCode)
                    try equal(manager.shortcut.modifiers, customShortcut.modifiers)
                    try equal(registrar.activeShortcut, manager.shortcut)
                    let persisted = defaults.data(forKey: ShortcutManager.preferenceKey)
                        .flatMap { try? JSONDecoder().decode(Shortcut.self, from: $0) }
                    try equal(persisted, manager.shortcut)
                }
            }),
            ShortcutScenario(name: "testRecorderConsumesEscapeAndRestoresOriginalSelection", run: {
                try withDefaults { defaults in
                    let registrar = MockHotKeyRegistrar()
                    let manager = ShortcutManager(defaults: defaults, registrar: registrar)
                    try expect(manager.apply(customShortcut))
                    let previousData = defaults.data(forKey: ShortcutManager.preferenceKey)
                    let recorder = ShortcutRecorderView(manager: manager)
                    manager.startRecording()
                    let event = NSEvent.keyEvent(with: .keyDown, location: .zero,
                        modifierFlags: [], timestamp: 0, windowNumber: 0,
                        context: nil, characters: "\u{1b}", charactersIgnoringModifiers: "\u{1b}",
                        isARepeat: false, keyCode: UInt16(kVK_Escape))!

                    try expect(recorder.performKeyEquivalent(with: event))
                    try expectFalse(manager.isRecording)
                    try expect(manager.isAvailable)
                    try equal(manager.shortcut, customShortcut)
                    try equal(registrar.activeShortcut, customShortcut)
                    try equal(defaults.data(forKey: ShortcutManager.preferenceKey), previousData)
                }
            }),
            ShortcutScenario(name: "testStartupConflictCanRecoverByApplyingAvailableShortcut", run: {
                try withDefaults { defaults in
                    let registrar = MockHotKeyRegistrar()
                    registrar.nextStatus = OSStatus(eventHotKeyExistsErr)
                    let manager = ShortcutManager(defaults: defaults, registrar: registrar)
                    try expectFalse(manager.isAvailable)
                    try expect(manager.hasError)
                    try expectFalse(manager.message.isEmpty)
                    try expectNil(registrar.activeShortcut)

                    registrar.nextStatus = noErr
                    try expect(manager.apply(customShortcut))
                    try expect(manager.isAvailable)
                    try expectFalse(manager.hasError)
                    try equal(manager.shortcut, customShortcut)
                    try equal(registrar.activeShortcut, customShortcut)
                }
            }),
            ShortcutScenario(name: "testCancelRecordingRetainsSelectionIfOriginalRegistrationCannotBeRestored", run: {
                try withDefaults { defaults in
                    let registrar = MockHotKeyRegistrar()
                    let manager = ShortcutManager(defaults: defaults, registrar: registrar)
                    try expect(manager.apply(customShortcut))
                    let previousData = defaults.data(forKey: ShortcutManager.preferenceKey)
                    manager.startRecording()
                    registrar.nextStatus = OSStatus(eventHotKeyExistsErr)

                    manager.cancelRecording()
                    try expectFalse(manager.isRecording)
                    try expectFalse(manager.isAvailable)
                    try expect(manager.hasError)
                    try expectFalse(manager.message.isEmpty)
                    try equal(manager.shortcut, customShortcut)
                    try expectNil(registrar.activeShortcut)
                    try equal(defaults.data(forKey: ShortcutManager.preferenceKey), previousData)
                }
            })
        ]
    }
}

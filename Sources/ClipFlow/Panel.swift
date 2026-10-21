import SwiftUI
import AppKit
import Carbon
import QuartzCore
import Combine

final class ClipPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var becomesKeyOnlyIfNeeded: Bool { get { false } set {} }
}
final class InteractiveHostingView<Content: View>: NSHostingView<Content> {
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
}

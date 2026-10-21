import SwiftUI
import AppKit

final class ClipPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var becomesKeyOnlyIfNeeded: Bool { get { false } set {} }
}
final class InteractiveHostingView<Content: View>: NSHostingView<Content> {
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
}

/// Clip the native backdrop as well as SwiftUI content. A SwiftUI clipShape
/// alone does not reliably clip the separate window-server material surface.
final class RoundedPanelSurface: NSView {
    static let cornerRadius: CGFloat = 18
    let backdrop = NSVisualEffectView()
    private let hosting: NSView
    private var maskSize = NSSize.zero
    override var isOpaque: Bool { false }

    init<Content: View>(frame: NSRect, rootView: Content) {
        hosting = InteractiveHostingView(rootView: rootView)
        super.init(frame: frame)
        wantsLayer = true
        layer?.backgroundColor = NSColor.clear.cgColor
        layer?.cornerRadius = Self.cornerRadius
        layer?.masksToBounds = true
        backdrop.material = .popover
        backdrop.blendingMode = .behindWindow
        backdrop.state = .active
        backdrop.frame = bounds
        hosting.frame = bounds
        backdrop.autoresizingMask = [.width, .height]
        hosting.autoresizingMask = [.width, .height]
        addSubview(backdrop)
        addSubview(hosting)
        updateBackdropMask()
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func layout() {
        super.layout()
        backdrop.frame = bounds
        hosting.frame = bounds
        updateBackdropMask()
    }

    private func updateBackdropMask() {
        guard bounds.width > 0, bounds.height > 0, maskSize != bounds.size else { return }
        maskSize = bounds.size
        // NSVisualEffectView.maskImage clips the actual backdrop in the
        // compositor, including behind-window blur, rather than just a border.
        let mask = NSImage(size: bounds.size)
        mask.lockFocus()
        NSColor.white.setFill()
        NSBezierPath(roundedRect: NSRect(origin: .zero, size: bounds.size),
                     xRadius: Self.cornerRadius, yRadius: Self.cornerRadius).fill()
        mask.unlockFocus()
        backdrop.maskImage = mask
        window?.invalidateShadow()
    }
}

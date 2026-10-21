import AppKit
import SwiftUI

struct ShortcutSettings: View {
    @ObservedObject var manager: ShortcutManager
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Label("唤起快捷键", systemImage: "keyboard").font(.title2.weight(.semibold))
            Text("点击下方区域，再按下你习惯的组合键。").foregroundStyle(.secondary)
            ShortcutRecorder(manager: manager).frame(height: 58)
                .accessibilityLabel("唤起快捷键录入")
            Text(manager.message.isEmpty ? "至少包含 Command、Control 或 Option；Esc 取消录入。" : manager.message)
                .font(.callout).foregroundStyle(manager.hasError ? Color.red : Color.secondary)
                .frame(height: 46, alignment: .topLeading)
            HStack {
                Button("恢复默认 ⌘⇧V") { manager.apply(.defaultShortcut) }
                Spacer()
                if manager.isRecording { Button("取消录入") { manager.cancelRecording() } }
            }
            Divider()
            Text("部分系统快捷键无法录入；若没有响应，请换一个组合。设置会自动保存，菜单栏始终可以打开 ClipFlow。")
                .font(.caption).foregroundStyle(.secondary)
        }.padding(24).frame(width: 410)
    }
}

struct ShortcutRecorder: NSViewRepresentable {
    @ObservedObject var manager: ShortcutManager
    func makeNSView(context: Context) -> ShortcutRecorderView { ShortcutRecorderView(manager: manager) }
    func updateNSView(_ view: ShortcutRecorderView, context: Context) {
        view.needsDisplay = true
        if manager.isRecording {
            DispatchQueue.main.async { [weak view] in
                guard let view, view.manager.isRecording, view.window?.isKeyWindow == true else { return }
                view.window?.makeFirstResponder(view)
            }
        }
    }
}

final class ShortcutRecorderView: NSView {
    let manager: ShortcutManager
    init(manager: ShortcutManager) {
        self.manager = manager
        super.init(frame: .zero)
        setAccessibilityElement(true)
        setAccessibilityRole(.button)
        setAccessibilityLabel("录入唤起快捷键")
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    override var acceptsFirstResponder: Bool { true }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
    override func mouseDown(with event: NSEvent) { manager.startRecording(); window?.makeFirstResponder(self); needsDisplay = true }
    override func resignFirstResponder() -> Bool { manager.cancelRecording(); return super.resignFirstResponder() }
    override func accessibilityPerformPress() -> Bool {
        manager.startRecording(); window?.makeFirstResponder(self); needsDisplay = true
        return true
    }
    override func keyDown(with event: NSEvent) {
        if !manager.isRecording, event.keyCode == 49 || event.keyCode == 36 {
            _ = accessibilityPerformPress()
            return
        }
        if !consume(event) { super.keyDown(with: event) }
    }
    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        consume(event) || super.performKeyEquivalent(with: event)
    }
    private func consume(_ event: NSEvent) -> Bool {
        guard manager.isRecording, event.type == .keyDown else { return false }
        guard !event.isARepeat else { return true }
        if event.keyCode == 53 { manager.cancelRecording() }
        else { manager.apply(Shortcut(event: event)) }
        needsDisplay = true
        return true
    }
    override func draw(_ dirtyRect: NSRect) {
        let recording = manager.isRecording
        let rect = bounds.insetBy(dx: 1, dy: 1)
        let path = NSBezierPath(roundedRect: rect, xRadius: 10, yRadius: 10)
        (recording ? NSColor.controlAccentColor.withAlphaComponent(0.08) : NSColor.controlBackgroundColor).setFill(); path.fill()
        (recording ? NSColor.controlAccentColor : NSColor.separatorColor).setStroke(); path.lineWidth = recording ? 2 : 1; path.stroke()
        let text = recording ? "请按下新的组合键…" : manager.shortcut.display
        let attributes: [NSAttributedString.Key: Any] = [.font: NSFont.systemFont(ofSize: recording ? 15 : 21, weight: .medium), .foregroundColor: NSColor.labelColor]
        let size = (text as NSString).size(withAttributes: attributes)
        (text as NSString).draw(at: NSPoint(x: (bounds.width-size.width)/2, y: (bounds.height-size.height)/2), withAttributes: attributes)
    }
}

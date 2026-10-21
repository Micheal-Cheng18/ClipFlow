import SwiftUI
import AppKit
import Carbon
import QuartzCore
import Combine

@MainActor final class Delegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    let store = Store()
    var panel: NSPanel!
    var status: NSStatusItem!
    var previous: NSRunningApplication?
    var hotkey: EventHotKeyRef?
    var monitors: [Any] = []
    var presentation = 0
    var closing = false
    var subscriptions = Set<AnyCancellable>()
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        panel = ClipPanel(contentRect: NSRect(x: 0, y: 0, width: 420, height: 540), styleMask: [.borderless], backing: .buffered, defer: false)
        panel.level = .floating; panel.isFloatingPanel = true; panel.hidesOnDeactivate = false; panel.delegate = self
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.contentView = InteractiveHostingView(rootView: Content(store: store, paste: { [weak self] in self?.paste($0) }))
        Publishers.Merge(store.$clips.map { _ in () }, store.$query.map { _ in () })
            .receive(on: RunLoop.main).sink { [weak self] in self?.resizePanel() }.store(in: &subscriptions)
        panel.isOpaque = false; panel.backgroundColor = .clear; panel.hasShadow = true
        status = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        status.button?.title = "⌘V"; status.button?.target = self; status.button?.action = #selector(toggle)
        let menu = NSMenu(); menu.addItem(withTitle: "打开 ClipFlow", action: #selector(toggle), keyEquivalent: "").target = self
        menu.addItem(withTitle: "辅助功能权限…", action: #selector(permission), keyEquivalent: "").target = self
        menu.addItem(withTitle: "退出", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        status.menu = menu
        InstallEventHandler(GetApplicationEventTarget(), { _, _, data in
            guard let data else { return OSStatus(eventNotHandledErr) }
            Task { @MainActor in Unmanaged<Delegate>.fromOpaque(data).takeUnretainedValue().toggle() }; return noErr
        }, 1, [EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))], Unmanaged.passUnretained(self).toOpaque(), nil)
        let result = RegisterEventHotKey(UInt32(kVK_ANSI_V), UInt32(cmdKey | shiftKey), EventHotKeyID(signature: 0x434C4950, id: 1), GetApplicationEventTarget(), 0, &hotkey)
        if result != noErr { status.button?.title = "ClipFlow ⚠" }
        if let monitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown], handler: { [weak self] _ in
            guard let self, !self.panel.frame.contains(NSEvent.mouseLocation) else { return }
            self.hide()
        }) { monitors.append(monitor) }
        if let monitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .leftMouseDown, .rightMouseDown], handler: { [weak self] event in
            if event.type == .keyDown && event.keyCode == 53 { self?.hide(); return nil }
            if event.type != .keyDown, let self, self.panel.isVisible, !self.panel.frame.contains(NSEvent.mouseLocation) { self.hide() }; return event
        }) { monitors.append(monitor) }
    }
    @objc func permission() { let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary; _ = AXIsProcessTrustedWithOptions(options) }
    @objc func toggle() {
        if panel.isVisible { hide(); return }
        if let front = NSWorkspace.shared.frontmostApplication, front.processIdentifier != ProcessInfo.processInfo.processIdentifier { previous = front }
        store.query = ""
        let point = NSEvent.mouseLocation
        let frame = (NSScreen.screens.first { $0.frame.contains(point) } ?? NSScreen.main)?.visibleFrame ?? .zero
        let size = NSSize(width: store.panelWidth, height: store.panelHeight)
        panel.setFrame(NSRect(origin: NSPoint(x: max(frame.minX, min(point.x - 20, frame.maxX - size.width)), y: max(frame.minY, min(point.y - size.height, frame.maxY - size.height))), size: size), display: false)
        presentation += 1
        closing = false
        let target = panel.frame
        panel.alphaValue = 0
        panel.setFrame(target.insetBy(dx: 4, dy: 4).offsetBy(dx: 0, dy: -6), display: false)
        NSApp.activate(ignoringOtherApps: true)
        panel.makeKeyAndOrderFront(nil)
        NSAnimationContext.runAnimationGroup { context in
            context.duration = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion ? 0 : 0.2
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            panel.animator().alphaValue = 1
            panel.animator().setFrame(target, display: true)
        }
    }
    func resizePanel() {
        guard panel.isVisible, !closing else { return }
        var frame = panel.frame
        let top = frame.maxY
        frame.size = NSSize(width: store.panelWidth, height: store.panelHeight)
        frame.origin.y = top - frame.height
        if let screen = panel.screen {
            frame.origin.y = max(screen.visibleFrame.minY, frame.origin.y)
            frame.origin.x = max(screen.visibleFrame.minX, min(frame.origin.x, screen.visibleFrame.maxX - frame.width))
        }
        panel.setFrame(frame, display: true)
    }
    func hide() {
        guard panel.isVisible, !closing else { return }
        closing = true
        presentation += 1
        let token = presentation
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion ? 0 : 0.16
            if !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion { self.panel.animator().setFrame(self.panel.frame.insetBy(dx: 3, dy: 3).offsetBy(dx: 0, dy: -4), display: true) }
            self.panel.animator().alphaValue = 0
        }, completionHandler: { [weak self] in
            guard let self, self.presentation == token else { return }
            self.panel.orderOut(nil)
            self.closing = false
        })
    }
    func windowDidResignKey(_ notification: Notification) {
        // Defer until AppKit finishes an activation transition; only close if
        // focus really moved to another app, never during an internal click.
        DispatchQueue.main.async { [weak self] in
            guard let self, !NSApp.isActive else { return }
            self.hide()
        }
    }
    func paste(_ clip: Clip) {
        store.copy(clip); hide()
        guard let app = previous, app.processIdentifier != ProcessInfo.processInfo.processIdentifier else { return }
        app.activate()
        guard AXIsProcessTrusted() else { permission(); return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            guard NSWorkspace.shared.frontmostApplication?.processIdentifier == app.processIdentifier else { return }
            let source = CGEventSource(stateID: .combinedSessionState)
            let down = CGEvent(keyboardEventSource: source, virtualKey: 9, keyDown: true); down?.flags = .maskCommand
            let up = CGEvent(keyboardEventSource: source, virtualKey: 9, keyDown: false); up?.flags = .maskCommand
            down?.post(tap: .cghidEventTap); up?.post(tap: .cghidEventTap)
        }
    }
}

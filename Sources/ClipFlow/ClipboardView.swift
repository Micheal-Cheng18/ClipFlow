import SwiftUI
import AppKit
import Carbon
import QuartzCore
import Combine

// Limit window dragging to the header so content buttons keep normal mouse handling.
struct DragHandle: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView { HeaderDragView() }
    func updateNSView(_ nsView: NSView, context: Context) {}
}
final class HeaderDragView: NSView {
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
    override func mouseDown(with event: NSEvent) { window?.performDrag(with: event) }
}
struct ClipRow: View {
    let clip: Clip
    let paste: () -> Void
    let pin: () -> Void
    let delete: () -> Void
    @State private var hovered = false
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: clip.imageData == nil ? "doc.text" : "photo").font(.system(size: 18)).foregroundStyle(.secondary)
                .frame(width: 36, height: 40).background(.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 9))
            Button(action: paste) {
                VStack(alignment: .leading, spacing: 6) {
                    if let data = clip.imageData, let image = NSImage(data: data) {
                        Image(nsImage: image).resizable().scaledToFit().frame(maxWidth: .infinity, maxHeight: 90, alignment: .leading).clipShape(RoundedRectangle(cornerRadius: 6))
                    }
                    Text(clip.text).font(.system(size: 13)).lineLimit(3).multilineTextAlignment(.leading).frame(maxWidth: .infinity, alignment: .leading)
                    Text(clip.imageData != nil ? (clip.pinned ? "已固定 · 图片" : "图片") : (clip.pinned ? "已固定 · 文本" : "文本 · \(clip.text.count) 字符")).font(.system(size: 10)).foregroundStyle(.secondary)
                }.contentShape(Rectangle())
            }.buttonStyle(.plain)
            VStack(spacing: 8) {
                Button(action: pin) { Image(systemName: clip.pinned ? "pin.fill" : "pin").foregroundStyle(clip.pinned ? Color.accentColor : .secondary).frame(width: 28, height: 24).contentShape(Rectangle()) }.help("固定 / 取消固定")
                Button(action: delete) { Image(systemName: "trash").frame(width: 28, height: 24).contentShape(Rectangle()) }.help("删除记录")
            }.buttonStyle(.borderless)
        }.padding(12)
        .background(hovered ? Color.primary.opacity(0.075) : Color.primary.opacity(0.018), in: RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(.primary.opacity(hovered ? 0.07 : 0.025)))
        .onHover { hovered = $0 }.animation(.easeOut(duration: 0.16), value: hovered)
    }
}
struct Content: View {
    @ObservedObject var store: Store
    @ObservedObject var shortcuts: ShortcutManager
    var paste: (Clip) -> Void
    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                Image(systemName: "square.on.square.fill").font(.system(size: 18)).foregroundStyle(.white).frame(width: 32, height: 32).background(.blue.gradient, in: RoundedRectangle(cornerRadius: 10))
                VStack(alignment: .leading, spacing: 2) { Text("ClipFlow · 0.7.1").font(.system(size: 16, weight: .semibold)); Text("你的剪贴板，随手可得").font(.system(size: 11)).foregroundStyle(.secondary) }
                Spacer()
                Text(shortcuts.isAvailable ? shortcuts.shortcut.display : "快捷键 ⚠").font(.system(size: 11, weight: .medium, design: .monospaced)).foregroundStyle(.secondary).padding(7).background(.primary.opacity(0.05), in: RoundedRectangle(cornerRadius: 7))
            }.padding(16).overlay { DragHandle().help("拖动移动窗口") }
            HStack(spacing: 8) { Image(systemName: "magnifyingglass").foregroundStyle(.secondary); TextField("搜索复制过的内容", text: $store.query).textFieldStyle(.plain); if !store.query.isEmpty { Button { store.query = "" } label: { Image(systemName: "xmark.circle.fill") }.buttonStyle(.plain) } }.padding(11).background(.primary.opacity(0.055), in: RoundedRectangle(cornerRadius: 10)).padding(.horizontal, 16)
            HStack { Text("历史记录"); Spacer(); Text("\(store.visible.count) 条") }.font(.system(size: 11, weight: .medium)).foregroundStyle(.secondary).padding(.horizontal, 22).padding(.top, 14).padding(.bottom, 10)
            ScrollView {
                LazyVStack(spacing: 5) {
                    ForEach(store.visible) { clip in
                        ClipRow(clip: clip, paste: { paste(clip) }, pin: {
                            if let i = store.clips.firstIndex(where: { $0.id == clip.id }) { withAnimation(.snappy(duration: 0.22)) { store.clips[i].pinned.toggle() }; store.save() }
                        }, delete: { withAnimation(.easeOut(duration: 0.18)) { store.clips.removeAll { $0.id == clip.id } }; store.save() })
                    }
                    if store.visible.isEmpty {
                        VStack(spacing: 10) { Image(systemName: store.query.isEmpty ? "clipboard" : "magnifyingglass").font(.system(size: 32, weight: .light)); Text(store.query.isEmpty ? "复制一点灵感" : "没有找到相关内容").font(.system(size: 14, weight: .medium)); Text("复制的文字会自动出现在这里").font(.caption) }.foregroundStyle(.secondary).frame(maxWidth: .infinity).padding(.vertical, 65)
                    }
                }.padding(.horizontal, 16).padding(.bottom, 12)
            }
            Divider().padding(.horizontal, 16)
            HStack {
                Button { store.paused.toggle() } label: { Label(store.paused ? "继续记录" : "正在记录", systemImage: store.paused ? "play.circle" : "pause.circle").foregroundStyle(store.paused ? Color.orange : Color.secondary) }.buttonStyle(.plain)
                Spacer()
                Button("清空未固定项") { withAnimation(.easeOut(duration: 0.2)) { store.clips.removeAll { !$0.pinned } }; store.save() }.buttonStyle(.borderless).disabled(!store.clips.contains { !$0.pinned })
            }.font(.system(size: 11)).padding(18)
        }.frame(width: store.panelWidth, height: store.panelHeight)
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(.primary.opacity(0.10)))
    }
}

// Deterministic illustrated demo; no real clipboard data or screen recording.
import AppKit
import ImageIO
import UniformTypeIdentifiers
let width = 760, height = 620
let output = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "docs/media/demo.gif"
let destination = CGImageDestinationCreateWithURL(URL(fileURLWithPath: output) as CFURL, UTType.gif.identifier as CFString, 60, nil)!
CGImageDestinationSetProperties(destination, [kCGImagePropertyGIFDictionary: [kCGImagePropertyGIFLoopCount: 0]] as CFDictionary)
func box(_ rect: NSRect, _ color: NSColor, _ radius: CGFloat = 12) { color.setFill(); NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius).fill() }
func text(_ string: String, _ x: CGFloat, _ y: CGFloat, _ size: CGFloat = 14, _ color: NSColor = .white) { (string as NSString).draw(at: NSPoint(x: x, y: y), withAttributes: [.font: NSFont.systemFont(ofSize: size, weight: .medium), .foregroundColor: color]) }
for frame in 0..<60 {
    let image = NSImage(size: NSSize(width: width, height: height))
    image.lockFocus()
    box(NSRect(x: 0,y: 0,width: width,height: height), NSColor(calibratedRed: 0.07, green: 0.09, blue: 0.15, alpha: 1), 0)
    text("ClipFlow", 48, 558, 28)
    text("Clipboard, one shortcut away.", 48, 530, 14, .lightGray)
    text("ILLUSTRATED DEMO · 示例数据 / 非实机录屏", 48, 25, 11, .lightGray)
    let stage = frame / 10
    let captions = ["⌘ ⇧ V   唤起历史", "搜索复制过的内容", "固定常用内容", "图片缩略图与粘贴", "删除与清空未固定项", "拖动标题移动窗口"]
    text(captions[stage], 48, 490, 17)
    let progress = CGFloat(frame % 10) / 9
    var px: CGFloat = 190
    if stage == 5 { px += progress * 65 }
    let alpha: CGFloat = stage == 0 ? min(1, progress * 2) : 1
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current?.cgContext.setAlpha(alpha)
    box(NSRect(x:px-4,y:69,width:388,height:408), NSColor.black.withAlphaComponent(0.2), 22)
    box(NSRect(x:px,y:77,width:380,height:400), NSColor(calibratedWhite:0.18,alpha:1),18)
    text("▣  ClipFlow",px+18,440,18)
    text("⌘ ⇧ V",px+292,443,12,.lightGray)
    box(NSRect(x:px+16,y:391,width:348,height:32),NSColor.white.withAlphaComponent(0.07),8)
    text(stage == 1 ? "⌕  Swift" : "⌕  搜索复制过的内容",px+26,400,12,.lightGray)
    text("历史记录",px+18,366,11,.lightGray)
    let entries = stage == 1 ? ["SwiftUI + AppKit", "Swift makes it simple."] : (stage == 4 ? ["SwiftUI + AppKit"] : ["SwiftUI + AppKit", "把灵感留在手边。", "图片 · 设计灵感"])
    for (i,entry) in entries.enumerated() {
        let y = CGFloat(282 - i*77)
        box(NSRect(x:px+14,y:y,width:352,height:68),NSColor.white.withAlphaComponent(i == 0 && stage == 2 ? 0.12 : 0.04),10)
        if i == 2 {
            box(NSRect(x:px+26,y:y+12,width:65,height:44),NSColor(calibratedRed:0.25,green:0.5,blue:0.8,alpha:1),6)
            box(NSRect(x:px+35,y:y+20,width:26,height:20),.systemTeal,5)
            text(entry,px+104,y+34,12)
        } else { text(entry,px+28,y+34,13); text("文本",px+28,y+13,10,.lightGray) }
        text(i == 0 && stage >= 2 ? "●" : "○",px+326,y+40,13,i == 0 && stage >= 2 ? .systemBlue : .lightGray)
        text("×",px+328,y+16,15,.lightGray)
    }
    text("◉ 正在记录",px+18,94,11,.lightGray)
    text("清空未固定项",px+275,94,11,.lightGray)
    if stage == 2 { text("↖",px+337,318,28,.white) }
    if stage == 3 { text("↖",px+220,165,28,.white) }
    if stage == 4 { text("↖",px+316,103,28,.white) }
    if stage == 5 { text("↖",px+160,438,28,.white) }
    NSGraphicsContext.restoreGraphicsState()
    image.unlockFocus()
    let cg = image.cgImage(forProposedRect:nil,context:nil,hints:nil)!
    CGImageDestinationAddImage(destination,cg,[kCGImagePropertyGIFDictionary:[kCGImagePropertyGIFDelayTime:0.13]] as CFDictionary)
}
precondition(CGImageDestinationFinalize(destination))

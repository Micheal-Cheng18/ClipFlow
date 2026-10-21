// Illustrated product demo. Uses only synthetic data, never the system clipboard.
// Render at 25 fps, then encode with generate-demo.sh for a stable GIF palette.
import AppKit
import ImageIO
import UniformTypeIdentifiers

let width = 840, height = 620, fps = 25, frameCount = 410
let directory = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "/tmp/clipflow-demo-frames"
try FileManager.default.createDirectory(atPath: directory, withIntermediateDirectories: true)
let ink = NSColor(calibratedRed: 0.15, green: 0.18, blue: 0.23, alpha: 1)
let muted = NSColor(calibratedRed: 0.48, green: 0.51, blue: 0.57, alpha: 1)
let blue = NSColor(calibratedRed: 0.19, green: 0.40, blue: 0.94, alpha: 1)
func clamp(_ x: Double) -> Double { min(1, max(0, x)) }
func smooth(_ x: Double) -> Double { let v = clamp(x); return v * v * (3 - 2 * v) }
func progress(_ t: Double, _ start: Double, _ duration: Double) -> Double { smooth((t - start) / duration) }
func box(_ r: CGRect, _ c: NSColor, _ radius: CGFloat = 10, stroke: NSColor? = nil) {
    let p = NSBezierPath(roundedRect: r, xRadius: radius, yRadius: radius)
    c.setFill(); p.fill()
    if let stroke { stroke.setStroke(); p.lineWidth = 0.7; p.stroke() }
}
// Drawing coordinates use a top-left origin, including AppKit text.
func label(_ value: String, _ x: CGFloat, _ y: CGFloat, _ size: CGFloat = 13, _ color: NSColor = ink, _ weight: NSFont.Weight = .regular) {
    (value as NSString).draw(at: CGPoint(x: x, y: y), withAttributes: [.font: NSFont.systemFont(ofSize: size, weight: weight), .foregroundColor: color])
}
func symbol(_ name: String, _ x: CGFloat, _ y: CGFloat, _ size: CGFloat = 14, _ color: NSColor = muted) {
    guard let source = NSImage(systemSymbolName: name, accessibilityDescription: nil)?.withSymbolConfiguration(.init(pointSize: size, weight: .medium)) else { return }
    let image = NSImage(size: source.size)
    image.lockFocus(); color.setFill(); NSRect(origin: .zero, size: source.size).fill(); source.draw(at: .zero, from: .zero, operation: .destinationIn, fraction: 1); image.unlockFocus()
    image.draw(in: CGRect(x: x, y: y, width: size, height: size), from: .zero, operation: .sourceOver, fraction: 1, respectFlipped: true, hints: nil)
}
func opacity(_ a: Double, _ body: () -> Void) {
    guard a > 0 else { return }
    NSGraphicsContext.saveGraphicsState()
    let context = NSGraphicsContext.current!.cgContext
    context.setAlpha(a)
    context.beginTransparencyLayer(auxiliaryInfo: nil)
    body()
    context.endTransparencyLayer()
    NSGraphicsContext.restoreGraphicsState()
}
func landscape(_ r: CGRect) {
    NSGraphicsContext.saveGraphicsState()
    NSBezierPath(roundedRect: r, xRadius: 7, yRadius: 7).addClip()
    NSGradient(starting: NSColor(calibratedRed: 0.68, green: 0.83, blue: 0.97, alpha: 1), ending: NSColor(calibratedRed: 0.94, green: 0.85, blue: 0.78, alpha: 1))!.draw(in: r, angle: 75)
    NSColor.white.withAlphaComponent(0.85).setFill(); NSBezierPath(ovalIn: CGRect(x: r.minX+r.width*0.67, y:r.minY+r.height*0.18, width:r.height*0.22,height:r.height*0.22)).fill()
    let p = NSBezierPath(); p.move(to: CGPoint(x:r.minX-8,y:r.maxY)); p.line(to: CGPoint(x:r.minX+r.width*0.35,y:r.minY+r.height*0.35)); p.line(to: CGPoint(x:r.minX+r.width*0.7,y:r.maxY)); p.close(); NSColor(calibratedRed:0.30,green:0.52,blue:0.63,alpha:1).setFill();p.fill()
    let q = NSBezierPath(); q.move(to: CGPoint(x:r.minX+r.width*0.35,y:r.maxY)); q.line(to: CGPoint(x:r.minX+r.width*0.78,y:r.minY+r.height*0.48)); q.line(to: CGPoint(x:r.maxX+10,y:r.maxY));q.close(); NSColor(calibratedRed:0.22,green:0.39,blue:0.48,alpha:1).setFill();q.fill()
    NSGraphicsContext.restoreGraphicsState()
}
struct Stop { var time: Double; var point: CGPoint }
let stops: [Stop] = [
    .init(time:0,point:.init(x:330,y:370)), .init(time:1.8,point:.init(x:330,y:370)),
    .init(time:2.45,point:.init(x:530,y:200)), .init(time:3.65,point:.init(x:530,y:200)),
    .init(time:4.0,point:.init(x:737,y:200)), .init(time:4.4,point:.init(x:737,y:200)),
    .init(time:4.95,point:.init(x:730,y:281)), .init(time:5.5,point:.init(x:730,y:281)),
    .init(time:6.35,point:.init(x:559,y:441)), .init(time:7.25,point:.init(x:559,y:441)),
    .init(time:7.8,point:.init(x:294,y:329)), .init(time:8.9,point:.init(x:294,y:329)),
    .init(time:9.5,point:.init(x:731,y:382)), .init(time:10.1,point:.init(x:731,y:382)),
    .init(time:10.9,point:.init(x:699,y:514)), .init(time:11.6,point:.init(x:699,y:514)),
    .init(time:12.15,point:.init(x:564,y:145)), .init(time:12.45,point:.init(x:564,y:145)),
    .init(time:13.35,point:.init(x:601,y:166)), .init(time:13.9,point:.init(x:601,y:166)),
    .init(time:14.5,point:.init(x:318,y:414)), .init(time:15.25,point:.init(x:318,y:414)),
    .init(time:16.0,point:.init(x:330,y:370))
]
func pointer(_ t: Double) -> CGPoint {
    for i in 1..<stops.count where t < stops[i].time {
        let a=stops[i-1],b=stops[i]; let u=CGFloat(progress(t,a.time,b.time-a.time))
        return CGPoint(x:a.point.x+(b.point.x-a.point.x)*u,y:a.point.y+(b.point.y-a.point.y)*u)
    }; return stops.last!.point
}
func cursor(_ p: CGPoint, _ t: Double) {
    NSGraphicsContext.saveGraphicsState(); let c=NSGraphicsContext.current!.cgContext; c.translateBy(x:p.x,y:p.y)
    let path=NSBezierPath(); path.move(to:.zero);path.line(to:.init(x:0,y:23));path.line(to:.init(x:6,y:17));path.line(to:.init(x:11,y:28));path.line(to:.init(x:16,y:25));path.line(to:.init(x:11,y:15));path.line(to:.init(x:21,y:15));path.close()
    NSColor.white.setStroke();path.lineWidth=3;path.stroke(); ink.setFill();path.fill();NSGraphicsContext.restoreGraphicsState()
    for click in [2.50,4.03,5.03,6.43,9.58,11.0,14.58] {
        let u=(t-click)/0.36
        if u >= 0 && u <= 1 { opacity((1-u)*0.45) { blue.setStroke(); let r=CGFloat(7+u*15);let ring=NSBezierPath(ovalIn:CGRect(x:p.x-r,y:p.y-r,width:r*2,height:r*2));ring.lineWidth=1.5;ring.stroke() } }
    }
}
let chapters: [(Double,String,String)] = [
    (0,"随手唤起","⌘ ⇧ V，让历史来到鼠标身边。"),
    (2.1,"即输即搜","找到需要的那段文字。"),
    (4.45,"留下常用内容","轻点固定，下次依然在。"),
    (5.8,"不止文字","图片也能一键粘贴回原应用。"),
    (8.55,"轻松整理","删除一条，其他记录自然补位。"),
    (10.45,"清空，保留重要的","未固定项清空，固定项留下。"),
    (11.85,"跟随你的工作流","拖动标题，放到顺手的位置。"),
    (14.05,"用完即走","点击外部，轻盈收起。")
]

for frame in 0..<frameCount {
    autoreleasepool {
        let t=Double(frame)/Double(fps)
        let rep=NSBitmapImageRep(bitmapDataPlanes:nil,pixelsWide:width,pixelsHigh:height,bitsPerSample:8,samplesPerPixel:4,hasAlpha:true,isPlanar:false,colorSpaceName:.deviceRGB,bytesPerRow:width*4,bitsPerPixel:32)!
        NSGraphicsContext.saveGraphicsState(); NSGraphicsContext.current=NSGraphicsContext(bitmapImageRep:rep)
        let ctx=NSGraphicsContext.current!.cgContext;ctx.translateBy(x:0,y:CGFloat(height));ctx.scaleBy(x:1,y:-1)
        // A flipped AppKit context keeps text and vector drawing in the same space.
        NSGraphicsContext.current=NSGraphicsContext(cgContext:ctx,flipped:true)
        box(CGRect(x:0,y:0,width:width,height:height),NSColor(calibratedRed:0.94,green:0.95,blue:0.98,alpha:1),0)
        box(CGRect(x:35,y:31,width:31,height:31),blue,9);symbol("square.on.square.fill",43,39,15,.white)
        label("ClipFlow",76,33,22,ink,.semibold);label("macOS clipboard manager",77,60,11,muted)
        label("示例演示 · 非实机录屏",653,44,11,muted)
        // Quiet context window: shows the image being pasted, not just a changing caption.
        box(CGRect(x:48,y:267,width:324,height:244),NSColor.white.withAlphaComponent(0.75),14,stroke:ink.withAlphaComponent(0.07))
        for (i,col) in [NSColor.systemRed,.systemYellow,.systemGreen].enumerated() { col.withAlphaComponent(0.65).setFill(); NSBezierPath(ovalIn:CGRect(x:63+i*15,y:283,width:7,height:7)).fill() }
        label("灵感笔记",176,279,10,muted)
        label("A little space for ideas.",69,316,15,ink,.medium)
        label("把值得留下的灵感，放在这里。",69,345,12,muted)
        let pasted=progress(t,6.67,0.28)*(1-progress(t,15.15,0.22))
        opacity(pasted) { landscape(CGRect(x:70,y:376,width:188,height:108)) }
        let chapterIndex=chapters.lastIndex(where: {t >= $0.0}) ?? 0
        let chapter=chapters[chapterIndex]
        // Crossfade feature headings; the last fades back into the opening heading.
        let endReset=progress(t,15.35,0.65)
        func caption(_ idx: Int,_ a: Double) { opacity(a) { label(String(format:"%02d",idx+1),48,132,11,blue,.semibold);label(chapters[idx].1,48,155,25,ink,.semibold);label(chapters[idx].2,48,196,12,muted) } }
        if chapterIndex > 0 && t < chapter.0+0.24 { let a=progress(t,chapter.0,0.24);caption(chapterIndex-1,1-a);caption(chapterIndex,a) }
        else { caption(chapterIndex,1-endReset);if endReset > 0 { caption(0,endReset) } }
        // One continuous panel, no chapter reset or teleporting cards.
        let show1=progress(t,0.65,0.24)*(1-progress(t,6.43,0.22))
        let show2=progress(t,8.12,0.24)*(1-progress(t,14.58,0.22))
        let visible=max(show1,show2)
        let drag=progress(t,12.45,0.9)
        let clear=progress(t,11.0,0.32)
        let pin=progress(t,5.03,0.22)
        let filter=progress(t,2.78,0.22)*(1-progress(t,4.03,0.22))
        let deleted=progress(t,9.58,0.3)
        let panelHeight:CGFloat=420-CGFloat(clear)*151
        let px:CGFloat=396+CGFloat(drag)*37,py:CGFloat=118+CGFloat(drag)*21
        opacity(visible) {
            NSGraphicsContext.saveGraphicsState()
            let scale=CGFloat(0.97+0.03*visible)
            ctx.translateBy(x:px+190,y:py+panelHeight/2+CGFloat(1-visible)*8);ctx.scaleBy(x:scale,y:scale);ctx.translateBy(x:-190,y:-panelHeight/2)
            let shadow=NSShadow();shadow.shadowColor=NSColor.black.withAlphaComponent(0.15);shadow.shadowBlurRadius=22;shadow.shadowOffset=NSSize(width:0,height:-7);shadow.set()
            box(CGRect(x:0,y:0,width:380,height:panelHeight),NSColor(calibratedWhite:0.985,alpha:1),18)
            NSShadow().set()
            box(CGRect(x:0,y:0,width:380,height:panelHeight),.clear,18,stroke:.white.withAlphaComponent(0.95))
            box(CGRect(x:17,y:17,width:30,height:30),blue,9);symbol("square.on.square.fill",25,25,14,.white)
            label("ClipFlow",57,16,16,ink,.semibold);label("你的剪贴板，随手可得",57,37,10,muted)
            box(CGRect(x:294,y:23,width:68,height:24),ink.withAlphaComponent(0.04),6);label("⌘ ⇧ V",307,27,11,muted,.medium)
            box(CGRect(x:16,y:66,width:348,height:34),ink.withAlphaComponent(0.035),9)
            symbol("magnifyingglass",27,76,13)
            var query=""
            if t>=2.7 && t<4.03 { let n=min(5,max(0,Int((t-2.7)/0.11)+1));query=String("Swift".prefix(n)) }
            label(query.isEmpty ? "搜索复制过的内容" : query,48,75,12,query.isEmpty ? muted : ink)
            if !query.isEmpty { symbol("xmark.circle.fill",335,77,12) }
            label("历史记录",18,113,10,muted,.medium)
            let count=clear>0.7 ? "1 条" : (filter>0.6 ? "1 条" : (deleted>0.6 ? "2 条" : "3 条"))
            label(count,337,113,10,muted)
            func card(_ index:Int,_ y:CGFloat,_ alpha:Double) { opacity(alpha) {
                let hover = (index==0 && t>4.6 && t<5.6) || (index==2 && t>6 && t<6.65) || (index==1 && t>9.2 && t<9.85)
                box(CGRect(x:14,y:y,width:352,height:70),ink.withAlphaComponent(hover ? 0.065 : 0.025),10)
                if index==2 { landscape(CGRect(x:26,y:y+10,width:66,height:50));label("山间的一点灵感",104,y+14,12,ink,.medium);label("图片 · PNG",104,y+39,10,muted) }
                else { symbol("doc.text",27,y+20,18);label(index==0 ? "SwiftUI + AppKit" : "把灵感留在手边。",56,y+13,13,ink,.medium);label(index==0 && pin>0.5 ? "已固定 · 文本" : "文本",56,y+39,10,muted) }
                symbol(index==0 && pin>0.5 ? "pin.fill" : "pin",329,y+13,12,index==0 && pin>0.5 ? blue : muted)
                symbol("trash",329,y+43,12)
            } }
            card(0,139,1)
            card(1,216,1-max(filter,deleted))
            card(2,293-CGFloat(deleted)*77,1-max(filter,clear))
            let footerY=panelHeight-38
            ink.withAlphaComponent(0.07).setFill();CGRect(x:16,y:footerY-6,width:348,height:0.5).fill()
            symbol("pause.circle",18,footerY+6,12);label("正在记录",36,footerY+5,10,muted)
            label("清空未固定项",283,footerY+5,10,clear>0.8 ? muted.withAlphaComponent(0.45) : muted)
            NSGraphicsContext.restoreGraphicsState()
        }
        // Shortcut hint appears only at the moments the panel is invoked.
        for start in [0.3,7.8] { let a=progress(t,start,0.12)*(1-progress(t,start+0.48,0.2));opacity(a) { box(CGRect(x:300,y:552,width:240,height:36),ink.withAlphaComponent(0.9),10);label("⌘  ⇧  V    打开剪贴板历史",318,562,12,.white,.medium) } }
        // Explicit undo explains the document reset before the seamless loop.
        let undoHint=progress(t,14.93,0.12)*(1-progress(t,15.6,0.2))
        opacity(undoHint) {
            box(CGRect(x:300,y:552,width:240,height:36),ink.withAlphaComponent(0.9),10)
            label("⌘ Z    撤销本次示例粘贴",324,562,12,.white,.medium)
        }
        cursor(pointer(t),t)
        label("文字 · 图片 · 只保存在本机",48,573,11,muted)
        NSGraphicsContext.restoreGraphicsState()
        let url=URL(fileURLWithPath:directory).appendingPathComponent(String(format:"%04d.png",frame))
        try! rep.representation(using:.png,properties:[:])!.write(to:url)
    }
}
print("Rendered \(frameCount) frames at \(fps) fps to \(directory)")

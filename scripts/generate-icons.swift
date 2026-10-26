import AppKit
let root = CommandLine.arguments[1]
let folder = URL(fileURLWithPath: root).appendingPathComponent("build/AppIcon.iconset")
try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
func image(_ size: Int) -> Data {
    let rep = NSBitmapImageRep(bitmapDataPlanes:nil,pixelsWide:size,pixelsHigh:size,bitsPerSample:8,samplesPerPixel:4,hasAlpha:true,isPlanar:false,colorSpaceName:.deviceRGB,bytesPerRow:0,bitsPerPixel:0)!
    NSGraphicsContext.saveGraphicsState(); NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep:rep)
    let scale = CGFloat(size) / 1024
    NSAffineTransform(transform: AffineTransform(scale: scale)).concat()
    let rect = NSRect(x:32,y:32,width:960,height:960)
    let shape = NSBezierPath(roundedRect:rect,xRadius:214,yRadius:214)
    NSGradient(starting:NSColor(srgbRed:0.06,green:0.62,blue:0.64,alpha:1),ending:NSColor(srgbRed:0.03,green:0.25,blue:0.44,alpha:1))!.draw(in:shape,angle:90)
    NSColor.white.setStroke()
    let mouse = NSBezierPath(roundedRect:NSRect(x:332,y:200,width:360,height:600),xRadius:180,yRadius:180); mouse.lineWidth = 38; mouse.stroke()
    let line = NSBezierPath(); line.move(to:NSPoint(x:512,y:784)); line.line(to:NSPoint(x:512,y:572)); line.lineWidth = 30; line.lineCapStyle = .round; line.stroke()
    NSColor(srgbRed:0.49,green:0.96,blue:0.80,alpha:1).setFill(); NSBezierPath(ovalIn:NSRect(x:474,y:620,width:76,height:90)).fill()
    NSGraphicsContext.restoreGraphicsState()
    return rep.representation(using:.png,properties:[:])!
}
for size in [16,32,128,256,512] {
    try image(size).write(to:folder.appendingPathComponent("icon_\(size)x\(size).png"))
    try image(size*2).write(to:folder.appendingPathComponent("icon_\(size)x\(size)@2x.png"))
}
for size in [16,24,32,48,64,128,256] { try image(size).write(to:URL(fileURLWithPath:root).appendingPathComponent("build/icon-\(size).png")) }

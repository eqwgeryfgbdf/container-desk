import AppKit
let directory=CommandLine.arguments[1]
try FileManager.default.createDirectory(atPath:directory,withIntermediateDirectories:true)
for points in [16,32,128,256,512] {
    for scale in [1,2] {
        let n=points*scale
        let image=NSImage(size:NSSize(width:n,height:n))
        image.lockFocus()
        let rect=NSRect(x:Double(n)*0.07,y:Double(n)*0.07,width:Double(n)*0.86,height:Double(n)*0.86)
        NSColor(calibratedRed:0.08,green:0.39,blue:0.9,alpha:1).setFill()
        NSBezierPath(roundedRect:rect,xRadius:Double(n)*0.19,yRadius:Double(n)*0.19).fill()
        let symbol=NSImage(systemSymbolName:"shippingbox",accessibilityDescription:nil)!.withSymbolConfiguration(.init(pointSize:Double(n)*0.48,weight:.medium))!
        let tinted=NSImage(size:symbol.size)
        tinted.lockFocus();NSColor.white.set();NSRect(origin:.zero,size:symbol.size).fill();symbol.draw(at:.zero,from:.zero,operation:.destinationIn,fraction:1);tinted.unlockFocus()
        tinted.draw(in:NSRect(x:Double(n)*0.25,y:Double(n)*0.25,width:Double(n)*0.5,height:Double(n)*0.5))
        image.unlockFocus()
        let bitmap=NSBitmapImageRep(data:image.tiffRepresentation!)!
        let file="icon_\(points)x\(points)\(scale==2 ? "@2x":"").png"
        try bitmap.representation(using:.png,properties:[:])!.write(to:URL(fileURLWithPath:directory).appendingPathComponent(file))
    }
}

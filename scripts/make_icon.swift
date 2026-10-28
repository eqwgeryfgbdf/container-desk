import AppKit

// Export the approved VM + Package artwork without redrawing the brand.
// Usage: swift scripts/make_icon.swift <output.iconset> [source.png]
let arguments = CommandLine.arguments
guard arguments.count == 2 || arguments.count == 3 else {
    fputs("Usage: swift scripts/make_icon.swift <output.iconset> [source.png]\n", stderr)
    exit(1)
}
let output = URL(fileURLWithPath: arguments[1], isDirectory: true)
let defaultSource = URL(fileURLWithPath: #filePath)
    .deletingLastPathComponent().deletingLastPathComponent()
    .appendingPathComponent("Resources/Brand/ContainerDesk-VM-Package.png")
let source = arguments.count == 3 ? URL(fileURLWithPath: arguments[2]) : defaultSource
guard let artwork = NSImage(contentsOf: source), artwork.size.width > 0 else {
    fputs("Cannot read brand artwork: \(source.path)\n", stderr)
    exit(1)
}
try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
for points in [16, 32, 128, 256, 512] {
    for scale in [1, 2] {
        let pixels = points * scale
        guard let bitmap = NSBitmapImageRep(
            bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels,
            bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true,
            isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
        ), let context = NSGraphicsContext(bitmapImageRep: bitmap) else {
            fatalError("Cannot allocate icon bitmap")
        }
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = context
        context.imageInterpolation = .high
        artwork.draw(in: NSRect(x: 0, y: 0, width: pixels, height: pixels),
                     from: .zero, operation: .copy, fraction: 1)
        NSGraphicsContext.restoreGraphicsState()
        let filename = "icon_\(points)x\(points)\(scale == 2 ? "@2x" : "").png"
        guard let data = bitmap.representation(using: .png, properties: [:]) else {
            fatalError("Cannot encode icon bitmap")
        }
        try data.write(to: output.appendingPathComponent(filename))
    }
}

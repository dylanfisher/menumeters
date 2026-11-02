// Render an SVG into an .iconset folder for iconutil: every size macOS asks for, at 1x and 2x.
//   swift scripts/render-icon.swift <icon.svg> <out.iconset>
// AppKit draws the SVG, so this needs no tool beyond the Xcode toolchain the build already uses.
import AppKit

let arguments = CommandLine.arguments
guard arguments.count == 3 else {
    FileHandle.standardError.write(Data("usage: render-icon.swift <icon.svg> <out.iconset>\n".utf8))
    exit(1)
}
guard let svg = NSImage(contentsOfFile: arguments[1]) else {
    FileHandle.standardError.write(Data("couldn't read an image from \(arguments[1])\n".utf8))
    exit(1)
}
let folder = URL(fileURLWithPath: arguments[2])
try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)

for points in [16, 32, 128, 256, 512] {
    for scale in [1, 2] {
        let pixels = points * scale
        guard
            let bitmap = NSBitmapImageRep(
                bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels, bitsPerSample: 8,
                samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB,
                bytesPerRow: 0, bitsPerPixel: 0)
        else {
            FileHandle.standardError.write(Data("couldn't make a \(pixels) px bitmap\n".utf8))
            exit(1)
        }
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
        svg.draw(in: NSRect(x: 0, y: 0, width: pixels, height: pixels))
        NSGraphicsContext.restoreGraphicsState()
        guard let png = bitmap.representation(using: .png, properties: [:]) else {
            FileHandle.standardError.write(Data("couldn't encode the \(pixels) px PNG\n".utf8))
            exit(1)
        }
        let name = "icon_\(points)x\(points)\(scale == 2 ? "@2x" : "").png"
        try png.write(to: folder.appendingPathComponent(name))
    }
}

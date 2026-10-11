#!/usr/bin/env swift
// Builds the menu bar icon from art-src/menubar/cat-face.png (a black pixel-art cat face on transparency).
// The face is cropped to its opaque pixels, padded square, and scaled with smooth edges to 18 and 36 px (macOS uses 1x and 2x).
// The image set is a template: macOS paints it white on a dark menu bar and black on a light one, so one drawing
// covers both.
// Usage: swift scripts/build-menubar-icon.swift
import AppKit

let root = URL(fileURLWithPath: CommandLine.arguments[0]).deletingLastPathComponent().deletingLastPathComponent()
let source = root.appendingPathComponent("art-src/menubar/cat-face.png")
let imageset = root.appendingPathComponent("app/TokenCats/Assets.xcassets/MenuBarIcon.imageset")

guard let data = try? Data(contentsOf: source), let rep = NSBitmapImageRep(data: data), let image = rep.cgImage else {
    fatalError("cannot read \(source.path)")
}
// The opaque pixels' bounding box (top-left origin, like CGImage cropping).
var minX = rep.pixelsWide, minY = rep.pixelsHigh, maxX = -1, maxY = -1
for y in 0..<rep.pixelsHigh { for x in 0..<rep.pixelsWide {
    var pixel = [Int](repeating: 0, count: 4)
    rep.getPixel(&pixel, atX: x, y: y)
    guard pixel[3] >= 128 else { continue }
    minX = min(minX, x); maxX = max(maxX, x); minY = min(minY, y); maxY = max(maxY, y)
}}
guard maxX >= 0 else { fatalError("no opaque pixels in \(source.lastPathComponent)") }
let side = max(maxX - minX + 1, maxY - minY + 1)
let square = CGRect(x: (minX + maxX + 1 - side) / 2, y: (minY + maxY + 1 - side) / 2, width: side, height: side)
guard let face = image.cropping(to: square) else { fatalError("crop failed") }

try FileManager.default.createDirectory(at: imageset, withIntermediateDirectories: true)
var images: [[String: String]] = []
for (scale, pixels) in [(1, 18), (2, 36)] {
    let name = scale == 1 ? "menubar-cat.png" : "menubar-cat@\(scale)x.png"
    let context = CGContext(data: nil, width: pixels, height: pixels, bitsPerComponent: 8, bytesPerRow: 0,
                            space: CGColorSpace(name: CGColorSpace.sRGB)!,
                            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    context.interpolationQuality = .high
    context.draw(face, in: CGRect(x: 0, y: 0, width: pixels, height: pixels))
    let png = NSBitmapImageRep(cgImage: context.makeImage()!).representation(using: .png, properties: [:])!
    try png.write(to: imageset.appendingPathComponent(name))
    images.append(["idiom": "universal", "filename": name, "scale": "\(scale)x"])
}
let contents: [String: Any] = ["images": images, "info": ["author": "xcode", "version": 1],
                               "properties": ["template-rendering-intent": "template"]]
try JSONSerialization.data(withJSONObject: contents, options: [.prettyPrinted, .sortedKeys])
    .write(to: imageset.appendingPathComponent("Contents.json"))
print("wrote \(imageset.path) from a \(side)×\(side) crop")

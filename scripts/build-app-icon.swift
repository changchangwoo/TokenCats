#!/usr/bin/env swift
// Builds the app icon from the in-game black cat, the first TokenCats cat (art-src/app-icon/black-idle-96.png, the
// idle frame of art-src/cats/black/idle.png, untouched). Close-up: the frame at 10× on a 1024 canvas, ear tips
// 196 px from the top, the tail cleared so only the cat's front shows, on a sky gradient. macOS icon grid: 832 body,
// 22.5% corners, transparent margin. Smaller sizes are scaled down from the 1024 render.
// Also writes a full-bleed square for the GitHub App logo and a 1280×640 repository social preview (the whole cat,
// tail included, at 6×).
// Usage: swift scripts/build-app-icon.swift
import AppKit

let root = URL(fileURLWithPath: CommandLine.arguments[0]).deletingLastPathComponent().deletingLastPathComponent()
let source = root.appendingPathComponent("art-src/app-icon/black-idle-96.png")
let iconset = root.appendingPathComponent("app/TokenCats/Assets.xcassets/AppIcon.appiconset")
let sRGB = CGColorSpace(name: CGColorSpace.sRGB)!

let skyTop = (0x9D, 0xDC, 0xFF), skyBottom = (0x3E, 0x8F, 0xE0)
let scale: CGFloat = 10, earTop: CGFloat = 196
/// In the 96 px frame: the row of the ear tips and the column between the eyes.
let earRow: CGFloat = 6, centerColumn: CGFloat = 44.5
/// The tail, in the 96 px frame: from `fromRow` down, everything right of the first gap after the body (searched
/// from `searchFrom`) is tail. Where the tail touches the body it starts at `touchingColumn` at the latest, one column
/// further left from `shiftRow`.
let tail = (fromRow: 58, searchFrom: 56, touchingColumn: 67, shiftRow: 87)

func context(_ size: Int, height: Int? = nil) -> CGContext {
    CGContext(data: nil, width: size, height: height ?? size, bitsPerComponent: 8, bytesPerRow: 0, space: sRGB,
              bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
}

func cat(withTail: Bool = false) -> CGImage {
    guard let frame = NSImage(contentsOf: source)?.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
        fatalError("missing \(source.path)")
    }
    let ctx = context(96)
    ctx.draw(frame, in: CGRect(x: 0, y: 0, width: 96, height: 96))
    if withTail { return ctx.makeImage()! }
    let pixels = ctx.data!.assumingMemoryBound(to: UInt8.self)
    for row in tail.fromRow..<96 {
        let alpha = { (column: Int) in pixels[row * ctx.bytesPerRow + column * 4 + 3] }
        let touching = row < tail.shiftRow ? tail.touchingColumn : tail.touchingColumn - 1
        let start = min((tail.searchFrom..<96).first { alpha($0) == 0 } ?? touching, touching)
        memset(pixels + row * ctx.bytesPerRow + start * 4, 0, (96 - start) * 4)
    }
    return ctx.makeImage()!
}

func color(_ rgb: (Int, Int, Int)) -> CGColor {
    CGColor(srgbRed: CGFloat(rgb.0) / 255, green: CGFloat(rgb.1) / 255, blue: CGFloat(rgb.2) / 255, alpha: 1)
}

/// The 1024 artwork: `body` is 832 for the app icon (rounded, with margin) or 1024 for the full-bleed square.
func render(body: CGFloat, rounded: Bool) -> CGImage {
    let size: CGFloat = 1024
    let ctx = context(1024)
    let inset = (size - body) / 2
    let rect = CGRect(x: inset, y: inset, width: body, height: body)
    if rounded {
        ctx.addPath(CGPath(roundedRect: rect, cornerWidth: body * 0.225, cornerHeight: body * 0.225, transform: nil))
        ctx.clip()
    }
    let gradient = CGGradient(colorsSpace: sRGB, colors: [color(skyTop), color(skyBottom)] as CFArray, locations: [0, 1])!
    ctx.drawLinearGradient(gradient, start: CGPoint(x: 0, y: rect.maxY), end: CGPoint(x: 0, y: rect.minY), options: [])
    ctx.interpolationQuality = .none
    let x = (size / 2 - centerColumn * scale).rounded()
    let frameTop = earTop - earRow * scale  // same placement in the square
    ctx.draw(cat(), in: CGRect(x: x, y: size - frameTop - 96 * scale, width: 96 * scale, height: 96 * scale))
    return ctx.makeImage()!
}

/// The repository social preview: the whole sitting cat at 6×, centered, ear tips 80 px from the top.
func socialPreview() -> CGImage {
    let (width, height, scale): (CGFloat, CGFloat, CGFloat) = (1280, 640, 6)
    let ctx = context(Int(width), height: Int(height))
    let gradient = CGGradient(colorsSpace: sRGB, colors: [color(skyTop), color(skyBottom)] as CFArray, locations: [0, 1])!
    ctx.drawLinearGradient(gradient, start: CGPoint(x: 0, y: height), end: .zero, options: [])
    ctx.interpolationQuality = .none
    let frameTop = 80 - earRow * scale
    ctx.draw(cat(withTail: true), in: CGRect(x: (width / 2 - centerColumn * scale).rounded(),
                                             y: height - frameTop - 96 * scale, width: 96 * scale, height: 96 * scale))
    return ctx.makeImage()!
}

func scaled(_ image: CGImage, to size: Int) -> CGImage {
    guard size != image.width else { return image }
    let ctx = context(size)
    ctx.interpolationQuality = .high
    ctx.draw(image, in: CGRect(x: 0, y: 0, width: size, height: size))
    return ctx.makeImage()!
}

func write(_ image: CGImage, to url: URL) {
    try! NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:])!.write(to: url)
}

let icon = render(body: 832, rounded: true)
let sizes: [(String, Int)] = [
    ("icon_16x16@1x.png", 16), ("icon_16x16@2x.png", 32), ("icon_32x32@1x.png", 32), ("icon_32x32@2x.png", 64),
    ("icon_128x128@1x.png", 128), ("icon_128x128@2x.png", 256), ("icon_256x256@1x.png", 256),
    ("icon_256x256@2x.png", 512), ("icon_512x512@1x.png", 512), ("icon_512x512@2x.png", 1024),
]
for (file, size) in sizes { write(scaled(icon, to: size), to: iconset.appendingPathComponent(file)) }
write(render(body: 1024, rounded: false), to: root.appendingPathComponent("docs/design/app-icon-square-1024.png"))
write(socialPreview(), to: root.appendingPathComponent("docs/design/social-preview-1280x640.png"))
print("wrote \(sizes.count) icon sizes, docs/design/app-icon-square-1024.png and docs/design/social-preview-1280x640.png")

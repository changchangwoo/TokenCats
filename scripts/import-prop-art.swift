// Turns a source picture of one prop into the art the app ships: trimmed to its opaque pixels, scaled to `height`
// points (the width follows the picture), written at 1x and @2x. Prints the size to put in `RoomProp.art`.
// A picture without transparency is taken to sit on a near-black backdrop: the near-black pixels reached from the
// edges are cleared first, so the prop's own dark outline stays.
//
//   swift scripts/import-prop-art.swift <source image> <image name> <height>
//
// Output: app/TokenCats/Resources/RoomArt/<image name>.png and <image name>@2x.png
import AppKit
import CoreGraphics

let args = CommandLine.arguments
guard args.count == 4, let height = Int(args[3]), height > 0 else {
    print("usage: swift scripts/import-prop-art.swift <source image> <image name> <height>")
    exit(2)
}
let source = URL(fileURLWithPath: args[1]), name = args[2]
let outDir = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
    .appendingPathComponent("app/TokenCats/Resources/RoomArt")

guard let src = CGImageSourceCreateWithURL(source as CFURL, nil),
      let image = CGImageSourceCreateImageAtIndex(src, 0, nil) else {
    print("cannot read \(source.path)"); exit(1)
}

/// The picture as RGBA pixels; without an alpha channel, the backdrop flood-filled from the edges is cleared.
func cutOut(_ image: CGImage) -> CGContext {
    let w = image.width, h = image.height
    let context = CGContext(data: nil, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w * 4,
                            space: CGColorSpace(name: CGColorSpace.sRGB)!,
                            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    context.draw(image, in: CGRect(x: 0, y: 0, width: w, height: h))
    let hasAlpha = ![.none, .noneSkipFirst, .noneSkipLast].contains(image.alphaInfo)
    guard !hasAlpha else { return context }
    let pixels = context.data!.assumingMemoryBound(to: UInt8.self)
    func isBackdrop(_ i: Int) -> Bool { max(pixels[i * 4], pixels[i * 4 + 1], pixels[i * 4 + 2]) <= 24 }
    var seen = [Bool](repeating: false, count: w * h)
    var stack = (0..<w).flatMap { [$0, (h - 1) * w + $0] } + (0..<h).flatMap { [$0 * w, $0 * w + w - 1] }
    while let i = stack.popLast() {
        guard !seen[i], isBackdrop(i) else { continue }
        seen[i] = true
        for c in 0..<4 { pixels[i * 4 + c] = 0 }
        let x = i % w, y = i / w
        if x > 0 { stack.append(i - 1) }
        if x < w - 1 { stack.append(i + 1) }
        if y > 0 { stack.append(i - w) }
        if y < h - 1 { stack.append(i + w) }
    }
    return context
}

/// The smallest rectangle (top-left origin) holding every pixel more than a little opaque.
func opaqueBounds(_ context: CGContext) -> CGRect {
    let w = context.width, h = context.height
    let pixels = context.data!.assumingMemoryBound(to: UInt8.self)
    var minX = w, minY = h, maxX = -1, maxY = -1
    for y in 0..<h {
        for x in 0..<w where pixels[(y * w + x) * 4 + 3] > 16 {
            minX = min(minX, x); maxX = max(maxX, x); minY = min(minY, y); maxY = max(maxY, y)
        }
    }
    guard maxX >= 0 else { print("picture is fully transparent"); exit(1) }
    return CGRect(x: minX, y: minY, width: maxX - minX + 1, height: maxY - minY + 1)
}

let pixels = cutOut(image)
let bounds = opaqueBounds(pixels)
guard let trimmed = pixels.makeImage()?.cropping(to: bounds) else { print("cannot trim"); exit(1) }
let width = Int((Double(height) * bounds.width / bounds.height).rounded())

func write(scale: Int, to url: URL) {
    let w = width * scale, h = height * scale
    let context = CGContext(data: nil, width: w, height: h, bitsPerComponent: 8, bytesPerRow: 0,
                            space: CGColorSpace(name: CGColorSpace.sRGB)!,
                            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    context.interpolationQuality = .high
    context.draw(trimmed, in: CGRect(x: 0, y: 0, width: w, height: h))
    let rep = NSBitmapImageRep(cgImage: context.makeImage()!)
    try! rep.representation(using: .png, properties: [:])!.write(to: url)
}

write(scale: 1, to: outDir.appendingPathComponent("\(name).png"))
write(scale: 2, to: outDir.appendingPathComponent("\(name)@2x.png"))
print("\(name): \(width) × \(height) pt (trimmed source \(Int(bounds.width)) × \(Int(bounds.height)) px)")

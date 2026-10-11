// Turns a source picture into the room art the app ships: scaled to the profile card's 840pt width,
// cropped from the top to the wall (132pt) or floor (68pt) height, written at 1x and @2x.
// Also prints the picture's average colour and its darkest common colour, as a starting point
// for the background's primary colours in room-themes.json.
//
//   swift scripts/import-room-art.swift <wall|floor> <source image> <background id> [top]
//
// `top` picks the band: 0 keeps the top edge (default), 1 keeps the bottom edge, 0.5 the middle. A scene whose
// interesting part is low (trees, a wall top) wants a value near 1.
//
// Output: app/TokenCats/Resources/RoomArt/room-<id>-<part>.png and room-<id>-<part>@2x.png
import AppKit
import CoreGraphics

let args = CommandLine.arguments
guard (4...5).contains(args.count), ["wall", "floor"].contains(args[1]) else {
    print("usage: swift scripts/import-room-art.swift <wall|floor> <source image> <background id> [top 0...1]")
    exit(2)
}
let part = args[1], source = URL(fileURLWithPath: args[2]), id = args[3]
let top = args.count == 5 ? min(1, max(0, Double(args[4]) ?? 0)) : 0
let width = 840, height = part == "wall" ? 132 : 68
let outDir = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
    .appendingPathComponent("app/TokenCats/Resources/RoomArt")

guard let src = CGImageSourceCreateWithURL(source as CFURL, nil),
      let image = CGImageSourceCreateImageAtIndex(src, 0, nil) else {
    print("cannot read \(source.path)"); exit(1)
}

func render(scale: Int) -> CGImage {
    let w = width * scale, h = height * scale
    let context = CGContext(data: nil, width: w, height: h, bitsPerComponent: 8, bytesPerRow: 0,
                            space: CGColorSpace(name: CGColorSpace.sRGB)!,
                            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    context.interpolationQuality = .high
    // Fit the width, keep the aspect ratio, and keep the band `top` asks for: CoreGraphics' origin is bottom-left,
    // so the picture is shifted down by the part of the overflow that lies above the band.
    let drawnHeight = Double(image.height) * Double(w) / Double(image.width)
    guard drawnHeight >= Double(h) else { print("source is too short for \(part)"); exit(1) }
    let above = (drawnHeight - Double(h)) * top
    context.draw(image, in: CGRect(x: 0, y: Double(h) - drawnHeight + above, width: Double(w), height: drawnHeight))
    return context.makeImage()!
}

func write(_ image: CGImage, to url: URL) {
    let dest = CGImageDestinationCreateWithURL(url as CFURL, "public.png" as CFString, 1, nil)!
    CGImageDestinationAddImage(dest, image, nil)
    guard CGImageDestinationFinalize(dest) else { print("cannot write \(url.path)"); exit(1) }
    print("wrote \(url.lastPathComponent)")
}

let one = render(scale: 1)
write(one, to: outDir.appendingPathComponent("room-\(id)-\(part).png"))
write(render(scale: 2), to: outDir.appendingPathComponent("room-\(id)-\(part)@2x.png"))

// Colour hints from the 1x picture.
let rep = NSBitmapImageRep(cgImage: one)
var sum = (0.0, 0.0, 0.0), counts: [String: Int] = [:]
for y in 0..<one.height { for x in 0..<one.width {
    guard let c = rep.colorAt(x: x, y: y)?.usingColorSpace(.sRGB) else { continue }
    sum.0 += c.redComponent; sum.1 += c.greenComponent; sum.2 += c.blueComponent
    // Bucket to 8 levels per channel so near-identical pixels count together.
    let key = String(format: "#%02X%02X%02X", Int(c.redComponent * 7).clamped * 36,
                     Int(c.greenComponent * 7).clamped * 36, Int(c.blueComponent * 7).clamped * 36)
    counts[key, default: 0] += 1
}}
extension Int { var clamped: Int { Swift.min(7, Swift.max(0, self)) } }
let n = Double(one.width * one.height)
print(String(format: "average #%02X%02X%02X", Int(sum.0 / n * 255), Int(sum.1 / n * 255), Int(sum.2 / n * 255)))
func luminance(_ hex: String) -> Int { Int(hex.dropFirst(1).prefix(2), radix: 16)! + Int(hex.dropFirst(3).prefix(2), radix: 16)! + Int(hex.dropFirst(5).prefix(2), radix: 16)! }
let common = counts.filter { Double($0.value) / n > 0.01 }.keys.sorted { luminance($0) < luminance($1) }
print("darkest common (>1%): \(common.first ?? "-")")

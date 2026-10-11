// Makes the closed-eye icon each coat blinks with in the closed notch: finds the eyes in art-src/cats/<coat>/icon.png
// (saturated yellow-green or blue pixels in the face band), paints them over with the surrounding fur, and draws
// a one-pixel lid along each eye's lower edge. Only eye pixels change, in the icon's own sRGB bytes. Writes
// icon-blink.png next to it, plus a side-by-side preview (open | closed, 8x) for review. Run it after changing an
// icon.png, then scripts/build-cat-art.swift. A hand-drawn icon-blink.png is just as fine: skip this script.
//
//   swift scripts/make-blink-icons.swift [preview.png]
import AppKit

let sources = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
    .appendingPathComponent("art-src/cats")
let cats = try! FileManager.default.contentsOfDirectory(atPath: sources.path)
    .filter { FileManager.default.fileExists(atPath: sources.appendingPathComponent("\($0)/icon.png").path) }
    .sorted()
let srgb = CGColorSpace(name: CGColorSpace.sRGB)!

/// RGBA bytes of an image, straight (not premultiplied) alpha.
struct Pixels {
    let width: Int, height: Int
    var bytes: [UInt8]

    init(_ image: CGImage) {
        width = image.width; height = image.height
        bytes = [UInt8](repeating: 0, count: width * height * 4)
        bytes.withUnsafeMutableBytes { buffer in
            let ctx = CGContext(data: buffer.baseAddress, width: width, height: height, bitsPerComponent: 8,
                                bytesPerRow: width * 4, space: srgb,
                                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
            ctx.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        }
    }

    /// (x, y) with y = 0 at the top.
    func at(_ x: Int, _ y: Int) -> (r: Double, g: Double, b: Double, a: Double) {
        let i = (y * width + x) * 4
        let a = Double(bytes[i + 3]) / 255
        guard a > 0 else { return (0, 0, 0, 0) }
        return (Double(bytes[i]) / 255 / a, Double(bytes[i + 1]) / 255 / a, Double(bytes[i + 2]) / 255 / a, a)
    }

    mutating func set(_ x: Int, _ y: Int, _ r: Double, _ g: Double, _ b: Double) {
        let i = (y * width + x) * 4
        let a = Double(bytes[i + 3]) / 255
        bytes[i] = UInt8((r * a * 255).rounded()); bytes[i + 1] = UInt8((g * a * 255).rounded())
        bytes[i + 2] = UInt8((b * a * 255).rounded())
    }

    func image() -> CGImage {
        var copy = bytes
        return copy.withUnsafeMutableBytes { buffer in
            CGContext(data: buffer.baseAddress, width: width, height: height, bitsPerComponent: 8,
                      bytesPerRow: width * 4, space: srgb,
                      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!.makeImage()!
        }
    }
}

func hsv(_ p: (r: Double, g: Double, b: Double, a: Double)) -> (h: Double, s: Double, v: Double) {
    let mx = max(p.r, p.g, p.b), mn = min(p.r, p.g, p.b), d = mx - mn
    var h = 0.0
    if d > 0 {
        if mx == p.r { h = 60 * ((p.g - p.b) / d).truncatingRemainder(dividingBy: 6) }
        else if mx == p.g { h = 60 * ((p.b - p.r) / d + 2) } else { h = 60 * ((p.r - p.g) / d + 4) }
    }
    return (h < 0 ? h + 360 : h, mx == 0 ? 0 : d / mx, mx)
}

/// Eye irises: yellow-green (black, tabby, cheese, tuxedo) or blue (white), never fur orange or nose pink.
func isEye(_ p: (r: Double, g: Double, b: Double, a: Double)) -> Bool {
    guard p.a > 0.5 else { return false }
    let (h, s, v) = hsv(p)
    return s > 0.18 && v > 0.40 && ((h >= 50 && h <= 110) || (h >= 190 && h <= 230))
}

func write(_ image: CGImage, _ url: URL) {
    let dest = CGImageDestinationCreateWithURL(url as CFURL, "public.png" as CFString, 1, nil)!
    CGImageDestinationAddImage(dest, image, nil); CGImageDestinationFinalize(dest)
}

var previews: [(open: CGImage, closed: CGImage)] = []
for coat in cats {
    let folder = sources.appendingPathComponent(coat)
    let source = CGImageSourceCreateImageAtIndex(
        CGImageSourceCreateWithURL(folder.appendingPathComponent("icon.png") as CFURL, nil)!, 0, nil)!
    let open = Pixels(source)
    var closed = open
    let w = open.width, h = open.height
    var eye = Set<Int>()
    for y in (h / 4)...(h * 2 / 3) { for x in 0..<w where isEye(open.at(x, y)) { eye.insert(y * w + x) } }
    // Eyes sit inside the face, ringed by fur. A blue blob that touches the transparent background is something
    // floating beside the cat (the foxfire cat's flames), so drop every connected blob that reaches it.
    var unvisited = eye
    while let start = unvisited.first {
        var blob: Set<Int> = [start], queue = [start], touchesOutside = false
        unvisited.remove(start)
        while let index = queue.popLast() {
            let x = index % w, y = index / w
            for dy in -1...1 { for dx in -1...1 {
                let nx = x + dx, ny = y + dy
                guard nx >= 0, nx < w, ny >= 0, ny < h else { touchesOutside = true; continue }
                if open.at(nx, ny).a <= 0.5 { touchesOutside = true }
                let neighbour = ny * w + nx
                if unvisited.remove(neighbour) != nil { blob.insert(neighbour); queue.append(neighbour) }
            }}
        }
        if touchesOutside { eye.subtract(blob) }
    }
    // Each eye is the box around its iris pixels, so the dark pupil inside closes too. The box fills with the
    // fur just above it, and its bottom row becomes the lid.
    // Dark-faced coats get a light lid and their fur from the darker side of the ring (the tuxedo's white blaze
    // runs between its eyes, the siamese wears a dark mask). The split cat's face is dark on the viewer's left only.
    let darkSides = ["black": [true, true], "tuxedo": [true, true], "siamese": [true, true], "split": [true, false]][coat] ?? [false, false]
    for (index, side) in [eye.filter { $0 % w < w / 2 }, eye.filter { $0 % w >= w / 2 }].enumerated() where !side.isEmpty {
        let darkFace = darkSides[index]
        let lid = darkFace ? (0.45, 0.38, 0.52) : (0.10, 0.08, 0.09)
        let xs = side.map { $0 % w }, ys = side.map { $0 / w }
        var left = xs.min()!, right = xs.max()!
        let top = ys.min()!, bottom = ys.max()!
        // On a light face a pupil can sit beside the iris rather than inside it (the cream cat looks sideways):
        // take in up to two dark columns on either side so the pupil closes too.
        func darkColumn(_ x: Int) -> Bool {
            x >= 0 && x < w && (top...bottom).contains { y in let p = open.at(x, y); return p.a > 0.5 && hsv(p).v < 0.3 }
        }
        if !darkFace {
            for _ in 0..<2 where darkColumn(left - 1) { left -= 1 }
            for _ in 0..<2 where darkColumn(right + 1) { right += 1 }
        }
        // Fur: the median (by brightness) of the ring around the box, outlines and stripes left out.
        var ring: [(r: Double, g: Double, b: Double, a: Double)] = []
        for y in max(0, top - 2)...min(h - 1, bottom + 2) { for x in max(0, left - 2)...min(w - 1, right + 2) {
            guard x < left || x > right || y < top || y > bottom else { continue }
            let p = open.at(x, y)
            guard p.a > 0.5, !isEye(p), hsv(p).v > 0.3 || darkFace else { continue }
            ring.append(p)
        }}
        ring.sort { hsv($0).v < hsv($1).v }
        let pick = darkFace ? ring.count / 4 : ring.count / 2
        let fur = ring.isEmpty ? lid : (ring[pick].r, ring[pick].g, ring[pick].b)
        for y in top...bottom { for x in left...right where open.at(x, y).a > 0.5 {
            if y == bottom { closed.set(x, y, lid.0, lid.1, lid.2) } else { closed.set(x, y, fur.0, fur.1, fur.2) }
        }}
    }
    let blinkName = "icon-blink.png"
    let closedImage = closed.image()
    write(closedImage, folder.appendingPathComponent(blinkName))
    print("\(coat): \(eye.count) eye pixels → art-src/cats/\(coat)/\(blinkName)")
    previews.append((open.image(), closedImage))
}

if CommandLine.arguments.count > 1 {
    let size = 24 * 8, gap = 16
    let ctx = CGContext(data: nil, width: size * 2 + gap, height: previews.count * (size + gap), bitsPerComponent: 8,
                        bytesPerRow: 0, space: srgb, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    ctx.interpolationQuality = .none
    ctx.setFillColor(CGColor(gray: 0.85, alpha: 1)); ctx.fill(CGRect(x: 0, y: 0, width: ctx.width, height: ctx.height))
    for (i, pair) in previews.enumerated() {
        let y = ctx.height - (i + 1) * (size + gap)
        ctx.draw(pair.open, in: CGRect(x: 0, y: y, width: size, height: size))
        ctx.draw(pair.closed, in: CGRect(x: size + gap, y: y, width: size, height: size))
    }
    write(ctx.makeImage()!, URL(fileURLWithPath: CommandLine.arguments[1]))
}

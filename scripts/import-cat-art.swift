#!/usr/bin/env swift
// Turns big AI-generated cat sheets into the six 96 px strip files a coat needs in art-src/cats/<coat>/.
//
//   swift scripts/import-cat-art.swift <coat> --walk-right <sheet> --walk-left <sheet>|mirror --groom <sheet> [options]
//
// Sheets: any PNG with real alpha where each pose is a separate blob on a transparent background (grid cells must
// not touch). Cells are found automatically and read row by row, left to right. A sheet with several rows can be
// narrowed to one row with "<file>#<row>" (0-based), e.g. --walk-right moves.png#0 --walk-left moves.png#1.
//   --walk-right  6 frames of the cat walking to the right (nose on the right).
//   --walk-left   6 frames walking to the left, or the word "mirror" to flip walk-right. Mirror only coats whose
//                 markings are symmetric: a half-and-half face would swap sides and stop matching idle.
//   --groom       10 frames. The first is the seated idle pose (it becomes idle.png too, so grooming starts from
//                 the very frame the cat rests in); the 5th and 9th (positions 4 and 8) are what petting shows,
//                 so they must be the paw-up, eyes-closed poses.
//   --idle-height Height in px of the seated idle silhouette (default 88, what the other coats sit at).
//   --walk-height Height in px of the tallest walking frame per sheet (default 84, black's). A wide drawing is
//                 capped so no frame is wider than 88 px (the room's collision envelope), which can make that walk
//                 shorter than asked; judge the result by head and body size next to black, not by the box.
//   --force       Overwrite an existing art-src/cats/<coat>/. Hand fixes made in the strips are lost: re-import
//                 only when the source sheets changed, otherwise edit the strips.
//
// What it does (the rules in AGENTS.md "sprite.rules"):
//   - one uniform scale per sheet, nearest-neighbour sampling (pixel art stays crisp);
//   - alpha becomes hard: source alpha >= 160 is opaque, anything else transparent; colours are un-premultiplied;
//   - every frame is 96×96 with the silhouette's bottom on y = 93 (2 px floor margin), centred, then nudged
//     sideways (±8 px) so it overlaps its clip's first frame best — the body stays put while legs, tail or a paw move;
//   - idle.png is groom frame 0, pixel for pixel; icon.png is idle's face crop (icon[x,y] = idle[8 + x*80/24, y*80/24]);
//     icon-blink.png starts as a copy of icon.png: run scripts/make-blink-icons.swift next (it only rewrites that file).
// Afterwards run scripts/build-cat-art.swift --gif-preview, look at the frames next to black, and `swift test`.
import Foundation
import ImageIO
import UniformTypeIdentifiers

let frameSize = 96
let floorY = frameSize - 3           // the bottom opaque row of every silhouette
let maxWidth = frameSize - 8         // widest silhouette the room's collision envelope allows
let maxHeight = frameSize - 6
let opaqueThreshold: UInt8 = 160
let alignSearch = 8

struct Pixel: Equatable { var r: UInt8 = 0, g: UInt8 = 0, b: UInt8 = 0, a: UInt8 = 0 }
struct Bitmap {
    let width: Int, height: Int
    var pixels: [Pixel]
    init(width: Int, height: Int) {
        self.width = width; self.height = height
        pixels = Array(repeating: Pixel(), count: width * height)
    }
    subscript(_ x: Int, _ y: Int) -> Pixel {
        get { pixels[y * width + x] }
        set { pixels[y * width + x] = newValue }
    }
}
struct Box {
    var minX: Int, minY: Int, maxX: Int, maxY: Int, count: Int
    var width: Int { maxX - minX + 1 }
    var height: Int { maxY - minY + 1 }
}
struct Failure: Error, CustomStringConvertible { let description: String }

func load(_ url: URL) throws -> Bitmap {
    guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
          let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
        throw Failure(description: "cannot read \(url.path)")
    }
    var bytes = [UInt8](repeating: 0, count: image.width * image.height * 4)
    bytes.withUnsafeMutableBytes { raw in
        let context = CGContext(data: raw.baseAddress, width: image.width, height: image.height, bitsPerComponent: 8,
                                bytesPerRow: image.width * 4, space: CGColorSpace(name: CGColorSpace.sRGB)!,
                                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        context.interpolationQuality = .none
        context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
    }
    var bitmap = Bitmap(width: image.width, height: image.height)
    for index in bitmap.pixels.indices {
        let byte = index * 4
        let a = bytes[byte + 3]
        // Core Graphics hands back premultiplied colour; AI sheets are ~253 alpha inside, so divide it out.
        func straight(_ c: UInt8) -> UInt8 { a == 0 ? 0 : UInt8(min(255, (Int(c) * 255 + Int(a) / 2) / Int(a))) }
        bitmap.pixels[index] = Pixel(r: straight(bytes[byte]), g: straight(bytes[byte + 1]), b: straight(bytes[byte + 2]), a: a)
    }
    return bitmap
}

func save(_ bitmap: Bitmap, to url: URL) throws {
    var bytes = [UInt8](repeating: 0, count: bitmap.width * bitmap.height * 4)
    for (index, pixel) in bitmap.pixels.enumerated() {
        let byte = index * 4
        bytes[byte] = pixel.r; bytes[byte + 1] = pixel.g; bytes[byte + 2] = pixel.b; bytes[byte + 3] = pixel.a
    }
    let provider = CGDataProvider(data: Data(bytes) as CFData)!
    let image = CGImage(width: bitmap.width, height: bitmap.height, bitsPerComponent: 8, bitsPerPixel: 32,
                        bytesPerRow: bitmap.width * 4, space: CGColorSpace(name: CGColorSpace.sRGB)!,
                        bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.last.rawValue), provider: provider,
                        decode: nil, shouldInterpolate: false, intent: .defaultIntent)!
    guard let writer = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil) else {
        throw Failure(description: "cannot create \(url.path)")
    }
    CGImageDestinationAddImage(writer, image, nil)
    guard CGImageDestinationFinalize(writer) else { throw Failure(description: "cannot save \(url.path)") }
}

/// Opaque blobs in a sheet, read row by row then left to right. Specks smaller than 2% of the biggest blob are
/// ignored. Blobs under a quarter of the biggest are detached bits of a pose (a foxfire flame, a sparkle): each joins
/// the pose whose centre is nearest, so the cell's box takes it in. A row is a run of poses whose centres sit within
/// half a pose height of each other.
func cells(of sheet: Bitmap) -> [[Box]] {
    let width = sheet.width, height = sheet.height
    var seen = [Bool](repeating: false, count: width * height)
    var boxes: [Box] = []
    for start in 0..<(width * height) where !seen[start] && sheet.pixels[start].a >= opaqueThreshold {
        seen[start] = true
        var queue = [start], head = 0
        var box = Box(minX: width, minY: height, maxX: 0, maxY: 0, count: 0)
        while head < queue.count {
            let index = queue[head]; head += 1
            let x = index % width, y = index / width
            box.minX = min(box.minX, x); box.minY = min(box.minY, y)
            box.maxX = max(box.maxX, x); box.maxY = max(box.maxY, y); box.count += 1
            for yy in max(0, y - 1)...min(height - 1, y + 1) {
                for xx in max(0, x - 1)...min(width - 1, x + 1) {
                    let neighbour = yy * width + xx
                    if !seen[neighbour] && sheet.pixels[neighbour].a >= opaqueThreshold {
                        seen[neighbour] = true; queue.append(neighbour)
                    }
                }
            }
        }
        boxes.append(box)
    }
    guard let biggest = boxes.map(\.count).max() else { return [] }
    boxes = boxes.filter { $0.count >= biggest / 50 }
    let bits = boxes.filter { $0.count < biggest / 4 }
    boxes = boxes.filter { $0.count >= biggest / 4 }
    func centre(_ box: Box) -> (x: Int, y: Int) { ((box.minX + box.maxX) / 2, (box.minY + box.maxY) / 2) }
    for bit in bits {
        let c = centre(bit)
        guard let owner = boxes.indices.min(by: { a, b in
            let ca = centre(boxes[a]), cb = centre(boxes[b])
            return (ca.x - c.x) * (ca.x - c.x) + (ca.y - c.y) * (ca.y - c.y) < (cb.x - c.x) * (cb.x - c.x) + (cb.y - c.y) * (cb.y - c.y)
        }) else { continue }
        boxes[owner].minX = min(boxes[owner].minX, bit.minX); boxes[owner].minY = min(boxes[owner].minY, bit.minY)
        boxes[owner].maxX = max(boxes[owner].maxX, bit.maxX); boxes[owner].maxY = max(boxes[owner].maxY, bit.maxY)
        boxes[owner].count += bit.count
    }
    boxes.sort { ($0.minY + $0.maxY) < ($1.minY + $1.maxY) }
    var rows: [[Box]] = []
    for box in boxes {
        let centre = (box.minY + box.maxY) / 2
        if let last = rows.last?.last, abs(centre - (last.minY + last.maxY) / 2) < max(last.height, box.height) / 2 {
            rows[rows.count - 1].append(box)
        } else {
            rows.append([box])
        }
    }
    return rows.map { $0.sorted { $0.minX < $1.minX } }
}

/// `box` of `sheet` scaled by `factor` into a 96 px frame: hard alpha, feet on the floor line, centred.
func render(_ sheet: Bitmap, _ box: Box, factor: Double) -> Bitmap {
    let drawWidth = max(1, Int((Double(box.width) * factor).rounded()))
    let drawHeight = max(1, Int((Double(box.height) * factor).rounded()))
    let left = (frameSize - drawWidth) / 2, top = floorY + 1 - drawHeight
    var frame = Bitmap(width: frameSize, height: frameSize)
    for y in 0..<drawHeight {
        for x in 0..<drawWidth {
            let sourceX = min(box.maxX, box.minX + Int((Double(x) + 0.5) * Double(box.width) / Double(drawWidth)))
            let sourceY = min(box.maxY, box.minY + Int((Double(y) + 0.5) * Double(box.height) / Double(drawHeight)))
            let pixel = sheet[sourceX, sourceY]
            if pixel.a >= opaqueThreshold { frame[left + x, top + y] = Pixel(r: pixel.r, g: pixel.g, b: pixel.b, a: 255) }
        }
    }
    return frame
}

func silhouette(_ frame: Bitmap) -> Box {
    var box = Box(minX: frameSize, minY: frameSize, maxX: -1, maxY: -1, count: 0)
    for y in 0..<frameSize { for x in 0..<frameSize where frame[x, y].a > 0 {
        box.minX = min(box.minX, x); box.minY = min(box.minY, y); box.maxX = max(box.maxX, x); box.maxY = max(box.maxY, y)
        box.count += 1
    }}
    return box
}

func shifted(_ frame: Bitmap, by dx: Int) -> Bitmap {
    var result = Bitmap(width: frameSize, height: frameSize)
    for y in 0..<frameSize { for x in 0..<frameSize where (0..<frameSize).contains(x - dx) { result[x, y] = frame[x - dx, y] } }
    return result
}

/// `frame` moved sideways (at most ±8 px, never off the frame) to where its silhouette overlaps `reference` most.
func aligned(_ frame: Bitmap, to reference: Bitmap) -> Bitmap {
    let box = silhouette(frame)
    var best = (score: -1.0, dx: 0)
    for dx in -alignSearch...alignSearch where box.minX + dx >= 0 && box.maxX + dx < frameSize {
        var both = 0, either = 0
        for y in 0..<frameSize { for x in 0..<frameSize {
            let a = reference[x, y].a > 0
            let sx = x - dx
            let b = sx >= 0 && sx < frameSize && frame[sx, y].a > 0
            if a && b { both += 1 }
            if a || b { either += 1 }
        }}
        let score = either == 0 ? 0 : Double(both) / Double(either)
        if score > best.score || (score == best.score && abs(dx) < abs(best.dx)) { best = (score, dx) }
    }
    return shifted(frame, by: best.dx)
}

func mirrored(_ frame: Bitmap) -> Bitmap {
    var result = Bitmap(width: frame.width, height: frame.height)
    for y in 0..<frame.height { for x in 0..<frame.width { result[x, y] = frame[frame.width - 1 - x, y] } }
    return result
}

func strip(_ frames: [Bitmap]) -> Bitmap {
    var result = Bitmap(width: frameSize * frames.count, height: frameSize)
    for (index, frame) in frames.enumerated() {
        for y in 0..<frameSize { for x in 0..<frameSize { result[index * frameSize + x, y] = frame[x, y] } }
    }
    return result
}

/// The closed-notch icon: the top 80×80 of the idle frame, shifted 8 px in, sampled down to 24×24 (the old
/// pipeline's portrait crop, so the face fills the notch).
func icon(from idle: Bitmap) -> Bitmap {
    var icon = Bitmap(width: 24, height: 24)
    for y in 0..<24 { for x in 0..<24 { icon[x, y] = idle[8 + x * 80 / 24, y * 80 / 24] } }
    return icon
}

// MARK: - A sheet argument: "<file>" or "<file>#<row>".

struct Sheet {
    let bitmap: Bitmap
    let boxes: [Box]
    let label: String

    init(_ argument: String, frames expected: Int, root: URL) throws {
        let parts = argument.split(separator: "#", maxSplits: 1).map(String.init)
        let url = URL(fileURLWithPath: parts[0], relativeTo: root)
        bitmap = try load(url)
        let rows = cells(of: bitmap)
        let picked: [Box]
        if parts.count == 2 {
            guard let row = Int(parts[1]), rows.indices.contains(row) else {
                throw Failure(description: "\(parts[0]) has rows 0..<\(rows.count); asked for row \(parts[1])")
            }
            picked = rows[row]
        } else {
            picked = rows.flatMap { $0 }
        }
        guard picked.count == expected else {
            throw Failure(description: "\(argument): expected \(expected) poses, found \(picked.count) "
                          + "(rows: \(rows.map(\.count)))")
        }
        boxes = picked
        label = parts[0]
    }

    /// Largest factor at which every pose fits the envelope and the tallest is at most `height` px.
    func factor(height: Int) -> Double {
        min(Double(height) / Double(boxes.map(\.height).max()!),
            Double(maxWidth) / Double(boxes.map(\.width).max()!),
            Double(maxHeight) / Double(boxes.map(\.height).max()!))
    }

    func frames(factor: Double) -> [Bitmap] {
        let rendered = boxes.map { render(bitmap, $0, factor: factor) }
        return [rendered[0]] + rendered.dropFirst().map { aligned($0, to: rendered[0]) }
    }
}

// MARK: - Main

do {
    var arguments = Array(CommandLine.arguments.dropFirst())
    guard let coat = arguments.first, !coat.hasPrefix("-") else {
        throw Failure(description: "usage: import-cat-art.swift <coat> --walk-right <sheet> --walk-left <sheet>|mirror --groom <sheet>")
    }
    arguments.removeFirst()
    var options: [String: String] = [:]
    var force = false
    while !arguments.isEmpty {
        let key = arguments.removeFirst()
        if key == "--force" { force = true; continue }
        guard key.hasPrefix("--"), !arguments.isEmpty else { throw Failure(description: "unexpected argument \(key)") }
        options[String(key.dropFirst(2))] = arguments.removeFirst()
    }
    guard let walkRightPath = options["walk-right"], let walkLeftPath = options["walk-left"], let groomPath = options["groom"] else {
        throw Failure(description: "--walk-right, --walk-left and --groom are all required")
    }
    let idleHeight = Int(options["idle-height"] ?? "88")!
    let walkHeight = Int(options["walk-height"] ?? "84")!
    let cwd = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    let repo = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
    let folder = repo.appendingPathComponent("art-src/cats/\(coat)")
    if FileManager.default.fileExists(atPath: folder.path) && !force {
        throw Failure(description: "\(folder.path) exists; pass --force to overwrite (hand edits in the strips are lost)")
    }

    // Grooming first: its seated pose sets the cat's size, and it is the idle frame.
    let groomSheet = try Sheet(groomPath, frames: 10, root: cwd)
    let groomFactor = min(Double(idleHeight) / Double(groomSheet.boxes[0].height),
                          groomSheet.factor(height: maxHeight))
    let groom = groomSheet.frames(factor: groomFactor)
    let idle = groom[0]

    // Walking: per sheet, the tallest frame at most walkHeight and no frame wider than 88.
    let walkRightSheet = try Sheet(walkRightPath, frames: 6, root: cwd)
    let walkLeftSheet = walkLeftPath == "mirror" ? nil : try Sheet(walkLeftPath, frames: 6, root: cwd)
    let walkRightFactor = walkRightSheet.factor(height: walkHeight)
    let walkLeftFactor = walkLeftSheet?.factor(height: walkHeight) ?? walkRightFactor
    let walkRight = walkRightSheet.frames(factor: walkRightFactor)
    let walkLeft = walkLeftSheet?.frames(factor: walkLeftFactor) ?? walkRight.map(mirrored)

    try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    try save(strip(walkRight), to: folder.appendingPathComponent("walk-right.png"))
    try save(strip(walkLeft), to: folder.appendingPathComponent("walk-left.png"))
    try save(idle, to: folder.appendingPathComponent("idle.png"))
    try save(strip(groom), to: folder.appendingPathComponent("groom.png"))
    try save(icon(from: idle), to: folder.appendingPathComponent("icon.png"))
    try save(icon(from: idle), to: folder.appendingPathComponent("icon-blink.png"))

    func describe(_ name: String, _ frames: [Bitmap], _ factor: Double) {
        let sizes = frames.map(silhouette).map { "\($0.width)×\($0.height)@\($0.minX)" }
        print(String(format: "  %-11@ scale %.4f  ", name, factor) + sizes.joined(separator: " "))
    }
    print("Imported \(coat) → \(folder.path)")
    print("  (width×height@left of each silhouette; bottoms all on y=\(floorY))")
    describe("walk-right", walkRight, walkRightFactor)
    describe("walk-left", walkLeft, walkLeftFactor)
    describe("idle/groom", groom, groomFactor)
    print("Next: swift scripts/make-blink-icons.swift, then swift scripts/build-cat-art.swift --gif-preview, then swift test.")
} catch {
    fputs("import failed: \(error)\n", stderr)
    exit(1)
}

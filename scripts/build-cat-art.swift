#!/usr/bin/env swift
// Builds the cat sprite sheets the app ships from the per-clip strips in art-src/cats/<coat>/.
//
//   swift scripts/build-cat-art.swift [--gif-preview]
//
// Every strip is copied pixel for pixel: no scaling, no overrides. What is in art-src/cats/<coat>/walk-right.png is
// exactly what the cat walks with. A coat is a folder; adding a folder adds a cat. See art-src/README.md.
//
// Output: app/TokenCats/Resources/CatArt/cat-<coat>.png (one 96×96 frame after another, in the order of `clips`;
//         petting reuses two grooming frames, see `petFromGroom`),
//         cat-<coat>-icon.png and cat-<coat>-icon-blink.png (copied), cat-assets.json (which frames each clip uses).
// --gif-preview also writes build/cat-art-preview/<coat>-<clip>.gif for looking at the motion.
import AppKit
import Foundation
import ImageIO
import UniformTypeIdentifiers

private struct Pixel {
    var r: UInt8 = 0
    var g: UInt8 = 0
    var b: UInt8 = 0
    var a: UInt8 = 0
}
private struct Bitmap {
    let width: Int
    let height: Int
    var pixels: [Pixel]
    init(width: Int, height: Int, fill: Pixel = Pixel()) {
        self.width = width
        self.height = height
        pixels = Array(repeating: fill, count: width * height)
    }
    subscript(_ x: Int, _ y: Int) -> Pixel {
        get { pixels[y * width + x] }
        set { pixels[y * width + x] = newValue }
    }
}
private let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
private let sources = root.appendingPathComponent("art-src/cats")
private let output = root.appendingPathComponent("app/TokenCats/Resources/CatArt")
private let frameSize = 96
private let previewBackground = Pixel(r: 218, g: 207, b: 194, a: 255)

/// The sheet's layout: each clip's file, its frame count, and its name in cat-assets.json. Order is sheet order.
private let clips: [(file: String, frames: Int, clip: String)] = [
    ("walk-right.png", 6, "walkRight"),
    ("walk-left.png", 6, "walkLeft"),
    ("idle.png", 1, "idle"),
    ("groom.png", 10, "groom"),
]

/// Petting has no drawing of its own: it shows grooming's 5th and 9th poses (paw up, eyes shut), so a retouched
/// groom.png changes petting too. These are positions in groom.png, counted from 0.
private let petFromGroom = [4, 8]

private struct BuildError: Error, CustomStringConvertible {
    let description: String
}

private func load(_ url: URL) throws -> Bitmap {
    guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
          let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
        throw NSError(domain: "CatArt", code: 1, userInfo: [NSLocalizedDescriptionKey: "Cannot load \(url.path)"])
    }
    var bytes = [UInt8](repeating: 0, count: image.width * image.height * 4)
    bytes.withUnsafeMutableBytes { raw in
        let context = CGContext(data: raw.baseAddress, width: image.width, height: image.height,
                                bitsPerComponent: 8, bytesPerRow: image.width * 4,
                                space: CGColorSpaceCreateDeviceRGB(),
                                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        context.interpolationQuality = .none
        context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
    }
    var bitmap = Bitmap(width: image.width, height: image.height)
    for index in bitmap.pixels.indices {
        let byte = index * 4
        bitmap.pixels[index] = Pixel(r: bytes[byte], g: bytes[byte + 1], b: bytes[byte + 2], a: bytes[byte + 3])
    }
    return bitmap
}

private func cgImage(_ bitmap: Bitmap) -> CGImage {
    var bytes = [UInt8](repeating: 0, count: bitmap.width * bitmap.height * 4)
    for (index, pixel) in bitmap.pixels.enumerated() {
        let byte = index * 4
        bytes[byte] = pixel.r
        bytes[byte + 1] = pixel.g
        bytes[byte + 2] = pixel.b
        bytes[byte + 3] = pixel.a
    }
    let provider = CGDataProvider(data: Data(bytes) as CFData)!
    return CGImage(width: bitmap.width, height: bitmap.height, bitsPerComponent: 8,
                   bitsPerPixel: 32, bytesPerRow: bitmap.width * 4,
                   space: CGColorSpaceCreateDeviceRGB(),
                   bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
                   provider: provider, decode: nil, shouldInterpolate: false, intent: .defaultIntent)!
}
private func save(_ bitmap: Bitmap, to url: URL) throws {
    guard let writer = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil) else {
        throw NSError(domain: "CatArt", code: 2, userInfo: [NSLocalizedDescriptionKey: "Cannot create \(url.path)"])
    }
    CGImageDestinationAddImage(writer, cgImage(bitmap), nil)
    guard CGImageDestinationFinalize(writer) else {
        throw NSError(domain: "CatArt", code: 3, userInfo: [NSLocalizedDescriptionKey: "Cannot save \(url.path)"])
    }
}

private func saveGIF(_ frames: [Bitmap], to url: URL, delay: Double = 0.14) throws {
    guard let writer = CGImageDestinationCreateWithURL(url as CFURL, UTType.gif.identifier as CFString, frames.count, nil) else {
        throw NSError(domain: "CatArt", code: 5, userInfo: [NSLocalizedDescriptionKey: "Cannot create GIF"])
    }
    CGImageDestinationSetProperties(writer, [kCGImagePropertyGIFDictionary: [kCGImagePropertyGIFLoopCount: 0]] as CFDictionary)
    for frame in frames {
        var opaque = Bitmap(width: frame.width, height: frame.height, fill: previewBackground)
        for y in 0..<frame.height {
            for x in 0..<frame.width where frame[x, y].a > 0 { opaque[x, y] = frame[x, y] }
        }
        CGImageDestinationAddImage(writer, cgImage(opaque),
            [kCGImagePropertyGIFDictionary: [kCGImagePropertyGIFDelayTime: delay]] as CFDictionary)
    }
    guard CGImageDestinationFinalize(writer) else {
        throw NSError(domain: "CatArt", code: 6, userInfo: [NSLocalizedDescriptionKey: "Cannot save GIF"])
    }
}

do {
    let coats = try FileManager.default.contentsOfDirectory(atPath: sources.path)
        .filter { name in
            var isFolder: ObjCBool = false
            return FileManager.default.fileExists(atPath: sources.appendingPathComponent(name).path, isDirectory: &isFolder)
                && isFolder.boolValue
        }
        .sorted()
    guard !coats.isEmpty else { throw BuildError(description: "no coat folders in \(sources.path)") }
    var catalog: [String: Any] = [:]
    for coat in coats {
        let folder = sources.appendingPathComponent(coat)
        var frames: [Bitmap] = []
        var clipFrames: [String: [Int]] = [:]
        for clip in clips {
            let strip = try load(folder.appendingPathComponent(clip.file))
            guard strip.height == frameSize, strip.width == frameSize * clip.frames else {
                throw BuildError(description: "\(coat)/\(clip.file) must be \(frameSize * clip.frames)×\(frameSize) "
                                 + "(\(clip.frames) frames of \(frameSize)px), is \(strip.width)×\(strip.height)")
            }
            clipFrames[clip.clip] = Array(frames.count..<(frames.count + clip.frames))
            for index in 0..<clip.frames {
                var frame = Bitmap(width: frameSize, height: frameSize)
                for y in 0..<frameSize { for x in 0..<frameSize { frame[x, y] = strip[index * frameSize + x, y] } }
                frames.append(frame)
            }
            if CommandLine.arguments.contains("--gif-preview"), clip.frames > 1 {
                let previews = root.appendingPathComponent("build/cat-art-preview")
                try FileManager.default.createDirectory(at: previews, withIntermediateDirectories: true)
                try saveGIF(Array(frames.suffix(clip.frames)),
                            to: previews.appendingPathComponent("\(coat)-\(clip.clip).gif"))
            }
        }
        if let groom = clipFrames["groom"] { clipFrames["pet"] = petFromGroom.map { groom[$0] } }
        var sheet = Bitmap(width: frameSize * frames.count, height: frameSize)
        for (index, frame) in frames.enumerated() {
            for y in 0..<frameSize { for x in 0..<frameSize { sheet[index * frameSize + x, y] = frame[x, y] } }
        }
        let sheetName = "cat-\(coat).png", iconName = "cat-\(coat)-icon.png"
        try save(sheet, to: output.appendingPathComponent(sheetName))
        for (source, target) in [("icon.png", iconName), ("icon-blink.png", "cat-\(coat)-icon-blink.png")] {
            let to = output.appendingPathComponent(target)
            try? FileManager.default.removeItem(at: to)
            try FileManager.default.copyItem(at: folder.appendingPathComponent(source), to: to)
        }
        catalog[coat] = ["sheet": sheetName, "icon": iconName, "frameSize": frameSize, "clips": clipFrames]
        print("Built \(coat): \(frames.count) frames at \(frameSize)×\(frameSize)px")
    }
    try JSONSerialization.data(withJSONObject: ["version": 2, "cats": catalog], options: [.prettyPrinted, .sortedKeys])
        .write(to: output.appendingPathComponent("cat-assets.json"), options: .atomic)
} catch {
    fputs("cat art build failed: \(error)\n", stderr)
    exit(1)
}

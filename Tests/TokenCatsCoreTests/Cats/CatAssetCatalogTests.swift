import Foundation
import ImageIO
import Testing
@testable import TokenCatsCore

struct CatAssetCatalogTests {
    @Test func blackCatUsesAPngAtlasAndNamedClips() throws {
                let art = resourcesURL.appendingPathComponent("CatArt")
        let data = try Data(contentsOf: art.appendingPathComponent("cat-assets.json"))
        let catalog = try JSONDecoder().decode(CatAssetCatalog.self, from: data)
        let cat = try #require(catalog.cats["black"])
        #expect(catalog.version == 2)
        #expect(cat.frameSize == 96)
        #expect(cat.clips["idle"] == [12])
        #expect(cat.clips["walkRight"]?.count == 6)
        #expect(cat.clips["walkLeft"]?.count == 6)
        #expect(cat.clips["groom"]?.count == 10)
        #expect(cat.clips["pet"]?.count == 2)
        #expect(cat.assetNames.allSatisfy { $0.hasSuffix(".png") })
        #expect(cat.assetNames.count == 2)
        #expect(cat.assetNames.allSatisfy {
            FileManager.default.fileExists(atPath: art.appendingPathComponent($0).path)
        })
        let atlas = try rgba(art.appendingPathComponent(cat.sheet))
        #expect(atlas.width == 23 * cat.frameSize)
        for index in try #require(cat.clips["pet"]) {
            #expect(rgbaPixel(atlas, x: index * cat.frameSize, y: 0)[3] == 0)
            #expect(rgbaPixel(atlas, x: index * cat.frameSize + 48, y: 48)[3] > 0)
        }
    }

    @Test func cheeseCatHasTheSameRuntimeClips() throws {
                let art = resourcesURL.appendingPathComponent("CatArt")
        let catalog = try JSONDecoder().decode(CatAssetCatalog.self,
                                               from: Data(contentsOf: art.appendingPathComponent("cat-assets.json")))
        let cheese = try #require(catalog.cats["cheese"])
        #expect(cheese.clips["idle"] == [12])
        #expect(cheese.clips["walkRight"]?.count == 6)
        #expect(cheese.clips["walkLeft"]?.count == 6)
        #expect(cheese.clips["groom"]?.count == 10)
        #expect(cheese.clips["pet"]?.count == 2)
    }

    @Test func cheeseWalkFramesFaceTheirTravelDirection() throws {
        let atlas = try rgba(resourcesURL.appendingPathComponent("CatArt/cat-cheese.png"))
        for frame in 0..<12 {
            var noseXs: [Int] = []
            for y in 36..<60 {
                for x in 0..<96 {
                    let pixel = rgbaPixel(atlas, x: frame * 96 + x, y: y)
                    if pixel[0] > 153, (51..<192).contains(Int(pixel[1])),
                       (64..<192).contains(Int(pixel[2])),
                       Double(pixel[0]) > Double(pixel[1]) * 1.35,
                       Double(pixel[2]) > Double(pixel[1]) * 0.8 {
                        noseXs.append(x)
                    }
                }
            }
            let noseX = try #require(noseXs.isEmpty ? nil : noseXs.reduce(0, +) / noseXs.count)
            #expect(frame < 6 ? noseX > 60 : noseX < 36, "frame \(frame) nose at \(noseX)")
        }
    }

    /// Every coat folder in art-src/cats has a complete atlas and valid clips.
    /// art-src/cats/<coat>/ is the only place a cat is drawn. The shipped sheet must be exactly its clip files laid
    /// side by side, and the shipped icons exact copies: editing CatArt by hand, or changing a source without running
    /// scripts/build-cat-art.swift, fails here.
    @Test(arguments: catalogCoats())
    func shippedArtIsExactlyTheSourceFolder(coat: String) throws {
        let art = resourcesURL.appendingPathComponent("CatArt")
        let source = repoRoot.appendingPathComponent("art-src/cats/\(coat)")
        let catalog = try JSONDecoder().decode(CatAssetCatalog.self,
                                               from: Data(contentsOf: art.appendingPathComponent("cat-assets.json")))
        let cat = try #require(catalog.cats[coat])
        let sheet = try rgba(art.appendingPathComponent(cat.sheet))
        let files = ["walkRight": "walk-right", "walkLeft": "walk-left", "idle": "idle", "groom": "groom"]
        #expect(Set(cat.clips.keys) == Set(files.keys).union(["pet"]))
        // Petting has no file of its own: it is grooming's 5th and 9th poses, so retouching groom.png moves it too.
        let groom = try #require(cat.clips["groom"])
        #expect(cat.clips["pet"] == [groom[4], groom[8]])
        #expect(!FileManager.default.fileExists(atPath: source.appendingPathComponent("pet.png").path))
        for (clip, file) in files {
            let strip = try rgba(source.appendingPathComponent("\(file).png"))
            let frames = try #require(cat.clips[clip])
            #expect(strip.width == frames.count * cat.frameSize, "\(coat)/\(file).png")
            for (position, frame) in frames.enumerated() {
                for y in 0..<cat.frameSize {
                    for x in 0..<cat.frameSize where rgbaPixel(strip, x: position * cat.frameSize + x, y: y)
                        != rgbaPixel(sheet, x: frame * cat.frameSize + x, y: y) {
                        Issue.record("\(coat)/\(file).png frame \(position) differs from the shipped sheet at \(x),\(y)")
                        return
                    }
                }
            }
        }
        for (file, shipped) in [("icon.png", cat.icon), ("icon-blink.png", cat.icon.replacingOccurrences(of: ".png", with: "-blink.png"))] {
            #expect(try Data(contentsOf: source.appendingPathComponent(file)) == Data(contentsOf: art.appendingPathComponent(shipped)),
                    "\(coat)/\(file)")
        }
    }

    @Test(arguments: catalogCoats())
    func everyCoatHasACompleteAtlas(coat: String) throws {
                let art = resourcesURL.appendingPathComponent("CatArt")
        let catalog = try JSONDecoder().decode(CatAssetCatalog.self,
                                               from: Data(contentsOf: art.appendingPathComponent("cat-assets.json")))
        let cat = try #require(catalog.cats[coat])
        let atlas = try rgba(art.appendingPathComponent(cat.sheet))
        #expect(cat.assetNames.count == 2)
        let idle = try #require(cat.clips["idle"]?.first)
        #expect(visibleBounds(atlas, frame: idle).height > 40)
        // The sheet holds exactly the frames its clips use: no spare poses, no gaps, nothing past the end.
        let used = Set(cat.clips.values.flatMap { $0 })
        #expect(atlas.width == used.count * cat.frameSize)
        #expect(used == Set(0..<used.count))
    }

    /// Grooming starts from the idle pose and petting keeps the cat seated, so those frames sit on the same
    /// floor at about the same height and cover the idle silhouette. Width is not compared: a raised paw or
    /// tail legitimately widens the outline, and forcing it equal used to squash frames along one axis.
    @Test(arguments: catalogCoats())
    func idleGroomAndPetHaveMatchingSizeAndFloor(coat: String) throws {
                let art = resourcesURL.appendingPathComponent("CatArt")
        let atlas = try rgba(art.appendingPathComponent("cat-\(coat).png"))
        let catalog = try JSONDecoder().decode(CatAssetCatalog.self,
                                               from: Data(contentsOf: art.appendingPathComponent("cat-assets.json")))
        let clips = try #require(catalog.cats[coat]).clips
        let idleFrame = try #require(clips["idle"]?.first)
        let groom = try #require(clips["groom"]), pet = try #require(clips["pet"])
        let idle = visibleBounds(atlas, frame: idleFrame)
        for frame in groom + pet {
            let bounds = visibleBounds(atlas, frame: frame)
            #expect(abs(bounds.height - idle.height) <= 6, "frame \(frame)")
            #expect(bounds.bottom == idle.bottom, "frame \(frame)")
        }
        #expect(silhouetteOverlap(atlas, idleFrame, groom[0]) >= 0.8)
        #expect(silhouetteOverlap(atlas, idleFrame, pet[0]) >= 0.75)
        #expect(silhouetteOverlap(atlas, idleFrame, pet[1]) >= 0.75)
    }

    /// Grooming begins from the very pose the cat rests in, so starting to groom shows no jump; the idle pose and
    /// the grooming poses come from the same drawing.
    @Test(arguments: catalogCoats())
    func groomingStartsFromTheIdlePose(coat: String) throws {
        let art = resourcesURL.appendingPathComponent("CatArt")
        let atlas = try rgba(art.appendingPathComponent("cat-\(coat).png"))
        let catalog = try JSONDecoder().decode(CatAssetCatalog.self,
                                               from: Data(contentsOf: art.appendingPathComponent("cat-assets.json")))
        let clips = try #require(catalog.cats[coat]).clips
        let idle = try #require(clips["idle"]?.first), groomStart = try #require(clips["groom"]?.first)
        var differing = 0
        for y in 0..<96 {
            for x in 0..<96 where rgbaPixel(atlas, x: idle * 96 + x, y: y) != rgbaPixel(atlas, x: groomStart * 96 + x, y: y) {
                differing += 1
            }
        }
        #expect(differing == 0)
    }

    @Test(arguments: catalogCoats())
    func everyCoatFitsTheRoomsCollisionEnvelope(coat: String) throws {
                let art = resourcesURL.appendingPathComponent("CatArt")
        let atlas = try rgba(art.appendingPathComponent("cat-\(coat).png"))
        let widest = (0..<(atlas.width / 96)).map { visibleBounds(atlas, frame: $0).width }.max() ?? 0
        #expect(widest <= 88, "coat \(coat) needs a larger room collision envelope")
    }
}

/// Coat ids in the bundled catalog, so tests cover every cat added later without edits here.
private func catalogCoats() -> [String] {
    let url = resourcesURL.appendingPathComponent("CatArt/cat-assets.json")
    guard let data = try? Data(contentsOf: url),
          let catalog = try? JSONDecoder().decode(CatAssetCatalog.self, from: data) else { return [] }
    return catalog.cats.keys.sorted()
}

/// Best intersection-over-union of two frames' silhouettes, allowing a small horizontal shift.
private func silhouetteOverlap(_ image: (width: Int, bytes: [UInt8]), _ first: Int, _ second: Int) -> Double {
    func opaque(_ frame: Int, _ x: Int, _ y: Int) -> Bool {
        x >= 0 && x < 96 && rgbaPixel(image, x: frame * 96 + x, y: y)[3] > 160
    }
    var best = 0.0
    for shift in -8...8 {
        var both = 0, either = 0
        for y in 0..<96 {
            for x in 0..<96 {
                let a = opaque(first, x, y), b = opaque(second, x - shift, y)
                if a && b { both += 1 }
                if a || b { either += 1 }
            }
        }
        if either > 0 { best = max(best, Double(both) / Double(either)) }
    }
    return best
}

private func visibleBounds(_ image: (width: Int, bytes: [UInt8]), frame: Int)
    -> (width: Int, height: Int, bottom: Int) {
    var minX = 96, minY = 96, maxX = 0, maxY = 0
    for y in 0..<96 {
        for x in 0..<96 where rgbaPixel(image, x: frame * 96 + x, y: y)[3] > 160 {
            minX = min(minX, x)
            minY = min(minY, y)
            maxX = max(maxX, x)
            maxY = max(maxY, y)
        }
    }
    return (maxX - minX + 1, maxY - minY + 1, maxY)
}

private func rgba(_ url: URL) throws -> (width: Int, bytes: [UInt8]) {
    guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
          let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
        throw NSError(domain: "CatAssetCatalogTests", code: 1)
    }
    var bytes = [UInt8](repeating: 0, count: image.width * image.height * 4)
    bytes.withUnsafeMutableBytes { raw in
        let context = CGContext(data: raw.baseAddress, width: image.width, height: image.height,
                                bitsPerComponent: 8, bytesPerRow: image.width * 4,
                                space: CGColorSpaceCreateDeviceRGB(),
                                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
    }
    return (image.width, bytes)
}

private func rgbaPixel(_ image: (width: Int, bytes: [UInt8]), x: Int, y: Int) -> [UInt8] {
    let offset = (y * image.width + x) * 4
    return Array(image.bytes[offset..<(offset + 4)])
}

import AppKit

/// Cat art from `cat-assets.json`, loaded per coat on first use and cached.
/// Every coat shares the same named clips: walkRight, walkLeft, groom, pet, idle.
@MainActor
final class CatSprites {
    static let shared = CatSprites()
    /// Coat used where a single cat stands for the app (closed notch icon).
    static let defaultCoat = "black"

    private struct CoatArt {
        let asset: CatAssetDefinition
        let sheet: CGImage?
        let icon: CGImage?
        /// The icon with its eyes shut (`<icon>-blink.png`, made by scripts/make-blink-icons.swift); nil if absent.
        let blink: CGImage?
    }

    private let catalog: CatAssetCatalog?
    private var coats: [String: CoatArt] = [:]
    private var frames: [String: CGImage] = [:]
    private var portraits: [String: CGImage] = [:]

    /// Hand-dropped overrides: `~/Library/Application Support/TokenCats/art/`.
    static var artDirectory: URL { AppPaths.supportDirectory.appendingPathComponent("art", isDirectory: true) }

    private init() {
        let manifestOverride = Self.artDirectory.appendingPathComponent("cat-assets.json")
        let manifestURL = FileManager.default.fileExists(atPath: manifestOverride.path) ? manifestOverride
            : (Bundle.main.url(forResource: "cat-assets", withExtension: "json", subdirectory: "CatArt")
                ?? Bundle.main.url(forResource: "cat-assets", withExtension: "json"))
        catalog = manifestURL.flatMap { try? Data(contentsOf: $0) }
            .flatMap { try? JSONDecoder().decode(CatAssetCatalog.self, from: $0) }
    }

    var icon: CGImage? { icon(coat: Self.defaultCoat) }

    /// Every coat named in the manifest, with or without art.
    var coatNames: Set<String> { Set(catalog.map { Array($0.cats.keys) } ?? []) }
    func hasArt(coat: String) -> Bool { art(coat) != nil }
    func icon(coat: String) -> CGImage? { art(coat)?.icon }
    /// The icon mid-blink, falling back to the open-eyed icon for coats without a blink frame.
    func blinkIcon(coat: String) -> CGImage? { art(coat).flatMap { $0.blink ?? $0.icon } }

    /// The icon is only 24 px for the closed notch. Larger store and collection faces use the 96 px idle art.
    func portrait(coat: String) -> CGImage? {
        if let cached = portraits[coat] { return cached }
        guard let idle = frame(clip: "idle", index: 0, coat: coat),
              let portrait = idle.cropping(to: CGRect(x: 8, y: 0, width: 80, height: 80)) else { return nil }
        portraits[coat] = portrait
        return portrait
    }

    func frame(_ index: Int, coat: String) -> CGImage? {
        guard let art = art(coat), let sheet = art.sheet, art.asset.frameSize > 0,
              index >= 0, index < sheet.width / art.asset.frameSize else { return nil }
        let key = "\(coat)-\(index)"
        if let cached = frames[key] { return cached }
        let size = art.asset.frameSize
        let frame = sheet.cropping(to: CGRect(x: index * size, y: 0, width: size, height: size))
        if let frame { frames[key] = frame }
        return frame
    }

    func frame(clip: String, index: Int, coat: String) -> CGImage? {
        guard index >= 0, let clipFrames = catalog?.cats[coat]?.clips[clip], !clipFrames.isEmpty else { return nil }
        return frame(clipFrames[index % clipFrames.count], coat: coat)
    }

    /// Frames in a named clip for a coat; 0 when the coat or clip is unknown.
    func clipLength(_ clip: String, coat: String) -> Int {
        catalog?.cats[coat]?.clips[clip]?.count ?? 0
    }

    private func art(_ coat: String) -> CoatArt? {
        if let cached = coats[coat] { return cached }
        guard let asset = catalog?.cats[coat] else { return nil }
        let art = CoatArt(asset: asset, sheet: Self.load(asset.sheet), icon: Self.load(asset.icon),
                          blink: Self.load(asset.icon.replacingOccurrences(of: ".png", with: "-blink.png")))
        coats[coat] = art
        return art
    }

    private static func load(_ name: String) -> CGImage? {
        let override = Self.artDirectory.appendingPathComponent(name)
        let url = FileManager.default.fileExists(atPath: override.path) ? override
            : (Bundle.main.url(forResource: name, withExtension: nil, subdirectory: "CatArt")
                ?? Bundle.main.url(forResource: name, withExtension: nil))
        return url.flatMap { NSImage(contentsOf: $0)?.cgImage(forProposedRect: nil, context: nil, hints: nil) }
    }
}

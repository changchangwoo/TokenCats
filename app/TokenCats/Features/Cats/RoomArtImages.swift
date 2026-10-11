import AppKit

/// Background pictures shipped in the app (`Resources/RoomArt`, 1x and @2x), loaded once per name.
/// Xcode merges each 1x/@2x pair into one multi-resolution TIFF in the bundle, so pictures are read through
/// `Bundle.image(forResource:)` rather than by PNG file name.
@MainActor
enum RoomArtImages {
    private static var images: [String: NSImage] = [:]

    /// The picture sized in points (AppKit picks the @2x pixels on Retina); nil when it is missing.
    static func image(_ name: String) -> NSImage? {
        if let cached = images[name] { return cached }
        guard let image = Bundle.main.image(forResource: name) else { return nil }
        images[name] = image
        return image
    }

    /// The 1x pictures as PNG bytes for the profile SVG, or nil when the theme has none (or a picture is missing).
    static func pngs(for art: RoomArt?) -> RoomArtPNGs? {
        guard let art, let wall = png(art.wall), let floor = png(art.floor) else { return nil }
        return RoomArtPNGs(wall: wall, floor: floor)
    }

    /// The 1x pictures of the props drawn from a picture, by image name, for the profile SVG.
    static func pngs(for props: [RoomProp]) -> [String: Data] {
        var out: [String: Data] = [:]
        for name in props.compactMap(\.art?.image) { out[name] = png(name) }
        return out
    }

    /// The representation whose pixels match the point size (1x), re-encoded as PNG.
    private static func png(_ name: String) -> Data? {
        guard let image = image(name) else { return nil }
        let reps = image.representations.compactMap { $0 as? NSBitmapImageRep }
        let oneX = reps.first { $0.pixelsWide == Int(image.size.width) } ?? reps.min { $0.pixelsWide < $1.pixelsWide }
        return oneX?.representation(using: .png, properties: [:])
    }
}

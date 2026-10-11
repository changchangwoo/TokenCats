import Foundation

/// Runtime art references. Every cat uses the same named clips, while files and frame ranges
/// live in data so new coats can be added without new GIF decoding or view-specific indices.
struct CatAssetCatalog: Codable, Equatable, Sendable {
    let version: Int
    let cats: [String: CatAssetDefinition]
}

struct CatAssetDefinition: Codable, Equatable, Sendable {
    let sheet: String
    let icon: String
    let frameSize: Int
    let clips: [String: [Int]]

    var assetNames: [String] { [sheet, icon] }
}

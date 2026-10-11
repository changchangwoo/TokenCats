// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "TokenCatsCore",
    platforms: [.macOS(.v14)],
    products: [.library(name: "TokenCatsCore", targets: ["TokenCatsCore"])],
    targets: [
        .target(name: "TokenCatsCore", path: "app/TokenCats/Core"),
        .testTarget(
            name: "TokenCatsCoreTests",
            dependencies: ["TokenCatsCore"],
            path: "Tests/TokenCatsCoreTests"
        ),
    ],
    swiftLanguageModes: [.v5]
)

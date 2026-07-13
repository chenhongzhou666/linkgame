// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "LinkGame",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "LinkGame", targets: ["LinkGame"])
    ],
    targets: [
        .executableTarget(
            name: "LinkGame",
            path: "Sources/LinkGame",
            swiftSettings: []
        )
    ]
)

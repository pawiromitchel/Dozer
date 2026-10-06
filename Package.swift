// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Dozer",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "Dozer", targets: ["Dozer"])
    ],
    targets: [
        // Vendored so the app builds without Xcode (see Vendor/KeyboardShortcuts/VENDORED.md).
        .target(
            name: "KeyboardShortcuts",
            path: "Vendor/KeyboardShortcuts",
            exclude: ["LICENSE", "VENDORED.md", "Localization"],
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
        .executableTarget(
            name: "Dozer",
            dependencies: ["KeyboardShortcuts"],
            path: "Sources/Dozer"
        ),
        .testTarget(
            name: "DozerTests",
            dependencies: ["Dozer"],
            path: "Tests/DozerTests"
        )
    ]
)

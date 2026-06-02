// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Hypercode",
    platforms: [
        .macOS(.v13),
    ],
    products: [
        .library(name: "Hypercode", targets: ["Hypercode"]),
        .executable(name: "hypercode", targets: ["HypercodeCLI"]),
    ],
    dependencies: [
        // SpecificationCore — the 0AL Specification-pattern foundation; the
        // Hypercode grammar and cascade rules are expressed as composable specs.
        .package(url: "https://github.com/SoundBlaster/SpecificationCore", from: "1.0.0"),
    ],
    targets: [
        .target(
            name: "Hypercode",
            dependencies: [
                .product(name: "SpecificationCore", package: "SpecificationCore"),
            ]
        ),
        .executableTarget(
            name: "HypercodeCLI",
            dependencies: ["Hypercode"]
        ),
        .testTarget(
            name: "HypercodeTests",
            dependencies: ["Hypercode"]
        ),
    ]
)

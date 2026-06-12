// swift-tools-version: 5.9
import PackageDescription

// Package version: 0.5.0 (echoed by the IR v2 emitter as resolver.version)
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
        // swift-crypto — SHA-256 for IR v2 node hashes; same API as CryptoKit,
        // works on Linux (decision R11 in DOCS/Workplan.md).
        .package(url: "https://github.com/apple/swift-crypto", from: "3.0.0"),
        .package(url: "https://github.com/apple/swift-docc-plugin", from: "1.0.0"),
    ],
    targets: [
        .target(
            name: "Hypercode",
            dependencies: [
                .product(name: "SpecificationCore", package: "SpecificationCore"),
                .product(name: "Crypto", package: "swift-crypto"),
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

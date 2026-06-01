// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Hypercode",
    products: [
        .library(name: "Hypercode", targets: ["Hypercode"]),
        .executable(name: "hypercode", targets: ["HypercodeCLI"]),
    ],
    targets: [
        .target(name: "Hypercode"),
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

// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "RememberThis",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "RememberThis", targets: ["RememberThis"]),
        .executable(name: "RememberThisUnitTests", targets: ["RememberThisUnitTests"])
    ],
    targets: [
        .target(name: "RememberThisCore"),
        .executableTarget(name: "RememberThis", dependencies: ["RememberThisCore"]),
        .executableTarget(
            name: "RememberThisUnitTests",
            dependencies: ["RememberThisCore"],
            path: "Tests/RememberThisTests"
        ),
        .testTarget(name: "RememberThisCoreTests", dependencies: ["RememberThisCore"])
    ]
)

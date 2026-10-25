// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "RidgelineCore",
    platforms: [
        .iOS(.v17),
        .macOS(.v13)
    ],
    products: [
        .library(name: "RidgelineCore", targets: ["RidgelineCore"])
    ],
    targets: [
        .target(
            name: "RidgelineCore",
            resources: [.process("Resources")]
        ),
        .testTarget(
            name: "RidgelineCoreTests",
            dependencies: ["RidgelineCore"]
        )
    ]
)

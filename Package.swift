// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "HVACRestock",
    platforms: [.iOS(.v17)],
    products: [
        .library(name: "HVACRestock", targets: ["HVACRestockApp"])
    ],
    targets: [
        .target(name: "HVACRestockCore"),
        .target(
            name: "HVACRestockApp",
            dependencies: ["HVACRestockCore"],
            resources: [.process("Resources")]
        ),
        .testTarget(
            name: "HVACRestockCoreTests",
            dependencies: ["HVACRestockCore"]
        )
    ]
)

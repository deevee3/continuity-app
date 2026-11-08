// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "OmniFlowMac",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "OmniFlowMac", targets: ["OmniFlowMac"])
    ],
    targets: [
        .executableTarget(
            name: "OmniFlowMac",
            path: "Sources/OmniFlowMac"
        )
    ]
)

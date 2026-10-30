// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "VidCropper",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "VidCropper", targets: ["VidCropper"])
    ],
    targets: [
        .executableTarget(
            name: "VidCropper",
            path: "Sources/VidCropper"
        )
    ],
    swiftLanguageVersions: [.v5]
)

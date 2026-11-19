// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "Pinny",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(name: "Pinny", path: "Sources/Pinny")
    ]
)

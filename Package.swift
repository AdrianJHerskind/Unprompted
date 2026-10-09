// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "Unprompted",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "Unprompted",
            path: "Sources/Unprompted"
        )
    ]
)

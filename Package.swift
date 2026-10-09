// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "DesktopAssistant",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "DesktopAssistant",
            path: "Sources/DesktopAssistant"
        )
    ]
)

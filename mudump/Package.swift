// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "mudump",
    platforms: [.macOS("27.0")],
    targets: [
        .executableTarget(name: "mudump"),
        .executableTarget(name: "mulabel"),
        .executableTarget(name: "mulufs"),
        .executableTarget(name: "mulive"),
        .executableTarget(
            name: "muvis",
            resources: [.process("Shaders.metal")]
        ),
    ]
)

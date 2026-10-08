// swift-tools-version:6.0
// Pins command-line build tools so every machine runs the same version, with no
// Homebrew or admin password needed. `make generate` runs XcodeGen from here.
import PackageDescription

let package = Package(
    name: "BuildTools",
    platforms: [.macOS(.v13)],
    dependencies: [
        .package(url: "https://github.com/yonaskolb/XcodeGen.git", from: "2.42.0"),
    ],
    targets: []
)

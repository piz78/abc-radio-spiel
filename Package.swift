// swift-tools-version:5.9
// Swift-Package nur für die plattformunabhängige Spiellogik (ABCSpiel/Core),
// damit sie mit `swift test` getestet werden kann. Die App selbst: ABCSpiel.xcodeproj öffnen.
import PackageDescription

let package = Package(
    name: "ABCCore",
    platforms: [.macOS(.v14), .iOS(.v17)],
    products: [
        .library(name: "ABCCore", targets: ["ABCCore"]),
        .executable(name: "abc-clips", targets: ["abc-clips"]),
    ],
    targets: [
        .target(name: "ABCCore", path: "ABCSpiel/Core"),
        .executableTarget(name: "abc-clips", dependencies: ["ABCCore"], path: "tools/clip-manifest"),
        .testTarget(name: "ABCCoreTests", dependencies: ["ABCCore"], path: "Tests/ABCCoreTests"),
    ]
)

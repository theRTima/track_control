// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "TrackControl",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "TrackControl", targets: ["TrackControl"]),
        .library(name: "TrackControlCore", targets: ["TrackControlCore"]),
    ],
    targets: [
        .target(
            name: "TrackControlCore",
            linkerSettings: [.linkedFramework("CoreAudio")]
        ),
        .executableTarget(
            name: "TrackControl",
            dependencies: ["TrackControlCore"]
        ),
        // Headless checks for the gesture engine: `swift run TrackControlSelfTest`.
        // (XCTest / swift-testing are not available with Command Line Tools only.)
        .executableTarget(
            name: "TrackControlSelfTest",
            dependencies: ["TrackControlCore"],
            path: "Tests/SelfTest"
        ),
    ]
)

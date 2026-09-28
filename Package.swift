// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "CaseCloser",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "CaseCloser", targets: ["TrackpadSign"])
    ],
    targets: [
        .executableTarget(
            name: "TrackpadSign",
            path: "Sources/TrackpadSign"
        ),
        .testTarget(
            name: "TrackpadSignTests",
            dependencies: ["TrackpadSign"],
            path: "Tests/TrackpadSignTests"
        )
    ]
)

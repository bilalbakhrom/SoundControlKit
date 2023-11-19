// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "SoundControlKit",
    platforms: [.iOS(.v13)],
    products: [
        .library(
            name: "SoundControlKit",
            targets: ["SoundControlKit"]),
    ],
    targets: [
        .target(
            name: "SoundControlKit"),
        .testTarget(
            name: "SoundControlKitTests",
            dependencies: ["SoundControlKit"]),
    ]
)

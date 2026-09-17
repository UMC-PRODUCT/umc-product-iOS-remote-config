// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "RemoteConfigEditor",
    platforms: [.macOS(.v26)],
    targets: [
        .executableTarget(name: "RemoteConfigEditor"),
        .testTarget(
            name: "RemoteConfigEditorTests",
            dependencies: ["RemoteConfigEditor"]
        ),
    ]
)

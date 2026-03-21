// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "SondeApp",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "SondeApp", targets: ["SondeApp"]),
    ],
    targets: [
        .target(
            name: "SondeCore",
            path: "Sources/SondeCore"
        ),
        .executableTarget(
            name: "SondeApp",
            dependencies: ["SondeCore"],
            path: "Sources/SondeApp",
            resources: [
                .copy("Resources")
            ]
        ),
    ]
)

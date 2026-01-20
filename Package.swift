// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "ScreenTimeCapsule",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(
            name: "ScreenTimeCapsule",
            targets: ["ScreenTimeCapsule"]
        )
    ],
    dependencies: [
        .package(url: "https://github.com/stephencelis/SQLite.swift.git", from: "0.15.0")
    ],
    targets: [
        .executableTarget(
            name: "ScreenTimeCapsule",
            dependencies: [
                .product(name: "SQLite", package: "SQLite.swift")
            ],
            path: "Sources"
        ),
        .testTarget(
            name: "ScreenTimeCapsuleTests",
            dependencies: ["ScreenTimeCapsule"],
            path: "Tests"
        )
    ]
)

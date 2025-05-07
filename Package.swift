// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "HR",
    platforms: [.macOS(.v11)],
    products: [
        .executable(name: "HR", targets: ["HR"])
    ],
    targets: [
        .executableTarget(
            name: "HR",
            path: "Sources/HR"
        )
    ]
)

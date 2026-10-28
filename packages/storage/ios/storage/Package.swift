// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "storage",
    platforms: [
        .iOS("15.0")
    ],
    products: [
        .library(name: "storage", targets: ["storage"])
    ],
    dependencies: [
        .package(name: "FlutterFramework", path: "../FlutterFramework")
    ],
    targets: [
        .target(
            name: "storage",
            dependencies: [
                .product(name: "FlutterFramework", package: "FlutterFramework")
            ],
            resources: [
                .process("PrivacyInfo.xcprivacy")
            ]
        )
    ]
)

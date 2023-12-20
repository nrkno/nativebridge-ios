// swift-tools-version: 5.7
import PackageDescription

let package = Package(
    name: "nativebridge-ios",
    products: [
        .library(name: "nativebridge-ios", targets: ["nativebridge-ios"])
    ],dependencies: [],
    targets: [
        .target(name: "nativebridge-ios", dependencies: [])
    ]
)

// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "BrickGame",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "BrickGame", targets: ["BrickGame"]),
        .executable(name: "GameLogicCheck", targets: ["GameLogicCheck"])
    ],
    targets: [
        .target(name: "BrickGame", path: "Brick/Game"),
        .executableTarget(name: "GameLogicCheck", dependencies: ["BrickGame"], path: "LogicVerification")
    ]
)

// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "ContextBasket",
    platforms: [.macOS(.v14)],
    products: [.executable(name: "ContextBasket", targets: ["ContextBasket"])],
    targets: [
        .executableTarget(
            name: "ContextBasket",
            path: "Sources/ContextBasketApp",
            exclude: ["README.md", "Resources"]
        ),
        .testTarget(
            name: "ContextBasketTests",
            dependencies: ["ContextBasket"],
            path: "Tests/ContextBasketAppTests"
        )
    ]
)

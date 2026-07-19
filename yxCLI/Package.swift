// swift-tools-version: 6.1
import PackageDescription

let package = Package(
    name: "yxCLI",
    platforms: [.macOS(.v12)],
    products: [
        .executable(name: "yxCLI", targets: ["yxCLI"])
    ],
    dependencies: [
        .package(path: "../")  // ✅ Correct way to reference sibling package
    ],
    targets: [
        .executableTarget(
            name: "yxCLI",
            dependencies: [
                .product(name: "YX", package: "yx"),
                .product(name: "Primitives", package: "yx"),
                .product(name: "Transport", package: "yx"),
                .product(name: "RPC", package: "yx")
            ]
        )
    ]
)

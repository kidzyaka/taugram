// swift-tools-version:5.5

import PackageDescription

let package = Package(
    name: "TauSettings",
    platforms: [.macOS(.v10_13)],
    products: [
        .library(name: "TauSettings", targets: ["TauSettings"]),
    ],
    dependencies: [
        .package(name: "SSignalKit", path: "../../submodules/telegram-ios/submodules/SSignalKit"),
        .package(name: "TelegramCore", path: "../../submodules/telegram-ios/submodules/TelegramCore"),
        .package(name: "Postbox", path: "../../submodules/telegram-ios/submodules/Postbox"),
    ],
    targets: [
        .target(
            name: "TauSettings",
            dependencies: [
                .product(name: "SwiftSignalKit", package: "SSignalKit", condition: nil),
                .product(name: "TelegramCore", package: "TelegramCore", condition: nil),
                .product(name: "Postbox", package: "Postbox", condition: nil),
            ],
            path: "Sources/TauSettings"),
    ]
)

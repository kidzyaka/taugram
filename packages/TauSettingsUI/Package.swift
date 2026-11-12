// swift-tools-version:5.5

import PackageDescription

let deps: [(String, String)] = [
    ("TGUIKit", "../TGUIKit"),
    ("InputDataUI", "../InputDataUI"),
    ("Localization", "../Localization"),
    ("TelegramContext", "../TelegramContext"),
    ("TelegramTheme", "../TelegramTheme"),
    ("TelegramUtils", "../TelegramUtils"),
    ("TauSettings", "../TauSettings"),
    ("InAppSettings", "../InAppSettings"),
    ("GeneralRows", "../GeneralRows"),
    ("ThemeSettings", "../ThemeSettings"),
    ("ColorPalette", "../ColorPalette"),
]

let package = Package(
    name: "TauSettingsUI",
    platforms: [.macOS(.v10_13)],
    products: [
        .library(name: "TauSettingsUI", targets: ["TauSettingsUI"]),
    ],
    dependencies: [
        .package(name: "SSignalKit", path: "../../submodules/telegram-ios/submodules/SSignalKit"),
        .package(name: "TelegramCore", path: "../../submodules/telegram-ios/submodules/TelegramCore"),
        .package(name: "Postbox", path: "../../submodules/telegram-ios/submodules/Postbox"),
    ] + deps.map { .package(name: $0.0, path: $0.1) },
    targets: [
        .target(
            name: "TauSettingsUI",
            dependencies: [
                .product(name: "SwiftSignalKit", package: "SSignalKit", condition: nil),
                .product(name: "TelegramCore", package: "TelegramCore", condition: nil),
                .product(name: "Postbox", package: "Postbox", condition: nil),
            ] + deps.map { .product(name: $0.0, package: $0.0, condition: nil) },
            path: "Sources/TauSettingsUI"),
    ]
)

// swift-tools-version:5.5

import PackageDescription

let package = Package(
    name: "TauSpeech",
    platforms: [.macOS(.v10_13)],
    products: [
        .library(name: "TauSpeechProtocol", targets: ["TauSpeechProtocol"]),
        .library(name: "TauSpeech", targets: ["TauSpeech"]),
    ],
    dependencies: [
        .package(name: "SSignalKit", path: "../../submodules/telegram-ios/submodules/SSignalKit"),
    ],
    targets: [
        .target(
            name: "TauSpeechProtocol",
            dependencies: [],
            path: "Sources/TauSpeechProtocol"),
        .target(
            name: "TauSpeech",
            dependencies: [
                "TauSpeechProtocol",
                .product(name: "SwiftSignalKit", package: "SSignalKit", condition: nil),
            ],
            path: "Sources/TauSpeech"),
    ]
)

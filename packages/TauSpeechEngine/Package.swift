// swift-tools-version:5.10

import PackageDescription

let package = Package(
    name: "TauSpeechEngine",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "TauSpeechEngine", targets: ["TauSpeechEngine"]),
    ],
    dependencies: [
        .package(name: "TauSpeech", path: "../TauSpeech"),
        .package(url: "https://github.com/FluidInference/FluidAudio.git", exact: "0.18.3"),
        .package(url: "https://github.com/argmaxinc/WhisperKit.git", exact: "1.1.1"),
    ],
    targets: [
        .target(
            name: "TauSpeechEngine",
            dependencies: [
                .product(name: "TauSpeechProtocol", package: "TauSpeech"),
                .product(name: "FluidAudio", package: "FluidAudio"),
                .product(name: "WhisperKit", package: "WhisperKit"),
            ],
            path: "Sources/TauSpeechEngine"),
    ]
)

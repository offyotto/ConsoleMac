// swift-tools-version: 6.1

import PackageDescription

let package = Package(
    name: "ConsoleMac",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "ConsoleMac", targets: ["ConsoleMac"])
    ],
    dependencies: [
        .package(url: "https://github.com/ml-explore/mlx-swift-lm", .upToNextMajor(from: "3.31.3")),
        .package(url: "https://github.com/huggingface/swift-huggingface", from: "0.9.0"),
        .package(url: "https://github.com/huggingface/swift-transformers", from: "1.3.0")
    ],
    targets: [
        .executableTarget(
            name: "ConsoleMac",
            dependencies: [
                .product(name: "MLXLLM", package: "mlx-swift-lm"),
                .product(name: "MLXLMCommon", package: "mlx-swift-lm"),
                .product(name: "MLXHuggingFace", package: "mlx-swift-lm"),
                .product(name: "HuggingFace", package: "swift-huggingface"),
                .product(name: "Tokenizers", package: "swift-transformers")
            ],
            path: "Sources/ConsoleMac",
            resources: [
                .process("Resources/terminal_24dp_1F1F1F_FILL0_wght400_GRAD0_opsz24.svg"),
                .process("Resources/chat_dashed_24dp_E3E3E3_FILL0_wght400_GRAD0_opsz24.svg"),
                .process("Resources/robot_2_24dp_E3E3E3_FILL0_wght400_GRAD0_opsz24.svg"),
                .process("Resources/hourglass_24dp_E3E3E3_FILL0_wght400_GRAD0_opsz24.svg"),
                .process("Resources/ProviderLogos"),
                .copy("Resources/AppIcon.icon"),
                .copy("Resources/AppIcon.icns")
            ]
        )
    ]
)

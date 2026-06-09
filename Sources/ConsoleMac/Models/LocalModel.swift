import Foundation

enum ModelInstallState: String, Codable, Hashable {
    case notInstalled
    case downloading
    case installed

    var title: String {
        switch self {
        case .notInstalled:
            return "Available"
        case .downloading:
            return "Downloading"
        case .installed:
            return "Installed"
        }
    }
}

enum ModelProvider: String, Codable, Hashable {
    case qwen
    case deepSeek
    case meta
    case mistral

    var displayName: String {
        switch self {
        case .qwen:
            return "Qwen"
        case .deepSeek:
            return "DeepSeek"
        case .meta:
            return "Meta"
        case .mistral:
            return "Mistral"
        }
    }

}

struct LocalModel: Identifiable, Hashable, Codable {
    let id: String
    var name: String
    var provider: ModelProvider
    var family: String
    var parameters: String
    var quantization: String
    var diskSize: String
    var summary: String
    var strengths: [String]
    var recommendedMemory: String
    var mlxModelID: String
    var downloadURL: URL
    var localFilename: String
    var status: ModelInstallState
    var downloadProgress: Double
    var downloadError: String?

    var subtitle: String {
        "\(family) · \(parameters) · \(quantization)"
    }

    init(
        id: String,
        name: String,
        provider: ModelProvider,
        family: String,
        parameters: String,
        quantization: String,
        diskSize: String,
        summary: String,
        strengths: [String],
        recommendedMemory: String,
        mlxModelID: String,
        downloadURL: URL,
        localFilename: String,
        status: ModelInstallState,
        downloadProgress: Double,
        downloadError: String? = nil
    ) {
        self.id = id
        self.name = name
        self.provider = provider
        self.family = family
        self.parameters = parameters
        self.quantization = quantization
        self.diskSize = diskSize
        self.summary = summary
        self.strengths = strengths
        self.recommendedMemory = recommendedMemory
        self.mlxModelID = mlxModelID
        self.downloadURL = downloadURL
        self.localFilename = localFilename
        self.status = status
        self.downloadProgress = downloadProgress
        self.downloadError = downloadError
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        provider = try container.decodeIfPresent(ModelProvider.self, forKey: .provider) ?? Self.provider(for: id)
        family = try container.decode(String.self, forKey: .family)
        parameters = try container.decode(String.self, forKey: .parameters)
        quantization = try container.decode(String.self, forKey: .quantization)
        diskSize = try container.decode(String.self, forKey: .diskSize)
        summary = try container.decode(String.self, forKey: .summary)
        strengths = try container.decode([String].self, forKey: .strengths)
        recommendedMemory = try container.decode(String.self, forKey: .recommendedMemory)
        mlxModelID = try container.decodeIfPresent(String.self, forKey: .mlxModelID) ?? Self.mlxModelID(for: id)
        downloadURL = try container.decode(URL.self, forKey: .downloadURL)
        localFilename = try container.decode(String.self, forKey: .localFilename)
        status = try container.decode(ModelInstallState.self, forKey: .status)
        downloadProgress = try container.decode(Double.self, forKey: .downloadProgress)
        downloadError = try container.decodeIfPresent(String.self, forKey: .downloadError)
    }

    static let catalog: [LocalModel] = [
        LocalModel(
            id: "qwen2.5-coder-7b-instruct-q4",
            name: "Qwen Coder 7B",
            provider: .qwen,
            family: "Qwen2.5 Coder",
            parameters: "7B",
            quantization: "MLX 4-bit",
            diskSize: "4.3 GB",
            summary: "MLX-native coding model accelerated on Apple Silicon for Swift, Python, TypeScript, shell work, and repo edits.",
            strengths: ["Coding", "Refactors", "Terminal help"],
            recommendedMemory: "8 GB unified memory",
            mlxModelID: "mlx-community/Qwen2.5-Coder-7B-Instruct-4bit",
            downloadURL: huggingFaceModelURL("mlx-community/Qwen2.5-Coder-7B-Instruct-4bit"),
            localFilename: "mlx-community--Qwen2.5-Coder-7B-Instruct-4bit.ready",
            status: .notInstalled,
            downloadProgress: 0
        ),
        LocalModel(
            id: "deepseek-coder-6.7b-instruct-q4",
            name: "DeepSeek Coder 6.7B",
            provider: .deepSeek,
            family: "DeepSeek Coder",
            parameters: "6.7B",
            quantization: "MLX 4-bit",
            diskSize: "4.0 GB",
            summary: "MLX-native code model for completion and debugging behavior in local development loops.",
            strengths: ["Debugging", "Completion", "Code search"],
            recommendedMemory: "8 GB unified memory",
            mlxModelID: "mlx-community/deepseek-coder-6.7b-instruct-hf-4bit-mlx",
            downloadURL: huggingFaceModelURL("mlx-community/deepseek-coder-6.7b-instruct-hf-4bit-mlx"),
            localFilename: "mlx-community--deepseek-coder-6.7b-instruct-hf-4bit-mlx.ready",
            status: .notInstalled,
            downloadProgress: 0
        ),
        LocalModel(
            id: "codellama-13b-instruct-q4",
            name: "Code Llama 13B",
            provider: .meta,
            family: "Code Llama",
            parameters: "13B",
            quantization: "MLX 4-bit",
            diskSize: "7.8 GB",
            summary: "Larger MLX-native local model for deeper explanations, longer coding tasks, and multi-file reasoning.",
            strengths: ["Large edits", "Explanations", "Planning"],
            recommendedMemory: "16 GB unified memory",
            mlxModelID: "mlx-community/CodeLlama-13b-Instruct-hf-4bit-MLX",
            downloadURL: huggingFaceModelURL("mlx-community/CodeLlama-13b-Instruct-hf-4bit-MLX"),
            localFilename: "mlx-community--CodeLlama-13b-Instruct-hf-4bit-MLX.ready",
            status: .notInstalled,
            downloadProgress: 0
        ),
        LocalModel(
            id: "mistral-7b-instruct-q4",
            name: "Mistral 7B Instruct",
            provider: .mistral,
            family: "Mistral",
            parameters: "7B",
            quantization: "MLX 4-bit",
            diskSize: "4.1 GB",
            summary: "General-purpose MLX-native local assistant for quick answers, command help, and lighter code tasks.",
            strengths: ["General chat", "Shell", "Low latency"],
            recommendedMemory: "8 GB unified memory",
            mlxModelID: "mlx-community/Mistral-7B-Instruct-v0.3-4bit",
            downloadURL: huggingFaceModelURL("mlx-community/Mistral-7B-Instruct-v0.3-4bit"),
            localFilename: "mlx-community--Mistral-7B-Instruct-v0.3-4bit.ready",
            status: .notInstalled,
            downloadProgress: 0
        ),
        LocalModel(
            id: "llama-3.2-3b-instruct-q4",
            name: "Llama 3.2 3B",
            provider: .meta,
            family: "Llama",
            parameters: "3B",
            quantization: "MLX 4-bit",
            diskSize: "2.0 GB",
            summary: "Small MLX-native local model for quick drafts and compact laptops where speed matters most.",
            strengths: ["Speed", "Low memory", "Drafting"],
            recommendedMemory: "4 GB unified memory",
            mlxModelID: "mlx-community/Llama-3.2-3B-Instruct-4bit",
            downloadURL: huggingFaceModelURL("mlx-community/Llama-3.2-3B-Instruct-4bit"),
            localFilename: "mlx-community--Llama-3.2-3B-Instruct-4bit.ready",
            status: .notInstalled,
            downloadProgress: 0
        )
    ]

    private static func huggingFaceModelURL(_ modelID: String) -> URL {
        URL(string: "https://huggingface.co/\(modelID)")!
    }

    private static func mlxModelID(for id: String) -> String {
        switch id {
        case "deepseek-coder-6.7b-instruct-q4":
            return "mlx-community/deepseek-coder-6.7b-instruct-hf-4bit-mlx"
        case "codellama-13b-instruct-q4":
            return "mlx-community/CodeLlama-13b-Instruct-hf-4bit-MLX"
        case "mistral-7b-instruct-q4":
            return "mlx-community/Mistral-7B-Instruct-v0.3-4bit"
        case "llama-3.2-3b-instruct-q4":
            return "mlx-community/Llama-3.2-3B-Instruct-4bit"
        default:
            return "mlx-community/Qwen2.5-Coder-7B-Instruct-4bit"
        }
    }

    private static func provider(for id: String) -> ModelProvider {
        if id.contains("deepseek") {
            return .deepSeek
        }
        if id.contains("codellama") || id.contains("llama") {
            return .meta
        }
        if id.contains("mistral") {
            return .mistral
        }
        return .qwen
    }
}

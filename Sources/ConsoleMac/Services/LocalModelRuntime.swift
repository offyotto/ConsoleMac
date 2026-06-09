import Foundation
import HuggingFace
import MLXHuggingFace
import MLXLLM
import MLXLMCommon
import Tokenizers

enum LocalModelRuntimeError: LocalizedError {
    case unsupportedArchitecture
    case noModelSelected
    case emptyResponse

    var errorDescription: String? {
        switch self {
        case .unsupportedArchitecture:
            return "MLX requires Apple Silicon. Console's local runtime is MLX-native and does not use a CPU llama.cpp fallback."
        case .noModelSelected:
            return "Choose or download a local model before using local mode."
        case .emptyResponse:
            return "The MLX model ran but did not return any text."
        }
    }
}

struct LocalModelRuntime {
    private static let modelDownloadPatterns = ["*.safetensors", "*.json", "*.jinja"]

    static func download(
        model: LocalModel,
        progressHandler: @Sendable @escaping (Progress) -> Void = { _ in }
    ) async throws {
        #if arch(arm64)
        _ = try await #hubDownloader().download(
            id: model.mlxModelID,
            revision: "main",
            matching: modelDownloadPatterns,
            useLatest: false,
            progressHandler: progressHandler
        )
        #else
        throw LocalModelRuntimeError.unsupportedArchitecture
        #endif
    }

    static func prepare(
        model: LocalModel,
        progressHandler: @Sendable @escaping (Progress) -> Void = { _ in }
    ) async throws {
        _ = try await MLXRuntimeCache.shared.container(
            for: model,
            progressHandler: progressHandler
        )
    }

    static func generateResponse(
        model: LocalModel,
        conversation: Conversation,
        preferences: AppPreferences
    ) async throws -> String {
        #if arch(arm64)
        let container = try await MLXRuntimeCache.shared.container(for: model)
        let searchContext = FileSearchService.context(
            for: conversation,
            preferences: preferences
        )
        let input = UserInput(
            chat: chatMessages(
                for: conversation,
                preferences: preferences,
                searchContext: searchContext
            )
        )
        let preparedInput = try await container.prepare(input: input)
        let stream = try await container.generate(
            input: preparedInput,
            parameters: GenerateParameters(
                maxTokens: 512,
                temperature: 0.4,
                topP: 0.9,
                repetitionPenalty: 1.05
            )
        )

        var response = ""
        for await generation in stream {
            if let chunk = generation.chunk {
                response += chunk
            }
        }

        let cleaned = response.trimmingCharacters(in: .whitespacesAndNewlines)
        guard cleaned.isEmpty == false else {
            throw LocalModelRuntimeError.emptyResponse
        }

        return cleaned
        #else
        throw LocalModelRuntimeError.unsupportedArchitecture
        #endif
    }

    private static func chatMessages(
        for conversation: Conversation,
        preferences: AppPreferences,
        searchContext: String
    ) -> [Chat.Message] {
        var messages: [Chat.Message] = [
            .system(AgentPromptBuilder.systemPromptText(preferences: preferences, searchContext: searchContext))
        ]

        for message in conversation.messages.suffix(12) {
            switch message.role {
            case .user:
                messages.append(.user(message.plainText))
            case .assistant:
                messages.append(.assistant(message.plainText))
            }
        }

        return messages
    }
}

private actor MLXRuntimeCache {
    static let shared = MLXRuntimeCache()

    private var containers: [String: ModelContainer] = [:]

    func container(
        for model: LocalModel,
        progressHandler: @Sendable @escaping (Progress) -> Void = { _ in }
    ) async throws -> ModelContainer {
        #if arch(arm64)
        if let cached = containers[model.id] {
            return cached
        }

        let configuration = LLMModelFactory.shared.configuration(id: model.mlxModelID)
        let container = try await LLMModelFactory.shared.loadContainer(
            from: #hubDownloader(),
            using: #huggingFaceTokenizerLoader(),
            configuration: configuration,
            progressHandler: progressHandler
        )
        containers[model.id] = container
        return container
        #else
        throw LocalModelRuntimeError.unsupportedArchitecture
        #endif
    }
}

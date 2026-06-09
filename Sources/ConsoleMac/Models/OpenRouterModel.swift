import Foundation

struct OpenRouterModel: Identifiable, Hashable, Codable {
    var id: String
    var name: String
    var contextLength: Int?
    var promptPrice: String?
    var completionPrice: String?

    var menuTitle: String {
        if isFree {
            return "\(name) · Free"
        }

        return name
    }

    var detailText: String {
        var parts = [id]

        if let contextLength {
            parts.append("\(Self.compactNumber(contextLength)) ctx")
        }

        if isFree {
            parts.append("free")
        }

        return parts.joined(separator: " · ")
    }

    var isFree: Bool {
        id.hasSuffix(":free") ||
        promptPrice == "0" && completionPrice == "0"
    }

    static let fallbackModels: [OpenRouterModel] = [
        OpenRouterModel(
            id: APIProvider.openRouter.defaultModel,
            name: "Claude Sonnet 4.5",
            contextLength: 1_000_000,
            promptPrice: nil,
            completionPrice: nil
        ),
        OpenRouterModel(
            id: "nex-agi/nex-n2-pro:free",
            name: "Nex N2 Pro",
            contextLength: nil,
            promptPrice: "0",
            completionPrice: "0"
        ),
        OpenRouterModel(
            id: "openrouter/auto",
            name: "OpenRouter Auto",
            contextLength: nil,
            promptPrice: nil,
            completionPrice: nil
        ),
        OpenRouterModel(
            id: "deepseek/deepseek-r1:free",
            name: "DeepSeek R1",
            contextLength: nil,
            promptPrice: "0",
            completionPrice: "0"
        ),
        OpenRouterModel(
            id: "google/gemini-2.5-pro",
            name: "Gemini 2.5 Pro",
            contextLength: nil,
            promptPrice: nil,
            completionPrice: nil
        ),
        OpenRouterModel(
            id: "openai/gpt-5",
            name: "GPT-5",
            contextLength: nil,
            promptPrice: nil,
            completionPrice: nil
        )
    ]

    private static func compactNumber(_ value: Int) -> String {
        if value >= 1_000_000 {
            return "\(value / 1_000_000)M"
        }

        if value >= 1_000 {
            return "\(value / 1_000)K"
        }

        return "\(value)"
    }
}

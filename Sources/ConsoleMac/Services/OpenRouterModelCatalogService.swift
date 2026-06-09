import Foundation

enum OpenRouterModelCatalogError: LocalizedError {
    case invalidResponse
    case apiError(statusCode: Int, body: String)

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "OpenRouter returned a model list Console could not parse."
        case .apiError(let statusCode, let body):
            return "OpenRouter models API error \(statusCode): \(body)"
        }
    }
}

enum OpenRouterModelCatalogService {
    private static let endpoint = "https://openrouter.ai/api/v1/models"

    static func fetchModels() async throws -> [OpenRouterModel] {
        guard let url = URL(string: endpoint) else {
            throw OpenRouterModelCatalogError.invalidResponse
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"

        let apiKey = (try? APIKeyStore.loadAPIKey(for: .openRouter)) ?? nil
        if let apiKey,
           apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false {
            request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        }

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw OpenRouterModelCatalogError.invalidResponse
        }

        guard (200..<300).contains(httpResponse.statusCode) else {
            let body = String(data: data, encoding: .utf8) ?? "No response body"
            throw OpenRouterModelCatalogError.apiError(statusCode: httpResponse.statusCode, body: body)
        }

        let catalog = try JSONDecoder().decode(OpenRouterModelsResponse.self, from: data)
        return mergedModels(catalog.data.map(\.openRouterModel))
    }

    static func normalizedModelID(from value: String) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = URL(string: trimmed),
              url.host?.localizedCaseInsensitiveContains("openrouter.ai") == true else {
            return trimmed
        }

        let components = url.path
            .split(separator: "/")
            .map(String.init)

        guard components.count >= 2 else {
            return trimmed
        }

        return components.suffix(2).joined(separator: "/")
    }

    static func mergedModels(_ fetchedModels: [OpenRouterModel]) -> [OpenRouterModel] {
        var modelsByID: [String: OpenRouterModel] = [:]

        for model in OpenRouterModel.fallbackModels {
            modelsByID[model.id] = model
        }

        for model in fetchedModels {
            modelsByID[model.id] = model
        }

        return modelsByID.values.sorted { lhs, rhs in
            if lhs.isFree != rhs.isFree {
                return lhs.isFree && !rhs.isFree
            }

            return lhs.menuTitle.localizedStandardCompare(rhs.menuTitle) == .orderedAscending
        }
    }
}

private struct OpenRouterModelsResponse: Decodable {
    var data: [OpenRouterModelPayload]
}

private struct OpenRouterModelPayload: Decodable {
    var id: String
    var name: String
    var contextLength: Int?
    var pricing: Pricing?

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case contextLength = "context_length"
        case pricing
    }

    var openRouterModel: OpenRouterModel {
        OpenRouterModel(
            id: id,
            name: name,
            contextLength: contextLength,
            promptPrice: pricing?.prompt,
            completionPrice: pricing?.completion
        )
    }
}

private struct Pricing: Decodable {
    var prompt: String?
    var completion: String?
}

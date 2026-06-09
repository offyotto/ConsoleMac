import Foundation

enum OpenAIResponsesServiceError: LocalizedError {
    case missingAPIKey
    case invalidURL
    case invalidResponse
    case apiError(statusCode: Int, body: String)
    case emptyResponse
    case tokenBudgetExceeded(estimatedTokens: Int)

    var errorDescription: String? {
        switch self {
        case .missingAPIKey:
            return "Add an OpenAI API key in Settings before using API agent mode."
        case .invalidURL:
            return "Console could not build the OpenAI API URL."
        case .invalidResponse:
            return "OpenAI returned a response Console could not parse."
        case .apiError(let statusCode, let body):
            return "OpenAI API error \(statusCode): \(body)"
        case .emptyResponse:
            return "The API model ran but did not return any text."
        case .tokenBudgetExceeded(let estimatedTokens):
            return "Console stopped before sending another OpenAI request because this turn was estimated at \(estimatedTokens) input tokens. Narrow the request, switch off extra tools, or ask it to continue with a smaller scope."
        }
    }
}

enum OpenAIResponsesService {
    private static let endpoint = "https://api.openai.com/v1/responses"

    static func generateResponse(
        conversation: Conversation,
        preferences: AppPreferences
    ) async throws -> String {
        guard let apiKey = try APIKeyStore.loadAPIKey(for: .openAI),
              apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false else {
            throw OpenAIResponsesServiceError.missingAPIKey
        }

        var inputItems = inputItems(for: conversation)
        let searchContext = FileSearchService.context(
            for: conversation,
            preferences: preferences
        )
        let instructions = AgentPromptBuilder.systemPromptText(
            preferences: preferences,
            searchContext: searchContext
        )
        let tools = tools(for: preferences)

        while true {
            let estimatedTokens = AgentBudget.estimatedOpenAIInputTokens(
                instructions: instructions,
                inputItems: inputItems,
                tools: tools
            )
            guard estimatedTokens <= AgentBudget.maximumEstimatedInputTokens else {
                throw OpenAIResponsesServiceError.tokenBudgetExceeded(estimatedTokens: estimatedTokens)
            }

            let response = try await createResponse(
                apiKey: apiKey,
                model: resolvedModelName(preferences.apiModel),
                instructions: instructions,
                inputItems: inputItems,
                tools: tools,
                includeWebSources: preferences.apiWebSearchEnabled
            )

            let toolCalls = toolCalls(from: response)
            if toolCalls.isEmpty {
                let text = outputText(from: response).trimmingCharacters(in: .whitespacesAndNewlines)
                guard text.isEmpty == false else {
                    throw OpenAIResponsesServiceError.emptyResponse
                }
                return text
            }

            guard let outputItems = response["output"] as? [Any] else {
                throw OpenAIResponsesServiceError.invalidResponse
            }

            inputItems.append(contentsOf: outputItems)
            for toolCall in toolCalls {
                let output = AgentToolService.execute(
                    name: toolCall.name,
                    argumentsJSON: toolCall.argumentsJSON,
                    preferences: preferences
                )
                inputItems.append([
                    "type": "function_call_output",
                    "call_id": toolCall.callID,
                    "output": AgentBudget.truncated(output, limit: AgentBudget.maximumMCPResultCharacters)
                ])
            }
        }
    }

    private static func createResponse(
        apiKey: String,
        model: String,
        instructions: String,
        inputItems: [Any],
        tools: [[String: Any]],
        includeWebSources: Bool
    ) async throws -> [String: Any] {
        guard let url = URL(string: endpoint) else {
            throw OpenAIResponsesServiceError.invalidURL
        }

        var payload: [String: Any] = [
            "model": model,
            "instructions": instructions,
            "input": inputItems,
            "tool_choice": "auto",
            "parallel_tool_calls": false
        ]

        if tools.isEmpty == false {
            payload["tools"] = tools
        }

        if includeWebSources {
            payload["include"] = ["web_search_call.action.sources"]
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw OpenAIResponsesServiceError.invalidResponse
        }

        guard (200..<300).contains(httpResponse.statusCode) else {
            let body = String(data: data, encoding: .utf8) ?? "No response body"
            throw OpenAIResponsesServiceError.apiError(statusCode: httpResponse.statusCode, body: body)
        }

        guard let object = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw OpenAIResponsesServiceError.invalidResponse
        }

        return object
    }

    private static func inputItems(for conversation: Conversation) -> [Any] {
        conversation.messages.suffix(16).map { message in
            [
                "role": message.role == .assistant ? "assistant" : "user",
                "content": message.plainText
            ]
        }
    }

    private static func tools(for preferences: AppPreferences) -> [[String: Any]] {
        var tools: [[String: Any]] = []

        if preferences.apiWebSearchEnabled {
            tools.append([
                "type": "web_search",
                "external_web_access": preferences.apiLiveWebSearchEnabled
            ])
        }

        tools.append(contentsOf: AgentToolService.toolDefinitions(preferences: preferences))
        return tools
    }

    private static func toolCalls(from response: [String: Any]) -> [OpenAIToolCall] {
        guard let output = response["output"] as? [[String: Any]] else { return [] }

        return output.compactMap { item in
            guard item["type"] as? String == "function_call",
                  let callID = item["call_id"] as? String,
                  let name = item["name"] as? String else {
                return nil
            }

            let argumentsJSON = item["arguments"] as? String ?? "{}"
            return OpenAIToolCall(callID: callID, name: name, argumentsJSON: argumentsJSON)
        }
    }

    private static func outputText(from response: [String: Any]) -> String {
        if let outputText = response["output_text"] as? String {
            return outputText
        }

        guard let output = response["output"] as? [[String: Any]] else { return "" }

        var pieces: [String] = []
        for item in output where item["type"] as? String == "message" {
            guard let contentItems = item["content"] as? [[String: Any]] else { continue }
            for content in contentItems {
                if let text = content["text"] as? String {
                    pieces.append(text)
                }
            }
        }

        return pieces.joined(separator: "\n")
    }

    private static func resolvedModelName(_ modelName: String) -> String {
        let trimmedModelName = modelName.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmedModelName.isEmpty ? "gpt-5" : trimmedModelName
    }
}

private struct OpenAIToolCall {
    var callID: String
    var name: String
    var argumentsJSON: String
}

import Foundation

enum OpenRouterChatServiceError: LocalizedError {
    case missingAPIKey
    case invalidURL
    case invalidResponse
    case apiError(statusCode: Int, body: String, summary: String, isRetryableProviderFailure: Bool)
    case emptyResponse
    case tokenBudgetExceeded(estimatedTokens: Int)

    var errorDescription: String? {
        switch self {
        case .missingAPIKey:
            return "Add an OpenRouter API key in Settings before using OpenRouter agent mode."
        case .invalidURL:
            return "Console could not build the OpenRouter API URL."
        case .invalidResponse:
            return "OpenRouter returned a response Console could not parse."
        case .apiError(let statusCode, _, let summary, _):
            return "OpenRouter API error \(statusCode): \(summary)"
        case .emptyResponse:
            return "The OpenRouter model ran but did not return any text."
        case .tokenBudgetExceeded(let estimatedTokens):
            return "Console stopped before sending another OpenRouter request because this turn was estimated at \(estimatedTokens) input tokens. Narrow the request, switch off extra tools, or ask it to continue with a smaller scope."
        }
    }

    var isRetryableProviderFailure: Bool {
        if case .apiError(_, _, _, let isRetryableProviderFailure) = self {
            return isRetryableProviderFailure
        }

        return false
    }
}

enum OpenRouterChatService {
    private static let endpoint = "https://openrouter.ai/api/v1/chat/completions"

    static func generateResponse(
        conversation: Conversation,
        preferences: AppPreferences
    ) async throws -> String {
        guard let apiKey = try APIKeyStore.loadAPIKey(for: .openRouter),
              apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false else {
            throw OpenRouterChatServiceError.missingAPIKey
        }

        let latestUserText = AgentBudget.latestUserText(in: conversation)
        let shouldExposeMCPTools = AgentBudget.shouldExposeMCPTools(for: latestUserText)
        let mcpContext = shouldExposeMCPTools
            ? MCPClientService.discoverTools(from: preferences.mcpServers)
            : MCPToolContext()
        defer { mcpContext.close() }

        let searchContext = FileSearchService.context(
            for: conversation,
            preferences: preferences
        )
        var systemPrompt = AgentPromptBuilder.systemPromptText(
            preferences: preferences,
            searchContext: searchContext
        )

        if shouldExposeMCPTools, mcpContext.hasTools {
            systemPrompt += "\nMCP tools are available in this turn. Use them when they help with GitHub or connected external systems."
        }

        if shouldExposeMCPTools, mcpContext.discoveryErrors.isEmpty == false {
            systemPrompt += "\nMCP discovery warnings:\n" + mcpContext.discoveryErrors.map { "- \($0)" }.joined(separator: "\n")
        }

        var messages = chatMessages(for: conversation, systemPrompt: systemPrompt)
        let tools = chatTools(
            preferences: preferences,
            mcpContext: mcpContext,
            query: latestUserText,
            includeMCPTools: shouldExposeMCPTools
        )
        let modelCandidates = modelCandidates(for: preferences.apiModel)
        var currentModelIndex = 0
        var fallbackNotice: String?

        while true {
            let model = modelCandidates[currentModelIndex]
            let response: [String: Any]
            let estimatedTokens = AgentBudget.estimatedOpenRouterInputTokens(messages: messages, tools: tools)
            guard estimatedTokens <= AgentBudget.maximumEstimatedInputTokens else {
                throw OpenRouterChatServiceError.tokenBudgetExceeded(estimatedTokens: estimatedTokens)
            }

            do {
                response = try await createChatCompletion(
                    apiKey: apiKey,
                    model: model,
                    messages: messages,
                    tools: tools,
                    webSearchEnabled: preferences.apiWebSearchEnabled
                )
            } catch let error as OpenRouterChatServiceError {
                guard error.isRetryableProviderFailure,
                      currentModelIndex + 1 < modelCandidates.count else {
                    throw error
                }

                let fallbackModel = modelCandidates[currentModelIndex + 1]
                currentModelIndex += 1
                fallbackNotice = "Retried with \(fallbackModel) because \(model) was unavailable through OpenRouter."
                continue
            }

            guard let choice = firstChoice(from: response),
                  let message = choice["message"] as? [String: Any] else {
                throw OpenRouterChatServiceError.invalidResponse
            }

            let toolCalls = toolCalls(from: message)
            if toolCalls.isEmpty {
                let text = outputText(from: message).trimmingCharacters(in: .whitespacesAndNewlines)
                guard text.isEmpty == false else {
                    throw OpenRouterChatServiceError.emptyResponse
                }
                if let fallbackNotice {
                    return "\(fallbackNotice)\n\n\(text)"
                }
                return text
            }

            messages.append(assistantMessageForHistory(message))

            for toolCall in toolCalls {
                let output: String
                if mcpContext.containsTool(named: toolCall.name) {
                    output = mcpContext.call(
                        exposedName: toolCall.name,
                        argumentsJSON: toolCall.argumentsJSON
                    )
                } else {
                    output = AgentToolService.execute(
                        name: toolCall.name,
                        argumentsJSON: toolCall.argumentsJSON,
                        preferences: preferences
                    )
                }

                messages.append([
                    "role": "tool",
                    "tool_call_id": toolCall.id,
                    "name": toolCall.name,
                    "content": AgentBudget.truncated(output, limit: AgentBudget.maximumMCPResultCharacters)
                ])
            }
        }
    }

    private static func createChatCompletion(
        apiKey: String,
        model: String,
        messages: [[String: Any]],
        tools: [[String: Any]],
        webSearchEnabled: Bool
    ) async throws -> [String: Any] {
        guard let url = URL(string: endpoint) else {
            throw OpenRouterChatServiceError.invalidURL
        }

        var payload: [String: Any] = [
            "model": model,
            "messages": messages,
            "temperature": 0.5,
            "max_tokens": 1800,
            "parallel_tool_calls": false
        ]

        if tools.isEmpty == false {
            payload["tools"] = tools
            payload["tool_choice"] = "auto"
        }

        if webSearchEnabled {
            payload["plugins"] = [
                [
                    "id": "web",
                    "max_results": 5
                ]
            ]
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Console", forHTTPHeaderField: "X-Title")
        request.setValue("https://console.local", forHTTPHeaderField: "HTTP-Referer")
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw OpenRouterChatServiceError.invalidResponse
        }

        guard (200..<300).contains(httpResponse.statusCode) else {
            let body = String(data: data, encoding: .utf8) ?? "No response body"
            throw openRouterAPIError(statusCode: httpResponse.statusCode, body: body)
        }

        guard let object = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw OpenRouterChatServiceError.invalidResponse
        }

        return object
    }

    private static func chatMessages(for conversation: Conversation, systemPrompt: String) -> [[String: Any]] {
        var messages: [[String: Any]] = [
            [
                "role": "system",
                "content": systemPrompt
            ]
        ]

        for message in conversation.messages.suffix(16) {
            messages.append([
                "role": message.role == .assistant ? "assistant" : "user",
                "content": message.plainText
            ])
        }

        return messages
    }

    private static func chatTools(
        preferences: AppPreferences,
        mcpContext: MCPToolContext,
        query: String,
        includeMCPTools: Bool
    ) -> [[String: Any]] {
        let localTools = AgentToolService.toolDefinitions(preferences: preferences).compactMap(chatTool(from:))
        guard includeMCPTools else { return localTools }
        return localTools + mcpContext.chatToolDefinitions(matching: query)
    }

    private static func chatTool(from responseTool: [String: Any]) -> [String: Any]? {
        guard responseTool["type"] as? String == "function",
              let name = responseTool["name"] as? String,
              let description = responseTool["description"] as? String,
              let parameters = responseTool["parameters"] as? [String: Any] else {
            return nil
        }

        return [
            "type": "function",
            "function": [
                "name": name,
                "description": description,
                "parameters": parameters
            ]
        ]
    }

    private static func firstChoice(from response: [String: Any]) -> [String: Any]? {
        guard let choices = response["choices"] as? [[String: Any]] else { return nil }
        return choices.first
    }

    private static func toolCalls(from message: [String: Any]) -> [OpenRouterToolCall] {
        guard let toolCalls = message["tool_calls"] as? [[String: Any]] else { return [] }

        return toolCalls.compactMap { toolCall in
            guard let id = toolCall["id"] as? String,
                  let function = toolCall["function"] as? [String: Any],
                  let name = function["name"] as? String else {
                return nil
            }

            return OpenRouterToolCall(
                id: id,
                name: name,
                argumentsJSON: function["arguments"] as? String ?? "{}"
            )
        }
    }

    private static func assistantMessageForHistory(_ message: [String: Any]) -> [String: Any] {
        var historyMessage: [String: Any] = [
            "role": "assistant"
        ]

        if let content = message["content"] as? String, content.isEmpty == false {
            historyMessage["content"] = content
        } else {
            historyMessage["content"] = NSNull()
        }

        if let toolCalls = message["tool_calls"] {
            historyMessage["tool_calls"] = toolCalls
        }

        return historyMessage
    }

    private static func outputText(from message: [String: Any]) -> String {
        if let content = message["content"] as? String {
            return content
        }

        if let contentItems = message["content"] as? [[String: Any]] {
            return contentItems.compactMap { item in
                item["text"] as? String
            }
            .joined(separator: "\n")
        }

        return ""
    }

    private static func resolvedModelName(_ modelName: String) -> String {
        let trimmedModelName = modelName.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmedModelName.isEmpty ? APIProvider.openRouter.defaultModel : trimmedModelName
    }

    private static func modelCandidates(for modelName: String) -> [String] {
        let selectedModel = resolvedModelName(modelName)
        var candidates = [selectedModel]

        if selectedModel.hasSuffix(":free") {
            candidates.append("openrouter/auto")
        }

        if selectedModel != APIProvider.openRouter.defaultModel {
            candidates.append(APIProvider.openRouter.defaultModel)
        }

        var seen: Set<String> = []
        return candidates.filter { seen.insert($0).inserted }
    }

    private static func openRouterAPIError(statusCode: Int, body: String) -> OpenRouterChatServiceError {
        let messages = parsedMessages(from: body)
        let summary = readableSummary(statusCode: statusCode, body: body, messages: messages)
        let lowercasedBody = body.lowercased()
        let retryableProviderFailure = statusCode == 429 ||
            lowercasedBody.contains("rate-limit") ||
            lowercasedBody.contains("rate limit") ||
            lowercasedBody.contains("temporarily") ||
            lowercasedBody.contains("provider returned error") ||
            lowercasedBody.contains("unexpected end of data")

        return .apiError(
            statusCode: statusCode,
            body: body,
            summary: summary,
            isRetryableProviderFailure: retryableProviderFailure
        )
    }

    private static func parsedMessages(from body: String) -> [String] {
        guard let data = body.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data) else {
            return []
        }

        var messages: [String] = []
        collectMessages(from: object, into: &messages)
        return messages
    }

    private static func collectMessages(from value: Any, into messages: inout [String]) {
        if let dictionary = value as? [String: Any] {
            if let message = dictionary["message"] as? String {
                messages.append(message)
            }

            if let provider = dictionary["provider_name"] as? String,
               let message = dictionary["message"] as? String {
                messages.append("\(provider): \(message)")
            }

            dictionary.values.forEach { collectMessages(from: $0, into: &messages) }
        } else if let array = value as? [Any] {
            array.forEach { collectMessages(from: $0, into: &messages) }
        }
    }

    private static func readableSummary(statusCode: Int, body: String, messages: [String]) -> String {
        let cleanMessages = messages
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        if let rateLimit = cleanMessages.first(where: { $0.localizedCaseInsensitiveContains("rate") }) {
            return rateLimit
        }

        if let providerMessage = cleanMessages.first(where: { $0.localizedCaseInsensitiveContains("provider") }) {
            return providerMessage
        }

        if let firstMessage = cleanMessages.first {
            return firstMessage
        }

        let trimmedBody = body.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmedBody.isEmpty == false else {
            return "OpenRouter returned HTTP \(statusCode) without details."
        }

        return String(trimmedBody.prefix(280))
    }
}

private struct OpenRouterToolCall {
    var id: String
    var name: String
    var argumentsJSON: String
}

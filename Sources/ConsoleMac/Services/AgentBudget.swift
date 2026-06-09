import Foundation

enum AgentBudget {
    static let maximumEstimatedInputTokens = 24_000
    static let maximumLocalFileCharacters = 14_000
    static let maximumMCPResultCharacters = 10_000
    static let maximumMCPToolDefinitions = 16

    static func latestUserText(in conversation: Conversation) -> String {
        conversation.messages.last(where: { $0.role == .user })?.plainText ?? ""
    }

    static func shouldExposeMCPTools(for query: String) -> Bool {
        let normalized = " \(query.lowercased()) "
        let keywords = [
            " github ", " gh ", " repo ", " repository ", " pull request ",
            " pr ", " issue ", " commit ", " branch ", " release ",
            " workflow ", " actions ", " ci ", " review "
        ]

        return keywords.contains { normalized.contains($0) }
    }

    static func estimatedTokens(forJSONObject object: Any) -> Int {
        guard JSONSerialization.isValidJSONObject(object),
              let data = try? JSONSerialization.data(withJSONObject: object) else {
            return max(1, "\(object)".count / 4)
        }

        return max(1, data.count / 4)
    }

    static func truncated(_ text: String, limit: Int) -> String {
        guard text.count > limit else { return text }
        let omitted = text.count - limit
        return String(text.prefix(limit)) + "\n\n[Console truncated \(omitted) characters to protect your token budget.]"
    }

    static func compactJSONString(_ value: Any, limit: Int = maximumMCPResultCharacters) -> (text: String, truncated: Bool) {
        let text: String
        if JSONSerialization.isValidJSONObject(value),
           let data = try? JSONSerialization.data(withJSONObject: value, options: [.sortedKeys]),
           let string = String(data: data, encoding: .utf8) {
            text = string
        } else {
            text = "\(value)"
        }

        guard text.count > limit else { return (text, false) }
        return (truncated(text, limit: limit), true)
    }

    static func estimatedOpenRouterInputTokens(messages: [[String: Any]], tools: [[String: Any]]) -> Int {
        estimatedTokens(forJSONObject: [
            "messages": messages,
            "tools": tools
        ])
    }

    static func estimatedOpenAIInputTokens(instructions: String, inputItems: [Any], tools: [[String: Any]]) -> Int {
        estimatedTokens(forJSONObject: [
            "instructions": instructions,
            "input": inputItems,
            "tools": tools
        ])
    }
}

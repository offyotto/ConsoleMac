import Foundation

enum AgentPromptBuilder {
    static func systemPromptText(
        preferences: AppPreferences,
        searchContext: String
    ) -> String {
        var lines = [
            "You are \(preferences.displayAssistantName), a coding assistant inside Console.",
            "Address the user as \(preferences.displayUserName).",
            responseStyleLine(for: preferences.responsePreference),
            "Be direct and practical. Keep answers useful first.",
            "Understand and respond naturally to casual language and informal phrasing.",
            "Use clear reasoning. Name uncertainty when it matters. Ask a clarifying question only when blocked.",
            "When code is involved, prefer concrete steps and working snippets. Flag potentially destructive operations before suggesting them.",
            "Do not claim to be Claude, Anthropic, OpenAI, or any other model brand.",
            "Console is a personal unsandboxed macOS app. Treat local file search snippets as real context, but do not invent files or claim to have read paths not shown."
        ]

        if preferences.apiAgentModeEnabled {
            lines.append("API agent mode may include web search and local file tools. Use tools when they improve the answer, and explain what changed after write operations.")
        }

        let customInstructions = preferences.customInstructions.trimmingCharacters(in: .whitespacesAndNewlines)
        if customInstructions.isEmpty == false {
            lines.append("User instructions: \(customInstructions)")
        }

        if searchContext.isEmpty == false {
            lines.append(searchContext)
        }

        let enabledMCPServers = preferences.mcpServers.filter(\.isEnabled)
        if enabledMCPServers.isEmpty == false {
            let serverNames = enabledMCPServers
                .map { "- \($0.name)" }
                .joined(separator: "\n")
            lines.append("""
            Configured MCP servers:
            \(serverNames)
            If a request needs an MCP tool not available in this turn, explain which configured server should handle it and what permission or action is needed.
            """)
        }

        return lines.joined(separator: "\n")
    }

    private static func responseStyleLine(for preference: ResponsePreference) -> String {
        switch preference {
        case .concise:
            return "Keep replies tight and high-signal unless the user asks for depth."
        case .balanced:
            return "Balance conciseness with practical detail."
        case .detailed:
            return "Give thorough, structured answers while staying clear."
        }
    }
}

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
            "Be warm, conversational, direct, and alive to the user's mood. Keep the answer useful first.",
            "Understand and naturally respond to modern casual language, including ngl, ykw, luv, awwww, :3, </3, lol, lmao, and stretched words for emphasis. Mirror the user's vibe lightly, but do not overdo slang.",
            "Use thoughtful reasoning: gather context, name uncertainty when it matters, ask a sharp clarifying question only when blocked, and become decisive once there is enough information.",
            "When code is involved, prefer concrete steps, working snippets, and verification. If something may be destructive, say so before suggesting it.",
            "Do not claim to be Claude, Anthropic, OpenAI, or any other model brand. You are Console's assistant.",
            "Console is a personal unsandboxed macOS app. Treat local file search snippets as real context, but do not invent files or claim to have read paths that are not shown."
        ]

        if preferences.apiAgentModeEnabled {
            lines.append("API agent mode may include web search and local file tools. Use tools when they materially improve the answer, and explain what changed after write operations.")
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
            If a request needs an MCP tool that is not available in this exact turn, explain which configured server should handle it and what permission, token, or user action is needed.
            """)
        }

        return lines.joined(separator: "\n")
    }

    private static func responseStyleLine(for preference: ResponsePreference) -> String {
        switch preference {
        case .concise:
            return "Keep replies tight and high-signal unless the user asks for depth."
        case .balanced:
            return "Balance friendliness with concise, practical detail."
        case .detailed:
            return "Give thorough, structured answers while staying conversational."
        }
    }
}

import Foundation

enum ResponsePreference: String, CaseIterable, Identifiable, Codable {
    case concise
    case balanced
    case detailed

    var id: String { rawValue }

    var title: String {
        switch self {
        case .concise:
            return "Concise"
        case .balanced:
            return "Balanced"
        case .detailed:
            return "Detailed"
        }
    }
}

enum ConversationRetentionPeriod: String, CaseIterable, Identifiable, Codable {
    case never
    case oneHour
    case oneDay
    case oneWeek
    case thirtyDays

    var id: String { rawValue }

    var title: String {
        switch self {
        case .never:
            return "Never"
        case .oneHour:
            return "1 hour"
        case .oneDay:
            return "24 hours"
        case .oneWeek:
            return "7 days"
        case .thirtyDays:
            return "30 days"
        }
    }

    var settingsSummary: String {
        switch self {
        case .never:
            return "Saved conversations stay until you delete them."
        default:
            return "Saved conversations are deleted after \(title.lowercased()) without activity."
        }
    }

    func expirationDate(from date: Date, calendar: Calendar = .current) -> Date? {
        switch self {
        case .never:
            return nil
        case .oneHour:
            return calendar.date(byAdding: .hour, value: 1, to: date)
        case .oneDay:
            return calendar.date(byAdding: .day, value: 1, to: date)
        case .oneWeek:
            return calendar.date(byAdding: .day, value: 7, to: date)
        case .thirtyDays:
            return calendar.date(byAdding: .day, value: 30, to: date)
        }
    }
}

enum APIProvider: String, CaseIterable, Identifiable, Codable {
    case openRouter
    case openAI

    var id: String { rawValue }

    var title: String {
        switch self {
        case .openRouter:
            return "OpenRouter"
        case .openAI:
            return "OpenAI"
        }
    }

    var defaultModel: String {
        switch self {
        case .openRouter:
            return "anthropic/claude-sonnet-4.5"
        case .openAI:
            return "gpt-5"
        }
    }

    var keychainAccount: String {
        switch self {
        case .openRouter:
            return "openrouter-api-key"
        case .openAI:
            return "openai-api-key"
        }
    }
}

struct SearchResourceBookmark: Identifiable, Hashable, Codable {
    let id: UUID
    var displayName: String
    var lastKnownPath: String
    var isDirectory: Bool
    var bookmarkData: Data?

    init(
        id: UUID = UUID(),
        displayName: String,
        lastKnownPath: String,
        isDirectory: Bool,
        bookmarkData: Data? = nil
    ) {
        self.id = id
        self.displayName = displayName
        self.lastKnownPath = lastKnownPath
        self.isDirectory = isDirectory
        self.bookmarkData = bookmarkData
    }

    static func homeDirectory() -> SearchResourceBookmark {
        let url = FileManager.default.homeDirectoryForCurrentUser
        return SearchResourceBookmark(
            displayName: "Home Folder",
            lastKnownPath: url.path,
            isDirectory: true
        )
    }
}

struct MCPServerConfig: Identifiable, Hashable, Codable {
    let id: UUID
    var name: String
    var endpoint: String
    var isEnabled: Bool

    init(
        id: UUID = UUID(),
        name: String,
        endpoint: String,
        isEnabled: Bool = true
    ) {
        self.id = id
        self.name = name
        self.endpoint = endpoint
        self.isEnabled = isEnabled
    }

    static let githubDockerName = "GitHub Docker MCP"
    static let githubDockerCommand = "GITHUB_PERSONAL_ACCESS_TOKEN=\"${GITHUB_PERSONAL_ACCESS_TOKEN:-$(gh auth token 2>/dev/null)}\" docker run -i --rm -e GITHUB_PERSONAL_ACCESS_TOKEN -e GITHUB_TOOLSETS=all ghcr.io/github/github-mcp-server"

    static var githubDockerDefault: MCPServerConfig {
        MCPServerConfig(
            name: githubDockerName,
            endpoint: githubDockerCommand,
            isEnabled: true
        )
    }

    var isGitHubDockerServer: Bool {
        name.localizedCaseInsensitiveContains("github") ||
        endpoint.localizedCaseInsensitiveContains("github-mcp-server")
    }
}

struct AppPreferences: Hashable, Codable {
    var hasCompletedOnboarding: Bool
    var hasSeededPersonalDefaults: Bool
    var userName: String
    var assistantName: String
    var responsePreference: ResponsePreference
    var keepCodeContext: Bool
    var saveTranscripts: Bool
    var customInstructions: String
    var defaultModelID: String?
    var conversationRetention: ConversationRetentionPeriod
    var agentSearchEnabled: Bool
    var fullFileSystemAccessEnabled: Bool
    var apiProvider: APIProvider
    var apiAgentModeEnabled: Bool
    var apiModel: String
    var apiWebSearchEnabled: Bool
    var apiLiveWebSearchEnabled: Bool
    var apiLocalFileToolsEnabled: Bool
    var apiFileWriteToolsEnabled: Bool
    var searchResources: [SearchResourceBookmark]
    var mcpServers: [MCPServerConfig]

    static let defaults = AppPreferences(
        hasCompletedOnboarding: false,
        hasSeededPersonalDefaults: true,
        userName: "",
        assistantName: "Console",
        responsePreference: .balanced,
        keepCodeContext: true,
        saveTranscripts: true,
        customInstructions: "",
        defaultModelID: nil,
        conversationRetention: .never,
        agentSearchEnabled: true,
        fullFileSystemAccessEnabled: true,
        apiProvider: .openRouter,
        apiAgentModeEnabled: false,
        apiModel: APIProvider.openRouter.defaultModel,
        apiWebSearchEnabled: true,
        apiLiveWebSearchEnabled: true,
        apiLocalFileToolsEnabled: true,
        apiFileWriteToolsEnabled: true,
        searchResources: [],
        mcpServers: [.githubDockerDefault]
    )

    init(
        hasCompletedOnboarding: Bool,
        hasSeededPersonalDefaults: Bool = false,
        userName: String,
        assistantName: String,
        responsePreference: ResponsePreference,
        keepCodeContext: Bool,
        saveTranscripts: Bool,
        customInstructions: String,
        defaultModelID: String?,
        conversationRetention: ConversationRetentionPeriod = .never,
        agentSearchEnabled: Bool = true,
        fullFileSystemAccessEnabled: Bool = true,
        apiProvider: APIProvider = .openRouter,
        apiAgentModeEnabled: Bool = false,
        apiModel: String = APIProvider.openRouter.defaultModel,
        apiWebSearchEnabled: Bool = true,
        apiLiveWebSearchEnabled: Bool = true,
        apiLocalFileToolsEnabled: Bool = true,
        apiFileWriteToolsEnabled: Bool = true,
        searchResources: [SearchResourceBookmark] = [],
        mcpServers: [MCPServerConfig] = []
    ) {
        self.hasCompletedOnboarding = hasCompletedOnboarding
        self.hasSeededPersonalDefaults = hasSeededPersonalDefaults
        self.userName = userName
        self.assistantName = assistantName
        self.responsePreference = responsePreference
        self.keepCodeContext = keepCodeContext
        self.saveTranscripts = saveTranscripts
        self.customInstructions = customInstructions
        self.defaultModelID = defaultModelID
        self.conversationRetention = conversationRetention
        self.agentSearchEnabled = agentSearchEnabled
        self.fullFileSystemAccessEnabled = fullFileSystemAccessEnabled
        self.apiProvider = apiProvider
        self.apiAgentModeEnabled = apiAgentModeEnabled
        self.apiModel = apiModel
        self.apiWebSearchEnabled = apiWebSearchEnabled
        self.apiLiveWebSearchEnabled = apiLiveWebSearchEnabled
        self.apiLocalFileToolsEnabled = apiLocalFileToolsEnabled
        self.apiFileWriteToolsEnabled = apiFileWriteToolsEnabled
        self.searchResources = searchResources
        self.mcpServers = mcpServers
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        hasCompletedOnboarding = try container.decodeIfPresent(Bool.self, forKey: .hasCompletedOnboarding) ?? false
        hasSeededPersonalDefaults = try container.decodeIfPresent(Bool.self, forKey: .hasSeededPersonalDefaults) ?? false
        userName = try container.decodeIfPresent(String.self, forKey: .userName) ?? ""
        assistantName = try container.decodeIfPresent(String.self, forKey: .assistantName) ?? "Console"
        responsePreference = try container.decodeIfPresent(ResponsePreference.self, forKey: .responsePreference) ?? .balanced
        keepCodeContext = try container.decodeIfPresent(Bool.self, forKey: .keepCodeContext) ?? true
        saveTranscripts = try container.decodeIfPresent(Bool.self, forKey: .saveTranscripts) ?? true
        customInstructions = try container.decodeIfPresent(String.self, forKey: .customInstructions) ?? ""
        defaultModelID = try container.decodeIfPresent(String.self, forKey: .defaultModelID)
        conversationRetention = try container.decodeIfPresent(ConversationRetentionPeriod.self, forKey: .conversationRetention) ?? .never
        agentSearchEnabled = try container.decodeIfPresent(Bool.self, forKey: .agentSearchEnabled) ?? true
        fullFileSystemAccessEnabled = try container.decodeIfPresent(Bool.self, forKey: .fullFileSystemAccessEnabled) ?? true
        apiProvider = try container.decodeIfPresent(APIProvider.self, forKey: .apiProvider) ?? .openRouter
        apiAgentModeEnabled = try container.decodeIfPresent(Bool.self, forKey: .apiAgentModeEnabled) ?? false
        apiModel = try container.decodeIfPresent(String.self, forKey: .apiModel) ?? apiProvider.defaultModel
        apiWebSearchEnabled = try container.decodeIfPresent(Bool.self, forKey: .apiWebSearchEnabled) ?? true
        apiLiveWebSearchEnabled = try container.decodeIfPresent(Bool.self, forKey: .apiLiveWebSearchEnabled) ?? true
        apiLocalFileToolsEnabled = try container.decodeIfPresent(Bool.self, forKey: .apiLocalFileToolsEnabled) ?? true
        apiFileWriteToolsEnabled = try container.decodeIfPresent(Bool.self, forKey: .apiFileWriteToolsEnabled) ?? true
        searchResources = try container.decodeIfPresent([SearchResourceBookmark].self, forKey: .searchResources) ?? []
        mcpServers = try container.decodeIfPresent([MCPServerConfig].self, forKey: .mcpServers) ?? []
    }

    var displayUserName: String {
        let trimmed = userName.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "You" : trimmed
    }

    var displayAssistantName: String {
        let trimmed = assistantName.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "Console" : trimmed
    }

    var userInitials: String {
        let pieces = displayUserName
            .split(separator: " ")
            .prefix(2)
            .compactMap(\.first)
        let initials = String(pieces).uppercased()
        return initials.isEmpty ? "Y" : initials
    }
}

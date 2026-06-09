import Foundation

@MainActor
final class ConsoleStore: ObservableObject {
    @Published var conversations: [Conversation] {
        didSet { saveState() }
    }

    @Published var selectedItem: SidebarSelection?
    @Published var draft = ""
    @Published var temporaryConversation: Conversation
    @Published var isGeneratingResponse = false
    @Published private(set) var apiKeyAvailable = APIKeyStore.apiKeyExists(for: .openRouter)
    @Published private(set) var openRouterModels = OpenRouterModel.fallbackModels
    @Published private(set) var isLoadingOpenRouterModels = false
    @Published private(set) var openRouterModelsError: String?
    @Published private(set) var commandPaletteRequestID = 0

    @Published var preferences: AppPreferences {
        didSet { saveState() }
    }

    @Published var models: [LocalModel] {
        didSet { saveState() }
    }

    private let stateKey = "ConsoleMac.State.v1"
    private var modelLoadTasks: [String: Task<Void, Never>] = [:]
    private var responseAnimationTasks: [Message.ID: Task<Void, Never>] = [:]
    private var retentionTimer: Timer?


    init() {
        temporaryConversation = Self.makeTemporaryConversation()

        if let state = Self.loadState(key: stateKey) {
            conversations = state.conversations
            preferences = state.preferences
            models = Self.mergedModels(savedModels: state.models)
        } else {
            conversations = []
            preferences = .defaults
            models = LocalModel.catalog
        }

        selectedItem = conversations.first.map { .conversation($0.id) } ?? .models
        let repairedPersonalDefaults = normalizePersonalDefaults()
        let repairedCachedModels = repairCachedModelState()
        normalizeDefaultModel()
        refreshAPIKeyAvailability()
        purgeExpiredConversations()
        startRetentionTimer()
        if repairedPersonalDefaults || repairedCachedModels {
            saveState()
        }

        refreshOpenRouterModels()
    }

    var selectedConversationID: Conversation.ID? {
        get {
            if case .conversation(let id) = selectedItem {
                return id
            }
            return nil
        }
        set {
            selectedItem = newValue.map(SidebarSelection.conversation)
        }
    }

    var selectedConversation: Conversation? {
        if case .temporaryChat = selectedItem {
            return temporaryConversation
        }

        guard let selectedConversationID else { return nil }
        return conversations.first { $0.id == selectedConversationID }
    }

    var isTemporaryChatSelected: Bool {
        if case .temporaryChat = selectedItem {
            return true
        }
        return false
    }

    var installedModels: [LocalModel] {
        models.filter { $0.status == .installed }
    }

    var selectedModel: LocalModel? {
        guard let defaultModelID = preferences.defaultModelID else {
            return installedModels.first
        }
        return installedModels.first { $0.id == defaultModelID }
    }

    var activeModelLabel: String {
        if preferences.apiAgentModeEnabled {
            return "\(preferences.apiProvider.title): \(resolvedAPIModelName)"
        }

        return selectedModel?.name ?? "Choose a model"
    }

    var canCompose: Bool {
        if preferences.apiAgentModeEnabled {
            return apiKeyAvailable
        }

        return selectedModel != nil
    }

    var canSendDraft: Bool {
        canCompose && !isGeneratingResponse && !draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var canExportSelectedConversation: Bool {
        selectedConversation?.messages.isEmpty == false
    }

    var canRetryLastResponse: Bool {
        canCompose && selectedConversation?.messages.contains { $0.role == .assistant } == true
    }

    var composerPlaceholder: String {
        if preferences.apiAgentModeEnabled {
            return apiKeyAvailable ? "Message \(resolvedAPIModelName)..." : "Add a \(preferences.apiProvider.title) API key in Settings..."
        }

        if let selectedModel {
            return "Message \(selectedModel.name)..."
        }
        return "Install a model to start..."
    }

    var retentionSummary: String {
        preferences.conversationRetention.settingsSummary
    }

    func conversation(id: UUID) -> Conversation? {
        conversations.first { $0.id == id }
    }

    func expirationDate(for conversation: Conversation) -> Date? {
        preferences.conversationRetention.expirationDate(from: conversation.updatedAt)
    }

    func expirationLabel(for conversation: Conversation) -> String? {
        guard let expirationDate = expirationDate(for: conversation) else { return nil }
        if expirationDate <= Date() {
            return "Expires soon"
        }
        return expirationDate.formatted(.relative(presentation: .numeric))
    }

    func conversations(in section: ConversationSection) -> [Conversation] {
        conversations
            .filter { $0.section == section }
            .sorted { $0.updatedAt > $1.updatedAt }
    }

    func showConversations() {
        selectedItem = .conversations
    }

    func showTemporaryChat() {
        selectedItem = .temporaryChat
        draft = ""
    }

    func resetTemporaryChat() {
        temporaryConversation = Self.makeTemporaryConversation()
        selectedItem = .temporaryChat
        draft = ""
    }

    func showModels() {
        selectedItem = .models
    }

    func requestCommandPalette() {
        commandPaletteRequestID += 1
    }

    func createConversation() {
        let conversation = Conversation(
            title: "New conversation",
            section: .today,
            messages: []
        )

        conversations.insert(conversation, at: 0)
        selectedItem = .conversation(conversation.id)
        draft = ""
    }

    func sendDraft() {
        let messageText = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !messageText.isEmpty, canCompose else { return }
        let selectedModel = selectedModel

        if case .temporaryChat = selectedItem {
            appendTemporaryMessage(messageText, model: selectedModel)
            return
        }

        if selectedConversationID == nil || selectedConversation == nil {
            createConversation()
        }

        guard let index = selectedIndex else { return }

        let userMessage = Message(
            role: .user,
            sender: preferences.displayUserName,
            blocks: [.paragraph(messageText)]
        )

        conversations[index].messages.append(userMessage)
        conversations[index].updatedAt = Date()
        conversations[index].section = .today

        if conversations[index].title == "New conversation" {
            conversations[index].title = Self.title(from: messageText)
        }

        let target = ResponseTarget.saved(conversations[index].id)
        let promptConversation = conversations[index]
        let responseID = appendAssistantPlaceholder(to: target)
        draft = ""
        generateAssistantResponse(
            target: target,
            responseID: responseID,
            promptConversation: promptConversation,
            model: selectedModel
        )
    }

    func copySelectedConversation() {
        guard let selectedConversation else { return }
        Pasteboard.copy(markdown(for: selectedConversation))
    }

    func exportSelectedConversation() {
        guard let selectedConversation else { return }
        FileAccessService.exportTranscript(
            title: selectedConversation.title,
            body: markdown(for: selectedConversation)
        )
    }

    func copy(_ message: Message) {
        Pasteboard.copy(message.plainText)
    }

    func export(_ message: Message) {
        FileAccessService.exportMessage(
            sender: message.sender,
            body: message.plainText
        )
    }

    func retry(_ message: Message) {
        guard message.role == .assistant else { return }
        guard canCompose else { return }
        let selectedModel = selectedModel

        if case .temporaryChat = selectedItem {
            var conversation = temporaryConversation
            guard let messageIndex = conversation.messages.firstIndex(where: { $0.id == message.id }) else { return }
            responseAnimationTasks[message.id]?.cancel()
            responseAnimationTasks[message.id] = nil
            conversation.messages[messageIndex].blocks = [.paragraph(Message.thinkingPlaceholderText)]
            conversation.updatedAt = Date()
            temporaryConversation = conversation

            var promptConversation = conversation
            promptConversation.messages = Array(conversation.messages.prefix(messageIndex))
            generateAssistantResponse(
                target: .temporary,
                responseID: message.id,
                promptConversation: promptConversation,
                model: selectedModel
            )
            return
        }

        guard let index = selectedIndex else { return }
        guard let messageIndex = conversations[index].messages.firstIndex(where: { $0.id == message.id }) else { return }
        responseAnimationTasks[message.id]?.cancel()
        responseAnimationTasks[message.id] = nil
        conversations[index].messages[messageIndex].blocks = [.paragraph(Message.thinkingPlaceholderText)]
        conversations[index].updatedAt = Date()

        var promptConversation = conversations[index]
        promptConversation.messages = Array(conversations[index].messages.prefix(messageIndex))
        generateAssistantResponse(
            target: .saved(conversations[index].id),
            responseID: message.id,
            promptConversation: promptConversation,
            model: selectedModel
        )
    }

    func selectModel(_ modelID: String) {
        guard models.contains(where: { $0.id == modelID && $0.status == .installed }) else { return }
        updatePreferences { preferences in
            preferences.defaultModelID = modelID
        }
    }

    func startModelDownload(_ modelID: String) {
        guard let index = models.firstIndex(where: { $0.id == modelID }) else { return }
        guard models[index].status != .installed, models[index].status != .downloading else { return }

        models[index].status = .downloading
        models[index].downloadProgress = 0.02
        models[index].downloadError = nil

        let model = models[index]
        let progressReporter = ModelDownloadProgressReporter(store: self, modelID: modelID)
        modelLoadTasks[modelID] = Task { [weak self, model, progressReporter] in
            do {
                try await LocalModelRuntime.download(model: model) { progress in
                    progressReporter.report(progress)
                }
                await MainActor.run {
                    self?.finishModelPreparation(modelID, error: nil)
                }
            } catch {
                await MainActor.run {
                    self?.finishModelPreparation(modelID, error: error)
                }
            }
        }
    }

    func removeModel(_ modelID: String) {
        guard let index = models.firstIndex(where: { $0.id == modelID }) else { return }
        modelLoadTasks[modelID]?.cancel()
        modelLoadTasks[modelID] = nil
        models[index].status = .notInstalled
        models[index].downloadProgress = 0
        models[index].downloadError = nil
        try? FileManager.default.removeItem(at: Self.localModelURL(for: models[index]))

        if preferences.defaultModelID == modelID {
            updatePreferences { preferences in
                preferences.defaultModelID = installedModels.first?.id
            }
        }
    }

    func updatePreferences(_ update: (inout AppPreferences) -> Void) {
        var copy = preferences
        let oldProvider = copy.apiProvider
        update(&copy)
        if oldProvider != copy.apiProvider,
           copy.apiModel.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
           copy.apiModel == oldProvider.defaultModel {
            copy.apiModel = copy.apiProvider.defaultModel
        }
        preferences = copy
        normalizeDefaultModel()
        purgeExpiredConversations()
        refreshAPIKeyAvailability()
    }

    func completeOnboarding(_ preferences: AppPreferences) {
        var next = preferences
        next.hasCompletedOnboarding = true
        Self.applyPersonalDefaults(to: &next)
        self.preferences = next
        normalizeDefaultModel()
    }

    func addSearchResourcesFromOpenPanel() {
        let resources = FileAccessService.pickSearchResources()
        guard resources.isEmpty == false else { return }

        updatePreferences { preferences in
            var existingPaths = Set(preferences.searchResources.map(\.lastKnownPath))
            for resource in resources where existingPaths.contains(resource.lastKnownPath) == false {
                preferences.searchResources.append(resource)
                existingPaths.insert(resource.lastKnownPath)
            }
            preferences.agentSearchEnabled = true
        }
    }

    func removeSearchResource(_ resourceID: SearchResourceBookmark.ID) {
        updatePreferences { preferences in
            preferences.searchResources.removeAll { $0.id == resourceID }
        }
    }

    func restoreGitHubDockerMCPServer() {
        updatePreferences { preferences in
            if let index = preferences.mcpServers.firstIndex(where: \.isGitHubDockerServer) {
                preferences.mcpServers[index].endpoint = MCPServerConfig.githubDockerCommand
                preferences.mcpServers[index].isEnabled = true
            } else {
                preferences.mcpServers.append(.githubDockerDefault)
            }
            preferences.hasSeededPersonalDefaults = true
        }
    }

    func addMCPServer(name: String, endpoint: String) {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedEndpoint = endpoint.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmedName.isEmpty == false, trimmedEndpoint.isEmpty == false else { return }

        updatePreferences { preferences in
            preferences.mcpServers.append(
                MCPServerConfig(name: trimmedName, endpoint: trimmedEndpoint)
            )
        }
    }

    func removeMCPServer(_ serverID: MCPServerConfig.ID) {
        updatePreferences { preferences in
            preferences.mcpServers.removeAll { $0.id == serverID }
        }
    }

    func setMCPServer(_ serverID: MCPServerConfig.ID, isEnabled: Bool) {
        updatePreferences { preferences in
            guard let index = preferences.mcpServers.firstIndex(where: { $0.id == serverID }) else { return }
            preferences.mcpServers[index].isEnabled = isEnabled
        }
    }

    func refreshAPIKeyAvailability() {
        apiKeyAvailable = APIKeyStore.apiKeyExists(for: preferences.apiProvider)
    }

    func refreshOpenRouterModels() {
        guard isLoadingOpenRouterModels == false else { return }
        isLoadingOpenRouterModels = true
        openRouterModelsError = nil

        Task {
            let result: Result<[OpenRouterModel], Error>
            do {
                result = .success(try await OpenRouterModelCatalogService.fetchModels())
            } catch {
                result = .failure(error)
            }

            await MainActor.run {
                self.isLoadingOpenRouterModels = false
                switch result {
                case .success(let models):
                    self.openRouterModels = models
                    self.openRouterModelsError = nil
                case .failure(let error):
                    self.openRouterModels = OpenRouterModelCatalogService.mergedModels(self.openRouterModels)
                    self.openRouterModelsError = error.localizedDescription
                }
            }
        }
    }

    func setAPIModel(from value: String) {
        updatePreferences { preferences in
            preferences.apiModel = OpenRouterModelCatalogService.normalizedModelID(from: value)
        }
    }

    fileprivate func updateDownloadProgress(_ modelID: String, progress: Double) {
        guard let index = models.firstIndex(where: { $0.id == modelID }),
              models[index].status == .downloading else { return }

        if progress.isFinite, progress > 0 {
            models[index].downloadProgress = max(models[index].downloadProgress, min(progress, 0.98))
        }
    }

    private func finishModelPreparation(_ modelID: String, error: Error?) {
        modelLoadTasks[modelID] = nil

        guard let index = models.firstIndex(where: { $0.id == modelID }) else { return }
        guard error == nil else {
            models[index].status = .notInstalled
            models[index].downloadProgress = 0
            models[index].downloadError = Self.modelDownloadFailureMessage(from: error)
            return
        }

        do {
            try Self.writeInstalledModelMarker(for: models[index])
            models[index].status = .installed
            models[index].downloadProgress = 1
            models[index].downloadError = nil

            if preferences.defaultModelID == nil {
                updatePreferences { preferences in
                    preferences.defaultModelID = modelID
                }
            }
        } catch {
            models[index].status = .notInstalled
            models[index].downloadProgress = 0
            models[index].downloadError = Self.modelDownloadFailureMessage(from: error)
        }
    }

    private func repairCachedModelState() -> Bool {
        var repairedAnyModel = false

        for index in models.indices where models[index].status != .installed {
            guard Self.hasCachedMLXSnapshot(for: models[index]) else { continue }

            do {
                try Self.writeInstalledModelMarker(for: models[index])
                models[index].status = .installed
                models[index].downloadProgress = 1
                models[index].downloadError = nil
                repairedAnyModel = true
            } catch {
                models[index].downloadError = Self.modelDownloadFailureMessage(from: error)
            }
        }

        return repairedAnyModel
    }

    private var selectedIndex: Int? {
        guard let selectedConversationID else { return nil }
        return conversations.firstIndex { $0.id == selectedConversationID }
    }

    private func appendTemporaryMessage(_ text: String, model: LocalModel?) {
        let userMessage = Message(
            role: .user,
            sender: preferences.displayUserName,
            blocks: [.paragraph(text)]
        )

        var conversation = temporaryConversation
        conversation.messages.append(userMessage)
        conversation.updatedAt = Date()
        temporaryConversation = conversation

        let promptConversation = temporaryConversation
        let responseID = appendAssistantPlaceholder(to: .temporary)
        draft = ""
        generateAssistantResponse(
            target: .temporary,
            responseID: responseID,
            promptConversation: promptConversation,
            model: model
        )
    }

    private func appendAssistantPlaceholder(to target: ResponseTarget) -> Message.ID {
        let message = Message(
            role: .assistant,
            sender: preferences.displayAssistantName,
            blocks: [.paragraph(Message.thinkingPlaceholderText)]
        )

        switch target {
        case .temporary:
            var conversation = temporaryConversation
            conversation.messages.append(message)
            conversation.updatedAt = Date()
            temporaryConversation = conversation
        case .saved(let conversationID):
            guard let index = conversations.firstIndex(where: { $0.id == conversationID }) else { return message.id }
            conversations[index].messages.append(message)
            conversations[index].updatedAt = Date()
        }

        return message.id
    }

    private func generateAssistantResponse(
        target: ResponseTarget,
        responseID: Message.ID,
        promptConversation: Conversation,
        model: LocalModel?
    ) {
        let preferences = preferences
        isGeneratingResponse = true

        Task { @MainActor [weak self] in
            guard let self else { return }

            do {
                if preferences.apiAgentModeEnabled {
                    switch preferences.apiProvider {
                    case .openAI:
                        // OpenAI Responses API does not stream yet — use non-streaming
                        // path and animate locally for a consistent feel.
                        let response = try await OpenAIResponsesService.generateResponse(
                            conversation: promptConversation,
                            preferences: preferences
                        )
                        self.applyFinalResponse(response, target: target, responseID: responseID)

                    case .openRouter:
                        // OpenRouter streams tokens live — feed each token directly into
                        // the message so the user sees words appear as they are generated.
                        var accumulated = ""
                        let finalResponse = try await OpenRouterChatService.streamResponse(
                            conversation: promptConversation,
                            preferences: preferences,
                            onToken: { [weak self] token in
                                guard let self else { return }
                                accumulated += token
                                let blocks = MessageBlock.markdownBlocks(from: accumulated)
                                _ = self.setAssistantResponseBlocks(blocks, target: target, responseID: responseID)
                            }
                        )
                        // Commit the fully assembled response to ensure the final parsed
                        // markdown (e.g. code fences that arrived mid-stream) is correct.
                        self.applyFinalResponse(finalResponse, target: target, responseID: responseID)
                    }
                } else if let model {
                    // Local MLX model — stream tokens directly (MLXRuntime already yields
                    // individual chunks).
                    let response = try await LocalModelRuntime.generateResponse(
                        model: model,
                        conversation: promptConversation,
                        preferences: preferences
                    )
                    self.applyFinalResponse(response, target: target, responseID: responseID)
                } else {
                    throw LocalModelRuntimeError.noModelSelected
                }
            } catch {
                let errorText = (error as? LocalizedError)?.errorDescription
                    ?? "The model failed to respond: \(error.localizedDescription)"
                self.applyFinalResponse(errorText, target: target, responseID: responseID)
            }

            self.responseAnimationTasks[responseID] = nil
            self.isGeneratingResponse = false
        }
    }

    /// Writes the completed response text into the message, applying full markdown parsing.
    private func applyFinalResponse(
        _ text: String,
        target: ResponseTarget,
        responseID: Message.ID
    ) {
        let blocks: [MessageBlock]
        if text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            blocks = [.paragraph("")]
        } else {
            blocks = MessageBlock.markdownBlocks(from: text)
        }
        _ = setAssistantResponseBlocks(blocks, target: target, responseID: responseID)
    }

    @discardableResult
    private func setAssistantResponseBlocks(
        _ blocks: [MessageBlock],
        target: ResponseTarget,
        responseID: Message.ID
    ) -> Bool {
        switch target {
        case .temporary:
            var conversation = temporaryConversation
            guard let messageIndex = conversation.messages.firstIndex(where: { $0.id == responseID }) else { return false }
            conversation.messages[messageIndex].blocks = blocks
            conversation.updatedAt = Date()
            temporaryConversation = conversation
        case .saved(let conversationID):
            guard let conversationIndex = conversations.firstIndex(where: { $0.id == conversationID }),
                  let messageIndex = conversations[conversationIndex].messages.firstIndex(where: { $0.id == responseID }) else { return false }
            conversations[conversationIndex].messages[messageIndex].blocks = blocks
            conversations[conversationIndex].updatedAt = Date()
        }

        return true
    }

    private func startRetentionTimer() {
        retentionTimer?.invalidate()
        retentionTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.purgeExpiredConversations()
            }
        }
    }

    private func purgeExpiredConversations(referenceDate: Date = Date()) {
        guard preferences.conversationRetention != .never else { return }

        let selectedID = selectedConversationID
        conversations.removeAll { conversation in
            guard let expirationDate = preferences.conversationRetention.expirationDate(from: conversation.updatedAt) else {
                return false
            }
            return expirationDate <= referenceDate
        }

        if let selectedID,
           conversations.contains(where: { $0.id == selectedID }) == false {
            selectedItem = conversations.first.map { .conversation($0.id) } ?? .conversations
        }
    }

    private func normalizeDefaultModel() {
        if let defaultModelID = preferences.defaultModelID,
           installedModels.contains(where: { $0.id == defaultModelID }) {
            return
        }

        if let firstInstalled = installedModels.first {
            preferences.defaultModelID = firstInstalled.id
        } else if preferences.defaultModelID != nil {
            preferences.defaultModelID = nil
        }
    }

    private var resolvedAPIModelName: String {
        let trimmedModel = preferences.apiModel.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmedModel.isEmpty ? preferences.apiProvider.defaultModel : trimmedModel
    }

    private func normalizePersonalDefaults() -> Bool {
        var next = preferences
        Self.applyPersonalDefaults(to: &next)
        Self.normalizeRemoteDefaults(to: &next)
        guard next != preferences else { return false }
        preferences = next
        return true
    }

    private static func applyPersonalDefaults(to preferences: inout AppPreferences) {
        guard preferences.hasSeededPersonalDefaults == false else { return }

        if preferences.mcpServers.contains(where: \.isGitHubDockerServer) == false {
            preferences.mcpServers.append(.githubDockerDefault)
        }

        if preferences.apiProvider == .openRouter,
           preferences.apiModel.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
           preferences.apiModel == APIProvider.openAI.defaultModel {
            preferences.apiModel = APIProvider.openRouter.defaultModel
        }

        preferences.hasSeededPersonalDefaults = true
    }

    private static func normalizeRemoteDefaults(to preferences: inout AppPreferences) {
        if let index = preferences.mcpServers.firstIndex(where: \.isGitHubDockerServer) {
            preferences.mcpServers[index].endpoint = MCPServerConfig.githubDockerCommand
            preferences.mcpServers[index].isEnabled = true
        }

        if preferences.apiProvider == .openRouter,
           preferences.apiModel.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
           preferences.apiModel == APIProvider.openAI.defaultModel {
            preferences.apiModel = APIProvider.openRouter.defaultModel
        }
    }

    private func markdown(for conversation: Conversation) -> String {
        conversation.messages
            .map { "\($0.sender):\n\($0.plainText)" }
            .joined(separator: "\n\n")
    }

    private func saveState() {
        let state = StoredState(
            conversations: conversations,
            preferences: preferences,
            models: models
        )

        guard let data = try? JSONEncoder().encode(state) else { return }
        UserDefaults.standard.set(data, forKey: stateKey)
    }

    private static func loadState(key: String) -> StoredState? {
        guard let data = UserDefaults.standard.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(StoredState.self, from: data)
    }

    private static func mergedModels(savedModels: [LocalModel]) -> [LocalModel] {
        var merged = LocalModel.catalog.map { catalogModel in
            var model = catalogModel
            if let saved = savedModels.first(where: { $0.id == catalogModel.id }) {
                let savedAsInstalled = saved.status == .installed && FileManager.default.fileExists(atPath: localModelURL(for: model).path)
                model.status = savedAsInstalled ? .installed : .notInstalled
                model.downloadProgress = savedAsInstalled ? 1 : 0
                model.downloadError = savedAsInstalled ? nil : saved.downloadError
            }
            return model
        }

        let catalogIDs = Set(LocalModel.catalog.map(\.id))
        merged.append(contentsOf: savedModels.filter { !catalogIDs.contains($0.id) })
        return merged
    }


    private static func title(from text: String) -> String {
        let words = text.split(separator: " ").prefix(6).joined(separator: " ")
        return words.isEmpty ? "New conversation" : words
    }

    private static func makeTemporaryConversation() -> Conversation {
        Conversation(
            title: "Temporary chat",
            section: .today,
            messages: []
        )
    }

    private static func createModelDirectoryIfNeeded() throws {
        try FileManager.default.createDirectory(
            at: modelStorageDirectory,
            withIntermediateDirectories: true
        )
    }

    private static func writeInstalledModelMarker(for model: LocalModel) throws {
        try createModelDirectoryIfNeeded()
        let destinationURL = localModelURL(for: model)
        let marker = Data(model.mlxModelID.utf8)
        try marker.write(to: destinationURL, options: .atomic)
    }

    private static func modelDownloadFailureMessage(from error: Error?) -> String {
        guard let error else {
            return "The model download could not be completed."
        }

        if let localizedError = error as? LocalizedError,
           let description = localizedError.errorDescription {
            return description
        }

        return error.localizedDescription
    }

    private static func hasCachedMLXSnapshot(for model: LocalModel) -> Bool {
        let fileManager = FileManager.default
        let repoDirectoryName = "models--\(model.mlxModelID.replacingOccurrences(of: "/", with: "--"))"

        return huggingFaceCacheRoots().contains { cacheRoot in
            let snapshotsDirectory = cacheRoot
                .appendingPathComponent(repoDirectoryName, isDirectory: true)
                .appendingPathComponent("snapshots", isDirectory: true)

            guard let snapshotURLs = try? fileManager.contentsOfDirectory(
                at: snapshotsDirectory,
                includingPropertiesForKeys: [.isDirectoryKey],
                options: [.skipsHiddenFiles]
            ) else {
                return false
            }

            return snapshotURLs.contains { snapshotURL in
                snapshotContainsUsableMLXModel(snapshotURL)
            }
        }
    }

    private static func snapshotContainsUsableMLXModel(_ snapshotURL: URL) -> Bool {
        let fileManager = FileManager.default
        guard let fileEnumerator = fileManager.enumerator(
            at: snapshotURL,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        ) else {
            return false
        }

        var hasWeights = false
        var hasConfig = false
        var hasTokenizer = false

        for case let fileURL as URL in fileEnumerator {
            guard fileManager.fileExists(atPath: fileURL.path) else { continue }

            switch fileURL.lastPathComponent {
            case "config.json":
                hasConfig = true
            case "tokenizer.json", "tokenizer_config.json":
                hasTokenizer = true
            default:
                if fileURL.pathExtension == "safetensors" {
                    hasWeights = true
                }
            }

            if hasWeights && hasConfig && hasTokenizer {
                return true
            }
        }

        return false
    }

    private static func huggingFaceCacheRoots() -> [URL] {
        var roots: [URL] = []

        if let hfHome = ProcessInfo.processInfo.environment["HF_HOME"],
           hfHome.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false {
            roots.append(URL(fileURLWithPath: hfHome).appendingPathComponent("hub", isDirectory: true))
        }

        if let cacheDirectory = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first {
            roots.append(cacheDirectory.appendingPathComponent("huggingface/hub", isDirectory: true))
        }

        roots.append(
            FileManager.default.homeDirectoryForCurrentUser
                .appendingPathComponent(".cache/huggingface/hub", isDirectory: true)
        )

        var seen = Set<String>()
        return roots.filter { seen.insert($0.standardizedFileURL.path).inserted }
    }

    private static func localModelURL(for model: LocalModel) -> URL {
        modelStorageDirectory.appendingPathComponent(model.localFilename)
    }

    private static var modelStorageDirectory: URL {
        let applicationSupport = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        )[0]
        return applicationSupport.appendingPathComponent("Console/Models", isDirectory: true)
    }
}

private enum ResponseTarget {
    case temporary
    case saved(UUID)
}

private struct StoredState: Codable {
    var conversations: [Conversation]
    var preferences: AppPreferences
    var models: [LocalModel]
}

private final class ModelDownloadProgressReporter: @unchecked Sendable {
    private weak var store: ConsoleStore?
    private let modelID: String

    @MainActor
    init(store: ConsoleStore, modelID: String) {
        self.store = store
        self.modelID = modelID
    }

    func report(_ progress: Progress) {
        let fractionCompleted = progress.fractionCompleted
        Task { @MainActor [weak store, modelID] in
            store?.updateDownloadProgress(modelID, progress: fractionCompleted)
        }
    }
}

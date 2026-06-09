import AppKit
import SwiftUI

struct ConsoleSettingsView: View {
    @ObservedObject var store: ConsoleStore
    @State private var mcpName = MCPServerConfig.githubDockerName
    @State private var mcpEndpoint = MCPServerConfig.githubDockerCommand
    @State private var apiKeyInput = ""
    @State private var apiKeyStatus = APIKeyStore.apiKeyExists(for: .openRouter) ? "Saved in Keychain" : "Not saved"
    @FocusState private var isAPIKeyFieldFocused: Bool

    var body: some View {
        TabView {
            Form {
                Section("Profile") {
                    TextField("What should the model call you?", text: binding(\.userName))
                    TextField("Model name", text: binding(\.assistantName))
                }

                Section("Response") {
                    Picker("Style", selection: binding(\.responsePreference)) {
                        ForEach(ResponsePreference.allCases) { preference in
                            Text(preference.title).tag(preference)
                        }
                    }
                    .pickerStyle(.segmented)
                }
            }
            .formStyle(.grouped)
            .padding(20)
            .tabItem {
                Label("Profile", systemImage: "person.crop.circle")
            }

            Form {
                Section("API Agent") {
                    Toggle("Use API agent mode", isOn: binding(\.apiAgentModeEnabled))
                    Picker("Provider", selection: binding(\.apiProvider)) {
                        ForEach(APIProvider.allCases) { provider in
                            Text(provider.title).tag(provider)
                        }
                    }

                    if store.preferences.apiProvider == .openRouter {
                        Picker("Model", selection: binding(\.apiModel)) {
                            ForEach(openRouterPickerModels) { model in
                                Text(model.menuTitle).tag(model.id)
                            }
                        }

                        LabeledContent("Selected", value: store.preferences.apiModel)

                        TextField("Custom model slug or OpenRouter URL", text: apiModelTextBinding)

                        HStack {
                            Button {
                                store.refreshOpenRouterModels()
                            } label: {
                                Label(
                                    store.isLoadingOpenRouterModels ? "Refreshing..." : "Refresh Models",
                                    systemImage: "arrow.clockwise"
                                )
                            }
                            .disabled(store.isLoadingOpenRouterModels)

                            if let error = store.openRouterModelsError {
                                Text(error)
                                    .font(Typography.interface(11))
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }
                        }
                    } else {
                        TextField("Model", text: binding(\.apiModel))
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("\(store.preferences.apiProvider.title) API key")
                            .font(Typography.interface(13, .medium))

                        HStack(spacing: 8) {
                            SecureField("Paste \(store.preferences.apiProvider.title) API key here", text: $apiKeyInput)
                                .textFieldStyle(.roundedBorder)
                                .labelsHidden()
                                .frame(minWidth: 320, maxWidth: .infinity)
                                .focused($isAPIKeyFieldFocused)
                                .onSubmit {
                                    saveAPIKey()
                                }

                            Button {
                                pasteAPIKeyFromClipboard()
                            } label: {
                                Label("Paste", systemImage: "doc.on.clipboard")
                            }

                            Button {
                                saveAPIKey()
                            } label: {
                                Label("Save Key", systemImage: "key")
                            }
                            .buttonStyle(.borderedProminent)

                            Button {
                                removeAPIKey()
                            } label: {
                                Label("Remove Key", systemImage: "trash")
                            }
                        }
                    }

                    LabeledContent("Key status", value: apiKeyStatus)
                }

                Section("Hosted Tools") {
                    Toggle("Web search", isOn: binding(\.apiWebSearchEnabled))
                    Toggle("Live web access", isOn: binding(\.apiLiveWebSearchEnabled))
                        .disabled(!store.preferences.apiWebSearchEnabled)
                    Toggle("Local file tools", isOn: binding(\.apiLocalFileToolsEnabled))
                    Toggle("Allow file write tools", isOn: binding(\.apiFileWriteToolsEnabled))
                        .disabled(!store.preferences.apiLocalFileToolsEnabled)
                }
            }
            .formStyle(.grouped)
            .padding(20)
            .tabItem {
                Label("API", systemImage: "network")
            }

            Form {
                Section("Default Model") {
                    Picker("Model", selection: defaultModelBinding) {
                        Text("None").tag("")
                        ForEach(store.installedModels) { model in
                            Text(model.name).tag(model.id)
                        }
                    }
                    .disabled(store.installedModels.isEmpty)

                    Button {
                        store.showModels()
                    } label: {
                        HStack(spacing: 7) {
                            ConsoleSymbolView(asset: .models, size: 14)
                            Text("Manage Models")
                        }
                    }
                }
            }
            .formStyle(.grouped)
            .padding(20)
            .tabItem {
                ConsoleSymbolView(asset: .models, size: 16)
                Text("Models")
            }

            Form {
                Section("Behavior") {
                    Toggle("Keep code context with new prompts", isOn: binding(\.keepCodeContext))
                    Toggle("Save transcripts on this Mac", isOn: binding(\.saveTranscripts))
                }

                Section("Custom Instructions") {
                    TextEditor(text: binding(\.customInstructions))
                        .font(Typography.interface(13))
                        .frame(minHeight: 150)
                }
            }
            .formStyle(.grouped)
            .padding(20)
            .tabItem {
                Label("Instructions", systemImage: "text.alignleft")
            }

            Form {
                Section("Agent Search") {
                    Toggle("Search local files before responding", isOn: binding(\.agentSearchEnabled))
                    Toggle("Use full Mac file access", isOn: binding(\.fullFileSystemAccessEnabled))

                    LabeledContent(
                        "Default scope",
                        value: store.preferences.fullFileSystemAccessEnabled ? "Home folder" : "Selected sources"
                    )
                }

                Section("Extra Sources") {
                    Button {
                        store.addSearchResourcesFromOpenPanel()
                    } label: {
                        Label("Add Files or Folders", systemImage: "folder.badge.plus")
                    }

                    if store.preferences.searchResources.isEmpty {
                        LabeledContent("Search sources", value: "None")
                    } else {
                        ForEach(store.preferences.searchResources) { resource in
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(resource.displayName)
                                        .font(Typography.interface(13, .medium))
                                    Text(resource.lastKnownPath)
                                        .font(Typography.interface(11))
                                        .foregroundStyle(.secondary)
                                        .lineLimit(1)
                                }

                                Spacer()

                                Button {
                                    store.removeSearchResource(resource.id)
                                } label: {
                                    Image(systemName: "minus.circle")
                                }
                                .buttonStyle(.borderless)
                                .help("Remove")
                            }
                        }
                    }
                }
            }
            .formStyle(.grouped)
            .padding(20)
            .tabItem {
                Label("Files", systemImage: "magnifyingglass")
            }

            Form {
                Section("MCP Servers") {
                    TextField("Name", text: $mcpName)
                    TextField("Endpoint or Docker command", text: $mcpEndpoint)

                    HStack {
                        Button {
                            store.addMCPServer(name: mcpName, endpoint: mcpEndpoint)
                            mcpName = ""
                            mcpEndpoint = ""
                        } label: {
                            Label("Add MCP Server", systemImage: "plus")
                        }
                        .disabled(mcpName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || mcpEndpoint.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                        Button {
                            store.restoreGitHubDockerMCPServer()
                            mcpName = MCPServerConfig.githubDockerName
                            mcpEndpoint = MCPServerConfig.githubDockerCommand
                        } label: {
                            Label("Restore GitHub Docker", systemImage: "arrow.clockwise")
                        }
                    }

                    if store.preferences.mcpServers.isEmpty {
                        LabeledContent("Configured servers", value: "None")
                    } else {
                        ForEach(store.preferences.mcpServers) { server in
                            HStack {
                                Toggle(isOn: mcpEnabledBinding(server.id)) {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(server.name)
                                            .font(Typography.interface(13, .medium))
                                        Text(server.endpoint)
                                            .font(Typography.interface(11))
                                            .foregroundStyle(.secondary)
                                            .lineLimit(2)
                                    }
                                }

                                Spacer()

                                Button {
                                    store.removeMCPServer(server.id)
                                } label: {
                                    Image(systemName: "minus.circle")
                                }
                                .buttonStyle(.borderless)
                                .help("Remove")
                            }
                        }
                    }
                }
            }
            .formStyle(.grouped)
            .padding(20)
            .tabItem {
                Label("MCP", systemImage: "point.3.connected.trianglepath.dotted")
            }

            Form {
                Section("Conversation Cleanup") {
                    Picker("Delete after", selection: binding(\.conversationRetention)) {
                        ForEach(ConversationRetentionPeriod.allCases) { period in
                            Text(period.title).tag(period)
                        }
                    }

                    LabeledContent("Applies to", value: "Saved conversations")
                    LabeledContent("Current policy", value: store.retentionSummary)
                }
            }
            .formStyle(.grouped)
            .padding(20)
            .tabItem {
                ConsoleSymbolView(asset: .retention, size: 16)
                Text("Cleanup")
            }
        }
        .frame(width: 700, height: 500)
        .onAppear {
            refreshAPIKeyStatus()
            store.refreshAPIKeyAvailability()
        }
        .onChange(of: store.preferences.apiProvider) {
            apiKeyInput = ""
            refreshAPIKeyStatus()
            store.refreshAPIKeyAvailability()
        }
    }

    private func binding<Value>(_ keyPath: WritableKeyPath<AppPreferences, Value>) -> Binding<Value> {
        Binding(
            get: { store.preferences[keyPath: keyPath] },
            set: { value in
                store.updatePreferences { preferences in
                    preferences[keyPath: keyPath] = value
                }
            }
        )
    }

    private var defaultModelBinding: Binding<String> {
        Binding(
            get: { store.preferences.defaultModelID ?? "" },
            set: { value in
                store.updatePreferences { preferences in
                    preferences.defaultModelID = value.isEmpty ? nil : value
                }
            }
        )
    }

    private var apiModelTextBinding: Binding<String> {
        Binding(
            get: { store.preferences.apiModel },
            set: { value in
                store.setAPIModel(from: value)
            }
        )
    }

    private var openRouterPickerModels: [OpenRouterModel] {
        let models = OpenRouterModelCatalogService.mergedModels(store.openRouterModels)
        if models.contains(where: { $0.id == store.preferences.apiModel }) {
            return models
        }

        let customModel = OpenRouterModel(
            id: store.preferences.apiModel,
            name: store.preferences.apiModel,
            contextLength: nil,
            promptPrice: nil,
            completionPrice: nil
        )

        return [customModel] + models
    }

    private func mcpEnabledBinding(_ serverID: MCPServerConfig.ID) -> Binding<Bool> {
        Binding(
            get: {
                store.preferences.mcpServers.first(where: { $0.id == serverID })?.isEnabled ?? false
            },
            set: { isEnabled in
                store.setMCPServer(serverID, isEnabled: isEnabled)
            }
        )
    }

    private func saveAPIKey() {
        let trimmedKey = apiKeyInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmedKey.isEmpty == false else {
            apiKeyStatus = "Paste or type a key first"
            isAPIKeyFieldFocused = true
            NSSound.beep()
            return
        }

        do {
            try APIKeyStore.saveAPIKey(trimmedKey, for: store.preferences.apiProvider)
            guard let savedKey = try APIKeyStore.loadAPIKey(for: store.preferences.apiProvider),
                  savedKey == trimmedKey else {
                throw APIKeyStoreError.verificationFailed
            }

            apiKeyInput = ""
            apiKeyStatus = "Saved \(store.preferences.apiProvider.title) key in Keychain"
            store.refreshAPIKeyAvailability()
            if store.preferences.apiProvider == .openRouter {
                store.refreshOpenRouterModels()
            }
        } catch {
            apiKeyStatus = error.localizedDescription
            NSSound.beep()
        }
    }

    private func pasteAPIKeyFromClipboard() {
        let pastedKey = NSPasteboard.general.string(forType: .string)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        guard pastedKey.isEmpty == false else {
            apiKeyStatus = "Clipboard is empty"
            isAPIKeyFieldFocused = true
            NSSound.beep()
            return
        }

        apiKeyInput = pastedKey
        apiKeyStatus = "Ready to save \(store.preferences.apiProvider.title) key"
        isAPIKeyFieldFocused = true
    }

    private func removeAPIKey() {
        APIKeyStore.deleteAPIKey(for: store.preferences.apiProvider)
        apiKeyInput = ""
        apiKeyStatus = "Removed"
        store.refreshAPIKeyAvailability()
    }

    private func refreshAPIKeyStatus() {
        apiKeyStatus = APIKeyStore.apiKeyExists(for: store.preferences.apiProvider) ? "Saved in Keychain" : "Not saved"
    }
}

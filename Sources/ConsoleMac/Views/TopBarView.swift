import AppKit
import SwiftUI

struct TopBarView: View {
    @ObservedObject var store: ConsoleStore

    var body: some View {
        HStack(spacing: 12) {
            Menu {
                if store.preferences.apiAgentModeEnabled {
                    Button("API Agent Mode Enabled") {}
                        .disabled(true)

                    Button("Use Local Model Mode") {
                        store.updatePreferences { preferences in
                            preferences.apiAgentModeEnabled = false
                        }
                    }

                    Divider()
                }

                if store.installedModels.isEmpty {
                    Button("Download a Model...") {
                        store.showModels()
                    }
                } else {
                    ForEach(store.installedModels) { model in
                        Button {
                            store.selectModel(model.id)
                        } label: {
                            HStack {
                                if store.selectedModel?.id == model.id {
                                    Image(systemName: "checkmark")
                                }
                                Text(model.name)
                            }
                        }
                    }
                }

                Divider()
                Button(store.preferences.apiAgentModeEnabled ? "API Settings..." : "Use API Agent Mode...") {
                    store.updatePreferences { preferences in
                        preferences.apiAgentModeEnabled = true
                    }
                    NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
                }

                Button("Manage Models...") {
                    store.showModels()
                }
            } label: {
                HStack(spacing: 7) {
                    Circle()
                        .fill(store.canCompose ? Color.primary : Theme.tertiaryText)
                        .frame(width: 6, height: 6)

                    Text(store.activeModelLabel)
                        .font(Typography.interface(12, .medium))
                        .lineLimit(1)

                    Image(systemName: "chevron.down")
                        .font(.system(size: 9, weight: .bold))
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(.thinMaterial, in: Capsule())
                .overlay {
                    Capsule()
                        .stroke(Theme.separator.opacity(0.55), lineWidth: 1)
                }
            }
            .menuStyle(.button)
            .buttonStyle(.plain)

            Spacer()

            Button {
                store.addSearchResourcesFromOpenPanel()
            } label: {
                Image(systemName: "magnifyingglass")
            }
            .buttonStyle(ToolbarIconButtonStyle())
            .help("Add Search Files")

            Button {
                store.showModels()
            } label: {
                ConsoleSymbolView(asset: .models, size: 15)
            }
            .buttonStyle(ToolbarIconButtonStyle())
            .help("Models")

            Button {
                store.copySelectedConversation()
            } label: {
                Image(systemName: "doc.on.doc")
            }
            .buttonStyle(ToolbarIconButtonStyle())
            .disabled(!store.canExportSelectedConversation)
            .help("Copy Conversation")

            Menu {
                if case .temporaryChat = store.selectedItem {
                    Button("Clear Temporary Chat") {
                        store.resetTemporaryChat()
                    }
                    Divider()
                }

                Button("Retry Last Response") {
                    if let message = store.selectedConversation?.messages.last(where: { $0.role == .assistant }) {
                        store.retry(message)
                    }
                }
                .disabled(!store.canRetryLastResponse)

                Button("Export Transcript") {
                    store.exportSelectedConversation()
                }
                .disabled(!store.canExportSelectedConversation)
            } label: {
                Image(systemName: "ellipsis")
            }
            .menuStyle(.button)
            .buttonStyle(ToolbarIconButtonStyle())
            .help("More")
        }
        .padding(.horizontal, 24)
        .frame(height: 52)
        .background(.bar)
    }
}

struct ToolbarIconButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 14, weight: .medium))
            .foregroundStyle(buttonForeground(isPressed: configuration.isPressed))
            .frame(width: 30, height: 30)
            .background {
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(configuration.isPressed ? Theme.subtleFill : Color.clear)
            }
    }

    private func buttonForeground(isPressed: Bool) -> some ShapeStyle {
        if !isEnabled {
            return AnyShapeStyle(Theme.tertiaryText.opacity(0.55))
        }

        return AnyShapeStyle(isPressed ? Color.primary : Theme.secondaryText)
    }
}

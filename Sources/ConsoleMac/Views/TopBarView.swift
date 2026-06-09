import AppKit
import SwiftUI

struct TopBarView: View {
    @ObservedObject var store: ConsoleStore
    @Binding var showCommandPalette: Bool
    @Binding var showShortcutsSheet: Bool
    @Environment(\.openConsoleSettings) private var openConsoleSettings

    var body: some View {
        HStack(spacing: 12) {
            modelPicker

            statusPill

            Spacer()

            Button {
                showCommandPalette = true
            } label: {
                HStack(spacing: 5) {
                    Image(systemName: "command")
                        .font(.system(size: 10, weight: .semibold))
                    Text("K")
                        .font(.system(size: 10, weight: .bold))
                }
                .foregroundStyle(.secondary)
                .padding(.horizontal, 7)
                .padding(.vertical, 4)
                .background(Capsule().fill(Theme.subtleFill))
            }
            .buttonStyle(PressableButtonStyle())
            .help("Quick switch (⌘K)")

            Button {
                store.addSearchResourcesFromOpenPanel()
            } label: {
                Image(systemName: "paperclip")
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
                ToastCenter.shared.show("Conversation copied", icon: "doc.on.doc.fill")
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
                        ToastCenter.shared.show("Cleared", icon: "trash")
                    }
                    Divider()
                }

                Button("Retry Last Response") {
                    if let message = store.selectedConversation?.messages.last(where: { $0.role == .assistant }) {
                        store.retry(message)
                    }
                }
                .disabled(!store.canRetryLastResponse)

                Button("Export Transcript…") {
                    store.exportSelectedConversation()
                }
                .disabled(!store.canExportSelectedConversation)

                if case .conversation(let id) = store.selectedItem,
                   store.conversation(id: id) != nil {
                    Divider()
                    Button(store.isPinned(id) ? "Unpin Conversation" : "Pin Conversation") {
                        store.togglePin(id)
                    }
                    Button("Delete Conversation", role: .destructive) {
                        store.deleteConversation(id)
                        ToastCenter.shared.show("Conversation deleted", icon: "trash")
                    }
                }

                Divider()
                Button("Keyboard Shortcuts…") {
                    showShortcutsSheet = true
                }
                .keyboardShortcut("/", modifiers: [.command])
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

    // MARK: - Model picker

    private var modelPicker: some View {
        Menu {
            if store.preferences.apiAgentModeEnabled {
                Button("API Agent Mode Enabled") {}.disabled(true)
                Button("Use Local Model Mode") {
                    store.updatePreferences { $0.apiAgentModeEnabled = false }
                }
                Divider()
            }

            if store.installedModels.isEmpty {
                Button("Download a Model…") { store.showModels() }
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
            Button(store.preferences.apiAgentModeEnabled ? "API Settings…" : "Use API Agent Mode…") {
                store.updatePreferences { $0.apiAgentModeEnabled = true }
                openConsoleSettings()
            }
            Button("Manage Models…") { store.showModels() }
        } label: {
            HStack(spacing: 7) {
                ZStack {
                    Circle()
                        .fill(store.canCompose ? Theme.accent : Theme.tertiaryText)
                        .frame(width: 7, height: 7)
                    if store.canCompose {
                        Circle()
                            .stroke(Theme.accent.opacity(0.35), lineWidth: 4)
                            .frame(width: 7, height: 7)
                    }
                }

                Text(store.activeModelLabel)
                    .font(Typography.interface(12, .medium))
                    .lineLimit(1)

                Image(systemName: "chevron.down")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 11)
            .padding(.vertical, 6)
            .background(Capsule().fill(.thinMaterial))
            .overlay(Capsule().stroke(Theme.separator.opacity(0.55), lineWidth: 1))
        }
        .menuStyle(.button)
        .buttonStyle(.plain)
    }

    // MARK: - Status pill

    @ViewBuilder
    private var statusPill: some View {
        if store.isGeneratingResponse {
            HStack(spacing: 5) {
                TimelineView(.animation(minimumInterval: 1 / 30.0)) { ctx in
                    let t = ctx.date.timeIntervalSinceReferenceDate
                    Circle()
                        .fill(Theme.accent)
                        .frame(width: 6, height: 6)
                        .opacity(0.5 + (sin(t * 4.5) + 1) / 4)
                }
                Text("Generating")
                    .font(Typography.interface(10.5, .semibold))
                    .foregroundStyle(Theme.accent)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Capsule().fill(Theme.accent.opacity(0.12)))
            .transition(.opacity.combined(with: .scale))
        }
    }
}

struct ToolbarIconButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled
    @State private var hovering = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 14, weight: .medium))
            .foregroundStyle(buttonForeground(isPressed: configuration.isPressed))
            .frame(width: 30, height: 30)
            .background {
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(fillStyle(pressed: configuration.isPressed))
            }
            .scaleEffect(configuration.isPressed ? 0.95 : 1)
            .onHover { hovering = $0 }
            .animation(Theme.Motion.hover, value: hovering)
            .animation(Theme.Motion.snap, value: configuration.isPressed)
    }

    private func buttonForeground(isPressed: Bool) -> some ShapeStyle {
        if !isEnabled {
            return AnyShapeStyle(Theme.tertiaryText.opacity(0.55))
        }
        return AnyShapeStyle(isPressed ? Color.primary : (hovering ? Color.primary : Theme.secondaryText))
    }

    private func fillStyle(pressed: Bool) -> Color {
        if pressed { return Theme.subtleFill }
        return hovering ? Theme.hoverFill : Color.clear
    }
}

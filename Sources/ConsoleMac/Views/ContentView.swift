import AppKit
import SwiftUI

struct ContentView: View {
    @ObservedObject var store: ConsoleStore

    @State private var showCommandPalette = false
    @State private var showShortcutsSheet = false
    @State private var showSettings = false

    var body: some View {
        NavigationSplitView {
            SidebarView(store: store)
                .navigationSplitViewColumnWidth(min: 220, ideal: 256, max: 320)
        } detail: {
            detailView
        }
        .navigationSplitViewStyle(.balanced)
        .environment(\.openConsoleSettings) {
            showSettings = true
        }
        .overlay { ToastOverlay() }
        .overlay { commandPaletteOverlay }
        .sheet(isPresented: onboardingBinding) {
            OnboardingView(store: store)
                .interactiveDismissDisabled()
        }
        .sheet(isPresented: $showSettings) {
            ConsoleSettingsView(store: store)
                .frame(minWidth: 760, idealWidth: 820, minHeight: 560, idealHeight: 640)
        }
        .sheet(isPresented: $showShortcutsSheet) {
            KeyboardShortcutsView(isPresented: $showShortcutsSheet)
        }
        .onChange(of: store.commandPaletteRequestID) { _, _ in
            showCommandPalette = true
        }
        .background(
            VStack {
                Button("") { showCommandPalette = true }
                    .keyboardShortcut("k", modifiers: [.command])
                Button("") { showShortcutsSheet.toggle() }
                    .keyboardShortcut("/", modifiers: [.command])
                Button("") { showSettings = true }
                    .keyboardShortcut(",", modifiers: [.command])
            }
            .opacity(0)
            .frame(width: 0, height: 0)
            .accessibilityHidden(true)
        )
    }

    @ViewBuilder
    private var detailView: some View {
        switch store.selectedItem {
        case .temporaryChat:
            ConversationDetailView(
                store: store,
                showCommandPalette: $showCommandPalette,
                showShortcutsSheet: $showShortcutsSheet
            )
        case .models:
            ModelsView(store: store)
        case .conversation(let id) where store.conversation(id: id) != nil:
            ConversationDetailView(
                store: store,
                showCommandPalette: $showCommandPalette,
                showShortcutsSheet: $showShortcutsSheet
            )
        default:
            ConversationHomeView(store: store)
        }
    }

    @ViewBuilder
    private var commandPaletteOverlay: some View {
        if showCommandPalette {
            ZStack {
                Color.black.opacity(0.18)
                    .ignoresSafeArea()
                    .transition(.opacity)
                    .onTapGesture { showCommandPalette = false }

                CommandPaletteView(store: store, isPresented: $showCommandPalette)
                    .environment(\.openConsoleSettings) {
                        showSettings = true
                    }
                    .transition(.scale(scale: 0.96).combined(with: .opacity))
                    .padding(.top, 80)
                    .frame(maxHeight: .infinity, alignment: .top)
            }
            .animation(.spring(response: 0.32, dampingFraction: 0.82), value: showCommandPalette)
        }
    }

    private var onboardingBinding: Binding<Bool> {
        Binding(
            get: { !store.preferences.hasCompletedOnboarding },
            set: { _ in }
        )
    }
}

// MARK: - Home view

struct ConversationHomeView: View {
    @ObservedObject var store: ConsoleStore
    @Environment(\.openConsoleSettings) private var openConsoleSettings

    var body: some View {
        ZStack {
            Color(nsColor: .windowBackgroundColor)
                .ignoresSafeArea()

            LinearGradient(
                colors: [
                    Theme.accent.opacity(0.08),
                    Color.clear,
                    Theme.accent.opacity(0.04)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 24) {
                    Spacer(minLength: 24)
                    StartCard(store: store, openSettings: openConsoleSettings)

                    if store.canCompose {
                        QuickPromptsCard(store: store)
                    }

                    if !store.conversations.isEmpty {
                        RecentConversationsCard(store: store)
                    }

                    Spacer(minLength: 24)
                }
                .padding(.horizontal, 32)
                .frame(maxWidth: 760)
                .frame(maxWidth: .infinity)
            }
        }
    }
}

private struct StartCard: View {
    @ObservedObject var store: ConsoleStore
    let openSettings: () -> Void

    var body: some View {
        VStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(Theme.subtleFill)
                    .frame(width: 64, height: 64)
                    .overlay(Circle().stroke(Theme.separator.opacity(0.5), lineWidth: 0.5))
                TerminalIconView(size: 32)
                    .foregroundStyle(.primary.opacity(0.8))
            }

            VStack(spacing: 5) {
                Text(headingText)
                    .font(Typography.interface(22, .semibold))
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.center)

                Text(subtitleText)
                    .font(Typography.interface(13))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 440)
            }

            HStack(spacing: 10) {
                if store.canCompose {
                    Button {
                        store.createConversation()
                    } label: {
                        Label("New Conversation", systemImage: "square.and.pencil")
                            .padding(.horizontal, 4)
                            .padding(.vertical, 2)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .keyboardShortcut("n", modifiers: [.command])
                } else if store.preferences.apiAgentModeEnabled {
                    Button {
                        openSettings()
                    } label: {
                        Label("Open Settings", systemImage: "key")
                            .padding(.horizontal, 4)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                } else {
                    Button {
                        store.showModels()
                    } label: {
                        HStack(spacing: 7) {
                            ConsoleSymbolView(asset: .models, size: 14)
                            Text("Browse Models")
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                }

                Button {
                    store.showModels()
                } label: {
                    HStack(spacing: 7) {
                        ConsoleSymbolView(asset: .models, size: 14)
                        Text(store.preferences.apiAgentModeEnabled ? "Local Models" : "Models")
                    }
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
            }
        }
        .padding(.vertical, 28)
        .padding(.horizontal, 24)
        .frame(maxWidth: .infinity)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Theme.separator.opacity(0.6), lineWidth: 1)
        }
        .shadow(color: Color.black.opacity(0.04), radius: 14, x: 0, y: 6)
    }

    private var headingText: String {
        if store.canCompose {
            return "Console"
        }
        return store.preferences.apiAgentModeEnabled ? "Add an API key" : "Install a model"
    }

    private var subtitleText: String {
        if store.canCompose {
            return "Start a conversation, attach files for context, and pick up where you left off."
        }
        return store.preferences.apiAgentModeEnabled
            ? "Add a \(store.preferences.apiProvider.title) API key in Settings to get started."
            : "Install a local model from the Models tab to get started."
    }
}

private struct QuickPromptsCard: View {
    @ObservedObject var store: ConsoleStore

    private let columns = [GridItem(.adaptive(minimum: 220, maximum: 320), spacing: 10)]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Suggestions")
                    .font(Typography.interface(13, .semibold))
                Spacer()
                Text("Tap to start")
                    .font(Typography.interface(11))
                    .foregroundStyle(.secondary)
            }
            LazyVGrid(columns: columns, spacing: 10) {
                ForEach(ConsoleStore.suggestedPrompts) { suggestion in
                    QuickPromptTile(suggestion: suggestion) {
                        store.createConversation()
                        store.draft = suggestion.prompt
                    }
                }
            }
        }
        .padding(18)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Theme.separator.opacity(0.5), lineWidth: 1)
        )
    }
}

private struct QuickPromptTile: View {
    let suggestion: SuggestedPrompt
    let action: () -> Void

    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .fill(Theme.subtleFill)
                        .frame(width: 28, height: 28)
                    Image(systemName: suggestion.icon)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Theme.accent)
                }

                VStack(alignment: .leading, spacing: 1) {
                    Text(suggestion.title)
                        .font(Typography.interface(12.5, .semibold))
                        .foregroundStyle(.primary)
                    Text(suggestion.prompt)
                        .font(Typography.interface(10.5))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer(minLength: 0)
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(hovering ? Theme.hoverFill : Theme.subtleFill.opacity(0.6))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(Theme.separator.opacity(hovering ? 0.8 : 0.4), lineWidth: 0.5)
            )
        }
        .buttonStyle(PressableButtonStyle())
        .onHover { hovering = $0 }
        .animation(Theme.Motion.hover, value: hovering)
    }
}

private struct RecentConversationsCard: View {
    @ObservedObject var store: ConsoleStore

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Recent")
                    .font(Typography.interface(13, .semibold))
                Spacer()
                Button {
                    store.showConversations()
                } label: {
                    Text("Show all")
                        .font(Typography.interface(11, .medium))
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
            }

            VStack(spacing: 4) {
                ForEach(Array(store.conversations.sorted { $0.updatedAt > $1.updatedAt }.prefix(4))) { conversation in
                    RecentRow(conversation: conversation) {
                        store.selectedItem = .conversation(conversation.id)
                    }
                }
            }
        }
        .padding(18)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Theme.separator.opacity(0.5), lineWidth: 1)
        )
    }
}

private struct RecentRow: View {
    let conversation: Conversation
    let select: () -> Void

    @State private var hovering = false

    var body: some View {
        Button(action: select) {
            HStack(spacing: 10) {
                Image(systemName: conversation.isPinned ? "pin.fill" : "bubble.left")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
                    .frame(width: 16)

                VStack(alignment: .leading, spacing: 1) {
                    Text(conversation.displayTitle)
                        .font(Typography.interface(12.5, .medium))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                    if let last = conversation.messages.last {
                        Text(last.plainText)
                            .font(Typography.interface(11))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }

                Spacer()

                Text(conversation.updatedAt.formatted(.relative(presentation: .numeric)))
                    .font(Typography.interface(10.5))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(hovering ? Theme.hoverFill : Color.clear)
        )
        .onHover { hovering = $0 }
        .animation(Theme.Motion.hover, value: hovering)
    }
}

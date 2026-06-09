import AppKit
import SwiftUI

struct ContentView: View {
    @ObservedObject var store: ConsoleStore

    @State private var showCommandPalette = false
    @State private var showShortcutsSheet = false

    var body: some View {
        NavigationSplitView {
            SidebarView(store: store)
                .navigationSplitViewColumnWidth(min: 220, ideal: 256, max: 320)
        } detail: {
            detailView
        }
        .navigationSplitViewStyle(.balanced)
        .overlay { ToastOverlay() }
        .overlay { commandPaletteOverlay }
        .sheet(isPresented: onboardingBinding) {
            OnboardingView(store: store)
                .interactiveDismissDisabled()
        }
        .sheet(isPresented: $showShortcutsSheet) {
            KeyboardShortcutsView(isPresented: $showShortcutsSheet)
        }
        .background(
            // Off-screen button to surface the ⌘/ shortcut globally.
            Button("") { showShortcutsSheet.toggle() }
                .keyboardShortcut("/", modifiers: [.command])
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

// MARK: - Home view (no conversation selected)

struct ConversationHomeView: View {
    @ObservedObject var store: ConsoleStore

    var body: some View {
        ZStack {
            Color(nsColor: .windowBackgroundColor)
                .ignoresSafeArea()

            // Soft ambient gradient background
            LinearGradient(
                colors: [
                    Theme.accent.opacity(0.10),
                    Color.clear,
                    Theme.accent.opacity(0.05)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 28) {
                    Spacer(minLength: 30)

                    GreetingCard(store: store)

                    if store.canCompose {
                        QuickPromptsCard(store: store)
                    }

                    if !store.conversations.isEmpty {
                        RecentConversationsCard(store: store)
                    }

                    Spacer(minLength: 30)
                }
                .padding(.horizontal, 32)
                .frame(maxWidth: 760)
                .frame(maxWidth: .infinity)
            }
        }
    }
}

private struct GreetingCard: View {
    @ObservedObject var store: ConsoleStore
    @State private var bob = false

    var body: some View {
        VStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(Theme.subtleFill)
                    .frame(width: 78, height: 78)
                    .overlay(Circle().stroke(Theme.separator.opacity(0.5), lineWidth: 0.5))
                TerminalIconView(size: 38)
                    .foregroundStyle(Theme.brandGradient)
                    .offset(y: bob ? -2 : 2)
            }
            .onAppear {
                withAnimation(Theme.Motion.drift) { bob.toggle() }
            }

            VStack(spacing: 6) {
                Text(greetingText)
                    .font(Typography.interface(26, .semibold))
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.center)

                Text(subtitleText)
                    .font(Typography.interface(13))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 480)
            }

            HStack(spacing: 10) {
                if store.canCompose {
                    Button {
                        store.createConversation()
                    } label: {
                        Label("New Conversation", systemImage: "square.and.pencil")
                            .font(Typography.interface(13, .medium))
                            .padding(.horizontal, 4)
                            .padding(.vertical, 2)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .keyboardShortcut("n", modifiers: [.command])
                } else if store.preferences.apiAgentModeEnabled {
                    Button {
                        NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
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
        .padding(.vertical, 32)
        .padding(.horizontal, 28)
        .frame(maxWidth: .infinity)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(Theme.separator.opacity(0.6), lineWidth: 1)
        }
        .shadow(color: Color.black.opacity(0.05), radius: 18, x: 0, y: 8)
    }

    private var greetingText: String {
        let name = store.preferences.displayUserName
        let salutation = nameOrFallback(name)
        if store.canCompose {
            return "\(timeBasedGreeting), \(salutation)"
        } else {
            return store.preferences.apiAgentModeEnabled ? "Add an API key" : "Install a model"
        }
    }

    private var subtitleText: String {
        if store.canCompose {
            return "Ask Console anything, attach context, and keep the thread ready for later."
        }
        return store.preferences.apiAgentModeEnabled
            ? "Save a \(store.preferences.apiProvider.title) API key in Settings before sending prompts."
            : "Choose a local coding model before sending prompts."
    }

    private var timeBasedGreeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5..<12: return "Good morning"
        case 12..<17: return "Good afternoon"
        case 17..<22: return "Good evening"
        default: return "Working late"
        }
    }

    private func nameOrFallback(_ name: String) -> String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty || trimmed == "You" ? "there" : trimmed.components(separatedBy: " ").first ?? trimmed
    }
}

private struct QuickPromptsCard: View {
    @ObservedObject var store: ConsoleStore

    private let columns = [GridItem(.adaptive(minimum: 220, maximum: 320), spacing: 10)]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: "sparkles")
                    .foregroundStyle(Theme.accent)
                Text("Quick prompts")
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
        .padding(20)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Theme.separator.opacity(0.55), lineWidth: 1)
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
                        .fill(Theme.accent.opacity(0.12))
                        .frame(width: 30, height: 30)
                    Image(systemName: suggestion.icon)
                        .font(.system(size: 13, weight: .medium))
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
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(hovering ? Theme.hoverFill : Theme.subtleFill.opacity(0.6))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(Theme.separator.opacity(hovering ? 0.9 : 0.4), lineWidth: 0.5)
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
                Image(systemName: "clock.arrow.circlepath")
                    .foregroundStyle(Theme.accent)
                Text("Recent conversations")
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
        .padding(20)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Theme.separator.opacity(0.55), lineWidth: 1)
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

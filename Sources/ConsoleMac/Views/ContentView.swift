import SwiftUI

struct ContentView: View {
    @ObservedObject var store: ConsoleStore

    var body: some View {
        NavigationSplitView {
            SidebarView(store: store)
                .navigationSplitViewColumnWidth(min: 220, ideal: 248, max: 300)
        } detail: {
            detailView
        }
        .navigationSplitViewStyle(.balanced)
        .sheet(isPresented: onboardingBinding) {
            OnboardingView(store: store)
                .interactiveDismissDisabled()
        }
    }

    @ViewBuilder
    private var detailView: some View {
        switch store.selectedItem {
        case .temporaryChat:
            ConversationDetailView(store: store)
        case .models:
            ModelsView(store: store)
        case .conversation(let id) where store.conversation(id: id) != nil:
            ConversationDetailView(store: store)
        default:
            ConversationHomeView(store: store)
        }
    }

    private var onboardingBinding: Binding<Bool> {
        Binding(
            get: { !store.preferences.hasCompletedOnboarding },
            set: { _ in }
        )
    }
}

private struct ConversationHomeView: View {
    @ObservedObject var store: ConsoleStore

    var body: some View {
        ZStack {
            Color(nsColor: .windowBackgroundColor)
                .ignoresSafeArea()

            VStack(spacing: 22) {
                Spacer()

                VStack(spacing: 14) {
                    ZStack {
                        Circle()
                            .fill(Theme.subtleFill)
                            .frame(width: 78, height: 78)
                        TerminalIconView(size: 38)
                            .foregroundStyle(.primary)
                    }

                    VStack(spacing: 8) {
                        Text(store.canCompose ? "Start a conversation" : setupTitle)
                            .font(Typography.interface(24, .semibold))
                            .foregroundStyle(.primary)

                        Text(store.canCompose ? "Ask Console anything, attach context, and keep the thread ready for later." : setupSubtitle)
                            .font(Typography.interface(14))
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: 420)
                    }

                    HStack(spacing: 10) {
                        if store.canCompose {
                            Button {
                                store.createConversation()
                            } label: {
                                Label("New Conversation", systemImage: "square.and.pencil")
                            }
                            .buttonStyle(.borderedProminent)
                        } else if store.preferences.apiAgentModeEnabled {
                            Button {
                                NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
                            } label: {
                                Label("Open Settings", systemImage: "key")
                            }
                            .buttonStyle(.borderedProminent)
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
                    }
                }
                .padding(32)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(Theme.separator.opacity(0.55), lineWidth: 1)
                }
                .shadow(color: Color.black.opacity(0.04), radius: 18, x: 0, y: 10)
                .padding(.horizontal, 24)

                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private var setupTitle: String {
        store.preferences.apiAgentModeEnabled ? "Add an API key" : "Install a model"
    }

    private var setupSubtitle: String {
        store.preferences.apiAgentModeEnabled
            ? "Save a \(store.preferences.apiProvider.title) API key in Settings before sending prompts."
            : "Choose a local coding model before sending prompts."
    }
}

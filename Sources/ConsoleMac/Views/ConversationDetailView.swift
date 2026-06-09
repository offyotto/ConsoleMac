import SwiftUI

struct ConversationDetailView: View {
    @ObservedObject var store: ConsoleStore
    @Binding var showCommandPalette: Bool
    @Binding var showShortcutsSheet: Bool

    var body: some View {
        VStack(spacing: 0) {
            TopBarView(
                store: store,
                showCommandPalette: $showCommandPalette,
                showShortcutsSheet: $showShortcutsSheet
            )

            Divider()

            if store.selectedConversation != nil {
                MessagesView(store: store)
                    .transition(.opacity)
            } else {
                EmptyConversationView()
            }

            ComposerView(store: store)
        }
        .background(Theme.windowBackground)
        .animation(.easeOut(duration: 0.18), value: store.selectedConversation?.id)
    }
}

private struct EmptyConversationView: View {
    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: "text.bubble")
                .font(.system(size: 32, weight: .light))
                .foregroundStyle(.secondary)
            Text("No conversation selected")
                .font(Typography.interface(16, .medium))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
